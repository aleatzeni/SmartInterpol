clear
close all
clc


% Images folder
mriPath = [uigetdir('','Select Folder containing the 2D intensity Images') filesep];
idcs = strfind(mriPath,filesep);
sub_folder = mriPath(1:idcs(end)-1);
if length(mriPath)<=2
    [mri_name,mri_folder]= uigetfile({'*.gz; *.nii; *.mgz'},'Select Intensities Volume');
    [lab_name,lab_folder] = uigetfile({'*.gz; *.nii; *.mgz'},'Select Segmentations Volume');
    labPath = [lab_folder lab_name];
    mriPath = [mri_folder mri_name];
else
    labPath = [uigetdir(sub_folder,'Select Folder containing the 2D manual Segmentation') filesep];
    
end

% Folder where your results will be (you don't need to create this)
result_path = [uigetdir(sub_folder,'Select Results Folder') filesep 'Results' filesep];

% First thing: create output directory if necessary - or throw an error if
% directory already exists and is not empty...
if exist(result_path,'dir')==0
    mkdir(result_path);
else
    if length(dir(result_path))>2
        fprintf('\n ACTION REQUIRED: \n Output directory already exists and is not empty: \n if you wish to continue press ENTER, if not press Ctrl+C and use another name for output folder \n');
        pause
    end
end

trained_net_file = [result_path filesep 'global_weights.mat'];

% LUT you used for manual labelling
[LUT,LUT_path] = uigetfile('*.txt','Select Lookup Table');
LUT_fullPath = [LUT_path LUT];

% Downsampling factor
prompt = {'Default downsampling factor 0.5, to change insert a number between 0 and 1 or press OK'};
dlgtitle = 'Downsampling factor';
default_DF = {'0.5'};
dims = [1 50];
answer = inputdlg(prompt,dlgtitle,dims,default_DF);
downsampling_factor = str2num(answer{1});

% Label fusion Downsampling factor
prompt = {'Default downsampling factor 3, to change insert a number between 1 and 10 or press OK'};
dlgtitle = 'Label Fusion downsampling factor';
default_DF = {'3'};
dims = [1 50];
answer = inputdlg(prompt,dlgtitle,dims,default_DF);
LF_downsampling_factor = str2num(answer{1});

% Let it run :)
if LUT_path>0
        SmartInterpol(mriPath,labPath , result_path, trained_net_file,'downsampling_factor',downsampling_factor,'LF_downsampling_factor',LF_downsampling_factor,'LUT_path',LUT_fullPath)

%     SmartInterpol(mriPath,labPath , result_path, trained_net_file,'downsampling_factor',downsampling_factor,'LF_downsampling_factor',LF_downsampling_factor,'LUT_path',LUT_fullPath,'EM',true,'maxepoch_global',3000,'LR_global',0.1,'lambda_DL',2,'EMIter',4,'minibatch_global',4,'LR_local',0.1,'minibatch_local',4,'minibatch_EM',4)
else
    SmartInterpol(mriPath,labPath , result_path, trained_net_file,'downsampling_factor',downsampling_factor,'LF_downsampling_factor',LF_downsampling_factor)
end





