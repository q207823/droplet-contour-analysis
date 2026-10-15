function img_filtered = lowpass_filter(img_crop, L,showup)
    % 輸入: 
    %   img_crop: 裁切後的水滴影像
    %   L: 想要濾除的波長下限 (pixel), 小於此長度的訊號會被視為高頻雜訊濾除
    % 輸出:
    %   img_filtered: 濾波後的影像 
    arguments
        img_crop
        L
        showup=0;
    end

    % 1. 轉為 Double 進行運算並獲取尺寸
    I = double(img_crop);
    [rows, cols] = size(I);
    
    % 2. 執行快速傅立葉轉換 (FFT) 並移動零頻分量至中心
    F = fftshift(fft2(I));
    
    % 3. 計算截止頻率 D0
    % 根據關係式 D0 = N / L。我們針對不同軸向分別計算以適應長方形 ROI。
    D0_rows = rows / L;
    D0_cols = cols / L;
    
    % 4. 建立高斯低通濾波器遮罩 (Gaussian Low-Pass Mask)
    [u, v] = meshgrid(1:cols, 1:rows);
    centerX = floor(cols/2) + 1;
    centerY = floor(rows/2) + 1;
    
    % 計算每個點到中心的標準化距離平方
    % 公式: H(u,v) = exp(-D^2 / (2 * D0^2))
    dist_sq = ((u - centerX).^2 / (D0_cols^2) + (v - centerY).^2 / (D0_rows^2));
    mask = exp(-dist_sq / 2);
    
    % 5. 在頻域中套用遮罩
    G = F .* mask;
    
    % 6. 逆傅立葉轉換回空間域
    % 使用 real() 確保捨棄微小的計算虛數誤差
    img_filtered = real(ifft2(ifftshift(G)));
    
    % 7. 轉回相同格式輸出
    img_filtered = cast(img_filtered,'like',img_crop);

    % --- 視覺化測試 (可選，若不需要可註解掉) ---
    if (showup==1)
        figure('Name', ['波長 L = ', num2str(L), ' 濾波測試']);
        subplot(1,2,1); imshow(img_crop); title('原始裁切影像');
        subplot(1,2,2); imshow(img_filtered); title(['濾波後 (L < ', num2str(L), ' px 被濾除)']);
    end
end