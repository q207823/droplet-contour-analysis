function xy_out = aboveline(xy, horizon)
% 保留 horizon 上方的輪廓點
%
% input:
%   xy      : Nx2，輪廓點 [x, y]
%   horizon : 2x2，[[x1,y1]; [x2,y2]]
%
% output:
%   xy_out  : horizon 上方的輪廓點

    x1 = horizon(1,1);
    y1 = horizon(1,2);
    x2 = horizon(2,1);
    y2 = horizon(2,2);

    % horizon: y = mx + b
    m = (y2-y1)/(x2-x1);
    y_horizon = y1 + m*(xy(:,1)-x1);

    % 影像座標中 y 越小代表越上方
    xy_out = xy(xy(:,2) <= y_horizon-4, :);
end