function output_filename = contact_angle_video(csv_file, horizon, contact_points, contact_angles, output_filename, options)
%CONTACT_ANGLE_VIDEO 將逐幀輪廓、接觸點與接觸角繪製成 MP4 影片。
%
% 【功能概述】
%   讀取含有所有時刻輪廓的 CSV，將座標旋轉到「地平線水平、向上為正」
%   的局部座標系，逐幀畫出輪廓、地平線、左右接觸點、角度割線、角弧與
%   角度數值，最後寫入 MPEG-4 影片，供使用者以肉眼檢查分析結果。
%
% 【輸入格式與意義】
%   csv_file         char 或 string，輪廓 CSV 的完整或相對路徑。
%                   必要欄位：
%                     Frame_Idx：影像原始幀號。
%                     X_um：輪廓 x 座標，單位 um。
%                     Y_um：輪廓 y 座標，單位 um。
%                   選用欄位：Time_s；若存在，會顯示於影片標題。
%
%   horizon         2×2 double。每列是一個地平線點 [x,y]，單位 um；
%                   第 1 點到第 2 點定義地平線正方向。
%
%   contact_points  所有 F 幀的左右接觸點，支援三種格式：
%                     1. F×4 double：每列為 [Lx,Ly,Rx,Ry]。
%                     2. 2×2×F double：每頁為 [左點;右點]。
%                     3. F×1 cell：每格是一個 2×2 的 [左點;右點]。
%                   座標單位與 CSV、HORIZON 相同。
%
%   contact_angles  F×2 double，單位 degree；每列為
%                   [左接觸角,右接觸角]，幀順序必須與 CSV 中第一次出現的
%                   Frame_Idx 順序一致。
%
%   output_filename char 或 string，輸出 MP4 路徑。若傳入空字串，預設在
%                   CSV 同一資料夾建立「原檔名_contact_angles.mp4」。
%
%   options.TargetDuration
%                   正數，預期影片長度，單位秒，預設 20。程式依原始幀號
%                   間隔重複畫面，再自動設定影格率以接近此長度。
%   options.Visible string，"on" 或 "off"，控制繪圖視窗是否顯示，預設 off。
%   options.LineWidth
%                   正數，輪廓線寬，預設 1.5。
%   options.MarkerSize
%                   正數，接觸點散佈標記面積，預設 55。
%
% 【輸出格式與意義】
%   output_filename char，實際寫出的 MP4 路徑。
%
% 【使用範例】
%   output = contact_angle_video(csv_file,horizon,contact_points, ...
%       contact_angles,"result.mp4",'TargetDuration',20);

    %% 1. 定義輸入規格
    % arguments 區塊在讀檔與繪圖前先限制必要輸入的尺寸與資料型別。
    arguments
        % 輪廓 CSV 路徑，可使用 MATLAB char 或 string。
        csv_file {mustBeTextScalar}
        % 地平線兩點，每列為 [x,y]，共 2×2。
        horizon (2,2) double {mustBeFinite, mustBeReal}
        % 接觸點支援多種格式，稍後由子函式統一轉成 2×2×F。
        contact_points
        % 每幀一列、左右各一欄的接觸角，尺寸為 F×2。
        contact_angles (:,2) double {mustBeReal}
        % 輸出影片路徑；空字串表示使用自動檔名。
        output_filename {mustBeTextScalar} = ""
        % 目標影片時長，單位為秒。
        options.TargetDuration (1,1) double {mustBePositive} = 20
        % 是否顯示 MATLAB figure；批次分析預設不顯示。
        options.Visible (1,1) string = "off"
        % 藍色輪廓線的寬度。
        options.LineWidth (1,1) double {mustBePositive} = 1.5
        % 紅色接觸點標記的面積大小。
        options.MarkerSize (1,1) double {mustBePositive} = 55
    end

    %% 2. 讀取 CSV 並檢查逐幀輸入數量
    % 統一路徑型別為 char，方便 isfile、readtable 與 VideoWriter 使用。
    csv_file = char(csv_file);
    % CSV 不存在時立即停止，避免後續 readtable 產生較不明確的錯誤。
    if ~isfile(csv_file)
        error('contact_angle_video:FileNotFound','CSV file not found: %s',csv_file);
    end
    % 將整份輪廓 CSV 讀成 table；每列代表某一幀的一個輪廓點。
    data = readtable(csv_file);
    % 定義本函式一定需要的欄位名稱。
    required = {'Frame_Idx','X_um','Y_um'};
    % 檢查三個必要欄位是否都存在於 CSV 表格中。
    if ~all(ismember(required,data.Properties.VariableNames))
        error('contact_angle_video:MissingColumns', ...
            'CSV must contain Frame_Idx, X_um and Y_um.');
    end

    % 依 CSV 中第一次出現的順序取得不重複幀號，避免自動排序改變資料時序。
    frames = unique(data.Frame_Idx,'stable');
    % F 為實際要繪製的輪廓幀數。
    frame_count = numel(frames);
    % 將三種可能的接觸點輸入格式統一整理成 2×2×F。
    contact_points = normalize_contact_points(contact_points,frame_count);
    % 接觸角列數必須與輪廓幀數完全相同，才能逐幀一一配對。
    if size(contact_angles,1) ~= frame_count
        error('contact_angle_video:SizeMismatch', ...
            'CONTACT_ANGLES must have one row per frame.');
    end

    %% 3. 建立固定的地平線局部座標系
    % 由地平線第 1 點指向第 2 點，得到尚未正規化的地平線向量。
    horizon_vector = horizon(2,:) - horizon(1,:);
    % 計算地平線長度，用於正規化及重合點檢查。
    horizon_length = norm(horizon_vector);
    % 若地平線兩點在數值精度下重合，就無法定義旋轉方向。
    if horizon_length <= eps(max(1,max(abs(horizon),[],'all')))
        error('contact_angle_video:InvalidHorizon', ...
            'The two horizon points must be distinct.');
    end
    % tangent 是沿地平線正方向的單位切向量。
    tangent = horizon_vector/horizon_length;
    % 將 tangent 逆時針旋轉 90 度，先建立候選單位法向量。
    normal = [-tangent(2),tangent(1)];
    % 將 CSV 中所有輪廓點組成 M×2 座標陣列，以便統一判斷方向與範圍。
    all_point = [data.X_um,data.Y_um];
    % 計算所有輪廓點在候選法向量上的帶正負號高度。
    all_signed = (all_point-horizon(1,:))*normal';
    % 水滴主體所在側通常有較大的法向延伸；若位於負側，就反轉法向量。
    if abs(min(all_signed)) > abs(max(all_signed))
        normal = -normal;
    end
    % all_s 是所有點沿地平線方向的局部座標，供固定 x 軸範圍使用。
    all_s = (all_point-horizon(1,:))*tangent';
    % all_z 是所有點朝水滴上方的局部高度，供固定 y 軸範圍使用。
    all_z = (all_point-horizon(1,:))*normal';

    %% 4. 決定輸出檔名、影片時間設定與繪圖資源
    % 若沒有指定輸出路徑，便在 CSV 所在資料夾自動建立 MP4 檔名。
    if strlength(string(output_filename)) == 0
        % 分離 CSV 的資料夾與不含副檔名的檔名。
        [folder,name] = fileparts(csv_file);
        % 組合預設輸出檔名：原檔名_contact_angles.mp4。
        output_filename = fullfile(folder,[name '_contact_angles.mp4']);
    else
        % 若呼叫端有提供路徑，統一轉成 char 供 VideoWriter 使用。
        output_filename = char(output_filename);
    end
    % 取得輸出影片所在資料夾；只有檔名時此值可能為空。
    output_folder = fileparts(output_filename);
    % 若指定的輸出資料夾尚不存在，就先建立資料夾。
    if ~isempty(output_folder) && ~isfolder(output_folder)
        mkdir(output_folder);
    end

    % 計算相鄰已分析幀的原始幀號間隔；第一幀固定至少顯示一次。
    frame_gaps = diff([double(frames(1))-1;double(frames(:))]);
    % 將間隔轉成至少為 1 的整數，作為各畫面寫入影片的重複次數。
    frame_gaps = max(1,round(frame_gaps));
    % 由總輸出影格數與目標時長反推 FPS，且 FPS 至少為 1。
    fps = max(1,round(sum(frame_gaps)/options.TargetDuration));

    % 建立 MPEG-4 影片寫入器，輸出位置由 output_filename 決定。
    writer = VideoWriter(output_filename,'MPEG-4');
    % 設定寫入器影格率，使最終長度接近 TargetDuration。
    writer.FrameRate = fps;
    % 正式開啟輸出影片檔案。
    open(writer);
    % 即使中途發生錯誤，也嘗試關閉 writer，避免留下鎖定或不完整的資源。
    writer_cleanup = onCleanup(@() close_writer_safely(writer));

    % 建立固定尺寸白底畫布；painters 渲染器可降低無視窗批次的 OpenGL 問題。
    fig = figure('Visible',char(options.Visible),'Color','w', ...
        'Position',[100,100,800,540],'Renderer','painters');
    % 若程式中途停止，onCleanup 會嘗試關閉 figure。
    figure_cleanup = onCleanup(@() close_figure_safely(fig));
    % 建立暫存 PNG 路徑，逐幀以離屏方式轉成可寫入影片的 RGB 影像。
    temporary_frame_file = [tempname '.png'];
    % 若程式中途停止，onCleanup 會移除暫存 PNG。
    frame_file_cleanup = onCleanup(@() delete_file_safely(temporary_frame_file));

    %% 5. 預先計算全影片共用的座標軸與圖形尺度
    % 所有輪廓點的最小、最大 s 決定固定水平顯示範圍。
    x_range = [min(all_s),max(all_s)];
    % 垂直顯示範圍同時納入所有輪廓點與地平線 z=0。
    z_range = [min([all_z;0]),max([all_z;0])];
    % 水平兩側各保留全寬 5% 的邊界，且至少保留 1 um。
    x_pad = max(0.05*diff(x_range),1);
    % 垂直上下各保留全高 10% 的邊界，且至少保留 1 um。
    z_pad = max(0.10*diff(z_range),1);
    % 接觸角割線長度設為全域水平寬度的 10%，且至少為 1 um。
    ray_length = max(0.10*diff(x_range),1);
    % 角弧半徑取割線長度的 45%，使弧線與數字保持可讀。
    arc_radius = 0.45*ray_length;

    %% 6. 逐幀繪圖並寫入影片
    % 依 stable 幀順序逐一處理每個已分析輪廓。
    for frame_number = 1:frame_count
        % 建立邏輯索引，挑出目前幀在 CSV 中的所有輪廓點。
        row = data.Frame_Idx == frames(frame_number);
        % 將目前幀的 x、y 欄位合併成 N_k×2 座標陣列。
        contour = [data.X_um(row),data.Y_um(row)];
        % 把目前輪廓投影到地平線切向量，得到水平局部座標。
        contour_s = (contour-horizon(1,:))*tangent';
        % 把目前輪廓投影到指向水滴的法向量，得到向上局部高度。
        contour_z = (contour-horizon(1,:))*normal';
        % 取出目前幀的 2×2 接觸點矩陣，列順序為左、右。
        cp = squeeze(contact_points(:,:,frame_number));
        % 將左右接觸點投影到地平線水平座標。
        cp_s = (cp-horizon(1,:))*tangent';
        % 將左右接觸點投影到地平線以上高度。
        cp_z = (cp-horizon(1,:))*normal';
        % 取出目前幀的 [左角,右角]，單位為 degree。
        angles = contact_angles(frame_number,:);

        % 清除上一幀所有圖形物件，保留同一個 figure 供下一幀重畫。
        clf(fig);
        % 在 figure 中建立新的座標軸物件。
        ax = axes(fig);
        % 以藍線依輪廓原始順序連接所有點。
        plot(ax,contour_s,contour_z,'b-','LineWidth',options.LineWidth);
        % 保留目前座標軸內容，以便疊加地平線、接觸點與角度圖形。
        hold(ax,'on');
        % 在 z=0 畫出黑色虛線，表示旋轉校正後的地平線。
        yline(ax,0,'k--','地平線','LineWidth',1.0);
        % 以紅色實心圓標記左右接觸點。
        scatter(ax,cp_s,cp_z,options.MarkerSize,'r','filled');

        % 左側割線從左接觸點朝 +s 內側方向旋轉左接觸角。
        left_ray = [cosd(angles(1)),sind(angles(1))];
        % 右側割線從右接觸點朝 -s 內側方向旋轉右接觸角。
        right_ray = [-cosd(angles(2)),sind(angles(2))];
        % 畫出左接觸點的紅色割線。
        plot(ax,cp_s(1)+[0,left_ray(1)]*ray_length, ...
            cp_z(1)+[0,left_ray(2)]*ray_length,'r-','LineWidth',2);
        % 畫出右接觸點的紅色割線。
        plot(ax,cp_s(2)+[0,right_ray(1)]*ray_length, ...
            cp_z(2)+[0,right_ray(2)]*ray_length,'r-','LineWidth',2);

        % 產生左角弧由 0 度到左接觸角的 40 個角度取樣點。
        theta_left = linspace(0,angles(1),40);
        % 右側內向地平線位於 180 度，因此角弧由 180-右角畫到 180 度。
        theta_right = linspace(180-angles(2),180,40);
        % 以接觸點為圓心畫出左側紅色角弧。
        plot(ax,cp_s(1)+arc_radius*cosd(theta_left), ...
            cp_z(1)+arc_radius*sind(theta_left),'r-','LineWidth',1);
        % 以接觸點為圓心畫出右側紅色角弧。
        plot(ax,cp_s(2)+arc_radius*cosd(theta_right), ...
            cp_z(2)+arc_radius*sind(theta_right),'r-','LineWidth',1);

        % 在左接觸點上方標示左接觸角，char(176) 是度數符號。
        text(ax,cp_s(1),cp_z(1)+0.65*ray_length, ...
            sprintf('L %.1f%c',angles(1),char(176)), ...
            'Color','r','HorizontalAlignment','center','FontWeight','bold', ...
            'Interpreter','none');
        % 在右接觸點上方標示右接觸角。
        text(ax,cp_s(2),cp_z(2)+0.65*ray_length, ...
            sprintf('R %.1f%c',angles(2),char(176)), ...
            'Color','r','HorizontalAlignment','center','FontWeight','bold', ...
            'Interpreter','none');

        % 若 CSV 有 Time_s 欄位，影片標題同時顯示原始幀號與時間。
        if ismember('Time_s',data.Properties.VariableNames)
            % 同一幀的所有點具有相同時間，因此只讀取該幀第一列。
            current_time = data.Time_s(find(row,1,'first'));
            % 時間顯示到小數點後 6 位，以保留高速攝影的時間解析度。
            title(ax,sprintf('Frame %g   Time %.6f s',frames(frame_number),current_time));
        else
            % 若沒有 Time_s，只在標題顯示原始幀號。
            title(ax,sprintf('Frame %g',frames(frame_number)));
        end
        % 標示水平軸為沿地平線方向的距離，單位 um。
        xlabel(ax,'沿地平線距離 (\mum)');
        % 標示垂直軸為地平線以上高度，單位 um。
        ylabel(ax,'地平線以上高度 (\mum)');
        % 固定 x、y 單位比例相同，避免水滴外形因拉伸而失真。
        axis(ax,'equal');
        % 所有幀使用相同的水平範圍，避免播放時畫面左右跳動。
        xlim(ax,x_range+[-x_pad,x_pad]);
        % 所有幀使用相同的垂直範圍，避免播放時畫面上下縮放。
        ylim(ax,z_range+[-z_pad,z_pad]);
        % 顯示格線，方便肉眼比較幾何位置。
        grid(ax,'on');
        % 顯示座標軸外框。
        box(ax,'on');
        % 強制 MATLAB 完成目前幀的繪圖更新。
        drawnow;

        % 將整個 figure 離屏輸出到暫存 PNG；此法可避開長時間批次的 GETFRAME OpenGL 錯誤。
        exportgraphics(fig,temporary_frame_file,'Resolution',90, ...
            'BackgroundColor','white');
        % 將暫存 PNG 讀回 RGB 陣列，作為 VideoWriter 的輸入影格。
        video_frame = imread(temporary_frame_file);
        % 依原始幀號間隔重複寫入目前畫面，以保留分析幀之間的時間比例。
        for repeat = 1:frame_gaps(frame_number)
            % 將一個 RGB 影格寫入 MP4。
            writeVideo(writer,video_frame);
        end
    end

    %% 7. 正常完成時主動關閉資源並移除暫存檔
    % 關閉影片寫入器，讓 VideoWriter 完成 MP4 索引與檔尾寫入。
    close(writer);
    % writer 已正常關閉，因此移除對應的 onCleanup 物件，避免重複關閉。
    clear writer_cleanup
    % 關閉繪圖視窗並釋放圖形資源。
    close(fig);
    % figure 已正常關閉，因此移除對應的 onCleanup 物件。
    clear figure_cleanup
    % 刪除逐幀轉檔使用的暫存 PNG。
    delete_file_safely(temporary_frame_file);
    % 暫存檔已刪除，因此移除對應的 onCleanup 物件。
    clear frame_file_cleanup
end

function result = normalize_contact_points(value,frame_count)
%NORMALIZE_CONTACT_POINTS 將多種接觸點輸入格式統一成 2×2×F。
%   value       ：呼叫端傳入的接觸點資料。
%   frame_count ：CSV 中的輪廓幀數 F。
%   result      ：2×2×F double；每頁為 [左點;右點]。

    %% 子函式階段 1：處理 cell 格式
    % cell 輸入應有 F 個元素，每個元素代表一幀。
    if iscell(value)
        % cell 數量必須與 CSV 幀數一致。
        if numel(value) ~= frame_count
            error('contact_angle_video:SizeMismatch', ...
                'CONTACT_POINTS must have one entry per frame.');
        end
        % 預先配置標準輸出陣列，避免迴圈中反覆擴充。
        result = zeros(2,2,frame_count);
        % 逐幀將 cell 中的 2×2 接觸點複製到第 3 維。
        for k = 1:frame_count
            % 每個 cell 必須剛好包含左、右兩列及 x、y 兩欄。
            if ~isequal(size(value{k}),[2,2])
                error('contact_angle_video:InvalidContactPoints', ...
                    'Each CONTACT_POINTS cell must contain a 2-by-2 matrix.');
            end
            % 將第 k 幀接觸點存入標準陣列的第 k 頁。
            result(:,:,k) = value{k};
        end

    %% 子函式階段 2：處理 F×4 矩陣格式
    % 每列依序必須是 [左x,左y,右x,右y]。
    elseif isnumeric(value) && ismatrix(value) && ...
            size(value,1) == frame_count && size(value,2) == 4
        % 預先配置 2×2×F 的標準輸出陣列。
        result = zeros(2,2,frame_count);
        % 將每一列拆成左、右兩個 [x,y] 點。
        for k = 1:frame_count
            % 第 1、2 欄組成左點；第 3、4 欄組成右點。
            result(:,:,k) = [value(k,1:2);value(k,3:4)];
        end

    %% 子函式階段 3：處理已經是 2×2×F 的格式
    % 若尺寸完全符合標準格式，不需重新配置或複製各幀資料。
    elseif isnumeric(value) && ndims(value) == 3 && ...
            size(value,1) == 2 && size(value,2) == 2 && ...
            size(value,3) == frame_count
        % 直接使用輸入值作為標準化結果。
        result = value;

    %% 子函式階段 4：處理只有一幀時的 2×2 特例
    % MATLAB 會將 2×2×1 顯示為 2×2，因此單幀資料另外允許 2×2 輸入。
    elseif isnumeric(value) && frame_count == 1 && isequal(size(value),[2,2])
        % 明確補上第 3 維，使後續主迴圈可用相同方式取值。
        result = reshape(value,2,2,1);
    else
        % 其餘型別或尺寸無法和 CSV 幀數一一配對，因此回報格式錯誤。
        error('contact_angle_video:InvalidContactPoints', ...
            'Unsupported CONTACT_POINTS size or type.');
    end
end

function close_writer_safely(writer)
%CLOSE_WRITER_SAFELY 發生錯誤或中止時，嘗試安全關閉 VideoWriter。
    % try/catch 確保清理階段不會因 writer 已關閉而覆蓋原始錯誤訊息。
    try
        % 完成並關閉影片檔案。
        close(writer);
    catch
        % 清理失敗時不再拋出第二個錯誤。
    end
end

function close_figure_safely(fig)
%CLOSE_FIGURE_SAFELY 發生錯誤或中止時，嘗試安全關閉繪圖視窗。
    % try/catch 避免無效圖形控制代碼造成第二個錯誤。
    try
        % 只有圖形物件仍有效時才呼叫 close。
        if isgraphics(fig)
            % 關閉 figure 並釋放圖形資源。
            close(fig);
        end
    catch
        % 清理失敗時不再拋出第二個錯誤。
    end
end

function delete_file_safely(path)
%DELETE_FILE_SAFELY 發生錯誤或中止時，移除本函式建立的暫存圖片。
    % try/catch 避免檔案已不存在或暫時鎖定時產生第二個錯誤。
    try
        % 只有暫存路徑仍存在時才執行刪除。
        if isfile(path)
            % 刪除逐幀輸出使用的暫存 PNG，不會碰觸原始 CSV 或分析資料。
            delete(path);
        end
    catch
        % 清理失敗時不再拋出第二個錯誤。
    end
end
