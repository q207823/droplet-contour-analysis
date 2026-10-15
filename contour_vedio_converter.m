% 清除工作區與指令視窗
clear; clc; close all;


% 1. 指定參數
filepath = 'D:\博士\研究\水滴\水滴實驗數據\實驗影片\已分析數據\20260911荷葉\荷葉\分離\data\20260911_test2_1X_10ul_10ms.csv';
target_duration = 20; % 最終影片長度 15 秒
output_filename = 'D:\博士\研究\水滴\水滴實驗數據\實驗影片\已分析數據\20260911荷葉\荷葉\分離\data\20260911_test2_1X_10ul_10ms.mp4'; % 儲存格式與路徑 (MP4)

% 讀取資料 (假設欄位名稱為 Frame, X, Y, Time)
% 若您的欄位名稱不同，請修改括號內的名稱
% data = readtable(filename,"Sheet","points");
data = readtable(filepath);

% 取得所有不重複的 Frame 數字
frames = unique(data.Frame_Idx,"stable");
num_frames = (max(frames)-min(frames)+1);

% 計算維持 15 秒所需的影格率 (FPS)
% 每一張在影片中重複的次數，因為sum(t_vedio)=num_frames，所以每張影片以fps重複t_vedio次會保證影片總時常相同
repeat_times= diff([0;frames-min(frames)+1]); %*target_duration/num_frames 
fps = round(num_frames / target_duration);

%% 2 & 3. 準備繪圖並整併成影片
% 設定 VideoWriter
v = VideoWriter(output_filename, 'MPEG-4');
v.FrameRate = fps; 
open(v);

% 建立畫布
fig = figure('Position', [100, 100, 800, 600]);

% 為了讓影片平穩，預先計算全域的 X 與 Y 邊界
% 避免播放時座標軸不斷縮放
x_min = min(data.X_um); x_max = max(data.X_um);
y_min = min(data.Y_um); y_max = max(data.Y_um);
x_pad = (x_max - x_min) * 0.1; % 增加 10% 邊距
y_pad = (y_max - y_min) * 0.1;

% 逐幀繪圖
for i = 1:length(frames)
    current_frame = frames(i);
    
    % 篩選當下 frame 的資料點
    idx = data.Frame_Idx == current_frame;
    current_X = data.X_um(idx);
    current_Y = data.Y_um(idx);
    
    % 取得當下時間 (假設同一個 frame 的時間都一樣，取第一個值)
    current_time = data.Time_s(find(idx, 1, 'first'));

    % 繪製散佈圖
    scatter(current_X, current_Y, 20, 'filled', 'MarkerFaceColor', 'b');
    
    % 設定座標軸等比例與範圍
    axis equal;
    xlim([x_min - x_pad, x_max + x_pad]);
    ylim([y_min - y_pad, y_max + y_pad]);
    
    % 標記 XY 軸座標標籤
    xlabel('x(um)');
    ylabel('y(um)');
    grid on;
    
    % 2. 在右上角標記當下時間至小數點後四位
    % 使用當前座標範圍來定位文字 (放在右上角)
    xl = xlim;
    yl = ylim;
    text_x = xl(2) - 0.05 * (xl(2) - xl(1));
    text_y = yl(2) - 0.05 * (yl(2) - yl(1));
    
    time_str = sprintf('Time: %.4f s', current_time);
    text(text_x, text_y, time_str, 'HorizontalAlignment', 'right', ...
         'VerticalAlignment', 'top', 'FontSize', 12, 'FontWeight', 'bold');
     
    % 將當下的圖表擷取為 Frame
    frame_img = getframe(fig);
    for k=1:repeat_times(i)
        % 將擷取到的圖片寫入影片中
        writeVideo(v, frame_img);
    end
    % 清除當前畫布，準備畫下一張
    clf;
end

% 4. 儲存影片並關閉
close(v);
close(fig);

disp(['影片已成功儲存為: ', output_filename]);