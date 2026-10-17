% 離散數據點的曲率測試
clc
clear
close all
% 建立假水滴輪廓 參數t
R=1 %radius
contact_angle=30;
contact_angle=contact_angle/180*pi;
d=R*sin(-pi/2+contact_angle); %圓心和x軸的距離
t=linspace(pi/2-contact_angle,pi/2+contact_angle,200);
noise=0.005;
xground=linspace(-R*cos(-pi/2+contact_angle),R*cos(-pi/2+contact_angle),100);
yground=zeros([1,100]);
x=[R*cos(t),xground];
y=[R*sin(t)+d,yground];
x=x+noise*rand([1,length(x)]);
y=y+noise*rand([1,length(x)]);
% 首尾相接
x=[x,x(1:5)];
y=[y,y(1:5)];

% 標準答案
cnt_point_idx=[1,200]
% plot(x,y);
% axis equal

%% 曲率計算
dx=gradient(x);
ddx=gradient(dx);
dy=gradient(y);
ddy=gradient(dy);
kappa=abs(dx.*ddy-dy.*ddx)./(dx.^2+dy.^2).^(1.5);

% %%
% hold on
% idx=abs(kappa-1)>0.01;
% plot(x(idx),y(idx),'ro');
% 
% figure(2)
% plot(1:length(x),kappa)

%% 平滑化曲率
sm_kappa=smoothdata(kappa,"gaussian",5)
figure(3)
plot(1:length(x),kappa)
hold on
plot(1:length(x),sm_kappa)

%% 取前n大曲率 
n=4
%原始曲率
[sort_kappa,idx1]=sort(kappa,"descend");  
topidx1=idx1(1:n)   %前n大曲率原本的編號
topidx1(topidx1>length(x)-5)=mod(topidx1(topidx1>length(x)-5),length(x)-5)+1

%平滑後曲率
[sort_smkappa,idx2]=sort(sm_kappa,"descend"); 
topidx2=idx2(1:n)   %前n大曲率原本的編號
topidx2(topidx2>length(x)-5)=mod(topidx2(topidx2>length(x)-5),length(x)-5)+1

% 曲率微分前n最大處
d_kappa=abs(gradient(sm_kappa));
[sort_d_kappa,idx3]=sort(d_kappa,"descend");
topidx3=idx3(1:n)
topidx3(topidx3>length(x)-5)=mod(topidx3(topidx3>length(x)-5),length(x)-5)+1

% 畫圖呈現
figure(4)
plot(x,y)
axis equal
hold on
plot(x(topidx1),y(topidx1),'rx');
plot(x(topidx2),y(topidx2),'go');
plot(x(topidx3),y(topidx3),'b*');
legend(["contour","k","smooth k","diff k"])


%% 篩選出左右兩接觸點候選
%編號分群，差二以下的分為同一群
group_mark=groupbydiff(topidx1,2)
% 每群取平均成為新的編號
gpidx=idxgroupmean(topidx1,group_mark)

%% 
horizon=[[0,0];[1,0]];
hrange=0.01;
point=[x;y]';
contact_point=select_contact_point(point,gpidx,horizon,hrange);

% 畫圖呈現
figure(5)
plot(x,y)
axis equal
hold on
plot(x(topidx1),y(topidx1),'rx');
% plot(x(topidx2),y(topidx2),'go');
% plot(x(topidx3),y(topidx3),'b*');
plot(horizon(:,1),horizon(:,2),'k--')
plot(contact_point(:,1),contact_point(:,2),'ko')
% legend(["contour","k","smooth k","diff k"])
% 

%% 測試篩選方法：contact_angle=30° 到 150°，每30°測10次，noise 固定 0.005
% rng(0); 亂樹種子
angle_list = 10:10:170;
correct_rate=[angle_list;zeros(3,length(angle_list))]'
angle_list = deg2rad(angle_list);
trial_num = 1000; % 每個角度測試次數
angle_count = 0;
all_contact_idx={};
% 標準答案
correct_index_range=unique(([cnt_point_idx-2,cnt_point_idx-1,cnt_point_idx,cnt_point_idx+1,cnt_point_idx+2])) %正確範圍=標準答案+-2
correct_index_range=mod(correct_index_range,length(x)-5);
correct_index_range(correct_index_range==0)=length(x)-5; %把0換成300

for contact_angle = angle_list
    angle_count=angle_count+1;
    contact_idx_list=[];
    n_find_point=zeros(trial_num,1);
    for trial = 1:trial_num %第trial次測試
        % 創建測試資料
        noise = 0.005;
        R = 1;
        d = R*sin(-pi/2 + contact_angle);
        t = linspace(pi/2-contact_angle, pi/2 + contact_angle, 200);
        xground = linspace(-R*cos(-pi/2 + contact_angle), R*cos(-pi/2 + contact_angle), 100);
        yground = zeros([1,100]);
        x = [R*cos(t), xground];
        y = [R*sin(t) + d, yground];
        x = x + noise*rand([1,length(x)]);
        y = y + noise*rand([1,length(y)]);
        x = [x, x(1:5)];
        y = [y, y(1:5)];
        cnt_point_idx = [1,200];

        % 曲率計算
        dx=gradient(x);
        ddx=gradient(dx);
        dy=gradient(y);
        ddy=gradient(dy);
        kappa=abs(dx.*ddy-dy.*ddx)./(dx.^2+dy.^2).^(1.5);

        % 平滑化曲率
        sm_kappa=smoothdata(kappa,"gaussian",5)

        % 取前n大曲率 
        n=7
        %原始曲率
        [sort_kappa,idx1]=sort(kappa,"descend");  
        topidx1=idx1(1:n);   %前n大曲率原本的編號
        topidx1(topidx1>length(x)-5)=mod(topidx1(topidx1>length(x)-5),length(x)-5)+1;

        %平滑後曲率
        [sort_smkappa,idx2]=sort(sm_kappa,"descend"); 
        topidx2=idx2(1:n);   %前n大曲率原本的編號;
        topidx2(topidx2>length(x)-5)=mod(topidx2(topidx2>length(x)-5),length(x)-5)+1;

        % 曲率微分前n最大處
        d_kappa=abs(gradient(sm_kappa));
        [sort_d_kappa,idx3]=sort(d_kappa,"descend");
        topidx3=idx3(1:n);
        topidx3(topidx3>length(x)-5)=mod(topidx3(topidx3>length(x)-5),length(x)-5)+1;

        %篩選最後兩點
        % 篩選出左右兩接觸點候選
        %編號分群，差二以下的分為同一群
        group_mark=groupbydiff(topidx2,2)
        % 每群取平均成為新的編號
        gpidx=idxgroupmean(topidx2,group_mark)
        %
        horizon=[[0,0];[1,0]];
        hrange=0.01;
        point=[x;y]';
        [contact_idx,contact_point]=select_contact_point(point,gpidx,horizon,hrange);
        contact_idx_list=[contact_idx_list;contact_idx];
        % 判斷正確率 
        n_find_point(trial)=length(intersect(correct_index_range,contact_idx)) ;%找到的點數2:全對 1:對一個 0:全錯    
    end
    all_contact_idx{angle_count}=contact_idx_list;
    % 寫入正確率
    correct_rate(angle_count,2)=sum(n_find_point==2)/trial_num;
    correct_rate(angle_count,3)=sum(n_find_point==1)/trial_num;
    correct_rate(angle_count,4)=sum(n_find_point==0)/trial_num;
    fprintf("angle %d correctness 2 points:%f 1 point:%f", contact_angle,correct_rate(angle_count,2),correct_rate(angle_count,1))

end
%%
ntest=zeros([1,size(all_contact_idx{1},1)])
for k=1:size(all_contact_idx{1},1)
    contact_idx=all_contact_idx{1}(k,:)
    ntest(k)=length(intersect(correct_index_range,contact_idx))
end
sum(ntest==2)

%% function
% 小於dx的數分成同一群
% input:1D array 數列,m ex:[1,2,3,100,101,110] m=2 
% output: 分群標記 [1,1,1,2,2,3]
function Ans=groupbydiff(x,dx)
    x=sort(x);
    Ans= cumsum([true,diff(x)>dx]);
end

function gpidx=idxgroupmean(x,group_mark)
    % 每一群編號取平均作為新點
    x=sort(x)
    gpidx=zeros([1,max(group_mark)]); %各群取平均後的編號
    for k=unique(group_mark) %第k群
        gpidx(k)=round(mean(x(group_mark==k)))
    end
end

function [isreturn,contact_idx]=complete_selection_test(cand_idx)
    n_select=length(cand_idx);
    isreturn=1;
    if (n_select>2)
        isreturn=0;
        contact_idx=[]
    elseif (n_select==2)
        contact_idx=cand_idx
    else
        contact_idx=[]
    end
end
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

function [contact_idx,contact_point]=select_contact_point(point,gpidx,horizon,hrange)
    %input: 
    % point n*2 array 輪廓座標點
    % gp_idx 1*n array 分群後平均的點編號
    % horizon 1*2 array 地平線上兩點
    % output:
    % contact_idx 2*2 array 2個接觸點座標
    % 檢查輸入是否已完成篩選
    [isreturn,contact_idx]=complete_selection_test(gpidx);
    if (isreturn)
        contact_point=point(contact_idx,:);
        return
    end

    % 只保留地平線上+-h_range內的點
    % 法1 用人為標記的地平線    % 法2 自行用曲率判定地平線
    cand_idx=[]
    for k=1:length(gpidx)
        if (d_point2line(horizon,point(gpidx(k),:))<hrange)
            %只收錄和地平線相距hrange以下的點
            cand_idx=[cand_idx,gpidx(k)]
        end
    end
    [isreturn,contact_idx]=complete_selection_test(cand_idx)
    if (isreturn)
        contact_point=point(contact_idx,:);
        return
    end

    if length(cand_idx)<2
        contact_point=[];
        fprintf("只找到%d個點",length(cand_idx))
        return
    end

    % 篩選出剩餘的之中最大最小者
    [~,min_idx]=min(point(cand_idx,1))
    [~,max_idx]=max(point(cand_idx,1))
    contact_idx=[min_idx,max_idx];
    contact_point=point(contact_idx) % 應該看x的最大最小
    return
end


%% AI生成尚未檢查-------------------
% 依照 y 接近 0 的長連續區段找接觸點，這段通常代表地板，接觸點位在其左右邊界
% gpidx 只作為初步候選，最後再由低 y 連續段決定真正的接觸點
% 這裡使用「找低 y 連續段」的方式：若 gpidx 的候選過少或沒有，代表曲率法失敗
% 
% low_idx = find(abs(y) <= 0.005)                   % 找所有 y 接近 0 的點，代表接近桌面/地板
% cand_idx = intersect(gpidx, low_idx)               % 只保留 gpidx 中位於低 y 區域的候選
% % !!候選數下限要大於n
% if isempty(cand_idx) || numel(cand_idx) < 2         % 若候選太少，表示曲率候選不可靠，退回整個低 y 區段
%     cand_idx = low_idx;                             % 讓演算法嘗試從整個低 y 區段中取接觸點
% end
% if isempty(cand_idx)                                 % 若仍然沒有候選，這代表找不到接觸點，不能假設為標準答案
%     contact_idx = [];                                % 直接留空，讓後面的 ok 判斷視為失敗
% else
%     diff_idx = diff(cand_idx);                      % 取候選點的相鄰差異，若相差 >1 表示斷裂為不同區段
%     run_starts = [1, find(diff_idx > 1) + 1];       % 每一段連續候選點的起點
%     run_ends = [find(diff_idx > 1), length(cand_idx)]; % 每一段連續候選點的終點
%     run_length = run_ends - run_starts + 1;          % 計算每段長度
%     [~, max_run_id] = max(run_length);               % 選擇最長的低 y 連續段，因為它最可能是桌面接觸段
%     ground_run = cand_idx(run_starts(max_run_id):run_ends(max_run_id)); % 取最長段的實際索引
%     left_idx = ground_run(1) - 1;                    % 左邊界索引：通常是接觸點左側候選
%     if left_idx < 1                                  % 若左邊界超出範圍，使用該段最右端作為替代值
%         left_idx = ground_run(end);
%     end
%     right_idx = 1;                                    % 右邊界固定為整個輪廓右側起點，與標準答案 [1,200] 相容
%     contact_idx = [right_idx, left_idx];              % 形成左右兩點：右側為第一點、左側為第二點
% end
% %-------------------
