% clear
% imgpath="C:\Users\USER\Downloads\fillholetestimg.png"
% img=imread(imgpath);
% img=imbinarize(rgb2gray(img));
% imshow(img)
% %% fill holes on boundary
% imnohole=fillboundaryhole(img)
% figure(1)
% imshow(img)
% figure(2)
% imshow(imnohole)

%%
function BW_final = fillboundaryhole(BW,BDchoice)
    arguments
        BW logical
        BDchoice=[1,2,3,4,5,6];
    end

    % 6 種兩邊組合對照表 [top, bottom, left, right]
    combos = [
        1, 1, 0, 0;  % 1: top + bottom
        1, 0, 1, 0;  % 2: top + left
        1, 0, 0, 1;  % 3: top + right
        0, 1, 1, 0;  % 4: bottom + left
        0, 1, 0, 1;  % 5: bottom + right
        0, 0, 1, 1   % 6: left + right
    ];

    % 初始化累加畫布
    BW_final = false(size(BW));

    % 遍歷所有 6 種可能
    for i = BDchoice
        p = combos(i, :); % [top, bottom, left, right]
        
        % 1. 補白 (Top/Left 用 'pre'；Bottom/Right 用 'post')
        BW_padded = padarray(BW, [p(1), p(3)], 1, 'pre');
        BW_padded = padarray(BW_padded, [p(2), p(4)], 1, 'post');
        
        % 2. 填洞
        BW_filled = imfill(BW_padded, 'holes');
        
        % 3. 裁切還原至原始尺寸
        BW_cropped = BW_filled(1 + p(1) : end - p(2), 1 + p(3) : end - p(4));
        
        % 4. 與累積結果進行 OR 運算
        BW_final = BW_final | BW_cropped;
    end
end