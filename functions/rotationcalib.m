function calibpoint=rotationcalib(v,point)
    % 將2D point 轉換到x軸為v向量方向的旋轉變換
    % v 1*2 vector; point n*2 vector
    % v=[3,4]
    % point=[[1,2];[3,4];[5,6]]
    calibpoint=zeros(size(point));
    u=v/norm(v);
    % theta=atan(u(2)/u(1));
    % rotmatrix=[[cos(theta),sin(theta)];[-sin(theta),cos(theta)]] %rotation matrix
    rotmatrix=[[u(1),u(2)];[-u(2),u(1)]];
    for k=1:size(point,1)
        calibpoint(k,:)=(rotmatrix*point(k,:)')';
    end
    % plot(point(:,1),point(:,2))
    % hold on
    % plot(calibpoint(:,1),calibpoint(:,2))
end