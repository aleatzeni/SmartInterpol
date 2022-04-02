function [mriOrig,labOrig,paddedSize,labListFull,labListShort,vol_pad,lab_pad]=normalise(mriOrigPath,labOrigPath,mriNormPath,labNormPath,img_name_base,lab_name_base)

listingIM = cleanDirList(dir([mriOrigPath '*.gz']));
listingLAB = cleanDirList(dir([labOrigPath '*.gz']));

if sum(listingIM{1,1}.name~=listingLAB{1,1}.name)>0
    error('The first slice of the stack needs to be labelled')
end

if sum(listingIM{1,end}.name~=listingLAB{1,end}.name)>0
    error('The last slice of the stack needs to be labelled')
end

Nims = length(listingIM);
size1=zeros(Nims,1);
size2=zeros(Nims,1);

disp('Estimating size of biggest 2D slice')
for i=1:Nims
    filenameIM=listingIM{1,i}.name;
    p1=find(filenameIM=='_'); p1=p1(end)+1;
    p2=find(filenameIM=='.'); p2=p2(end-1)-1;
    sliceNo{i}=filenameIM(p1:p2);
    IM=myMRIread([mriOrigPath filesep filenameIM]);
    mriOrig{i}=IM;
    Iall{i} = IM.vol(:,:,1,1);
    maxIntensitiyList(i) = max(max((IM.vol(:,:,1,1))));
    size1(i) = size(IM.vol,1);
    size2(i) = size(IM.vol,2);
end
max_intensity = max(maxIntensitiyList);
max_size1 = max(size1);
max_size2 = max(size2);
paddedSize = [max_size1 max_size2];

vol_pad = zeros(max_size1,max_size2,Nims);
lab_pad = zeros(size(vol_pad));
labOrig = cell(1,Nims);
aux=[]; aux.vox2ras0=eye(4); aux.volres=ones(1,3);

disp('Normalising and Padding 2D slices')
for i=1:Nims
    disp(num2str(i))
    IM=Iall{i};
    IM_norm = IM/max_intensity*255;
    minValue=min(IM(:));
    mri=[];
    seg=[];
    pad1 = max_size1-size(IM,1);
    pad2 = max_size2-size(IM,2);
    if pad1>0 && pad2>0
        padsize = [pad1 pad2];
        mri=padarray(IM_norm,padsize,minValue,'post');
        if exist([labOrigPath filesep listingIM{1,i}.name],'file')
            LAB=myMRIread([labOrigPath filesep listingIM{1,i}.name]);
            labOrig{i}=LAB;
            seg=padarray(LAB.vol(:,:,1,1),padsize,min(LAB.vol(:)),'post');
        else
            seg=zeros(max_size1,max_size2);
        end
    elseif pad1>0 && pad2==0
        padsize = [pad1 0];
        mri=padarray(IM_norm,padsize,minValue,'post');
        if exist([labOrigPath filesep listingIM{1,i}.name],'file')
            LAB=myMRIread([labOrigPath filesep listingIM{1,i}.name]);
            labOrig{i}=LAB;
            seg=padarray(LAB.vol(:,:,1,1),padsize,min(LAB.vol(:)),'post');
        else
            seg=zeros(max_size1,max_size2);
        end
    elseif pad1==0 && pad2>0
        padsize = [0 pad2];
        mri=padarray(IM_norm,padsize,minValue,'post');
        if exist([labOrigPath filesep listingIM{1,i}.name],'file')
            LAB=myMRIread([labOrigPath filesep listingIM{1,i}.name]);
            labOrig{i}=LAB;
            seg=padarray(LAB.vol(:,:,1,1),padsize,min(LAB.vol(:)),'post');
        else
            seg=zeros(max_size1,max_size2);
        end
    elseif pad1==0 && pad2==0
        if exist([labOrigPath filesep listingIM{1,i}.name],'file')
            LAB=myMRIread([labOrigPath filesep listingIM{1,i}.name]);
            labOrig{i}=LAB;
            seg=LAB.vol(:,:,1,1);
        else
            seg=zeros(max_size1,max_size2);
        end
        mri=IM_norm;
        
    end
    vol_pad(:,:,i) = mri;
    lab_pad(:,:,i)=seg;
    aux.vol=mri;
    myMRIwrite(aux,[mriNormPath filesep img_name_base sliceNo{i} '.nii.gz']);
end

labListFull=unique(lab_pad(:));

if any(labListFull>255)
    for l=1:length(labListFull)
        lab_pad (lab_pad==labListFull(l))=l-1;
    end
end

labListShort=unique(lab_pad(:));

for i=1:Nims
    n_lab_slice = length(unique(lab_pad(:,:,i)));
    if n_lab_slice>1
        aux.vol=lab_pad(:,:,i);
        myMRIwrite(aux,[labNormPath filesep lab_name_base sliceNo{i} '.nii.gz']);
    else
        continue
    end
end


