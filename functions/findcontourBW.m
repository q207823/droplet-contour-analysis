function xy = findcontourBW(img_crop,showup,threshold_ratio,background)
    arguments
        img_crop 
        showup=0
        threshold_ratio=0.8 %閾值=threshold_ratio*最暗亮度+(1-threshold_ratio)*最亮亮度
        background=0; %背景顏色 0黑底白物 1白底黑物
    end
    type=class(img_crop);
    if (isequal(type,'uint8'))
        datamax= 2^8-1;
    elseif (isequal(type,'uint16'))
        datamax=2^16-1;
    end
    % 統一變成黑底白物分析
    if (background==1)
        img_crop=datamax-img_crop;
    end

    % threshold=double(0.65*mean(img_crop(1:50,1:50),"all")+0.35*max(img_crop,[],"all"));
    %
    if (any(size(img_crop)<60)) %如果照片太小就用otsu method自動找閾值
        threshold=graythresh(img_crop);
        BWimg=imbinarize(img_crop,threshold);
    else
        threshold=double((threshold_ratio)*mean(img_crop(1:50,1:50),"all")+(1-threshold_ratio)*max(img_crop,[],"all"));
        BWimg=imbinarize(img_crop,threshold/datamax);
    end
    % BWimg=imbinarize(img_crop);
    % BWimg=imbinarize(img_crop,threshold/datamax);


    % 外加對付無底板數據 !!尚需檢查是否適用有底版者
    %open: 先(對白處)腐蝕再膨脹，消除小白點
    %close: 先(對白處)膨脹再腐蝕，消除小黑點 

    % se = strel('disk',6);
    % BW_open=imopen(BWimg,se);
    % se = strel('disk',2);
    % BW_filled = imfill(BW_open, 'holes'); %去除靠近亮區周圍的亮點
    % BW_close=imclose(BW_filled,se);
    % BW_close=bwmorph(BW_close,"hbreak");
    

    % 有底板已測試
    % BW_filled = imfill(BWimg, 'holes'); %去除靠近亮區周圍的亮點
    BW_filled = fillboundaryhole(BWimg,1); %填滿白色內部的黑點

    BW_open=bwareaopen(BW_filled,4);

    se = strel('disk',2);
    BW_close=imclose(BW_open,se);



    % figure(3)
    %
    [B, ~] = bwboundaries(BW_close, 'noholes');
    if isempty(B)
        fprintf('警告：未找到任何輪廓！\n');
        xy = [];
        return;
    end
    
    stats = regionprops(BW_close, 'Area');
    [~, max_idx] = max([stats.Area]);
    curr_b = B{max_idx};
    xy = [curr_b(:, 2), curr_b(:, 1)]; % [X, Y]
    
    % 顯示輪廓點
    if showup==1
        figure("Name","BWimg")
        imshow(BWimg)
        figure("Name","filled")
        imshow(BW_filled)
        figure("Name","close")
        imshow(BW_close)
        figure("Name","contour")
        imshow(img_crop); hold on;
        plot(xy(:,1), xy(:,2), 'r', 'LineWidth', 2);
        title('5. 最終輪廓與原始影像疊圖');
    end
end