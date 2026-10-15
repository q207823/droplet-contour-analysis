function cineinfo = readcineinfo(cine)
%READCINEINFO 讀取 Phantom cine 的基本影片資訊
%
% INPUT:
%   cine                    PhNewCineFromFile() 建立的 cine handle
%
% OUTPUT:
%   cineinfo                儲存影片資訊的 structure
%       .n_firstframe       第一幀的 Phantom frame number
%       .n_totalframe       影片總幀數
%       .fps                影片幀率
%       .imgsize            影像解析度 [width height]
%       .pixeldepth         影像有效 bit depth


% 讀取 fps

% 建立 double 型態的 pointer。
p = libpointer('doublePtr', 0);

% Selector 480 = GCI_DFRAMERATE，讀取 double 精度的 fps。
PhGetCineInfo(cine, 480, p);

% 將 fps 存入 structure。
cineinfo.fps = double(p.Value);


% 讀取第一幀

% 建立 int32 型態的 pointer。
p = libpointer('int32Ptr', int32(0));

% Selector 38 = GCI_FIRSTIMAGENO，讀取第一幀編號。
PhGetCineInfo(cine, 38, p);

% 將第一幀編號存入 structure。
cineinfo.n_firstframe = double(p.Value);


% 讀取影片總幀數

% 建立 uint32 型態的 pointer。
p = libpointer('uint32Ptr', uint32(0));

% Selector 29 = GCI_IMAGECOUNT，讀取 cine 中儲存的影像數量。
PhGetCineInfo(cine, 29, p);

% 將影片總幀數存入 structure。
cineinfo.n_totalframe = double(p.Value);

p = libpointer('uint32Ptr',0);
PhGetCineInfo(cine, PhFileConst.GCI_MAXIMGSIZE, p);
cineinfo.imgSizeInBytes = p.Value;


% 讀取影像寬度

% 建立 uint32 型態的 pointer。
p = libpointer('uint32Ptr', uint32(0));

% Selector 24 = GCI_IMWIDTH，讀取目前影像寬度。
PhGetCineInfo(cine, 24, p);

% 暫存影像寬度。
imgwidth = double(p.Value);


% 讀取影像高度

% 建立 uint32 型態的 pointer。
p = libpointer('uint32Ptr', uint32(0));

% Selector 25 = GCI_IMHEIGHT，讀取目前影像高度。
PhGetCineInfo(cine, 25, p);

% 暫存影像高度。
imgheight = double(p.Value);


%儲存影像解析度

% 將解析度以 [width height] 格式存入 structure。
cineinfo.imgsize = [imgwidth imgheight];


%讀取 pixel depth

% 建立 uint32 型態的 pointer。
p = libpointer('uint32Ptr', uint32(0));

% Selector 4 = GCI_REALBPP，讀取 cine 的實際 pixel bit depth。
PhGetCineInfo(cine, 4, p);

% 將 pixel depth 存入 structure。
cineinfo.pixeldepth = double(p.Value);

end