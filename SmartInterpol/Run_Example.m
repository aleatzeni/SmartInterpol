clear
close all
clc

% % % %%%%%%%%%%%%% EXAMPLE %%%%%%%%%%%%
im_vol = '../sample_data/inputIM.nii.gz';
lab_vol = '../sample_data/inputLAB.nii.gz';
result_path = '../testLAB/'; % does not exist, will be created
trained_net_file = '../testLAB/trained_net.mat'; % does not exist, will be created

SmartInterpol(im_vol, lab_vol, result_path, trained_net_file)

