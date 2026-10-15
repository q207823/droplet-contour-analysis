function [p1, xmin, xmax, ymin, ymax] = crop_horizon_roi2(I)
% 輸入：
% I                         原始圖片
%
% 輸出：
% p1 = [x1 y1; x2 y2]       使用者選取的地平線兩點
% xmin, xmax                ROI 的 x 範圍
% ymin, ymax                ROI 的 y 範圍

%% ==================== 初始化 ====================
p1 = [];
xmin = [];
xmax = [];
ymin = [];
ymax = [];
pts = [];
h_plots = [];
h_line = [];
h_rect = [];
mode = 1;
cancelled = false;
[img_h, img_w] = size(I, [1, 2]);

% --- 新增功能初始化變數 ---
is_right_dragging = false; % 判斷是否正在右鍵拖曳
h_crosshair_h = [];        % 水平十字輔助線
h_crosshair_v = [];        % 垂直十字輔助線
h_temp_line = [];          % 右鍵拖曳預覽的地平線
h_temp_rect = [];          % 右鍵拖曳預覽的 ROI 框

%% ==================== 建立視窗 ====================
fig_h = figure('Name', '地平線與分析範圍選取', 'NumberTitle', 'off');
imshow(I);
hold on;

show_horizon_title();

% 設定滑鼠與鍵盤事件
set(fig_h, 'WindowButtonDownFcn', @mouse_callback);
set(fig_h, 'WindowButtonUpFcn', @mouse_up_callback);       % 新增：滑鼠放開事件
set(fig_h, 'WindowButtonMotionFcn', @mouse_motion_callback); % 新增：滑鼠移動事件
set(fig_h, 'WindowKeyPressFcn', @key_callback);
set(fig_h, 'UserData', 'running');

waitfor(fig_h, 'UserData', 'done');

%% ==================== Esc 強制結束處理 ====================
if cancelled
    p1 = []; xmin = []; xmax = []; ymin = []; ymax = [];
    return;
end

%% ==================== 共用點擊輸入邏輯 ====================
    function commit_input(x, y)
        if mode == 1
            if size(p1, 1) >= 2, return; end
            p1 = [p1; x, y];
            h = plot(x, y, 'yo', 'MarkerSize', 8, 'MarkerFaceColor', 'y', 'HitTest', 'off');
            h_plots = [h_plots, h];
            if size(p1, 1) == 2
                h_line = plot(p1(:,1), p1(:,2), 'y-', 'LineWidth', 2, 'HitTest', 'off');
            end
        elseif mode == 2
            if size(pts, 1) >= 2, return; end
            pts = [pts; x, y];
            h = plot(x, y, 'yo', 'MarkerSize', 8, 'MarkerFaceColor', 'y', 'HitTest', 'off');
            h_plots = [h_plots, h];
            if size(pts, 1) == 2
                temp_xmin = min(pts(:,1));
                temp_xmax = max(pts(:,1));
                temp_ymin = min(pts(:,2));
                temp_ymax = max(pts(:,2));
                h_rect = rectangle('Position', [temp_xmin, temp_ymin, temp_xmax-temp_xmin, temp_ymax-temp_ymin], ...
                    'EdgeColor', 'y', 'LineStyle', '--', 'LineWidth', 2, 'HitTest', 'off');
            end
        end
        drawnow;
    end

%% ==================== 滑鼠事件 ====================
    function mouse_callback(obj, ~)
        click_type = get(obj, 'SelectionType');
        curr_pt = get(gca, 'CurrentPoint');
        x = curr_pt(1, 1);
        y = curr_pt(1, 2);

        % 防止初始點擊在範圍外
        if x < 1 || x > img_w || y < 1 || y > img_h
            return;
        end

        if strcmp(click_type, 'normal')
            % 左鍵立即輸入
            commit_input(x, y);
        elseif strcmp(click_type, 'alt')
            % 右鍵按下，啟動拖曳預覽模式
            is_right_dragging = true;
        end
    end

    function mouse_motion_callback(~, ~)
        curr_pt = get(gca, 'CurrentPoint');
        x = curr_pt(1, 1);
        y = curr_pt(1, 2);

        % 限制座標在圖片範圍內
        x = max(1, min(img_w, x));
        y = max(1, min(img_h, y));

        % 1. 更新十字游標 (若在確認階段則隱藏)
        if mode == 3
            if ~isempty(h_crosshair_h) && isvalid(h_crosshair_h)
                set(h_crosshair_h, 'Visible', 'off');
                set(h_crosshair_v, 'Visible', 'off');
            end
        else
            if isempty(h_crosshair_h) || ~isvalid(h_crosshair_h)
                h_crosshair_h = plot([1, img_w], [y, y], 'c-', 'LineWidth', 0.5, 'HitTest', 'off');
                h_crosshair_v = plot([x, x], [1, img_h], 'c-', 'LineWidth', 0.5, 'HitTest', 'off');
            else
                set(h_crosshair_h, 'YData', [y, y], 'Visible', 'on');
                set(h_crosshair_v, 'XData', [x, x], 'Visible', 'on');
            end
        end

        % 2. 處理右鍵拖曳預覽
        if is_right_dragging
            if mode == 1 && size(p1, 1) == 1
                if isempty(h_temp_line) || ~isvalid(h_temp_line)
                    h_temp_line = plot([p1(1,1), x], [p1(1,2), y], 'y--', 'LineWidth', 1.5, 'HitTest', 'off');
                else
                    set(h_temp_line, 'XData', [p1(1,1), x], 'YData', [p1(1,2), y]);
                end
            elseif mode == 2 && size(pts, 1) == 1
                t_xmin = min(pts(1,1), x);
                t_xmax = max(pts(1,1), x);
                t_ymin = min(pts(1,2), y);
                t_ymax = max(pts(1,2), y);
                if isempty(h_temp_rect) || ~isvalid(h_temp_rect)
                    h_temp_rect = rectangle('Position', [t_xmin, t_ymin, t_xmax-t_xmin, t_ymax-t_ymin], ...
                        'EdgeColor', 'y', 'LineStyle', ':', 'LineWidth', 1.5, 'HitTest', 'off');
                else
                    set(h_temp_rect, 'Position', [t_xmin, t_ymin, t_xmax-t_xmin, t_ymax-t_ymin]);
                end
            end
        end
        drawnow;
    end

    function mouse_up_callback(~, ~)
        if is_right_dragging
            is_right_dragging = false;
            
            % 刪除預覽用的繪圖物件
            if ~isempty(h_temp_line) && isvalid(h_temp_line)
                delete(h_temp_line);
            end
            if ~isempty(h_temp_rect) && isvalid(h_temp_rect)
                delete(h_temp_rect);
            end
            h_temp_line = [];
            h_temp_rect = [];
            
            % 取得放開右鍵時的最終座標
            curr_pt = get(gca, 'CurrentPoint');
            x = max(1, min(img_w, curr_pt(1, 1)));
            y = max(1, min(img_h, curr_pt(1, 2)));
            
            % 正式輸入該座標
            commit_input(x, y);
        end
    end

%% ==================== 鍵盤事件 ====================
    function key_callback(~, event)
        switch event.Key
            case 'z'
                if mode == 1
                    if ~isempty(p1)
                        p1(end,:) = [];
                        delete(h_plots(end));
                        h_plots(end) = [];
                        if ~isempty(h_line)
                            delete(h_line);
                            h_line = [];
                        end
                    end
                elseif mode == 2
                    if ~isempty(pts)
                        pts(end,:) = [];
                        delete(h_plots(end));
                        h_plots(end) = [];
                        if ~isempty(h_rect)
                            delete(h_rect);
                            h_rect = [];
                        end
                    else
                        mode = 1;
                        cla;
                        imshow(I);
                        hold on;
                        p1 = []; h_plots = []; h_line = [];
                        show_horizon_title();
                        
                        % 清除殘留的預覽變數
                        h_crosshair_h = []; h_crosshair_v = [];
                    end
                elseif mode == 3
                    mode = 2;
                    cla;
                    imshow(I);
                    hold on;
                    h1 = plot(p1(1,1), p1(1,2), 'yo', 'MarkerSize', 8, 'MarkerFaceColor', 'y', 'HitTest', 'off');
                    h2 = plot(p1(2,1), p1(2,2), 'yo', 'MarkerSize', 8, 'MarkerFaceColor', 'y', 'HitTest', 'off');
                    h_plots = [h1, h2];
                    h_line = plot(p1(:,1), p1(:,2), 'y-', 'LineWidth', 2, 'HitTest', 'off');
                    pts = []; h_rect = [];
                    show_roi_title();
                    
                    % 清除殘留的預覽變數
                    h_crosshair_h = []; h_crosshair_v = [];
                end

            case 'return'
                if mode == 1
                    if size(p1, 1) == 2
                        mode = 2;
                        delete(h_plots);
                        h_plots = [];
                        show_roi_title();
                    else
                        msgbox('請先選取兩個點來定義地平線！');
                    end
                elseif mode == 2
                    if size(pts, 1) == 2
                        xmin = max(1, round(min(pts(:,1))));
                        xmax = min(img_w, round(max(pts(:,1))));
                        ymin = max(1, round(min(pts(:,2))));
                        ymax = min(img_h, round(max(pts(:,2))));
                        mode = 3;
                        show_final_image();
                    else
                        msgbox('請先選取兩個對角點來定義分析範圍！');
                    end
                elseif mode == 3
                    set(fig_h, 'UserData', 'done');
                    close(fig_h);
                end

            case 'escape'
                cancelled = true;
                set(fig_h, 'UserData', 'done');
                close(fig_h);
        end
    end

%% ==================== 標題顯示 ====================
    function show_horizon_title()
        title({'【步驟 1：選取地平線】', '左鍵點擊或右鍵拖曳選取地平線上兩點', 'z：撤銷  Enter：確認  Esc：取消'},"FontSize",20);
    end

    function show_roi_title()
        title({'【步驟 2：選取分析區域】', '左鍵點擊或右鍵拖曳選取矩形兩個對角點', 'z：撤銷 / 回上一步  Enter：確認  Esc：取消'},"FontSize",20);
    end

    function show_final_image()
        img_crop = I(ymin:ymax, xmin:xmax, :);
        cla;
        imshow(img_crop);
        hold on;

        p1_crop_x = p1(:,1) - xmin + 1;
        p1_crop_y = p1(:,2) - ymin + 1;

        plot(p1_crop_x, p1_crop_y, 'y-', 'LineWidth', 2);
        plot(p1_crop_x, p1_crop_y, 'yo', 'MarkerSize', 8, 'MarkerFaceColor', 'y');

        title({'【步驟 3：確認分析區域與地平線】', 'Enter：完成  z：重新選取 ROI  Esc：取消'},"FontSize",20);
        drawnow;
    end
end