%% 水滴高速影像分析程式
%% initialize
clc
clear
close all
LoadPhantomLibraries();
RegisterPhantom(true);
% 匯入函數
libpath="D:\博士\研究\水滴\水滴實驗數據\程式\影像分析\functions"
addpath(libpath);

%% 參數設定
folderpath="D:\博士\研究\水滴\水滴實驗數據\實驗影片\已分析數據\20260911荷葉\荷葉\分離\data";
filename="20261010_test6_2X_10ul_10ms";
filepath=folderpath+"\"+filename+".cine";
filepath=char(filepath);
xlsxname = filename+".xlsx";
csvname = filename+".csv";
xlsxpath=folderpath+"\data\"+xlsxname;
csvpath=folderpath+"\data\"+csvname;

% bkstage=[F_first,F_start,F_roll,_F_pinch,F_last]和平移後的數據都計入了
bkstage_orig=readmatrix(xlsxpath,"Sheet","input parameters","Range","B:B") %目測抽斷階段分界幀數[rolloff, pinchoff]
for k=1:length(bkstage_orig)-1 %把沒有紀錄的位置視為同一個分界點
    if (isnan(bkstage_orig(k)))
        bkstage_orig(k)=bkstage_orig(k+1)
    end
end

%% 讀取檔案
[hres, cine] = PhNewCineFromFile(filepath); % only support input character array 'abc'
cineinfo=readcineinfo(cine);    %讀取檔案參數% 自動計算 dt (兩張分析影像之間的時間間隔)
real_fps=cineinfo.fps %影片幀率
dt_between_frames = 1/real_fps;
fprintf('分析間隔 dt = %.6f 秒\n', dt_between_frames);
% 關閉垂直翻轉 如此PhGetCineImage才會讀出正向的照片
p = libpointer('int32Ptr',false);
PhSetCineInfo(cine, PhFileConst.GCI_VFLIPVIEWACTIVE, p);
bkstage_frame=bkstage_orig-cineinfo.n_firstframe+1  %從第一幀開始編號為1=原始影片的幀數-第一幀的編號

% 比例尺
expparameter=split(filename,"_");
magnification=str2double(erase(expparameter(3),"X"))
calib_xlsx="D:\博士\研究\水滴\水滴實驗數據\顯微鏡頭放大倍率校正.xlsx";
sheetname=["針尖1280 720","針尖1024 512"];
[img2, origIm] = ReadCineFileImage(filepath,cineinfo.n_firstframe , 0);
if (isequal(size(img2),[720,1280]))
    sheetname="針尖1280 720";
    scalematrix=[readmatrix(calib_xlsx,"Range","K3:K11","Sheet",sheetname),readmatrix(calib_xlsx,"Range","M3:M11","Sheet",sheetname)];
    umpix=scalematrix(scalematrix(:,1)==magnification,2) %轉換為真實尺寸um/pixel
elseif (isequal(size(img2),[512,1024]))
    sheetname="針尖1024 512";
    scalematrix=[readmatrix(calib_xlsx,"Range","K3:K11","Sheet",sheetname),readmatrix(calib_xlsx,"Range","M3:M11","Sheet",sheetname)];
    umpix=scalematrix(scalematrix(:,1)==magnification,2) %轉換為真實尺寸um/pixel
else
    fprintf("比例尺不支援尺寸為"+num2str(size(img2))+"的圖片 比例尺設為1")
    umpix=1;
end

%% 取第一張點選地平線與裁切範圍
%用來選取ROI的參考圖片幀數，多於1張時會在不同區段使用不同ROI裁切。
% ex: testframe=[100,700] 100~700使用第一個ROI，700~使用第二個
testframes=[bkstage_orig(2)+1]; %原始座標
% testframes=[bkstage_orig(2),bkstage_orig(4)-50]; %原始座標
ROIcrop_range=zeros(length(testframes),2,2);
for k=1:length(testframes)
    [testimg,orgimg]=ReadCineFileImage(filepath,testframes(k),0);
    [temp_horizon,xmin, xmax, ymin, ymax]=crop_horizon_roi(testimg)
    ROIcrop_range(k,:,:)=[[xmin,ymin];[xmax,ymax]];
    if (k==1)
        glb_horizon=temp_horizon; %只取第一次的地平線為基準
    end

    % 未使用 將地平線兩點從原圖座標轉換成裁切後圖片座標
    loc_horizon(:,1) = glb_horizon(:,1) - xmin + 1;
    loc_horizon(:,2) = glb_horizon(:,2) - ymin + 1;

    img_crop = testimg(ROIcrop_range(k,1,2):ROIcrop_range(k,2,2), ROIcrop_range(k,1,1)  :ROIcrop_range(k,2,1));
    % img_crop = testimg(ymin:ymax, xmin:xmax);
    imshow(img_crop)
    fprintf('已設定 ROI 範圍：X[%d, %d], Y[%d, %d]\n', xmin, xmax, ymin, ymax);
end
%% 先擷取幾張測試效果
% 邊緣閾值參數
background_color=0  %黑底0 白底1
thresholdratio=0.7 %threshold=左上角背景值*thresholdratio+圖片最大值*(1-thresholdratio)

%分析幀數範圍1~n_totalframe
startframe=bkstage_frame(3)+40;

% 每幾幀分析一次
analyze_step=2;
% 建立空陣列
all_data_list = {};   % all_data_list{k} 第k個圖片的輪廓點table
data_counter = 0;
% 欲分析的幀數清單
frame_indices =  startframe : analyze_step : bkstage_frame(end-1);

h_waitbar = waitbar(0, '正在分析水滴輪廓...', 'Name', 'Processing Video');
ntmp=0
for k = frame_indices               %讀取idx_firstframe後的第k-1幀
    ntmp=ntmp+1
    data_counter=data_counter+1;    %分析的照片數
    curr_time = (bkstage_frame(end)-k)/real_fps;  %倒數秒數
    

    % 讀取該幀
    imageNo = cineinfo.n_firstframe + k - 1;    %換算回影片的原始幀數
    imgRange = get(libstruct('tagIMRANGE'));
    imgRange.First = imageNo;
    imgRange.Cnt   = 1;
    [HRES, pixels, imgHeader] = PhGetCineImage(cine, imgRange, cineinfo.imgSizeInBytes);
    pixels = ExtractImageMatrixFromImageBuffer(pixels,imgHeader);
    if IsColorHeader(imgHeader)
        samplespp = 3;
    else
        samplespp = 1;
    end
    bps = GetEffectiveBitsFromIH(imgHeader);

    [~, img] = ConstructMatlabImage( ...
        pixels, ...
        imgHeader.biWidth, ...
        imgHeader.biHeight, ...
        samplespp, ...
        bps);
    img=img*16;
    % imshow(img) %要加PhSetCineInfo(cine, PhFileConst.GCI_VFLIPVIEWACTIVE, p)否則畫面顛倒!! 
    % A. 根據 ROI 裁切
    %當前幀數使用的ROI
    % 找到testframes中小於等於k的最大值編號
    idx=max(1,sum(testframes-bkstage_orig(1)<=k)) %sum(testframes>=k)會是有幾個數字比k小
    xmin=ROIcrop_range(idx,1,1)
    xmax=ROIcrop_range(idx,2,1)    
    ymin=ROIcrop_range(idx,1,2)
    ymax=ROIcrop_range(idx,2,2)

    img_crop2 = img(ymin:ymax, xmin:xmax);
    % imshow(img_crop2)
    % B. 頻域低通濾波 (去除高頻雜訊)
    L=2 %波長下限，波長小於L的高頻會被濾除
    img_filt=lowpass_filter(img_crop2,L,0);
    
    % C. 提取輪廓
    %依據當下該幀的亮度決定閾值=圖片左上角(背景)平均*ratio+max(img_filt)*(1-ratio)
    show_flag = (mod(k,1) == 0);
    % img_crop=uint8(double(img_crop)/255);
    xy_crop =findcontourBW(img_filt,1,thresholdratio,background_color);  
    % xy_crop= aboveline(xy_crop,loc_horizon)         % 待改!!只保留地平線以上的點
    if (mod(ntmp,6) == 0)
        close all
    end

    if ~isempty(xy_crop)
        % D. 重要：還原座標到原始影像尺寸
        xy_full_x = (xy_crop(:, 1) + xmin - 1)*umpix;
        xy_full_y = (xy_crop(:, 2) + ymin - 1)*umpix;
        
        % E. 整理數據
        num_pts = length(xy_full_x);
        temp_table = table(...
            repmat(curr_time, num_pts, 1), ...
            repmat(k, num_pts, 1), ...
            xy_full_x, ...
            xy_full_y, ...
            'VariableNames', {'Time_s', 'Frame_Idx', 'X_um', 'Y_um'});
        
        all_data_list{data_counter} = temp_table;
    end
    waitbar(data_counter/length(frame_indices), h_waitbar, sprintf('進度：%d / %d 幀', data_counter, length(frame_indices)));
end
close(h_waitbar);


%% 逐張擷取輪廓
%____________
%分析幀數範圍1~n_totalframe

% 把[F_first,F_start,F_roll,_F_pinch,F_last]和平移後的數據都計入了
% startframe=1000;
f_pinch=bkstage_frame(end-1);
% 每幾幀分析一次
analyze_step=[20,1];
% 欲分析的幀數清單 
frame_indices=creat_framelist(bkstage_frame(2:end-1),analyze_step);

% 建立空陣列
all_data_list = {};   % all_data_list{k} 第k個圖片的輪廓點table
data_counter = 0;
%%
h_waitbar = waitbar(0, '正在分析水滴輪廓...', 'Name', 'Processing Video');

for k = frame_indices               %讀取idx_firstframe後的第k-1幀
    data_counter=data_counter+1;    %分析的照片數
    curr_time = (f_pinch-k)/real_fps;  %倒數秒數
    
    
    % 讀取該幀
    imageNo = cineinfo.n_firstframe + k - 1;  %換算回影片的原始幀數
    imgRange = get(libstruct('tagIMRANGE'));
    imgRange.First = imageNo;
    imgRange.Cnt   = 1;
    [HRES, pixels, imgHeader] = PhGetCineImage(cine, imgRange, cineinfo.imgSizeInBytes);
    pixels = ExtractImageMatrixFromImageBuffer(pixels,imgHeader);
    if IsColorHeader(imgHeader)
        samplespp = 3;
    else
        samplespp = 1;
    end
    bps = GetEffectiveBitsFromIH(imgHeader);

    [~, img] = ConstructMatlabImage( ...
        pixels, ...
        imgHeader.biWidth, ...
        imgHeader.biHeight, ...
        samplespp, ...
        bps);
    img=img*16;
    % imshow(img) %要加PhSetCineInfo(cine, PhFileConst.GCI_VFLIPVIEWACTIVE, p)否則畫面顛倒!! 
    % A. 根據 ROI 裁切
    % 選擇當前幀數使用的ROI
    % 找到testframes中小於等於k的最大值編號
    idx=max(1,sum(testframes-bkstage_orig(1)<=k)) %sum(testframes>=k)會是有幾個數字比k小
    xmin=ROIcrop_range(idx,1,1)
    xmax=ROIcrop_range(idx,2,1)    
    ymin=ROIcrop_range(idx,1,2)
    ymax=ROIcrop_range(idx,2,2)
    %裁切
    img_crop2 = img(ymin:ymax, xmin:xmax);
    % imshow(img_crop2)
    % B. 頻域低通濾波 (去除高頻雜訊)
    L=2 %波長下限，波長小於L的高頻會被濾除
    img_filt=lowpass_filter(img_crop2,L,0);
    
    % C. 提取輪廓 
    % 設定 showup=0 以免迴圈中彈出過多視窗，最後一張再顯示
    show_flag = (mod(k,100) == 0);
    % xy_crop =findcontourBW(img_filt,0);  
    xy_crop =findcontourBW(img_filt,0,thresholdratio,background_color);  
    % xy_crop= aboveline(xy_crop,loc_horizon)         % 待改!!只保留地平線以上的點
    if (mod(k,400) == 0)
        close all
    end

    if ~isempty(xy_crop)
        % D. 重要：還原座標到原始影像尺寸
        xy_full_x = (xy_crop(:, 1) + xmin - 1)*umpix;
        xy_full_y = (xy_crop(:, 2) + ymin - 1)*umpix;
        
        % E. 整理數據
        num_pts = length(xy_full_x);
        temp_table = table(...
            repmat(curr_time, num_pts, 1), ...
            repmat(k, num_pts, 1), ...
            xy_full_x, ...
            xy_full_y, ...
            'VariableNames', {'Time_s', 'Frame_Idx', 'X_um', 'Y_um'});
        
        all_data_list{data_counter} = temp_table;
    end
    waitbar(data_counter/length(frame_indices), h_waitbar, sprintf('進度：%d / %d 幀', data_counter, length(frame_indices)));
end
close(h_waitbar);


%% 關閉影片
PhDestroyCine(cine);
UnregisterPhantom();
UnloadPhantomLibraries();
    
%% 4. 儲存成 XLSX 檔案
%--------------------------------------------------------------------------
real_horizon=glb_horizon*umpix %地平線轉換為真實尺寸
writematrix(["x (pixel)","y (pixel)"],xlsxpath,"Sheet","parameters","Range","A1")
writematrix([[xmax,ymax];[xmin,ymin]],xlsxpath,"Sheet","parameters","Range","A2")
writematrix(["horizon x(um)","horizon y(um)"])
writematrix(real_horizon,xlsxpath,"Sheet","parameters","Range","A5")  %20260913 地平線要改成um單位
writematrix(["umpix"],xlsxpath,"Sheet","parameters","Range","A7")
writematrix(umpix,xlsxpath,"Sheet","parameters","Range","B7")
writematrix("analyze_step",xlsxpath,"Sheet","parameters","Range","A8")
writematrix(analyze_step,xlsxpath,"Sheet","parameters","Range","B8")
writematrix(testframes,xlsxpath,"Sheet","parameters","Range","A12")


% 儲存成 CSV 檔案
if isempty(all_data_list)
    fprintf('未偵測到任何輪廓，停止儲存。\n');
else
    final_table = vertcat(all_data_list{:});
    writetable(final_table, csvpath);
    fprintf('分析完成！結果已儲存至：%s\n', csvpath);
end
