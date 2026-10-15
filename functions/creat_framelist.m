% %% test
% stage=[20,50,80]
% step=[10,5]
% framelist=creat_framelist(stage,step)
% %%
function framelist=creat_framelist(stage,step)
    framelist=[];
    for k=1:length(stage)-1
        framelist=[framelist,[stage(k):step(k):stage(k+1)]];
    end
end