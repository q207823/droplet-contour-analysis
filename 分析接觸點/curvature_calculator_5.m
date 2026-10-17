function [contact_point, contact_idx, diagnostics] = curvature_calculator_5(point, horizon, options)
%CURVATURE_CALCULATOR_5 由有序水滴輪廓找出左右兩個固液接觸點。
%
% 【重要說明】
%   本函式不直接計算接觸角，而是找出接觸點。接觸角需再呼叫
%   contact_angle_calculator，利用接觸點附近的輪廓割線計算。例如：
%
%       [contact_point,contact_idx] = curvature_calculator_5(point,horizon);
%       theta = contact_angle_calculator(point,horizon,contact_point, ...
%           'ContactIndices',contact_idx,'NumSecantPoints',5);
%
% 【輸入】
%   point    N×2 double，每列為一個 [x,y] 輪廓點。輪廓點必須依輪廓
%            順序排列，且整條輪廓視為首尾相接的封閉循環。
%   horizon  2×2 double，兩列為地平線上的兩個點 [x,y]。第 1 點指向
%            第 2 點的方向定義局部座標的水平正方向。
%
% 【選項】
%   MinArcFraction          搜尋圓弧段時允許的最短比例，預設 0.25。
%   MaxArcFraction          搜尋圓弧段時允許的最長比例，預設 0.90。
%   FarFraction             初始圓形擬合採用的高處輪廓點比例，預設 0.35。
%   RefinementPasses        圓形模型反覆修正次數，預設 2。
%   ExpectedGroundFraction  預期地面段占完整輪廓的比例，預設 1/3。
%
% 【輸出】
%   contact_point  2×2 double，依沿地平線方向由左至右排列的接觸點。
%   contact_idx    1×2 double，接觸點在原始 POINT 中的索引。
%   diagnostics    診斷資訊，包括圓弧段、地面段、圓形擬合與局部座標軸。
%
% 【核心方法】
%   1. 將輪廓轉換成沿地平線的 s 座標與垂直地平線的 z 座標。
%   2. 以離地平線較遠的輪廓點建立初始圓形模型。
%   3. 比較每個點對「地平線模型」與「圓形模型」的符合程度，找出連續
%      的圓弧段；此步驟主要用於修正圓形模型及輸出診斷資訊。
%   4. 在循環輪廓上尋找一段固定長度的連續點，使其 z 幾乎不變且 s
%      隨索引近似線性變化；這一段被視為沿著固體表面的地面段。
%   5. 地面段兩端外側緊鄰的輪廓點，即定義為左右接觸點。
%
%   相較於直接尋找單點最大曲率，此方法以整段輪廓共同擬合，因此較不
%   容易受到像素鋸齒、單點雜訊或離散曲率尖峰影響。

    arguments
        point (:,2) double {mustBeFinite, mustBeReal}
        horizon (2,2) double {mustBeFinite, mustBeReal}
        options.MinArcFraction (1,1) double = 0.25
        options.MaxArcFraction (1,1) double = 0.90
        options.FarFraction (1,1) double = 0.35
        options.RefinementPasses (1,1) double = 2
        options.ExpectedGroundFraction (1,1) double = 1/3
    end

    %% 1. 檢查輪廓點數與地平線
    % 點數太少時，無法可靠地分辨圓弧段與地面段。
    if size(point,1) < 12
        error('curvature_calculator_5:TooFewPoints', ...
            'At least 12 ordered contour points are required.');
    end

    % horizon_vector 是地平線第 1 點指向第 2 點的向量。
    horizon_vector = horizon(2,:) - horizon(1,:);
    % 地平線長度用於檢查兩點是否重合，並將方向正規化。
    horizon_length = norm(horizon_vector);
    if horizon_length <= eps(max(abs(horizon),[],'all'))
        error('curvature_calculator_5:InvalidHorizon', ...
            'The two horizon points must be distinct.');
    end

    %% 2. 移除輪廓尾端重複的封閉點
    % 某些輪廓產生器會把最前面的數個點再次附加到陣列尾端，以明確表示
    % 封閉輪廓。計算時先忽略這些完全重複的尾端點，但輸出的索引仍對應
    % 原始 POINT。舊版資料產生器可能重複前 5 個點，因此不可只檢查 1 點。
    n_original = size(point,1);
    closure_count = repeated_closure_count(point);
    n = n_original - closure_count;
    contour = point(1:n,:);

    %% 3. 建立以地平線為基準的局部座標系
    % tangent：沿地平線的單位切向量；s 座標沿此方向增加。
    tangent = horizon_vector / horizon_length;
    % normal：將 tangent 逆時針旋轉 90 度得到的候選單位法向量。
    normal = [-tangent(2), tangent(1)];
    % 先把所有輪廓點平移，使 horizon(1,:) 成為局部座標原點。
    relative = contour - horizon(1,:);
    % s：每個輪廓點沿地平線方向的投影座標。
    s = relative * tangent';
    % z_signed：每個輪廓點在地平線法向方向的帶正負號高度。
    z_signed = relative * normal';

    % 讓法向量固定朝向水滴主體。若大部分較遠的輪廓位於法向量負側，
    % 就同時反轉 normal 與 z_signed，使水滴方向通常對應正 z。
    if quantile(z_signed,0.90) < -quantile(z_signed,0.10)
        z_signed = -z_signed;
        normal = -normal;
    end
    % z 僅表示到地平線的法向距離，不保留上下符號。
    z = abs(z_signed);

    %% 4. 使用離地平線較遠的點建立初始圓形模型
    % 高處點通常屬於液滴自由表面，而不是近水平的固體表面。取距離地平線
    % 最遠的一部分輪廓點，可避免初始圓形擬合被地面段嚴重拉偏。
    far_count = max(12, min(n-4, round(options.FarFraction*n)));
    [~, far_order] = sort(z,'descend');
    circle_idx = far_order(1:far_count);
    [centre_s, centre_z, radius] = fit_circle_algebraic(s(circle_idx), z_signed(circle_idx));

    %% 5. 設定允許的圓弧段長度
    % 圓弧段必須是一段循環連續索引，且長度限制為完整輪廓的一定比例。
    min_arc_length = max(8, round(options.MinArcFraction*n));
    max_arc_length = min(n-4, round(options.MaxArcFraction*n));
    if min_arc_length > max_arc_length
        error('curvature_calculator_5:InvalidArcFractions', ...
            'MinArcFraction and MaxArcFraction do not define a valid range.');
    end

    %% 6. 反覆比較圓形模型與地平線模型，修正自由表面圓形
    % preference > 0 表示該點相對更像圓弧；preference < 0 表示更像地面。
    preference = zeros(n,1);
    for pass = 1:max(1,round(options.RefinementPasses))
        % 每一點到目前圓形的徑向殘差。
        circle_residual = abs(hypot(s-centre_s,z_signed-centre_z)-radius);

        % 用最靠近已知地平線的 20% 點估計量測雜訊。MAD 乘以 1.4826 可在
        % 近似常態雜訊下對應標準差，且比直接使用標準差更不怕離群值。
        near_count = max(8, round(0.20*n));
        sorted_z = sort(z);
        noise_scale = max(1.4826*median(abs(sorted_z(1:near_count) - ...
            median(sorted_z(1:near_count)))), eps(max(abs(contour),[],'all')));
        % clip 限制單一極端殘差的影響，避免少數壞點主導模型比較。
        clip = max(4*noise_scale, quantile(sorted_z(1:near_count),0.90));
        clip = max(clip, eps(max(abs(contour),[],'all')));

        % line_loss：點離地平線越遠，地平線模型損失越大。
        line_loss = min((z/clip).^2, 9);
        % circle_loss：點離擬合圓越遠，圓形模型損失越大。
        circle_loss = min((circle_residual/clip).^2, 9);
        % 正值表示圓形模型優於地平線模型，因此該點較像液滴自由表面。
        preference = line_loss - circle_loss;

        % 在封閉輪廓上尋找總 preference 最大的連續段，視為圓弧段。
        [~, ~, arc_idx] = best_cyclic_run(preference, ...
            min_arc_length, max_arc_length);
        % 以找到的完整圓弧段重新擬合圓，供下一輪比較使用。
        if numel(arc_idx) >= 12
            [centre_s, centre_z, radius] = fit_circle_algebraic( ...
                s(arc_idx), z_signed(arc_idx));
        end
    end

    %% 7. 尋找沿固體表面的連續地面段
    % 原始合成資料約由 200 個圓弧點與 100 個地面點構成，因此預設地面段
    % 長度為總輪廓的 1/3。若實際輪廓取樣方式不同，可用
    % ExpectedGroundFraction 調整。
    ground_length = round(options.ExpectedGroundFraction*n);
    ground_length = max(4,min(n-8,ground_length));
    % best_horizon_run 同時要求：
    %   (1) z 幾乎固定，也就是靠近同一條地平線；
    %   (2) s 隨點序近似線性變化，也就是輪廓點沿地面依序前進。
    [ground_start,ground_end,ground_idx,ground_fit_cost] = ...
        best_horizon_run(s,z_signed,ground_length);

    %% 8. 將地面段兩端外側的相鄰點定義為接觸點
    % ground_start 前一點與 ground_end 後一點屬於液滴自由表面，並緊鄰
    % 地面段的左右兩端。mod 讓索引跨過 1 或 n 時仍能在封閉輪廓上循環。
    raw_idx = [mod(ground_start-2,n)+1, mod(ground_end,n)+1];
    % 接觸點在輪廓陣列中的先後順序不一定等於幾何左右，因此最後依 s
    % 由小到大排序，確保輸出固定為 [左接觸點;右接觸點]。
    [~, left_to_right] = sort(s(raw_idx),'ascend');
    contact_idx = raw_idx(left_to_right);
    contact_point = point(contact_idx,:);

    %% 9. 視需要輸出診斷資訊
    % 只有呼叫端要求第三個輸出時才建立 diagnostics，節省一般批次處理成本。
    if nargout >= 3
        diagnostics = struct( ...
            'unique_point_count', n, ...
            'repeated_closure_count', closure_count, ...
            'arc_indices', arc_idx, ...
            'ground_indices', ground_idx, ...
            'ground_fit_cost', ground_fit_cost, ...
            'circle_centre_local', [centre_s, centre_z], ...
            'circle_radius', radius, ...
            'model_preference', preference, ...
            'horizon_tangent', tangent, ...
            'drop_normal', normal);
    end
end

function [best_start,best_end,best_idx,best_cost] = best_horizon_run(s,z,run_length)
%BEST_HORIZON_RUN 找出最符合「近水平、等間距」條件的循環連續段。
%   對每一個可能的起點建立長度為 RUN_LENGTH 的候選段，並分別計算：
%   1. s 相對於線性點序模型的殘差；
%   2. z 相對於該段平均高度的殘差。
%   兩者平方和最小的候選段被選為地面段。

    n = numel(s);
    % 每個 starts 元素代表一個可能的循環起點（此處用 0-based 方便 mod）。
    starts = (0:n-1)';
    offsets = 0:run_length-1;
    % index_matrix 的每一列是一段完整的候選循環索引。
    index_matrix = mod(starts+offsets,n)+1;

    % 轉置後，每一欄代表一個候選段，每一列代表段內的相對點序。
    s_runs = s(index_matrix)';
    z_runs = z(index_matrix)';
    sample_number = (0:run_length-1)';
    % s 約為「斜率×點序+截距」，因此使用一次直線設計矩陣。
    line_design = [sample_number,ones(run_length,1)];

    % s_residual 衡量點在地平線方向上的取樣是否近似均勻。
    s_residual = s_runs-line_design*(line_design\s_runs);
    % z_residual 衡量候選段是否維持近似固定的法向高度。
    z_residual = z_runs-mean(z_runs,1);
    % 對每個候選段加總兩種殘差平方，選擇成本最小者。
    costs = sum(s_residual.^2+z_residual.^2,1);
    [best_cost,best_start] = min(costs);
    best_idx = index_matrix(best_start,:);
    best_end = best_idx(end);
end

function count = repeated_closure_count(point)
%REPEATED_CLOSURE_COUNT 計算輪廓尾端重複了多少個開頭點。
%   最多檢查 20 點，並用隨座標尺度調整的機器精度作為相等容許值。

    n = size(point,1);
    max_count = min(20, floor(n/4));
    scale = max(1, max(abs(point),[],'all'));
    tolerance = 32*eps(scale);
    count = 0;
    for k = 1:max_count
        if all(abs(point(n-k+1:n,:) - point(1:k,:)) <= tolerance,'all')
            count = k;
        end
    end
end

function [centre_x, centre_y, radius] = fit_circle_algebraic(x, y)
%FIT_CIRCLE_ALGEBRAIC 以線性最小平方法擬合圓。
%   將 (x-a)^2+(y-b)^2=r^2 展開成
%   x^2+y^2+A*x+B*y+C=0，再以反斜線運算求 A、B、C。

    x = x(:);
    y = y(:);
    design = [x, y, ones(size(x))];
    coefficient = design \ -(x.^2 + y.^2);
    centre_x = -coefficient(1)/2;
    centre_y = -coefficient(2)/2;
    radius_squared = centre_x^2 + centre_y^2 - coefficient(3);
    radius = sqrt(max(radius_squared, eps));
end

function [best_start, best_end, best_idx] = best_cyclic_run(value, min_length, max_length)
%BEST_CYCLIC_RUN 找出總分最高的循環連續區段。
%   對所有允許的長度完整搜尋，但對全部起點向量化計算。一般輪廓只有
%   數百點，因此此法速度可接受，且不需設定容易受淺接觸角影響的門檻值。

    value = value(:);
    n = numel(value);
    % 把數列複製兩次後建立前綴和，即可用一次相減取得跨越尾端的循環區段總分。
    doubled_prefix = [0; cumsum([value; value])];
    best_score = -Inf;
    best_start = 1;
    best_length = min_length;
    starts = (1:n)';
    for run_length = min_length:max_length
        % scores(j) 是從第 j 點開始、長度為 run_length 的區段總分。
        scores = doubled_prefix(starts+run_length) - doubled_prefix(starts);
        [candidate_score, local_start] = max(scores);
        if candidate_score > best_score
            best_score = candidate_score;
            best_start = local_start;
            best_length = run_length;
        end
    end
    % 將最佳起點及長度還原成 1-based 的循環索引。
    best_idx = mod((best_start-1) + (0:best_length-1), n) + 1;
    best_end = best_idx(end);
end
