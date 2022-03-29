clear

addpath(genpath('./functions'))

[filename,pathname]=uigetfile({'*.nii.gz';'*.mgz'},'Select input image volume');
im_vol=[pathname filesep filename];

[filename,pathname]=uigetfile({'*.nii.gz';'*.mgz'},'Select input label volume (partial labels)');
lab_vol=[pathname filesep filename];

result_path=uigetdir(pwd(),'Select output directory');
result_path=[result_path filesep];

trained_net_file = [result_path filesep 'trained_net.mat'];

% Eugenio: If not labeled, decide what to do with first and last slices
firstSliceOption = 0;
lastSliceOption = 0;
permutation = detectLabPlane(lab_vol);
mri = myMRIread(lab_vol);
annot = squeeze(sum(sum(permute(mri.vol>0,permutation), 1), 2)>0);
if annot(1)==0
    answer = questdlg('No labels found in first slice; shall I consider it annotated (i.e.,g there is no tissue in it)?');
    if strcmpi(answer,'yes')
        firstSliceOption = 1;
    elseif strcmpi(answer,'no')
        firstSliceOption = 2;
    elseif strcmpi(answer,'cancel')
        error('Cancelled');
    end
end
if annot(1)==0
    answer = questdlg('No labels found in last slice; shall I consider it annotated (i.e.,g there is no tissue in it)?');
    if strcmpi(answer,'yes')
        lastSliceOption = 1;
    elseif strcmpi(answer,'no')
        lastSliceOption = 2;
    elseif strcmpi(answer,'cancel')
        error('Cancelled');
    end
end

SmartInterpol(im_vol, lab_vol, result_path, trained_net_file, 'firstSliceOption', firstSliceOption, 'lastSliceOption', lastSliceOption);



