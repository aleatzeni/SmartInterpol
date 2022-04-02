function prepareTrainingFile(imDir,labDir,trainingFilePath,img_name_base,lab_name_base)
ims_list = dir([imDir filesep img_name_base '*.nii.gz']);

Nims = length(ims_list);
fid=fopen(trainingFilePath,'w');
for i=1:Nims
    % z coordinate / slice
    k1=strfind(ims_list(1).name,'_');
    k2=strfind(ims_list(1).name,'.nii.gz');
    slice=str2double(ims_list(i).name(k1(end)+1:k2));
    fprintf(fid,'%f\n',slice);
    
    % image file
    fprintf(fid,'%s/%s\n',imDir,ims_list(i).name);
    
    % segmentations, if "available"
    
    dd=dir([labDir filesep lab_name_base num2str(slice,'%.4d') '*.nii.gz']);
    if isempty(dd)==0
        fprintf(fid,'%s/%s\n',labDir,dd.name);
        fprintf(fid,'%s/%s\n',labDir,dd.name);
    else
        fprintf(fid,'N/A\n');
    end
    
end

fclose(fid);