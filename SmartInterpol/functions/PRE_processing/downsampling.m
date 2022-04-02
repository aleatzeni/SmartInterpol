function [fullResSize,lowResSize]=downsampling(imDir,outDir,name_base,downsampling_factor,interp_method)
im_list = dir([imDir filesep '*.nii.gz']);
N = length(im_list);
img = MRIread(char([imDir im_list(1).name ]));
fullResSize= size(img.vol);

for i=1:N
        img = MRIread(char([imDir im_list(i).name]));
        k1=strfind(im_list(i).name,'_');
        k2=strfind(im_list(i).name,'.nii.gz');
        sliceNo = str2double(im_list(i).name(k1(end)+1:k2-1));
        aux=[]; aux.vox2ras0=eye(4); aux.volres=ones(1,3);
        mri=[];
        mri(:,:)=imresize(img.vol,downsampling_factor,interp_method);
        aux.vol=mri;
        MRIwrite(aux,char([outDir filesep name_base num2str(sliceNo,'%.4d') '.nii.gz']));
end
lowResSize = size(aux.vol);
