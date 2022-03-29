clear
close all
clc

% % % %%%%%%%%%%%%% EXAMPLE %%%%%%%%%%%%
im_vol = './inputIM.nii.gz';
lab_vol = './inputLAB.nii.gz';
result_path = './test/';
trained_net_file = './global_weights.mat';
 
SmartInterpol(im_vol, lab_vol, result_path, trained_net_file,'firstSliceOption',2,'lastSliceOption',2, 'maxepoch_global',100,'maxepoch_local',50);


