function [p1, xmin, xmax, ymin, ymax] = crop_horizon_roi(I)
% 輸入：
% I                         原始圖片
%
% 輸出：
% p1 = [x1 y1; x2 y2]      使用者選取的地平線兩點
% xmin, xmax                ROI 的 x 範圍
% ymin, ymax                ROI 的 y 範圍


%% ==================== 初始化 ====================

% 初始化地平線座標。
p1 = [];

% 初始化 ROI 邊界。
xmin = [];

% 初始化 ROI 邊界。
xmax = [];

% 初始化 ROI 邊界。
ymin = [];

% 初始化 ROI 邊界。
ymax = [];

% 初始化 ROI 點座標，沿用原 cropimg 中的變數名稱。
pts = [];

% 初始化目前畫出的黃色點物件。
h_plots = [];

% 初始化地平線物件。
h_line = [];

% 初始化 ROI 矩形物件。
h_rect = [];

% 設定目前操作階段，1 = 地平線、2 = ROI、3 = 最終確認。
mode = 1;

% 記錄使用者是否按 Esc 強制結束。
cancelled = false;

% 取得圖片高度與寬度。
[img_h, img_w] = size(I, [1, 2]);


%% ==================== 建立視窗 ====================

% 建立互動式選取視窗。
fig_h = figure( ...
    'Name', '地平線與分析範圍選取', ...
    'NumberTitle', 'off');

% 顯示原始圖片。
imshow(I);

% 保留目前圖片，使之後可以疊加點、線與矩形。
hold on;

% 顯示第一階段操作說明。
show_horizon_title();

% 設定滑鼠點擊事件。
set(fig_h, 'WindowButtonDownFcn', @mouse_callback);

% 設定鍵盤按鍵事件。
set(fig_h, 'WindowKeyPressFcn', @key_callback);

% 初始化 UserData。
set(fig_h, 'UserData', 'running');

% 等待使用者完成整個選取流程，或關閉視窗。
waitfor(fig_h, 'UserData', 'done');

% ==================== Esc 強制結束處理 ====================
% 如果使用者曾按 Esc。
if cancelled

    % 清空地平線輸出。
    p1 = [];

    % 清空 ROI 輸出。
    xmin = [];

    % 清空 ROI 輸出。
    xmax = [];

    % 清空 ROI 輸出。
    ymin = [];

    % 清空 ROI 輸出。
    ymax = [];

    % 結束函數。
    return;

end
% ==================== 滑鼠事件 ====================
    function mouse_callback(obj, ~)
        % 取得此次滑鼠點擊的種類。
        click_type = get(obj, 'SelectionType');

        % 只接受滑鼠左鍵。
        if ~strcmp(click_type, 'normal')

            % 若不是左鍵則不執行任何動作。
            return;

        end

        % 取得目前滑鼠在圖片座標軸的位置。
        curr_pt = get(gca, 'CurrentPoint');

        % 取得滑鼠的 x 座標。
        x = curr_pt(1, 1);

        % 取得滑鼠的 y 座標。
        y = curr_pt(1, 2);

        % 防止使用者點擊圖片的 x 範圍之外。
        if x < 1 || x > img_w

            % 若超出圖片則忽略此次點擊。
            return;

        end

        % 防止使用者點擊圖片的 y 範圍之外。
        if y < 1 || y > img_h

            % 若超出圖片則忽略此次點擊。
            return;

        end


        %% ---------- 第一階段：選取地平線 ----------

        % 判斷目前是否正在選取地平線。
        if mode == 1

            % 最多只能選取兩個地平線點。
            if size(p1, 1) >= 2

                % 如果已有兩點則不再接受新點。
                return;

            end

            % 將目前點加入地平線座標。
            p1 = [p1; x, y];

            % 在圖片上畫出黃色點。
            h = plot( ...
                x, ...
                y, ...
                'yo', ...
                'MarkerSize', 8, ...
                'MarkerFaceColor', 'y');

            % 儲存黃色點的 graphics handle。
            h_plots = [h_plots, h];

            % 判斷是否已經選滿兩個點。
            if size(p1, 1) == 2

                % 使用兩個點畫出地平線。
                h_line = plot( ...
                    p1(:,1), ...
                    p1(:,2), ...
                    'y-', ...
                    'LineWidth', 2);

            end


        %% ---------- 第二階段：選取 ROI ----------

        % 判斷目前是否正在選取 ROI。
        elseif mode == 2

            % 最多只能選取 ROI 的兩個對角點。
            if size(pts, 1) >= 2

                % 如果已有兩點則不再接受新點。
                return;

            end

            % 將目前點加入 ROI 座標。
            pts = [pts; x, y];

            % 在圖片上畫出黃色點。
            h = plot( ...
                x, ...
                y, ...
                'yo', ...
                'MarkerSize', 8, ...
                'MarkerFaceColor', 'y');

            % 儲存黃色點的 graphics handle。
            h_plots = [h_plots, h];

            % 判斷 ROI 是否已經選滿兩個對角點。
            if size(pts, 1) == 2

                % 計算暫時的 ROI xmin。
                temp_xmin = min(pts(:,1));

                % 計算暫時的 ROI xmax。
                temp_xmax = max(pts(:,1));

                % 計算暫時的 ROI ymin。
                temp_ymin = min(pts(:,2));

                % 計算暫時的 ROI ymax。
                temp_ymax = max(pts(:,2));

                % 畫出黃色虛線矩形。
                h_rect = rectangle( ...
                    'Position', ...
                    [temp_xmin, ...
                     temp_ymin, ...
                     temp_xmax-temp_xmin, ...
                     temp_ymax-temp_ymin], ...
                    'EdgeColor', 'y', ...
                    'LineStyle', '--', ...
                    'LineWidth', 2);

            end

        end

        % 立即更新畫面。
        drawnow;

    end
% ==================== 鍵盤事件 ====================

    function key_callback(~, event)

        % 根據按下的鍵執行不同操作。
        switch event.Key


            %% ---------- Z：回到上一步 / 撤銷 ----------

            % 使用 z 鍵進行撤銷。
            case 'z'


                %% 地平線選取階段

                % 判斷目前是否在地平線選取階段。
                if mode == 1

                    % 如果至少選取了一個點。
                    if ~isempty(p1)

                        % 移除最後一個地平線點。
                        p1(end,:) = [];

                        % 刪除最後一個黃色點。
                        delete(h_plots(end));

                        % 從 graphics handle 中移除該點。
                        h_plots(end) = [];

                        % 如果地平線已經畫出。
                        if ~isempty(h_line)

                            % 刪除地平線。
                            delete(h_line);

                            % 清空地平線 graphics handle。
                            h_line = [];

                        end

                    end


                %% ROI 選取階段

                % 判斷目前是否在 ROI 階段。
                elseif mode == 2

                    % 如果已經選取至少一個 ROI 點。
                    if ~isempty(pts)

                        % 移除最後一個 ROI 點。
                        pts(end,:) = [];

                        % 刪除最後一個黃色點。
                        delete(h_plots(end));

                        % 移除該 graphics handle。
                        h_plots(end) = [];

                        % 如果矩形已經畫出。
                        if ~isempty(h_rect)

                            % 刪除 ROI 矩形。
                            delete(h_rect);

                            % 清空 ROI 矩形 graphics handle。
                            h_rect = [];

                        end

                    % 如果 ROI 還完全沒有選點。
                    else

                        % 回到第一階段。
                        mode = 1;

                        % 清除目前圖形。
                        cla;

                        % 重新顯示原圖。
                        imshow(I);

                        % 保持繪圖。
                        hold on;

                        % 清空地平線點，讓使用者重新選擇。
                        p1 = [];

                        % 清空點 graphics handle。
                        h_plots = [];

                        % 清空地平線 graphics handle。
                        h_line = [];

                        % 顯示地平線操作說明。
                        show_horizon_title();

                    end


                %% 最終確認階段

                % 判斷目前是否在最終確認階段。
                elseif mode == 3

                    % 回到 ROI 選取階段。
                    mode = 2;

                    % 清除目前圖形。
                    cla;

                    % 顯示原始圖片。
                    imshow(I);

                    % 保持繪圖。
                    hold on;

                    % 重新畫出已選定的地平線第一點。
                    h1 = plot( ...
                        p1(1,1), ...
                        p1(1,2), ...
                        'yo', ...
                        'MarkerSize', 8, ...
                        'MarkerFaceColor', 'y');

                    % 重新畫出已選定的地平線第二點。
                    h2 = plot( ...
                        p1(2,1), ...
                        p1(2,2), ...
                        'yo', ...
                        'MarkerSize', 8, ...
                        'MarkerFaceColor', 'y');

                    % 儲存地平線兩點的 graphics handle。
                    h_plots = [h1, h2];

                    % 重新畫出地平線。
                    h_line = plot( ...
                        p1(:,1), ...
                        p1(:,2), ...
                        'y-', ...
                        'LineWidth', 2);

                    % 清空 ROI 點，讓使用者重新框選。
                    pts = [];

                    % 清空矩形 graphics handle。
                    h_rect = [];

                    % 顯示 ROI 操作說明。
                    show_roi_title();

                end


            %% ---------- Enter：進入下一階段 ----------

            % 使用 Enter 確認目前選擇。
            case 'return'
                %% 地平線完成

                % 判斷目前是否在第一階段。
                if mode == 1

                    % 確認已選取兩個地平線點。
                    if size(p1, 1) == 2

                        % 進入 ROI 選取階段。
                        mode = 2;

                        % 清除地平線點的黃色圓點。
                        delete(h_plots);

                        % 清空黃色點 graphics handle。
                        h_plots = [];

                        % 顯示 ROI 操作說明。
                        show_roi_title();

                    else

                        % 若尚未選滿兩點則顯示警告。
                        msgbox('請先選取兩個點來定義地平線！');

                    end


                %% ROI 完成

                % 判斷目前是否在第二階段。
                elseif mode == 2

                    % 確認已選取兩個 ROI 對角點。
                    if size(pts, 1) == 2

                        % 將 ROI 最小 x 座標四捨五入。
                        xmin = round(min(pts(:,1)));

                        % 將 ROI 最大 x 座標四捨五入。
                        xmax = round(max(pts(:,1)));

                        % 將 ROI 最小 y 座標四捨五入。
                        ymin = round(min(pts(:,2)));

                        % 將 ROI 最大 y 座標四捨五入。
                        ymax = round(max(pts(:,2)));

                        % 防止 xmin 超出左邊界。
                        xmin = max(1, xmin);

                        % 防止 xmax 超出右邊界。
                        xmax = min(img_w, xmax);

                        % 防止 ymin 超出上邊界。
                        ymin = max(1, ymin);

                        % 防止 ymax 超出下邊界。
                        ymax = min(img_h, ymax);

                        % 進入最終確認階段。
                        mode = 3;

                        % 顯示裁切後圖片與地平線。
                        show_final_image();

                    else

                        % 若尚未選滿兩點則顯示警告。
                        msgbox('請先選取兩個對角點來定義分析範圍！');

                    end


                %% 最終確認完成

                % 判斷目前是否在第三階段。
                elseif mode == 3

                    % 將 UserData 設為 done，使 waitfor 結束等待。
                    set(fig_h, 'UserData', 'done');

                    % 關閉互動視窗。
                    close(fig_h);

                end


            %% ---------- Esc：強制結束 ----------

            % 使用 Esc 強制取消。
            case 'escape'

                % 設定取消旗標。
                cancelled = true;

                % 將 UserData 設為 done。
                set(fig_h, 'UserData', 'done');

                % 關閉視窗。
                close(fig_h);

        end

    end
% ==================== 顯示地平線提示 ====================
    function show_horizon_title()

        % 顯示第一階段操作方式。
        title({ ...
            '【步驟 1：選取地平線】', ...
            '左鍵點選地平線上的兩個點', ...
            'z：撤銷　 Enter：確認　 Esc：取消'},"FontSize",20);

    end
% ==================== 顯示 ROI 提示 ====================

    function show_roi_title()

        % 顯示第二階段操作方式。
        title({ ...
            '【步驟 2：選取分析區域】', ...
            '左鍵點選矩形的兩個對角點', ...
            'z：撤銷 / 回上一步　 Enter：確認　 Esc：取消'},"FontSize",20);

    end
% ==================== 顯示最終確認圖片 ====================

    function show_final_image()

        % 從原始圖片中擷取 ROI。
        img_crop = I(ymin:ymax, xmin:xmax, :);

        % 清除原本的圖片與圖形。
        cla;

        % 顯示裁切後的 ROI 圖片。
        imshow(img_crop);

        % 保持繪圖以疊加地平線。
        hold on;

        % 將原圖中的地平線 x 座標轉換成 ROI 局部座標。
        p1_crop_x = p1(:,1) - xmin + 1;

        % 將原圖中的地平線 y 座標轉換成 ROI 局部座標。
        p1_crop_y = p1(:,2) - ymin + 1;

        % 在 ROI 圖片上畫出地平線。
        plot( ...
            p1_crop_x, ...
            p1_crop_y, ...
            'y-', ...
            'LineWidth', 2);

        % 在 ROI 圖片上畫出地平線的兩個端點。
        plot( ...
            p1_crop_x, ...
            p1_crop_y, ...
            'yo', ...
            'MarkerSize', 8, ...
            'MarkerFaceColor', 'y');

        % 顯示最終確認說明。
        title({ ...
            '【步驟 3：確認分析區域與地平線】', ...
            'Enter：完成　 z：重新選取 ROI　 Esc：取消'},"FontSize",20);

        % 更新畫面。
        drawnow;

    end

end