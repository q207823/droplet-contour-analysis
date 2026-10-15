function [contact_angle, diagnostics] = contact_angle_calculator(point, horizon, contact_point, options)
%CONTACT_ANGLE_CALCULATOR 以輪廓割線估算左右接觸角。
%
% 【功能概述】
%   從每個接觸點沿著有序輪廓，判斷哪一個索引方向會進入水滴上方，
%   再以「接觸點」到「沿該方向第 n 個輪廓點」的割線近似局部切線。
%   最後計算此割線與朝向水滴內部之地平線方向的夾角。
%
% 【輸入格式與意義】
%   point           N×2 double。
%                   第 1 欄為 x 座標，第 2 欄為 y 座標；單位可為 pixel
%                   或 um，但 POINT 與 HORIZON 必須使用相同座標系與單位。
%                   N 個點必須依輪廓順序排列，並視為首尾相接的循環輪廓。
%
%   horizon         2×2 double。
%                   每列是一個地平線上的點：[x, y]。兩點不可重合；
%                   第 1 點到第 2 點定義地平線正方向。
%
%   contact_point   2×2 double。
%                   兩列分別是一個接觸點的 [x, y]。輸入時左右順序不限；
%                   函式會依沿地平線的投影座標重新排序成左、右。
%
%   options.NumSecantPoints
%                   正整數，預設為 5。表示從接觸點沿輪廓走幾個索引間隔，
%                   並以該點作為割線另一端；若輪廓不足，最多使用 N-1。
%
%   options.ContactIndices
%                   選填，含兩個元素的索引，對應 CONTACT_POINT 在 POINT
%                   中的位置。若省略，會以歐氏距離最近的輪廓點自動配對。
%
%   options.Showup   logical 或 0/1，預設為 0（不顯示）。
%                   設為 1 時，會另開一個視窗顯示校正後輪廓、接觸點、
%                   接觸角割線、角弧與左右角度數值。
%
% 【輸出格式與意義】
%   contact_angle   1×2 double，單位為 degree。
%                   格式固定為 [左接觸角, 右接觸角]，範圍為 0 到 180 度。
%
%   diagnostics     struct，選填的診斷資訊，包含：
%                   contact_points_left_to_right：排序後接觸點，2×2。
%                   contact_indices：接觸點在 POINT 中的索引，1×2。
%                   secant_indices：割線另一端的索引，1×2。
%                   secant_points：割線另一端座標，2×2。
%                   contour_direction：沿輪廓前進方向，+1 或 -1。
%                   num_secant_points：實際採用的索引間隔數。
%                   horizon_tangent：地平線單位切向量，1×2。
%                   drop_normal：指向水滴上方的單位法向量，1×2。
%                   local_coordinate：每個輪廓點的 [s,z]，N×2；
%                       s 為沿地平線座標，z 為地平線以上高度。
%
% 【使用範例】
%   [contact_point,contact_idx] = curvature_calculator_6(point,horizon);
%   [angle,info] = contact_angle_calculator(point,horizon,contact_point, ...
%       'NumSecantPoints',5,'ContactIndices',contact_idx,'Showup',1);

    %% 1. 定義輸入規格與基本資料檢查
    % arguments 區塊會先限制陣列尺寸、資料型別及有限值，避免錯誤資料進入計算。
    arguments
        % N×2 的實數輪廓座標；每一列是一個 [x,y] 點。
        point (:,2) double {mustBeFinite, mustBeReal}
        % 2×2 的地平線兩點；兩點必須在相同座標系中。
        horizon (2,2) double {mustBeFinite, mustBeReal}
        % 2×2 的接觸點座標；輸入順序可為任意順序。
        contact_point (2,2) double {mustBeFinite, mustBeReal}
        % 從接觸點沿輪廓走的索引間隔數，預設取第 5 個點。
        options.NumSecantPoints (1,1) double {mustBeInteger, mustBePositive} = 5
        % 選填的兩個接觸點索引；空陣列表示由座標自動尋找。
        options.ContactIndices double = []
        % 是否顯示單幀分析結果；false/0 不顯示，true/1 才建立圖形視窗。
        options.Showup (1,1) logical = false
    end

    % 取得輪廓總點數 N，後續循環索引與邊界檢查都會使用此值。
    n = size(point,1);
    % 少於 3 點無法形成可用的局部輪廓，因此立即停止並回報錯誤。
    if n < 3
        error('contact_angle_calculator:TooFewPoints', ...
            'At least three ordered contour points are required.');
    end

    %% 2. 建立以地平線為基準的局部座標系
    % 由地平線第 1 點指向第 2 點，得到尚未正規化的地平線向量。
    horizon_vector = horizon(2,:) - horizon(1,:);
    % 計算地平線向量長度，用於正規化與重合點檢查。
    horizon_length = norm(horizon_vector);
    % 以座標尺度相關的機器精度判斷兩個地平線點是否實際重合。
    if horizon_length <= eps(max(1,max(abs(horizon),[],'all')))
        error('contact_angle_calculator:InvalidHorizon', ...
            'The two horizon points must be distinct.');
    end

    % tangent 是沿地平線正方向的單位切向量。
    tangent = horizon_vector / horizon_length;
    % 將 tangent 逆時針旋轉 90 度，先建立其中一個候選單位法向量。
    normal = [-tangent(2), tangent(1)];
    % 將所有輪廓點平移，使地平線第 1 點成為局部座標原點。
    relative = point - horizon(1,:);
    % s 是每個輪廓點在地平線切向量上的投影座標。
    s = relative * tangent';
    % z_signed 是每個輪廓點在候選法向量上的帶正負號投影高度。
    z_signed = relative * normal';

    % 比較法向量正、負兩側的最大輪廓延伸量；水滴主體所在側應具有較大延伸。
    if abs(min(z_signed)) > abs(max(z_signed))
        % 若水滴主要位於負側，反轉法向量，使正 z 固定代表地平線以上／水滴方向。
        normal = -normal;
        % 法向量反轉後，所有帶正負號高度也必須同步反號。
        z_signed = -z_signed;
    end

    %% 3. 將接觸點統一排序為左、右，並取得其輪廓索引
    % 計算兩個接觸點沿地平線方向的投影座標。
    contact_s = (contact_point - horizon(1,:)) * tangent';
    % 依投影座標由小到大排序；結果固定為第 1 列左側、第 2 列右側。
    [~, contact_order] = sort(contact_s, 'ascend');
    % 依剛才的排序重新排列接觸點座標。
    contact_point = contact_point(contact_order,:);

    % 若呼叫端沒有提供索引，便由接觸點座標尋找 POINT 中最近的點。
    if isempty(options.ContactIndices)
        % 預先配置 1×2 索引陣列，欄位依序代表左、右接觸點。
        contact_idx = zeros(1,2);
        % 分別處理左、右兩個接觸點。
        for side = 1:2
            % 計算所有輪廓點到該接觸點的平方距離，取最小者的索引。
            [~, contact_idx(side)] = min(sum((point-contact_point(side,:)).^2,2));
        end
    else
        % 若有提供索引，必須剛好有兩個元素，分別對應兩個接觸點。
        if numel(options.ContactIndices) ~= 2
            error('contact_angle_calculator:InvalidContactIndices', ...
                'ContactIndices must contain exactly two indices.');
        end
        % 將索引統一整理成 1×2 列向量，避免輸入為直行向量時維度不一致。
        contact_idx = reshape(options.ContactIndices,1,[]);
        % CONTACT_POINT 已重新排序，因此索引也必須套用相同的左右排序。
        contact_idx = contact_idx(contact_order);
        % 索引必須是介於 1 到 N 的整數，否則無法安全存取 POINT。
        if any(contact_idx < 1 | contact_idx > n | contact_idx ~= round(contact_idx))
            error('contact_angle_calculator:InvalidContactIndices', ...
                'ContactIndices must be valid integer indices into POINT.');
        end
    end

    %% 4. 從每個接觸點判斷「沿輪廓向上」的方向，選出割線端點
    % 實際步數不能超過 N-1，以免繞一圈後回到原接觸點。
    step_count = min(options.NumSecantPoints,n-1);
    % 預先配置左右割線端點在 POINT 中的索引。
    secant_idx = zeros(1,2);
    % 紀錄選擇的輪廓方向：+1 代表索引增加，-1 代表索引減少。
    contour_direction = zeros(1,2);

    % 左、右接觸點分別判斷一次。
    for side = 1:2
        % centre 是目前接觸點在 POINT 中的索引。
        centre = contact_idx(side);
        % 建立索引增加方向的後續點；mod 讓索引跨過 N 後回到 1。
        forward = mod((centre-1)+(1:step_count),n)+1;
        % 建立索引減少方向的後續點；mod 讓索引低於 1 時從 N 繼續。
        backward = mod((centre-1)-(1:step_count),n)+1;
        % 取得接觸點本身的局部高度，作為比較兩方向上升量的基準。
        z0 = z_signed(centre);

        % 計算索引增加方向各候選點相對於接觸點的高度變化。
        forward_rise = z_signed(forward)-z0;
        % 計算索引減少方向各候選點相對於接觸點的高度變化。
        backward_rise = z_signed(backward)-z0;
        % 分數同時考慮最大上升量與平均上升量，降低單一雜訊點造成的誤判。
        forward_score = max(forward_rise) + mean(forward_rise);
        % 對索引減少方向計算相同的上升分數。
        backward_score = max(backward_rise) + mean(backward_rise);

        % 選擇上升分數較高的方向，視為從接觸點進入水滴上方的輪廓分支。
        if forward_score >= backward_score
            % 取該方向第 step_count 個點作為割線另一端。
            secant_idx(side) = forward(end);
            % +1 表示沿 POINT 索引增加方向取點。
            contour_direction(side) = 1;
        else
            % 若反方向上升較明顯，取索引減少方向的第 step_count 個點。
            secant_idx(side) = backward(end);
            % -1 表示沿 POINT 索引減少方向取點。
            contour_direction(side) = -1;
        end
    end

    %% 5. 計算割線與朝向水滴內部之地平線的夾角
    % delta_s 是接觸點到割線端點在地平線方向上的位移。
    delta_s = s(secant_idx)' - s(contact_idx)';
    % delta_z 是接觸點到割線端點朝水滴上方的高度位移。
    delta_z = z_signed(secant_idx)' - z_signed(contact_idx)';
    % 左接觸點朝水滴內部是 +s；右接觸點朝水滴內部是 -s。
    inward_sign = [1,-1];
    % atan2d 使用垂直位移與「朝內」水平位移，得到幾何夾角。
    contact_angle = atan2d(abs(delta_z),inward_sign.*delta_s);
    % 先將可能的角度數值統一映射到 0 到 360 度。
    contact_angle = mod(contact_angle,360);
    % 若角度大於 180 度，改取其較小的等價夾角，使結果限制在 0 到 180 度。
    contact_angle(contact_angle > 180) = 360-contact_angle(contact_angle > 180);

    %% 6. 依 Showup 選項決定是否顯示單幀圖像化結果
    % 預設 Showup=false，因此一般批次分析不會建立任何 figure 或拖慢迴圈。
    if options.Showup
        % 繪圖工作交由獨立子函式處理，使角度計算主流程保持單純且可重用。
        plot_contact_angle_result([s,z_signed],contact_idx,secant_idx, ...
            contact_angle,step_count);
    end

    %% 7. 視需要整理診斷資訊
    % 只有呼叫端要求第二個輸出時才建立 diagnostics，避免不必要的記憶體使用。
    if nargout >= 2
        % 將中間結果集中成 struct，供除錯、畫圖或參數敏感度分析使用。
        diagnostics = struct( ...
            'contact_points_left_to_right', contact_point, ... % 左右排序後的接觸點座標。
            'contact_indices', contact_idx, ...                % 左右接觸點的原輪廓索引。
            'secant_indices', secant_idx, ...                  % 左右割線端點的輪廓索引。
            'secant_points', point(secant_idx,:), ...          % 左右割線端點的原始座標。
            'contour_direction', contour_direction, ...        % 向上分支的索引前進方向。
            'num_secant_points', step_count, ...               % 實際使用的索引間隔數。
            'horizon_tangent', tangent, ...                    % 地平線單位切向量。
            'drop_normal', normal, ...                         % 指向水滴上方的單位法向量。
            'local_coordinate', [s,z_signed]);                 % 所有輪廓點的局部 [s,z]。
    end
end

function plot_contact_angle_result(local_coordinate,contact_idx,secant_idx,contact_angle,step_count)
%PLOT_CONTACT_ANGLE_RESULT 顯示單幀輪廓、接觸點與接觸角。
%
% 【輸入】
%   local_coordinate  N×2 double，每列為 [s,z]；s 沿地平線，z 朝水滴上方。
%   contact_idx       1×2 double，左右接觸點在輪廓中的索引。
%   secant_idx        1×2 double，左右割線端點在輪廓中的索引。
%   contact_angle     1×2 double，[左角,右角]，單位 degree。
%   step_count        scalar，割線端點與接觸點相隔的輪廓索引數。
%
% 【輸出】
%   無數值輸出；此子函式只建立一個 MATLAB figure。

    %% 繪圖階段 1：定義線寬與圖形尺度
    % 輪廓 POINT 的基準線寬集中定義在此，方便未來統一調整。
    point_line_width = 2;
    % 依使用者要求，接觸點外框、角度割線與角弧皆為 POINT 線寬的一半。
    result_line_width = point_line_width/2;
    % 分離局部水平座標 s。
    s = local_coordinate(:,1);
    % 分離指向水滴上方的局部高度 z。
    z = local_coordinate(:,2);
    % 以整體輪廓尺度決定角度示意線長度，避免不同放大倍率下過長或過短。
    plot_scale = max([max(s)-min(s),max(z)-min(z),1]);
    % 角度割線顯示長度設為整體尺度的 12%。
    ray_length = 0.12*plot_scale;
    % 角弧半徑取角度割線長度的 45%。
    arc_radius = 0.45*ray_length;

    %% 繪圖階段 2：建立畫布並繪製輪廓與地平線
    % 建立白底圖形視窗；只有 Showup=1 時主函式才會呼叫本子函式。
    fig = figure('Color','w','Name','接觸角分析結果','NumberTitle','off');
    % 在圖形視窗內建立座標軸。
    ax = axes(fig);
    % 以藍線和小圓點畫出依序排列的全部輪廓 POINT。
    plot(ax,s,z,'-o','Color',[0,0.4470,0.7410], ...
        'LineWidth',point_line_width,'MarkerSize',3, ...
        'MarkerFaceColor',[0,0.4470,0.7410]);
    % 保留目前圖形，以便疊加地平線、接觸點、割線和角弧。
    hold(ax,'on');
    % 在 z=0 畫出黑色虛線，表示旋轉校正後的地平線。
    yline(ax,0,'k--','地平線','LineWidth',result_line_width);

    %% 繪圖階段 3：標記左右接觸點與實際使用的割線端點
    % 以紅色實心圓標出左右接觸點；外框線寬為 POINT 線寬的一半。
    plot(ax,s(contact_idx),z(contact_idx),'ro','MarkerSize',9, ...
        'MarkerFaceColor','r','LineWidth',result_line_width);
    % 以紅色菱形標出第 step_count 個輪廓點，也就是實際割線取樣端點。
    plot(ax,s(secant_idx),z(secant_idx),'rd','MarkerSize',6, ...
        'MarkerFaceColor','r','LineWidth',result_line_width);

    %% 繪圖階段 4：繪製左右接觸角割線與角弧
    % 左側水滴內向方向為 +s，因此割線方向為 [cos(左角),sin(左角)]。
    left_ray = [cosd(contact_angle(1)),sind(contact_angle(1))];
    % 右側水滴內向方向為 -s，因此水平分量需加負號。
    right_ray = [-cosd(contact_angle(2)),sind(contact_angle(2))];
    % 從左接觸點沿左側割線方向畫出紅線，線寬為 POINT 的一半。
    plot(ax,s(contact_idx(1))+[0,left_ray(1)]*ray_length, ...
        z(contact_idx(1))+[0,left_ray(2)]*ray_length, ...
        'r-','LineWidth',result_line_width);
    % 從右接觸點沿右側割線方向畫出紅線，線寬為 POINT 的一半。
    plot(ax,s(contact_idx(2))+[0,right_ray(1)]*ray_length, ...
        z(contact_idx(2))+[0,right_ray(2)]*ray_length, ...
        'r-','LineWidth',result_line_width);

    % 左側角弧由地平線 +s 方向的 0 度畫到左接觸角。
    theta_left = linspace(0,contact_angle(1),40);
    % 右側角弧由割線方向 180-右角畫到地平線 -s 方向的 180 度。
    theta_right = linspace(180-contact_angle(2),180,40);
    % 以左接觸點為圓心畫出紅色角弧。
    plot(ax,s(contact_idx(1))+arc_radius*cosd(theta_left), ...
        z(contact_idx(1))+arc_radius*sind(theta_left), ...
        'r-','LineWidth',result_line_width);
    % 以右接觸點為圓心畫出紅色角弧。
    plot(ax,s(contact_idx(2))+arc_radius*cosd(theta_right), ...
        z(contact_idx(2))+arc_radius*sind(theta_right), ...
        'r-','LineWidth',result_line_width);

    %% 繪圖階段 5：標示角度數值並完成座標軸設定
    % 在左接觸點上方顯示左接觸角；char(176) 為度數符號。
    text(ax,s(contact_idx(1)),z(contact_idx(1))+0.70*ray_length, ...
        sprintf('L %.1f%c',contact_angle(1),char(176)), ...
        'Color','r','FontWeight','bold','HorizontalAlignment','center', ...
        'Interpreter','none');
    % 在右接觸點上方顯示右接觸角。
    text(ax,s(contact_idx(2)),z(contact_idx(2))+0.70*ray_length, ...
        sprintf('R %.1f%c',contact_angle(2),char(176)), ...
        'Color','r','FontWeight','bold','HorizontalAlignment','center', ...
        'Interpreter','none');
    % 標題同時說明本次割線使用的輪廓點間隔數。
    title(ax,sprintf('接觸角分析結果：第 %d 個輪廓點割線',step_count));
    % 水平軸為沿地平線方向的局部距離，單位沿用輸入座標。
    xlabel(ax,'沿地平線方向座標 s');
    % 垂直軸為朝水滴上方的局部高度，單位沿用輸入座標。
    ylabel(ax,'地平線以上高度 z');
    % 固定兩軸比例相同，避免水滴輪廓及角度因畫面縮放而失真。
    axis(ax,'equal');
    % 顯示格線與座標軸外框，方便目視檢查位置。
    grid(ax,'on');
    box(ax,'on');
end
