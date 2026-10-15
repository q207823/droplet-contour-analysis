clear
clc          
%% read
folderpath="D:\博士\研究\水滴\水滴實驗數據\實驗影片\已分析數據\20261010光滑壓克力小光圈\光滑壓克力\data"
libpath="D:\博士\研究\水滴\水滴實驗數據\程式\影像分析\functions"
addpath(libpath)
filename="20261010_test2_1X_10ul_10ms"
csvpath=folderpath+"\"+filename+".csv"
xlsxpath=folderpath+"\"+filename+".xlsx"
% data=readtable(xlsxpath,"Sheet","points")
data=readtable(csvpath)
horizonpoint=readmatrix(xlsxpath,"Sheet","parameters","Range","A5:B6");
horizonvec=horizonpoint(2,:)-horizonpoint(1,:)

% 逐張分析:列出幀數編號清單
framelist=unique(data.Frame_Idx,"stable");
timelist=unique(data.Time_s,"stable"); % 注意，unique(A)會自動排序，用"stable"才會依照出現次序保留所有不重複的元素 20260913

%% 有底版分析
% 找x最大最小的點 寬度
w=zeros([length(framelist),1]); %寬度
h=zeros([length(framelist),1]); %高度
contact_angle=zeros([length(framelist),2])
% 找接觸點

for k2= 1:length(framelist) %第k張
    point=table2array(data(data.Frame_Idx==framelist(k2),3:4)); %逆時針編號
    % 銳角情況 找x最大最小
    % 旋轉校正
    calibpoint=rotationcalib(horizonvec,point);
    calibpoint(:,2)=max(calibpoint(:,2))-calibpoint(:,2);
    [~,leftidx]=min(calibpoint(:,1)); %左接觸
    [~,rightidx]=max(calibpoint(:,1));%右接觸
    [~,topidx]=max(calibpoint(:,2));    %最高點
    %畫圖
    if (mod(k2,2)==1)
        plot(calibpoint(:,1),calibpoint(:,2))
        hold on
        axis equal
        plot(calibpoint(leftidx,1),calibpoint(leftidx,2),'ro')
        plot(calibpoint(rightidx,1),calibpoint(rightidx,2),'ro')
        plot(calibpoint(topidx,1),calibpoint(topidx,2),'ro')
        hold off
        pause(0.1)
    end

    w(k2)=abs(calibpoint(leftidx,1)-calibpoint(rightidx,1)); %寬度
    h(k2)=calibpoint(topidx,2);          %高度
    contact_point=[calibpoint(leftidx,:);calibpoint(rightidx,:)]
    [contact_angle(k2),~]=contact_angle_calculator(point, horizonvec, contact_point, NumSecantPoints=10)


end

%% 側視圖分析
rmin=zeros(size(framelist));
time=zeros(size(framelist))
for k1=1:length(framelist)     % 逐張圖片分析
    % 取出目前 frame 的所有輪廓點
    point=table2array(data(data.Frame_Idx==framelist(k1),3:4));
    time(k1)=data.Time_s(find(data.Frame_Idx==framelist(k1),1));
    % 找出目前輪廓所有不同的 y 座標
    yposition=unique(point(:,2));

    % 儲存每個 y 位置的點數
    n_point=zeros(size(yposition));

    % 儲存每個 y 位置的頸部半徑
    r_neck=NaN(size(yposition));

    for k2=1:length(yposition)
        % 取出目前高度的所有輪廓點
        point_aty=point(point(:,2)==yposition(k2),:);
        n_point(k2)=size(point_aty,1);
        % 至少需要左右兩個輪廓點才能計算寬度
        if size(point_aty,1)>1
            % 該高度的輪廓寬度 / 2 = 頸部半徑
            r_neck(k2)= ...
                (max(point_aty(:,1))-min(point_aty(:,1)))/2;
        end
    end
    % 找出目前 frame 最小的頸部半徑!!警告!!如果拍到接近水滴下緣會找錯
    [rmin(k1),idx]=min(r_neck,[],"omitnan");

    % 找出局部極小值-----------------!!警告!!在第二階段或是有拍到針頭的情況會找錯地方
    % [yposition,sort_idx]=sort(yposition);
    % r_neck=r_neck(sort_idx);
    % idx=find(islocalmin(r_neck),1,'first');
    % rmin(k1)=r_neck(idx);

    % 繪製目前 frame 的 r(y)
    figure(1)
    plot(yposition,r_neck)
    hold on

    % 標出最小值
    plot(yposition(idx),rmin(k1),'bo')

end
figure
plot(time,rmin,'o-')
xlabel('Time (s)')
ylabel('r_{min} (\mum)')

%% 無底板專用
r=zeros([length(framelist),1]); 
contact_angle=zeros([length(framelist),2])
% 找半徑
for k2= 1:length(framelist) %第k張
    calibpoint=table2array(data(data.Frame_Idx==framelist(k2),3:4)); %逆時針編號
    area=polyarea(calibpoint(:,1),calibpoint(:,2)); %計算圓形截面面積
    r(k2)=(area/pi)^0.5;
end


%% save
outputT=array2table([timelist,w,h],"VariableNames",["t(s)","width(um)","hight(um)"]);
% outputT=array2table([timelist(1:valid_idx),r(1:valid_idx)],"VariableNames",["t(s)","r(um)"])

% outputT=array2table([time,rmin],"VariableNames",["t(s)","r(um)"])

writetable(outputT,xlsxpath,"Sheet","長寬")


%% 找輪廓可解析的幀數

figure(1)
plot(1:length(timelist),w(1:end),'b.')
hold on
plot(1:length(timelist),h(1:end),'r.')

legend(["width","hight"])
ylabel("neck length(um)")
xlabel("frame")
%%
figure(1)
plot(timelist(1:valid_idx),w(1:valid_idx),'b.')
hold on
plot(timelist(1:valid_idx),h(1:valid_idx),'r.')

legend(["width","hight"])
ylabel("neck length(um)")
xlabel("t(s)")

%% 無底板半徑
figure(1)
plot(timelist(1:end),r(1:end),'b.')

ylabel("r(um)")
xlabel("t(s)")
% set(gca, 'YScale', 'log')
% set(gca, 'XScale', 'log')

tt=timelist(end-400:end-1)
rr=r(end-400:end-1)


%% 選最後階段擬合
tt=timelist(end-300:end-20)
ww=w(end-300:end-20)
hh=h(end-300:end-20)



figure(5)
plot(tt,ww,'.')
hold on
plot(tt,hh,'.')
legend(["width","hight"])
ylabel("neck length(um)")
xlabel("t(s)")

%%
figure(2)
sm=smoothdata(contact_angle(1:end-10,1))
plot(timelist(1:end-10),contact_angle(1:end-10,1),'.')
hold on
plot(timelist(1:end-10),sm,"LineWidth",2)
ylabel("contact angle (deg)")
xlabel("t(s)")
title("contact angle- time plot")
%%
figure(3)
sm=smoothdata(contact_angle(1:end-10,2))
plot(timelist(1:end-10),contact_angle(1:end-10,1),'.')
hold on
plot(timelist(1:end-10),sm,"LineWidth",2)
ylabel("contact angle (deg)")
xlabel("t(s)")
title("contact angle- time plot")


%%
calibpoint=table2array(data(data.Frame_Idx==1,3:4));
for k2=1:size(calibpoint,1)
    plot(calibpoint(k2,1),calibpoint(k2,2),"bo")
    hold on 
    pause(0.01)
end

%% function
function d=d_point2line(line,point)
    %點到直線距離
    %line 2*2 array [[x1,y1];[x2,y2]]
    %point 1*2 array [px,py]
    u=(line(2,:)-line(1,:))/norm((line(2,:)-line(1,:))); %直線的單位向量
    v=point-line(1,:);
    proj=dot(v,u)*u;  %v在直線方向上的投影
    normproj= v-proj; %v在垂直直線方向的分量
    d=norm(normproj);
end

function d=d_point2line2(line,point)
    %點到直線距離
    %line 2*2 array [[x1,y1];[x2,y2]]
    %point 1*2 array [px,py]
    u=(line(2,:)-line(1,:))/norm((line(2,:)-line(1,:))); %直線的單位向量
    v=point-line(1,:);
    proj=dot(v,u)*u;  %v在直線方向上的投影
    normproj= v-proj; %v在垂直直線方向的分量
end