% filepath="C:\Users\USER\Downloads\20260831_085913.jpg";
% testimg=imread(filepath);
% [glb_horizon,xmin, xmax, ymin, ymax]=crop_horizon_roi_V3(testimg)
%%
function [p1, xmin, xmax, ymin, ymax] = crop_horizon_roi_V3(I)
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

% --- 新增預覽與輔助線變數 ---
is_right_dragging = false; % 判斷是否正在右鍵拖曳
h_crosshair_h = [];        % 水平十字輔助線
h_crosshair_v = [];        % 垂直十字輔助線
h_temp_pt = [];            % 右鍵拖曳預覽的第二個點
h_temp_line = [];          % 右鍵拖曳預覽的地平線
h_temp_rect = [];          % 右鍵拖曳預覽的 ROI 框

%% ==================== 建立視窗 ====================
fig_h = figure('Name', '地平線與分析範圍選取', 'NumberTitle', 'off');
imshow(I);
hold on;

show_horizon_title();

% 設定滑鼠與鍵盤事件
set(fig_h, 'WindowButtonDownFcn', @mouse_callback);
set(fig_h, 'WindowButtonUpFcn', @mouse_up_callback);
set(fig_h, 'WindowButtonMotionFcn', @mouse_motion_callback);
set(fig_h, 'WindowKeyPressFcn', @key_callback);
set(fig_h, 'UserData', 'running');

waitfor(fig_h, 'UserData', 'done');

%% ==================== Esc 強制結束處理 ====================
if cancelled
    p1 = []; xmin = []; xmax = []; ymin = []; ymax = [];
    return;
end

%% ==================== 正式寫入座標邏輯 ====================
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

%% ==================== 即時更新輔助線與預覽圖形 ====================
    function update_preview(x, y)
        % 1. 更新十字輔助線 (第三階段隱藏)
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

        % 2. 右鍵按住拖曳時的預覽繪製
        if is_right_dragging
            % 畫出/更新預覽中的點 (黃色圓點)
            if isempty(h_temp_pt) || ~isvalid(h_temp_pt)
                h_temp_pt = plot(x, y, 'yo', 'MarkerSize', 8, 'MarkerFaceColor', 'y', 'HitTest', 'off');
            else
                set(h_temp_pt, 'XData', x, 'YData', y, 'Visible', 'on');
            end

            % 地平線階段：已存在第 1 點時，繪製延伸虛線
            if mode == 1 && size(p1, 1) == 1
                if isempty(h_temp_line) || ~isvalid(h_temp_line)
                    h_temp_line = plot([p1(1,1), x], [p1(1,2), y], 'y--', 'LineWidth', 1.5, 'HitTest', 'off');
                else
                    set(h_temp_line, 'XData', [p1(1,1), x], 'YData', [p1(1,2), y], 'Visible', 'on');
                end

            % ROI階段：已存在第 1 點時，繪製框線矩形
            elseif mode == 2 && size(pts, 1) == 1
                t_xmin = min(pts(1,1), x);
                t_xmax = max(pts(1,1), x);
                t_ymin = min(pts(1,2), y);
                t_ymax = max(pts(1,2), y);
                w = max(0.1, t_xmax - t_xmin);
                h = max(0.1, t_ymax - t_ymin);
                if isempty(h_temp_rect) || ~isvalid(h_temp_rect)
                    h_temp_rect = rectangle('Position', [t_xmin, t_ymin, w, h], ...
                        'EdgeColor', 'y', 'LineStyle', ':', 'LineWidth', 1.5, 'HitTest', 'off');
                else
                    set(h_temp_rect, 'Position', [t_xmin, t_ymin, w, h], 'Visible', 'on');
                end
            end
        end
    end

%% ==================== 滑鼠事件處理 ====================
    function mouse_callback(obj, ~)
        click_type = get(obj, 'SelectionType');
        curr_pt = get(gca, 'CurrentPoint');
        x = max(1, min(img_w, curr_pt(1, 1)));
        y = max(1, min(img_h, curr_pt(1, 2)));

        if strcmp(click_type, 'normal')
            % 左鍵：直接點擊確定
            commit_input(x, y);
        elseif strcmp(click_type, 'alt')
            % 右鍵按下：啟動拖曳預覽
            if (mode == 1 && size(p1, 1) >= 2) || (mode == 2 && size(pts, 1) >= 2)
                return;
            end
            is_right_dragging = true;
            update_preview(x, y);
            drawnow;
        end
    end

    function mouse_motion_callback(~, ~)
        curr_pt = get(gca, 'CurrentPoint');
        x = max(1, min(img_w, curr_pt(1, 1)));
        y = max(1, min(img_h, curr_pt(1, 2)));

        update_preview(x, y);
        drawnow;
    end

    function mouse_up_callback(~, ~)
        if is_right_dragging
            is_right_dragging = false;

            % 刪除所有預覽用的圖形物件
            if ~isempty(h_temp_pt) && isvalid(h_temp_pt), delete(h_temp_pt); end
            if ~isempty(h_temp_line) && isvalid(h_temp_line), delete(h_temp_line); end
            if ~isempty(h_temp_rect) && isvalid(h_temp_rect), delete(h_temp_rect); end
            h_temp_pt = []; h_temp_line = []; h_temp_rect = [];

            % 取得放開右鍵時的位置並正式寫入
            curr_pt = get(gca, 'CurrentPoint');
            x = max(1, min(img_w, curr_pt(1, 1)));
            y = max(1, min(img_h, curr_pt(1, 2)));

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
                        reset_preview_handles();
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
                    reset_preview_handles();
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

    function reset_preview_handles()
        h_crosshair_h = []; h_crosshair_v = [];
        h_temp_pt = []; h_temp_line = []; h_temp_rect = [];
    end

%% ==================== 標題顯示 ====================
    function show_horizon_title()
        title({'【步驟 1：選取地平線】', '左鍵按一下選點，或右鍵按住拖曳預覽選點', 'z：撤銷  Enter：確認  Esc：取消'},"FontSize",20);
    end

    function show_roi_title()
        title({'【步驟 2：選取分析區域】', '左鍵按一下選點，或右鍵按住拖曳預覽選點', 'z：撤銷 / 回上一步  Enter：確認  Esc：取消'},"FontSize",20);
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