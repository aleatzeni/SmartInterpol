function SmartInterpol(ims_path,labs_path,results_path,trained_net_path,varargin)
tic

% Eugenio: number of copies with intensity / nonlinear shape distortions
N_AUG = 50; % TODO: revert to 50; 

% The following global variables are used in the full MICCAI pipeline not
% in the adHoc (vanilla) version
global GLOBAL_POSTERIORS;
global USE_GLOBAL_POSTERIORS;
global SAMPLING;
%
addpath(genpath('./functions'))

%%%%%%%%%%%%%%%%%%%%%%%%%%%% PARSE INPUTS %%%%%%%%%%%%%%%%%%%%%%%%%%%%%
disp(' Parsing inputs')
p = inputParser;

defaultLUT = './fsLUT.txt';
defaultDownsamplingFactor = 0.5; % Halves dimensions
defaultLFdownsamplingFactor = 3; % Factor to reduce size of image before label fusion
defautAladinParameters = '-omp 4 -speeeeed'; % Affine registration parameters
defaultF3dParameters = ' -vel --lncc 6 -sx -5 -sy -5 -omp 4'; % Nonlinear registration parameters
defaultVarianceLhood = 20^2; % Variance for likelihood estimation
defaultAlpha = 0.05; % Sharpness of the prior based on slice distance
defaultLambdaDL = 0.5; % Weight for deep learning contribution
defaultRho = 0.5; % Sharpness of the prior based on distance maps
defaultEM = int8(false); % If true uses EM algorithm (MICCAI)
defaultEMIter = 5; % Number of iterations for the Expextation-Maximisation algorithm (MICCAI)
defaultMultiscale = int8(true); %if true uses network channels for multiscale
defaultMultiscaleSigma1 = 2; % Kernel dimension for multiscale channel 2
defaultMultiscaleSigma2 = 5; % Kernel dimension for multiscale channel 3
defaultPatchSize = 0; % Patch size for global training
defaultLrGlobalTraining = 0.01; % Initial learning rate for global training
defaultMiniBatchSizeGlobal = 2; % Mini batch size for global training
defaultMaxEpochGlobal = 300; % Maximum number of epochs for global training
defaultLrLocalTraining = 0.05; % Initial learning rate for local training
defaultMiniBatchSizeLocal = 2; % Mini batch size for local training
defaultMaxEpochLocal = 100; %Maximum number of epochs for local training, potentially to be reverted to 150
defaultMiniBatchSizeEM = 4; % Mini batch size for local training
defaultMaxEpochEM = 180; % Maximum number of epochs for local training
defaultMRF = 0;  %if true applies MRF on posteriors
defaultMRFconstant = 3; % constant for MRF smothness
% Eugenio
 % what to do with first/last slice if unlabeled:
 % 0 = ask user; 
 % 1 = it's actually all zeros (ie there's no tissue); use as labeled slice
 % 2 = there is tissue, so label with info or other labeled slices
defaultFirstSliceOption = 0;
defaultLastSliceOption = 0;



addRequired(p,'imgs_path',@ischar) % Path to the input images
addRequired(p,'labs_path',@ischar) % Path to the manual segmentations
addRequired(p,'results_path',@ischar) % Path of the output images
addRequired(p,'trained_net_path',@checkExt) % Path of the global weights

addOptional(p,'LUT_path',defaultLUT,@checkExt) % Path of the look up table
addOptional(p,'downsampling_factor',defaultDownsamplingFactor)
addOptional(p,'LF_downsampling_factor',defaultLFdownsamplingFactor)
addOptional(p,'reg_aladin_optional',defautAladinParameters,@ischar)
addOptional(p,'reg_f3d_optional',defaultF3dParameters,@ischar)
addOptional(p,'lhood_variance',defaultVarianceLhood,@isscalar)
addOptional(p,'alpha',defaultAlpha,@isscalar)
addOptional(p,'lambda_DL',defaultLambdaDL,@isscalar)
addOptional(p,'rho',defaultRho,@isscalar)
addOptional(p,'MRF',defaultMRF,@islogical)
addOptional(p,'MRFconstant',defaultMRFconstant,@isscalar)
addOptional(p,'EM',defaultEM,@islogical)
addOptional(p,'EMIter',defaultEMIter,@isscalar)
addOptional(p,'multiscale',defaultMultiscale,@islogical)
addOptional(p,'multiscale_sigma1',defaultMultiscaleSigma1,@isscalar)
addOptional(p,'multiscale_sigma2',defaultMultiscaleSigma2,@isscalar)
addOptional(p,'patch_size',defaultPatchSize,@isnumeric)
addOptional(p,'LR_global',defaultLrGlobalTraining,@isscalar)
addOptional(p,'minibatch_global',defaultMiniBatchSizeGlobal,@isscalar)
addOptional(p,'maxepoch_global',defaultMaxEpochGlobal,@isscalar)
addOptional(p,'LR_local',defaultLrLocalTraining,@isscalar)
addOptional(p,'minibatch_local',defaultMiniBatchSizeLocal,@isscalar)
addOptional(p,'maxepoch_local',defaultMaxEpochLocal,@isscalar)
addOptional(p,'minibatch_EM',defaultMiniBatchSizeEM,@isscalar)
addOptional(p,'maxepoch_EM',defaultMaxEpochEM,@isscalar)
addOptional(p,'execution_date',string(datetime('now','TimeZone','local','Format','d-MMM-y HH:mm:ss ZZZZ')))

% Eugenio
addOptional(p,'firstSliceOption',defaultFirstSliceOption,@isscalar)
addOptional(p,'lastSliceOption',defaultLastSliceOption,@isscalar)


parse(p,ims_path,labs_path,results_path,trained_net_path,varargin{:})

% Create input validation function

    function checkExt(x)
        [~,~,Ext] = fileparts(x);
        if (strcmp(Ext,'.txt') || strcmp(Ext,'.mat'))==0
            error('Wrong format (.txt or .mat)')
        end
    end
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% RENAME INPUT FOR PRACTICAL REASONS %%%%%%%%%%%%%%%%%%%%%%%%%%%

im_path = p.Results.imgs_path;
lab_path = p.Results.labs_path;
outputDir = p.Results.results_path; % Output directory: contains the segmentations with the 3 methods
LUTfile = p.Results.LUT_path;
trained_net_path = p.Results.trained_net_path;
downsampling_factor = p.Results.downsampling_factor;
lf_downsampling_factor = p.Results.LF_downsampling_factor;
reg_aladin_optional = p.Results.reg_aladin_optional;
reg_f3d_optional = p.Results.reg_f3d_optional;
lhood_variance = p.Results.lhood_variance;
alpha = p.Results.alpha;
lambda_DL = p.Results.lambda_DL;
rho = p.Results.rho;
MRF = p.Results.MRF;
MRFconstant = p.Results.MRFconstant;
EM = p.Results.EM;
EM_ITERATIONS = p.Results.EMIter;
multiscale = p.Results.multiscale;
multiscale_sigma1 = p.Results.multiscale_sigma1;
multiscale_sigma2 = p.Results.multiscale_sigma2;
patch_size = p.Results.patch_size;
LR_global = p.Results.LR_global;
minibatch_global = p.Results.minibatch_global;
maxepoch_global = p.Results.maxepoch_global;
LR_local = p.Results.LR_local;
minibatch_local = p.Results.minibatch_local;
maxepoch_local = p.Results.maxepoch_local;
minibatch_EM = p.Results.minibatch_EM;
maxepoch_EM = p.Results.maxepoch_EM;
% Eugenio
firstSliceOption = p.Results.firstSliceOption;
lastSliceOption = p.Results.lastSliceOption;

ALADIN = './functions/NiftyReg/Linux_files/niftyreg/reg-apps/reg_aladin';
F3D = './functions/NiftyReg/Linux_files/niftyreg/reg-apps/reg_f3d';
RESAMPLE = './functions/NiftyReg/Linux_files/niftyreg/reg-apps/reg_resample';
TRANSFORM = './functions/NiftyReg/Linux_files/niftyreg/reg-apps/reg_transform';

system(['chmod u+x ./functions/NiftyReg/Linux_files/niftyreg/reg-apps/reg_*' ])

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% % First thing: create output directory if necessary - or throw an error if
% % directory already exists and is not empty...
% if exist(outputDir,'dir')==0
%     mkdir(outputDir);
% else
%     if length(dir(outputDir))>2
%         fprintf('\n ACTION REQUIRED: \n Output directory already exists and is not empty: \n if you wish to continue press ENTER, if not press Ctrl+C and use another name for output folder \n');
%         pause
%     end
% end

% Create a temporary directory we'll need for a bunch of stuff
tempdir=[outputDir filesep 'tmp' filesep];
mkdir(tempdir);

% Create a temporary directory where we'll store the registrations
regdir=[tempdir 'registrations' filesep];
mkdir(regdir);

% Create a temporary directory where we'll store the results of individual
% slices
single_slice_res=[tempdir 'single_slice_res' filesep];
mkdir(single_slice_res)

% Store parameters of analysis in output directory
parameters_filename=[outputDir filesep 'parameters.mat'];
save(parameters_filename,'p')

img_name_base = 'slice_';
lab_name_base = 'lab_';
imgFolderFullRes = [tempdir 'imgs_fullRes' filesep];
imgFolderHalfRes = [tempdir 'imgs_halfRes' filesep];
trainingLabFolderFullRes = [tempdir 'trainingLabs_fullRes' filesep];
trainingLabFolderHalfRes = [tempdir 'trainingLabs_halfRes' filesep];
mkdir(imgFolderFullRes)
mkdir(trainingLabFolderFullRes)
mkdir(imgFolderHalfRes)
mkdir(trainingLabFolderHalfRes)

if isfile(im_path)==1
    isVol=1;
else
    isVol=0;
end

if EM==0
    methods={'LF','DL','adHoc'};
else
    methods={'LF','DL','adHoc','DL-EM-LF'};
end

if isVol==1
    
    permutation = detectLabPlane(lab_path);
    
    disp('Loading input volume')
    vol = myMRIread(char(im_path));
    volRearranged = permute(vol.vol,permutation);
    Nims = size(volRearranged,3);
    
    clear vol
    
    disp('Loading input segmentation volume')
    lab = myMRIread(char(lab_path));
    labRearranged = permute(lab.vol,permutation);
    labListFull=unique(labRearranged(:));
    Nlab = length(labListFull);
    
    clear lab
    
    % Eugenio: what if there are no labels in first and last slice?
    if max(max(labRearranged(:,:,1)))>0
        firstSliceOption = 1; % i.e., there's manual labels in there, no matter what the user said
        disp('Found labels in first slice, ignoring value of firstSliceOption');
    else
        if firstSliceOption == 0 % ask the user
            disp('Is the *first* slice all zeros because there is not tissue ...');
            x = input('... rather than because you didn''t label it (yes/no) ','s');
            if strcmpi(x,'yes')
                firstSliceOption = 1;
            elseif strcmp(x,'no')
                firstSliceOption = 2;
            else
                error('answer must be yes or no');
            end
        end
    end
    
    if max(max(labRearranged(:,:,end)))>0
        lastSliceOption = 1; % i.e., there's manual labels in there, no matter what the user said
        disp('Found labels in last slice, ignoring value of lastSliceOption');
    else
        if lastSliceOption == 0 % ask the user
            disp('Is the *last* slice all zeros because there is not tissue ...');
            x = input('... rather than because you didn''t label it (yes/no) ','s');
            if strcmpi(x,'yes')
                lastSliceOption = 1;
            elseif strcmp(x,'no')
                lastSliceOption = 2;
            else
                error('answer must be yes or no');
            end
        end
    end
    
    % Eugenio: add fake first slice if needed
    if firstSliceOption == 2
        % Idenfitify first labeled slice
        aux = squeeze(sum(sum(labRearranged,1),2));
        idx = find(aux);
        idx = idx(1);
        % Copy it at the front
        aux = zeros(size(volRearranged,1),size(volRearranged,2),size(volRearranged,3)+1);
        aux(:,:,1) = volRearranged(:,:,idx);
        aux(:,:,2:end) = volRearranged;
        volRearranged = aux;
        Nims = Nims + 1;
        aux(:,:,1) = labRearranged(:,:,idx);
        aux(:,:,2:end) = labRearranged;
        labRearranged = aux;        
    end
    
    if lastSliceOption == 2
        % Idenfitify last labeled slice
        aux = squeeze(sum(sum(labRearranged,1),2));
        idx = find(aux);
        idx = idx(end);
        % Copy it at the end
        aux = zeros(size(volRearranged,1),size(volRearranged,2),size(volRearranged,3)+1);
        aux(:,:,end) = volRearranged(:,:,idx);
        aux(:,:,1:end-1) = volRearranged;
        volRearranged = aux;
        Nims = Nims + 1;
        aux(:,:,end) = labRearranged(:,:,idx);
        aux(:,:,1:end-1) = labRearranged;
        labRearranged = aux;        
    end
    
    

    disp('Creating sub LUT')
    subLUT_filename = createSubLUT(LUTfile,labListFull,outputDir);
    LUTfile = subLUT_filename;
    %     if any(labListFull>255)
    %        labRearranged = reversemap(labRearranged,labListFull);
    %     end
    
    if any(labListFull>255)
        for l=1:length(labListFull)
            labRearranged(labRearranged==labListFull(l))=l-1;
        end
    end
    
    labListShort=uint32(unique(labRearranged(:)));
    
    disp('Extracting 2D slices')
    % Eugenio: added firstSliceOption,lastSliceOption to extract2DfromVol call
    extract2DfromVol(volRearranged,labRearranged,imgFolderFullRes,trainingLabFolderFullRes,img_name_base,lab_name_base,firstSliceOption,lastSliceOption);
    fullResSize1 = size(volRearranged,1);
    fullResSize2 = size(volRearranged,2);
    mriOrig = cell(1,size(volRearranged,3));
    mri=[]; mri.vox2ras0=eye(4); mri.volres=ones(1,3); mri.vol=zeros(fullResSize1,fullResSize2);
    mriOrig(:) = {mri};
    
    clear volRearranged
    clear labRearranged
    clear mri
    
else
    % Bring to same size and normalise
    [mriOrig,~,paddedSize,labListFull,labListShort,vol_pad,lab_pad]=normalise(im_path,lab_path,imgFolderFullRes,trainingLabFolderFullRes,img_name_base,lab_name_base);
    fullResSize1 = paddedSize(1);
    fullResSize2 = paddedSize(2);
    Nims = length(mriOrig);
    disp('Creating sub LUT')
    subLUT_filename = createSubLUT(LUTfile,labListFull,outputDir);
    LUTfile = subLUT_filename;
    lab_pad_methods = cell(length(methods),1);
    lab_pad_methods(:) = {lab_pad};
    Nlab=length(labListFull);
    
    clear lab_pad
end


disp('Downsampling images')
% Downsample images with linear
if downsampling_factor~=1
    downsampled_img_path = [tempdir 'downsampled_imgs' filesep];
    mkdir(downsampled_img_path)
    interp_method = 'bilinear';
    [fullResSize,lowResSize]=downsampling(imgFolderFullRes,downsampled_img_path,img_name_base,downsampling_factor,interp_method);
elseif downsampling_factor==1
    fullResSize=[fullResSize1 fullResSize2];
    lowResSize=fullResSize;
    downsampled_img_path=imgFolderFullRes;
end

fprintf('Downsampling images to 1/%d resolution',lf_downsampling_factor)
% Downsample images with linear
if lf_downsampling_factor~=1
    interp_method = 'bilinear';
    [fullResSize,halfResSize]=downsampling(imgFolderFullRes,imgFolderHalfRes,img_name_base,round(1/lf_downsampling_factor,2),interp_method);
elseif lf_downsampling_factor==1
    fullResSize=[fullResSize1 fullResSize2];
    halfResSize=fullResSize;
    imgFolderHalfRes=imgFolderFullRes;
end


if any(lowResSize>2048)
    error('You need to downsample more: set downsampling_factor to less than 0.5')
end

disp('Downsampling segmentations')
% Downsample segmentations with nearest
if downsampling_factor~=1
    downsampled_lab_path = [tempdir 'downsampled_labs' filesep];
    mkdir(downsampled_lab_path)
    interp_method = 'nearest';
    [~,~]=downsampling(trainingLabFolderFullRes,downsampled_lab_path,lab_name_base,downsampling_factor,interp_method);
elseif downsampling_factor==1
    downsampled_lab_path= trainingLabFolderFullRes;
end

% Prepare trainig file
trainingFile_path = [tempdir filesep 'training_file.txt'];
prepareTrainingFile(downsampled_img_path,downsampled_lab_path,trainingFile_path,img_name_base,lab_name_base);

% Extract train and test
fid = fopen(trainingFile_path,'r');
Zcoords=[];
isTest=[];
imageFiles=[];
simpleLabelFiles=[];
fullLabelFiles=[];
while 1
    sliceNo=fgetl(fid);
    if ~ischar(sliceNo) || length(strtrim(sliceNo))==0
        break;
    else
        Zcoords(end+1)=str2double(sliceNo);
        imageFiles{end+1}=fgetl(fid);
        aux=fgetl(fid);
        if strcmp(lower(aux),'n/a')
            simpleLabelFiles{end+1}='';
            fullLabelFiles{end+1}='';
            isTest(end+1)=1;
        else
            simpleLabelFiles{end+1}=aux;
            fullLabelFiles{end+1}=fgetl(fid);
            isTest(end+1)=0;
        end
    end
end
fclose(fid);
isTest = uint64(isTest);
Zcoords = uint64(Zcoords);

disp(['Found a total of ' num2str(Nims) ' images (' num2str(sum(isTest==0)) ' labeled)'])

imList=dir([imgFolderFullRes '*.nii.gz']);
imgFilesFullRes=cleanDirList(imList);

imListHalfRes=dir([imgFolderHalfRes '*.nii.gz']);
imgFilesHalfRes = cleanDirList(imListHalfRes);


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% STEP 1: fine tune VGG16/segnet/ImageNet with all available training data (Structure level labels) %
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
if ~exist(trained_net_path,'file')
    % Create directories with training data
    disp('Creating training dataset for global finetuning of network')
    disp('(on all labeled slices, with structure level labels)');
    trainingImDir=[tempdir 'trainingImsSimple' filesep];
    mkdir(trainingImDir);
    trainingLabDir=[tempdir 'trainingLabsSimple' filesep];
    mkdir(trainingLabDir);
    for i=find(~isTest)
        
        % Eugenio: augment N_AUG time
                
        % images
        Imri=myMRIread(char(imageFiles{i}));
        I=double(Imri.vol);
       
        if size(I,3)==1 && multiscale==1
            Iscaled1=imgaussfilt(I,multiscale_sigma1);
            Iscaled2=imgaussfilt(I,multiscale_sigma2);
            I=cat(3,I,Iscaled1,Iscaled2);
        elseif size(I,3)==1 && multiscale==0
            I=repmat(I,[1 1 3]);
        end
        
        % labels
        Lmri=myMRIread(char(simpleLabelFiles{i}));
        L=Lmri.vol;
        if size(L,3)>1, error('Label files should not have multiple channels...'); end
        if any(L(:)>255), error('Simple labels cannot be greater than 255'); end
        

        for n_aug = 1 : N_AUG
            % imwrite(uint8(I),[trainingImDir img_name_base num2str(i,'%.4d') '.png'])
            
            [Iaug, Laug] = random_nonlin_deformation(I, L);
            Iaug = random_contrast_augmentation(Iaug);
            Iaug = random_gamma_augmentation(Iaug);
            
            imwrite(uint8(Iaug),[trainingImDir  img_name_base num2str(i,'%.4d') '_' num2str(n_aug,'%.3d') '.png'])
            imwrite(uint8(Laug),[trainingLabDir img_name_base num2str(i,'%.4d') '_' num2str(n_aug,'%.3d') '.png']);
        end
        
        clear Imri
        clear Iscaled1
        clear Iscaled2
        
        clear Lmri
        clear L
    end
    
    
    % Classes and sizes of dataset
    [codeSimple,nameSimple,~]=read_fscolorlut(LUTfile);
    classes=strtrim(string(nameSimple));
    classes=matlab.lang.makeValidName(classes);
    if patch_size==0
        imageSize = [size(I,1) size(I,2) 3];
    else
        imageSize = [patch_size(1) patch_size(2) 3];
    end
    clear I
    numClasses = numel(classes);
    labelIDs=labListShort;
    
    % Create data store
    imds = imageDatastore(trainingImDir);
    pxds = pixelLabelDatastore(trainingLabDir,classes,labelIDs);
    
    % Load net: pretrained VGG16
    % Eugenio: we bypass GitHub's file size limtation in this simple way
    % load lgraph.mat lgraph
    system(['cat lgraph.0* > ' tempdir '/lgraph.mat' ]);
    load([tempdir '/lgraph.mat'], 'lgraph');
    delete([tempdir '/lgraph.mat']);
    
    
    % Replace input layer to adapt to size of the input images
    imLayer = imageInputLayer(imageSize,'Name','inputImage');
    lgraph = replaceLayer(lgraph,'inputImage',imLayer);
    % Replace last convolutional layer and pixel classification layer to reflect the number of classes to
    % segment
    convLayer = convolution2dLayer(3,numClasses,'Name','decoder1_conv1','BiasLearnRateFactor',20,'WeightLearnRateFactor',20,'Padding','same'); %5
    lgraph = replaceLayer(lgraph,'decoder1_conv1',convLayer);
    pxLayer = pixelClassificationLayer('Name','pixelLabels','Classes', classes);
    lgraph = replaceLayer(lgraph,'pixelLabels', pxLayer);
    
    % surgery to increase learning rates of the 2 rightmost convlutional layers
    % For some reason matlab doesn't let you change the LR directly, so you
    % have to extact the layer, change the learning rate, and plug it back in
    %     decoder1_conv1=lgraph.Layers(87);
    %     decoder1_conv1.BiasLearnRateFactor=5;
    %     decoder1_conv1.WeightLearnRateFactor=5;
    %     lgraph = removeLayers(lgraph, 'decoder1_conv1');
    %     lgraph = addLayers(lgraph, decoder1_conv1);
    %     lgraph = connectLayers(lgraph, 'decoder1_relu_2' ,'decoder1_conv1');
    %     lgraph = connectLayers(lgraph, 'decoder1_conv1' ,'decoder1_bn_1');
    %
    decoder1_conv2=lgraph.Layers(84);
    decoder1_conv2.BiasLearnRateFactor=20;%5;
    decoder1_conv2.WeightLearnRateFactor=20;%5;
    lgraph = removeLayers(lgraph, 'decoder1_conv2');
    lgraph = addLayers(lgraph, decoder1_conv2);
    lgraph = connectLayers(lgraph, 'decoder1_unpool' ,'decoder1_conv2');
    lgraph = connectLayers(lgraph, 'decoder1_conv2' ,'decoder1_bn_2');
    
    decoder2_conv1=lgraph.Layers(80);
    decoder2_conv1.BiasLearnRateFactor=20;%5;
    decoder2_conv1.WeightLearnRateFactor=20;%5;
    lgraph = removeLayers(lgraph, 'decoder2_conv1');
    lgraph = addLayers(lgraph, decoder2_conv1);
    lgraph = connectLayers(lgraph, 'decoder2_relu_2' ,'decoder2_conv1');
    lgraph = connectLayers(lgraph, 'decoder2_conv1' ,'decoder2_bn_1');
    
    decoder2_conv2=lgraph.Layers(77);
    decoder2_conv2.BiasLearnRateFactor=20;%5;
    decoder2_conv2.WeightLearnRateFactor=20;%5;
    lgraph = removeLayers(lgraph, 'decoder2_conv2');
    lgraph = addLayers(lgraph, decoder2_conv2);
    lgraph = connectLayers(lgraph, 'decoder2_unpool' ,'decoder2_conv2');
    lgraph = connectLayers(lgraph, 'decoder2_conv2' ,'decoder2_bn_2');
    
    % Training options
    disp('Global finetuning of network')
    % maxEpoch=round(3000/sum(~isTest));
    initialLearningRate=LR_global;   % TODO: maybe decrease (and increase maxepoch?)
    options = trainingOptions('sgdm', ...
        'Momentum', 0.9, ...
        'InitialLearnRate', initialLearningRate, ... %1e-3, ...
        'L2Regularization', 0.0001, ...
        'MaxEpochs', maxepoch_global, ...
        'MiniBatchSize',minibatch_global, ...
        'Shuffle', 'every-epoch', ...
        'VerboseFrequency',2);
    
    % Augmentation options
    
    % Eugenio: contrast brightness not needed anymore
        augmenter = imageDataAugmenter('RandXReflection',false,...
        'RandXTranslation', [-15 15], 'RandYTranslation',[-15 15], ...
        'RandXScale',[0.85 1.15],'RandYScale',[0.85 1.15], ...
        'RandRotation',[-15 15]); % ,...
        %'RandContrast',[0.90 1.1],'RandBrightness',[-20 20]);
    % Data source

%     augmenter = imageDataAugmenter('RandXReflection',false,...
%         'RandXTranslation', [-15 15], 'RandYTranslation',[-15 15], ...
%         'RandXScale',[0.85 1.15],'RandYScale',[0.85 1.15], ...
%         'RandRotation',[-15 15],...
%         'RandContrast',[0.90 1.1],'RandBrightness',[-20 20]);
%     % Data source
    if patch_size~=0
        datasource = randomPatchExtractionDatastore(imds,pxds,patch_size,'DataAugmentation',augmenter);
    else
        datasource = pixelLabelImageSource(imds,pxds,'DataAugmentation',augmenter);
    end
    
    % Training; before starting, we look at activations in an early layer, to
    % see that we're actually mostly finetuning the later layers
    [trainedNetGlobal, info] = trainNetwork(datasource,lgraph,options);
    disp('Global finetuning done!')
    system(['rm -rf ' trainingImDir]);
    system(['rm -rf ' trainingLabDir]);
    clear imds
    clear pxds
    clear datasource
    
    % Create and save a figure with the loss
    close all,
    h=figure();
    v=1:length(info.TrainingAccuracy);
    plot(v,100*info.TrainingLoss,'r',v,info.TrainingAccuracy,'b','linewidth',1);
    legend({'Training loss (x100)','Training accuracy'},'fontsize',20);
    xlabel('Iteration','fontsize',20);
    title('Global finetuning of network','fontsize',20);
    saveas(h,[outputDir filesep 'globalFinetuning.png']);
    close all
    
    if 0  % for debugging purposes...
        close all,
        figure
        for i=1:length(imageFiles)
            try
                I=imread(imageFiles{i});
            catch
                Imri=myMRIread(char(imageFiles{i}));
                I=uint8(repmat(Imri.vol,[1 1 3]));
            end
            POST = activations(trainedNetGlobal,I,'softmax');
            [POSTrgb,SEGrgb]=createPostImage(POST,RGBsimple);
            
            subplot(1,3,1), imshow(I)
            subplot(1,3,2), imshow(POSTrgb)
            subplot(1,3,3), imshow(SEGrgb)
            title(['Image ' num2str(i)]);
            
            pause
        end
        close all
    end
    save(trained_net_path,'trainedNetGlobal');
    
else
    disp('Global weights already available');
end
clear trainedNetGlobal
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% STEP 2: Combined label fusion and deep learning %
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

disp('Beginning combined label fusion and deep learning');

% These 2 guys encode to which labeled slices our current network is tuned to
DL_post_full_res = zeros(fullResSize(1),fullResSize(2),1,Nlab);

for i=find(isTest)
    
    disp(['Working on slice ' num2str(i)]);
    
    outputPrefix=[single_slice_res lab_name_base num2str(Zcoords(i),'%.4d')];
    
    % Find "bread" slices and their distance to the "meat"
    idx= find(~isTest & Zcoords < Zcoords(i));
    indI=idx(end);
    idx= find(~isTest & Zcoords > Zcoords(i));
    indJ=idx(1);
    
    DISTI=Zcoords(i)-Zcoords(indI);
    DISTJ=Zcoords(indJ)-Zcoords(i);
    
    %Load test image at full resolution
    if lf_downsampling_factor==1
        TESTfilename = [imgFilesFullRes{i}.folder filesep imgFilesFullRes{i}.name];
        mri=myMRIread(char(TESTfilename));
        TESTimage=mri.vol;
    else
        TESTfilename = [imgFilesHalfRes{i}.folder filesep imgFilesHalfRes{i}.name];
        mri=myMRIread(char(TESTfilename));
        TESTimage=mri.vol;
    end
    
    % Run registrations, and put together label list
    
    SEGS=cell(Nims,1);
    for idx=[indI indJ]
        
        fprintf('   Registering %d to %d \n',idx,i)
        
        REF=imageFiles{i};
        FLO=imageFiles{idx};
        REFFullRes=TESTfilename;
        
        
        % Create output names
        RES_affine_img=strcat(regdir,filesep,num2str(idx),'to',num2str(i),'_affine_img.nii.gz');
        affine_matrix=strcat(regdir,filesep,num2str(idx),'to',num2str(i),'_affine_trans.txt');
        RES_nonlin_img=strcat(regdir,filesep,num2str(idx),'to',num2str(i),'_nonlin.nii.gz');
        nonlin_cpp=strcat(regdir,filesep,num2str(idx),'to',num2str(i),'_nonlin_cpp.nii.gz');
        dense_def=strcat(regdir,filesep,num2str(idx),'to',num2str(i),'_nonlin_denseDef_cpp.nii.gz');
        def_fullRes=strcat(regdir,filesep,num2str(idx),'to',num2str(i),'_fullRes_cpp.nii.gz');
        RES_img_fullRes=strcat(regdir,filesep,num2str(idx),'to',num2str(i),'_nonlin_fullRes.nii.gz');
        
        % Perform pairwise registration  between test and training image using command line
        if ~exist(RES_affine_img,'file')
            res1=call_reg_aladin(ALADIN,REF,FLO,RES_affine_img,affine_matrix,reg_aladin_optional);
            if res1, error('Error in reg_aladin'); end
        end
        
        % Reg_f3d
        if ~exist(RES_nonlin_img,'file')
            res2=call_reg_f3d(F3D,REF,FLO,RES_nonlin_img,affine_matrix,nonlin_cpp,reg_f3d_optional);
            if res2, error('Error in reg_f3d'); end
        end
        
        if downsampling_factor~=1
            % Reg_tranform to get dense deformation field
            if ~exist(dense_def,'file')
                res3=call_reg_transform(TRANSFORM,REF,nonlin_cpp,dense_def);
                if res3, error('Error in reg_transform'); end
            end
            
            % Upsample dense deformation field
            mri=myMRIread(char(dense_def));
            dense_def_lowRes=squeeze(mri.vol);
            
            dense_def_lowResR=dense_def_lowRes(:,:,1);
            dense_def_lowResC=dense_def_lowRes(:,:,2);
            %             dense_def_fullResR=imresize(dense_def_lowResR,fullResSize,'bilinear');
            %             dense_def_fullResC=imresize(dense_def_lowResC,fullResSize,'bilinear');
            dense_def_fullResR=imresize(dense_def_lowResR,halfResSize,'bilinear');
            dense_def_fullResC=imresize(dense_def_lowResC,halfResSize,'bilinear');
            
            mri=[]; mri.vox2ras0=eye(4); mri.volres=ones(1,3);
            dense_def_fullRes(:,:,1)=dense_def_fullResR;
            dense_def_fullRes(:,:,2)=dense_def_fullResC;
            mri.vol=dense_def_fullRes;
            myMRIwrite(mri,char(def_fullRes));
            
            if lf_downsampling_factor~=1
                %Resampling the deformed images to half resolution
                REFhalfRes=TESTfilename;
                RES_img_HalfRes = strcat(regdir,filesep,num2str(idx),'to',num2str(i),'_nonlin_HalfRes.nii.gz');
                res4=call_reg_resample(RESAMPLE,REFhalfRes,FLO,RES_img_HalfRes,def_fullRes,'prob');
                
            else
                %               %Resampling the deformed images to full resolution
                res4=call_reg_resample(RESAMPLE,REFFullRes,FLO,RES_img_fullRes,def_fullRes,'prob');
            end
            if res4, error('Error in reg_resample'); end
        end
        % Gather list of labels
        mri=myMRIread(char(fullLabelFiles{idx}));
        SEG=mri.vol;
        SEGS{idx}=SEG;
    end
    clear mri
    clear SEG
    clear dense_def_fullResC
    clear dense_def_fullResR
    clear dense_def_lowResC
    clear dense_def_lowResR
    clear dense_def_lowRes
    clear dense_def_fullRes
    
    %     Now that we have the full label list, compute distance transforms,
    %     and propagate them to target space with the corresponding transform
    for idx=[indI indJ]
        fprintf('   Computing and warping distance transforms for training slice: %d \n',idx)
        dist=distance_transform_multilabel(SEGS{idx},labListShort);
        probs=distToProbs(dist,rho);
        clear dist
        
        % Make appropriate Nifti object, write to disk, and resample!
        prob_map_file=strcat(regdir,num2str(idx),'_to_',num2str(i),'_probMap.nii.gz') ;
        result_path=strcat(regdir,num2str(idx),'_to_',num2str(i),'_WarpedProbMap.nii.gz');
        
        mri=[]; mri.vox2ras0=eye(4); mri.volres=ones(1,3);
        mri.vol=probs;
        myMRIwrite(mri,char(prob_map_file));
        clear probs
        
        if downsampling_factor~=1
            if lf_downsampling_factor~=1
                nonlin_cpp=strcat(regdir,num2str(idx),'to',num2str(i),'_fullRes_cpp.nii.gz');
                res=call_reg_resample(RESAMPLE,REFhalfRes,prob_map_file,result_path,nonlin_cpp,'prob' );
            else
                nonlin_cpp=strcat(regdir,num2str(idx),'to',num2str(i),'_fullRes_cpp.nii.gz');
                res=call_reg_resample(RESAMPLE,REFFullRes,prob_map_file,result_path,nonlin_cpp,'prob' );
            end
            if res, error('Error in reg_resample'); end
        else
            nonlin_cpp=strcat(regdir,num2str(idx),'to',num2str(i),'_nonlin_cpp.nii.gz');
            res=call_reg_resample(RESAMPLE,REF,prob_map_file,result_path,nonlin_cpp,'prob' );
            if res, error('Error in reg_resample'); end
        end
    end
    
    % Load warped images
    if downsampling_factor~=1
        if lf_downsampling_factor~=1
            warped_imageI=myMRIread(char(strcat(regdir,num2str(indI),'to',num2str(i),'_nonlin_HalfRes.nii.gz')));
            warped_imageJ=myMRIread(char(strcat(regdir,num2str(indJ),'to',num2str(i),'_nonlin_HalfRes.nii.gz')));
            
        else
            warped_imageI=myMRIread(char(strcat(regdir,num2str(indI),'to',num2str(i),'_nonlin_fullRes.nii.gz')));
            warped_imageJ=myMRIread(char(strcat(regdir,num2str(indJ),'to',num2str(i),'_nonlin_fullRes.nii.gz')));
        end
    else
        warped_imageI=myMRIread(char(strcat(regdir,num2str(indI),'to',num2str(i),'_nonlin.nii.gz')));
        warped_imageJ=myMRIread(char(strcat(regdir,num2str(indJ),'to',num2str(i),'_nonlin.nii.gz')));
    end
    
    
    % Load warped probability maps of each label
    prob_warpedI=myMRIread(char(strcat(regdir,num2str(indI),'_to_',num2str(i),'_WarpedProbMap.nii.gz')));
    prob_warpedJ=myMRIread(char(strcat(regdir,num2str(indJ),'_to_',num2str(i),'_WarpedProbMap.nii.gz')));
    
    fprintf('   Computing posteriors with label fusion for test slice %d after registration with %d and %d \n',i,indI,indJ )
    
    %Soft segmentation
    labelFusion_post=soft_seg_local_fusion_intensity_matching(TESTimage,prob_warpedI.vol,prob_warpedJ.vol,warped_imageI.vol,warped_imageJ.vol,DISTI,DISTJ,alpha,lhood_variance);
    
    clear warped_imageI
    clear warped_imageJ
    clear prob_warpedI
    clear prob_warpedJ
    
    if lf_downsampling_factor==1
        [~,idx]=max(labelFusion_post,[],4);
        % Hard segmentation
        HARDSEG_LF=labListFull(idx);
    else
        HARDSEG_LF = zeros(fullResSize);
        MAX_P = zeros(fullResSize);
        for t=1:size(labelFusion_post,4)
            P = imresize(squeeze(labelFusion_post(:,:,1,t)),fullResSize);
            M = P>MAX_P;
            HARDSEG_LF(M)=labListFull(t);
            MAX_P(M) = P(M);
        end
    end
    
    % Write hard segmentation to disk
    mriOutput=mriOrig{i};
    size1 = size(mriOrig{i}.vol,1);
    size2 = size(mriOrig{i}.vol,2);
    
    mriOutput.vol=(HARDSEG_LF(1:size1,1:size2));
    
    myMRIwrite(mriOutput,char([outputPrefix '.LF.nii.gz']));
    
    %     if isVol==0
    %         % Collect results in a volume
    %         lab_pad_methods{1}(:,:,i) = mriOutput.vol;
    %     end
    
    clear HARDSEG_LF
    clear mriOutput
    
    
    %%%%%%%%%%%%%%%%%%%%%%%%%
    % MACHINE LEARNING PART %
    %%%%%%%%%%%%%%%%%%%%%%%%%
    
    % Step 1 of the ML part: fine tune global net to this sandwhich, using
    % only labeled slices. Do not redo if we have it from a previous slice
    weights_filename = [tempdir filesep 'trainedNetSandwich' num2str(indI) '_' num2str(indJ) '.mat'];
    
    if ~exist(weights_filename,'file')
        
        disp('   Creating training dataset for finetuning to this sandwich')
        
        trainingImDir=[tempdir filesep 'trainingImsSandwich'];
        trainingLabDir=[tempdir filesep 'trainingLabsSandwich'];
        if exist(trainingImDir,'dir')
            system(['rm -rf ' trainingImDir]);
            system(['rm -rf ' trainingLabDir]);
        end
        mkdir(trainingImDir);
        mkdir(trainingLabDir);
        
        for j=[indI indJ]
            
            % Eugenio: again, redone to accomodate nonlinear / contrast /
            % brightness / gamma augmentation
            
            % images
            Imri=myMRIread(char(imageFiles{j}));
            I=uint8(Imri.vol);
            if size(I,3)==1 && multiscale==1
                Iscaled1=imgaussfilt(I,multiscale_sigma1);
                Iscaled2=imgaussfilt(I,multiscale_sigma2);
                I=cat(3,I,Iscaled1,Iscaled2);
            elseif size(I,3)==1 && multiscale==0
                I=repmat(I,[1 1 3]);
            end
            
            % labels
            Lmri=myMRIread(char(fullLabelFiles{j}));
            L=Lmri.vol;
            if size(L,3)>1, error('Label files should not have multiple channels...'); end
            if any(L(:)>255), error('Labels cannot be greater than 255'); end
            
            % imwrite(uint8(I),[trainingImDir filesep img_name_base num2str(j,'%.4d') '.png']);
            % imwrite(uint8(L),[trainingLabDir filesep img_name_base num2str(j,'%.4d') '.png']);
            
            for n_aug = 1 : N_AUG
                
                [Iaug, Laug] = random_nonlin_deformation(I, L);
                Iaug = random_contrast_augmentation(Iaug);
                Iaug = random_gamma_augmentation(Iaug);
                
                imwrite(uint8(Iaug),[trainingImDir filesep img_name_base num2str(j,'%.4d') '_' num2str(n_aug,'%.3d')  '.png']);
                imwrite(uint8(Laug),[trainingLabDir filesep img_name_base num2str(j,'%.4d') '_' num2str(n_aug,'%.3d') '.png']);
            end
        end
        
        % Classes and sizes of dataset
        [codeSimple,nameSimple,~]=read_fscolorlut(LUTfile);
        classes=strtrim(string(nameSimple));
        classes=matlab.lang.makeValidName(classes);
        
        imageSize = [size(I,1) size(I,2) 3];
        
        numClasses = numel(classes);
        labelIDs=labListShort;
        
        clear I
        clear L
        clear Imri
        clear Lmri
        clear Iscaled1
        clear Iscaled2
        
        
        % Create data store
        imds = imageDatastore(trainingImDir);
        pxds = pixelLabelDatastore(trainingLabDir,classes,labelIDs);
        
        % Create net, by taking the one pretrained on the whole volume, and
        % replacing a couple of layers towards the end to reflect the new
        % number of labels
        load(trained_net_path,'trainedNetGlobal');
        netSandwich = layerGraph(trainedNetGlobal);
        pxLayer = pixelClassificationLayer('Name','labelsSandwich','ClassNames', classes);
        netSandwich = removeLayers(netSandwich, 'pixelLabels');
        netSandwich = addLayers(netSandwich, pxLayer);
        netSandwich = connectLayers(netSandwich, 'softmax' ,'labelsSandwich');
        
        refLayer=netSandwich.Layers(84);
        decoder1_conv1=convolution2dLayer(refLayer.FilterSize,length(classes),...
            'Name','decoder1_conv1','NumChannels',refLayer.NumChannels,...
            'Stride',refLayer.Stride,'Padding',refLayer.PaddingSize,...
            'WeightLearnRateFactor',refLayer.WeightLearnRateFactor,...
            'WeightL2Factor',refLayer.WeightL2Factor,...
            'BiasLearnRateFactor',refLayer.BiasLearnRateFactor,...
            'BiasL2Factor',refLayer.BiasL2Factor);
        netSandwich = removeLayers(netSandwich, 'decoder1_conv1');
        netSandwich = addLayers(netSandwich, decoder1_conv1);
        netSandwich = connectLayers(netSandwich, 'decoder1_relu_2' ,'decoder1_conv1');
        netSandwich = connectLayers(netSandwich, 'decoder1_conv1' ,'decoder1_bn_1');
        
        decoder1_bn_1 = batchNormalizationLayer('Name','decoder1_bn_1');
        netSandwich = removeLayers(netSandwich, 'decoder1_bn_1');
        netSandwich = addLayers(netSandwich, decoder1_bn_1);
        netSandwich = connectLayers(netSandwich, 'decoder1_conv1' ,'decoder1_bn_1');
        netSandwich = connectLayers(netSandwich, 'decoder1_bn_1' ,'decoder1_relu_1');
        
        % Training options
        disp('   Finetuning to this sandwich')
        options = trainingOptions('sgdm', ...
            'Momentum', 0.9, ...
            'InitialLearnRate', LR_local, ... % TODO:now 0.1 maybe decrease (and increase maxepoch?)
            'L2Regularization', 0.0001, ...
            'MaxEpochs', maxepoch_local, ...
            'MiniBatchSize', minibatch_local, ...
            'Shuffle', 'every-epoch', ...
            'VerboseFrequency', 2);
        
        % Augmentation otions
        % Eugenio: remove contrast/brightness
        augmenter = imageDataAugmenter('RandXReflection',false,...
            'RandXTranslation', [-15 15], 'RandYTranslation',[-15 15], ...
            'RandXScale',[0.95 1.05],'RandYScale',[0.95 1.05], ...
            'RandRotation',[-15 15]); %,...
            %'RandContrast',[0.975 1.025],'RandBrightness',[-2 2]);
        % Data source
        datasource = pixelLabelImageSource(imds,pxds,'DataAugmentation',augmenter);
        
        % Training; before starting, we look at activations in an early layer, to
        % see that we're actually mostly finetuning the later layers
        
        [trainedNetSandwich, ~] = trainNetwork(datasource,netSandwich,options);
        close all
%         system(['rm -rf ' trainingImDir]);
%         system(['rm -rf ' trainingLabDir]);
        save(weights_filename,'trainedNetSandwich');
        disp('   Finetuning of sanwich done!')
        
        close all
        clear imds
        clear pxds
        clear datasource
        
    else
        disp('   Local weights already available!')
        load(weights_filename,'trainedNetSandwich');
    end
    
    %     % Create and save a figure with the loss
    %     close all,
    %     h=figure();
    %     v=1:length(infoSandwich.TrainingAccuracy);
    %     plot(v,100*infoSandwich.TrainingLoss,'r',v,infoSandwich.TrainingAccuracy,'b','linewidth',3);
    %     legend({'Training loss (x100)','Training accuracy'},'fontsize',20);
    %     xlabel('Iteration','fontsize',20);
    %     title('Local finetuning of network','fontsize',20);
    %     saveas(h,[outputDir filesep 'localFinetuning.png']);
    %     close all
    
    % We can push the input image and write the output to disk
    disp('   Writing output of purely DL to disk');
    try
        I=imread(imageFiles{i});
    catch
        Imri=myMRIread(char(imageFiles{i}));
        I=Imri.vol;
        if size(I,3)==1 && multiscale==1
            Iscaled1=imgaussfilt(I,multiscale_sigma1);
            Iscaled2=imgaussfilt(I,multiscale_sigma2);
            I=cat(3,I,Iscaled1,Iscaled2);
            I=uint8(I);
        elseif size(I,3)==1 && multiscale==0
            I=uint8(repmat(Imri.vol,[1 1 3]));
        end
    end
    DL_post = activations(trainedNetSandwich,I,'softmax');
    DL_post = reshape(DL_post,[size(DL_post,1) size(DL_post,2) 1 size(DL_post,3)]);
    
    clear I
    clear Imri
    clear Iscaled1
    clear Iscaled2
    
    if downsampling_factor~=1
        for lab=1:size(DL_post,4)
            DL_post_full_res(:,:,1,lab) = imresize(DL_post(:,:,1,lab),fullResSize,'bilinear');
        end
    else
        DL_post_full_res=DL_post;
    end
    
    clear DL_post
    
    [~,idx]=max(DL_post_full_res,[],4);
    HARDSEG_DL=labListFull(idx);
    
    % Write hard segmentation to disk
    mriOutput=mriOrig{i};
    size1 = size(mriOrig{i}.vol,1);
    size2 = size(mriOrig{i}.vol,2);
    
    mriOutput.vol=(HARDSEG_DL(1:size1,1:size2));
    
    myMRIwrite(mriOutput,char([outputPrefix '.DL.nii.gz']));
    
    %     if isVol==0
    %         % Collect results in a volume
    %         lab_pad_methods{2}(:,:,i)= mriOutput.vol;
    %     end
    
    clear HARDSEG_DL
    
    disp('Computing ad-hoc combination of DL and LF');
    if lf_downsampling_factor==1
        adhocDeepFusion_post = labelFusion_post .* (DL_post_full_res.^lambda_DL);
        
        clear DL_post_full_res
        
        normalizer=1e-12+sum(adhocDeepFusion_post,4);
        adhocDeepFusion_post=bsxfun(@rdivide,adhocDeepFusion_post,normalizer);
        if MRF==1
            HARDSEG_ADHOC_MRF = mrf(adhocDeepFusion_post,labListFull,MRFconstant);
            mriOutputMRF = mriOutput;
            mriOutputMRF.vol=(HARDSEG_ADHOC_MRF(1:size1,1:size2));
            myMRIwrite(mriOutput,char([outputPrefix '.adHocMRF.nii.gz']));
            
        end
        [~,idx]=max(adhocDeepFusion_post,[],4);
        HARDSEG_ADHOC=labListFull(idx);
        
        mriOutput.vol=(HARDSEG_ADHOC(1:size1,1:size2));
    else
        DL_post_resized = imresize3(squeeze(DL_post_full_res),[halfResSize(1) halfResSize(2) size(DL_post_full_res,4)]);
        DL_post_half_res(:,:,1,:) = DL_post_resized;
        adhocDeepFusion_post = labelFusion_post .* (DL_post_half_res.^lambda_DL);
        normalizer=1e-12+sum(adhocDeepFusion_post,4);
        adhocDeepFusion_post=bsxfun(@rdivide,adhocDeepFusion_post,normalizer);

        clear DL_post_half_res
        if MRF==1
            HARDSEG_ADHOC_MRF = mrf(real(adhocDeepFusion_post),labListFull,MRFconstant);
            mriOutputMRF = mriOutput;
            mriOutputMRF.vol=imresize(HARDSEG_ADHOC_MRF,fullResSize,'nearest');
            myMRIwrite(mriOutput,char([outputPrefix '.adHocMRF.nii.gz']));
        end
        
        HARDSEG_ADHOC = zeros(fullResSize);
        MAX_P = zeros(fullResSize);
        for t=1:size(adhocDeepFusion_post,4)
            P = imresize(squeeze(adhocDeepFusion_post(:,:,1,t)),fullResSize);
            M = P>MAX_P;
            HARDSEG_ADHOC(M)=labListFull(t);
            MAX_P(M) = P(M);
        end
        
        
        mriOutput.vol=(HARDSEG_ADHOC);
        
    end
    
    
    %     if isVol==0
    %         % Collect results in a volume
    %         lab_pad_methods{3}(:,:,i) = mriOutput.vol;
    %     end
    
    disp('Writing to disk ad-hoc combination of DL and LF');
    
    myMRIwrite(mriOutput,char([outputPrefix '.adHoc.nii.gz']));
    
    clear HARDSEG_ADHOC
    clear mriOutput
    
    if EM==1
        %%%%%%%%%%%%%%%%%%%%%%%%% EM ALGORITHM %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        
        % Data we'll need in memory because we use over and over...
        GT_II=imread([trainingLabDir filesep img_name_base num2str(indI,'%.4d') '.png']);
        GT_JJ=imread([trainingLabDir filesep img_name_base num2str(indJ,'%.4d') '.png']);
        
        [XX,YY]=ndgrid(1:size(GT_II,1),1:size(GT_II,2));
        try
            I=imread(imageFiles{i}); II=imread(imageFiles{indI}); JJ=imread(imageFiles{indJ});
        catch
            Imri=myMRIread(char(imageFiles{i})); IImri=myMRIread(char(imageFiles{indI})); JJmri=myMRIread(char(imageFiles{indJ}));
            I=Imri.vol; II=IImri.vol; JJ=JJmri.vol;
            if size(I,3)==1 && multiscale==1
                Iscaled1=imgaussfilt(I,multiscale_sigma1);% Try varying the scale factor.
                Iscaled2=imgaussfilt(I,multiscale_sigma2);
                I=cat(3,I,Iscaled1,Iscaled2);
                I=uint8(I);
                IIscaled1=imgaussfilt(II,multiscale_sigma1);% Try varying the scale factor.
                IIscaled2=imgaussfilt(II,multiscale_sigma2);
                II=cat(3,II,IIscaled1,IIscaled2);
                II=uint8(II);
                JJscaled1=imgaussfilt(JJ,multiscale_sigma1);% Try varying the scale factor.
                JJscaled2=imgaussfilt(JJ,multiscale_sigma2);
                JJ=cat(3,JJ,JJscaled1,JJscaled2);
                JJ=uint8(JJ);
            elseif size(I,3)==1 && multiscale==0
                I=uint8(repmat(Imri.vol,[1 1 3]));
                II=uint8(repmat(IImri.vol,[1 1 3]));
                JJ=uint8(repmat(JJmri.vol,[1 1 3]));
            end
        end
        %         idxII=sub2ind([fullResSize1 fullResSize2 1 Nlab],XX(:),YY(:),1+GT_II(:));
        %         idxJJ=sub2ind([fullResSize1 fullResSize2 1 Nlab],XX(:),YY(:),1+GT_JJ(:));
        %         npix=numel(I);
        
        
        % Main loop of EM algorithm
        costsEM=[];
        for iterationsEM=1:EM_ITERATIONS
            fprintf('   EM iteration for network %d \n',iterationsEM)
            
            % E step
            postDL_I = activations(trainedNetSandwich,I,'softmax');
            if lf_downsampling_factor~=1
                postDL_I_resized = imresize3(squeeze(postDL_I),[halfResSize(1) halfResSize(2) Nlab]);
                postDL_I = [];
                postDL_I(:,:,1,:) = postDL_I_resized;
            end
            W=(postDL_I.^lambda_DL).*squeeze(labelFusion_post);
            normalizerW=sum(W,3);
            %             costI=-sum(sum(sum(log(normalizerW))))/npix;
            W=bsxfun(@rdivide,W,normalizerW);
            
            
            %             % compute rest of components of the cost, and add to vector for
            %             % later plotting if desired
            %             postDL_II = activations(trainedNetSandwich,II,'softmax');
            %             postDL_JJ = activations(trainedNetSandwich,JJ,'softmax');
            %             costII=-lambda_DL*sum(log(postDL_II(idxII)))/npix;
            %             costJJ=-lambda_DL*sum(log(postDL_JJ(idxJJ)))/npix;
            %             costTot=costII+costJJ+costI;
            %             costsEM(end+1)=costTot;
            
            mriOutput=mriOrig{i};
            size1 = size(mriOrig{i}.vol,1);
            size2 = size(mriOrig{i}.vol,2);
            if lf_downsampling_factor==1
                [~,idx]=max(W,[],3);
                HARDSEG_EM_IT=labListFull(idx);
                
                % Write hard segmentation to disk
                mriOutput.vol=HARDSEG_EM_IT(1:size1,1:size2);
                
                myMRIwrite(mriOutput,char([outputPrefix '.EMit' num2str(iterationsEM) '.nii.gz']));
                
                [~,idx]=max(postDL_I,[],3);
                HARDSEG_EM_IT_DL=labListFull(idx);
                
                mriOutput.vol=HARDSEG_EM_IT_DL(1:size1,1:size2);
                
                myMRIwrite(mriOutput,char([outputPrefix '.EMit' num2str(iterationsEM) '.onlyDL.nii.gz']));
            else
                HARDSEG_EM_IT = zeros(fullResSize);
                MAX_P = zeros(fullResSize);
                for t=1:size(W,4)
                    P = imresize(squeeze(W(:,:,1,t)),fullResSize);
                    M = P>MAX_P;
                    HARDSEG_EM_IT(M)=labListFull(t);
                    MAX_P(M) = P(M);
                end
                mriOutput.vol=(HARDSEG_EM_IT(1:size1,1:size2));
                
                HARDSEG_EM_IT_DL = zeros(fullResSize);
                MAX_P = zeros(fullResSize);
                for t=1:size(postDL_I,4)
                    P = imresize(squeeze(postDL_I(:,:,1,t)),fullResSize);
                    M = P>MAX_P;
                    HARDSEG_EM_IT_DL(M)=labListFull(t);
                    MAX_P(M) = P(M);
                end
                mriOutput.vol=(HARDSEG_EM_IT_DL(1:size1,1:size2));
            end
            
            
            %             disp(['      Iteration ' num2str(iterationsEM) ' of EM; cost is: ' num2str(costTot) '  ( ' num2str(costII) ' + ' num2str(costJJ) ' + ' num2str(costI) ' )' ]);
            
            %%%%%%%%%%
            % M step %
            %%%%%%%%%%
            
            if iterationsEM < EM_ITERATIONS % no M step in the last iteration
                
                trainingImDirMstep=[tempdir filesep 'trainingImsMstep' filesep];
                trainingLabDirMstep=[tempdir filesep 'trainingLabsMstep' filesep];
                if exist(trainingImDirMstep,'dir')
                    system(['rm -rf ' trainingImDirMstep]);
                    system(['rm -rf ' trainingLabDirMstep]);
                end
                mkdir(trainingImDirMstep);
                mkdir(trainingLabDirMstep);
                
                for j=[indI indJ]
                    % images
                    if strcmp(imageFiles{j}(end-1:end),'gz') % we support nifti and also normal images
                        Imri=myMRIread(char(imageFiles{j}));
                        I=uint8(Imri.vol);
                    else
                        I=imread(imageFiles{j});
                    end
                    if size(I,3)==1 && multiscale==1
                        Iscaled1=imgaussfilt(I,multiscale_sigma1);% Try varying the scale factor.
                        Iscaled2=imgaussfilt(I,multiscale_sigma2);
                        I=cat(3,I,Iscaled1,Iscaled2);
                    elseif size(I,3)==1 && multiscale==0
                        I=repmat(I,[1 1 3]);
                    end
                    imwrite(uint8(I),[trainingImDirMstep filesep img_name_base num2str(j,'%.4d') '.png']);
                    
                    % labels
                    if strcmp(fullLabelFiles{j}(end-1:end),'gz') % we support nifti and also normal images
                        Lmri=myMRIread(char(fullLabelFiles{j}));
                        L=Lmri.vol;
                    else
                        L=imread(fullLabelFiles{j});
                    end
                    if size(L,3)>1, error('Label files should not have multiple channels...'); end
                    if any(L(:)>255), error('Labels cannot be greater than 255'); end
                    imwrite(uint8(L),[trainingLabDirMstep filesep img_name_base num2str(j,'%.4d') '.png']);
                end
                
                if strcmp(imageFiles{i}(end-1:end),'gz') % we support nifti and also normal images
                    Imri=myMRIread(char(imageFiles{i}));
                    I=uint8(Imri.vol);
                else
                    I=imread(imageFiles{i});
                end
                if size(I,3)==1 && multiscale==1
                    Iscaled1=imgaussfilt(I,multiscale_sigma1);% Try varying the scale factor.
                    Iscaled2=imgaussfilt(I,multiscale_sigma2);
                    I=cat(3,I,Iscaled1,Iscaled2);
                elseif size(I,3)==1 && multiscale==0
                    I=repmat(I,[1 1 3]);
                end
                imwrite(uint8(I),[trainingImDirMstep filesep img_name_base num2str(i,'%.4d') '.png']);
                imwrite(zeros(size(I,1),size(I,2)),[trainingLabDirMstep filesep img_name_base num2str(i,'%.4d') '.png']);
                
                GLOBAL_POSTERIORS = W;
                USE_GLOBAL_POSTERIORS = 1;
                SAMPLING=1; % Set to 1 to use the sampling
                
                % Create data store
                imds = imageDatastore(trainingImDirMstep);
                pxds = pixelLabelDatastore(trainingLabDirMstep,classes,labelIDs);
                
                % Training options
                options = trainingOptions('sgdm', ...
                    'Momentum', 0.9, ...
                    'InitialLearnRate', LR_local/decoder2_conv2.WeightLearnRateFactor, ...
                    'L2Regularization', 0.0001, ...
                    'MaxEpochs', maxepoch_EM, ...
                    'MiniBatchSize', minibatch_EM, ...
                    'Shuffle', 'every-epoch', ...
                    'VerboseFrequency', 2);
                
                
                % Augmentation otions
                augmenter = imageDataAugmenter('RandXReflection',false,...
                    'RandXTranslation', [-15 15], 'RandYTranslation',[-15 15], ...
                    'RandXScale',[0.95 1.05],'RandYScale',[0.95 1.05], ...
                    'RandRotation',[-15 15], ...
                    'RandContrast',[0.99 1.01],'RandBrightness',[-1 1]);
                
                % Data source
                datasource = pixelLabelImageSource(imds,pxds,'DataAugmentation',augmenter);
                
                % Training; before starting, we look at activations in an early layer, to
                % see that we're actually mostly finetuning the later layers
                disp('      Finetuning-M step...')
                [trainedNetSandwich, infoSandwich] = trainNetwork(datasource,layerGraph(trainedNetSandwich),options);
                disp('      Finetuning-M step done!!')
            end
        end
        
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        clear GT_II
        clear GT_JJ
        clear I
        clear pxds
        clear imds
        clear global USE_GLOBAL_POSTERIORS
        clear global GLOBAL_POSTERIORS
        clear global SAMPLING
        
        
        % Write final output of this slice to disk
        mriOutput=mriOrig{i};
        size1 = size(mriOrig{i}.vol,1);
        size2 = size(mriOrig{i}.vol,2);
        
        if lf_downsampling_factor==1
            [~,idx]=max(W,[],3);
            HARDSEG_EM=labListFull(idx);
            
            %         if isVol==0
            %             % Collect results in a volume
            %             lab_pad_methods{4}(:,:,i) = HARDSEG_EM;
            %         end
            
            % Write hard segmentation to disk
            mriOutput.vol=HARDSEG_EM(1:size1,1:size2);
            myMRIwrite(mriOutput,char([outputPrefix '.DL-EM-LF.nii.gz']));
        else
            HARDSEG_EM = zeros(fullResSize);
            MAX_P = zeros(fullResSize);
            for t=1:size(W,4)
                P = imresize(squeeze(W(:,:,1,t)),fullResSize);
                M = P>MAX_P;
                HARDSEG_EM(M)=labListFull(t);
                MAX_P(M) = P(M);
            end
            mriOutput.vol=(HARDSEG_EM(1:size1,1:size2));
        end
        
        
        %     % A little check...
        %     if 0
        %         aux=myMRIread('/home/atzeni/Dropbox/MRes_PhD/PhD/Label_fusion_matlab/MasksCropped/seg_2043.mapped.cropped.nii.gz');
        %         GT=aux.vol;
        %
        %         MASK=GT>0;
        %         for uselessIndex=1:4
        %             MASK=imdilate(MASK,[0 1 0; 1 1 1; 0 1 0]);
        %         end
        %
        %         gt=GT(MASK);
        %         adhoc=HARDSEG_ADHOC(MASK);
        %         lf=HARDSEG_LF(MASK);
        %         dl=HARDSEG_DL(MASK);
        %         em=HARDSEG_EM(MASK);
        %
        %         adhoc=100*sum(adhoc==gt)/length(gt)
        %         lf=100*sum(lf==gt)/length(gt)
        %         dl=100*sum(dl==gt)/length(gt)
        %         em=100*sum(em==gt)/length(gt)
        %
        %         save /tmp/kk.mat adhoc lf dl em
        %
        %     end
        %
        %
        
        clear HARDSEG_EM
        clear mriOutput
        
    end
end
% Clean up
% system(['rm -rf ' tempdir ]);  % TODO: uncomment this

if isVol==1
    % Eugenio: Added flags to skip the first and / or last  slice if we
    % artificially copied them. 
    skip_first = (firstSliceOption == 2);
    skip_last = (lastSliceOption == 2);
    reconstructVolume(ims_path,trainingLabFolderFullRes,Nims,permutation,outputDir,lab_name_base,methods,skip_first,skip_last);
    % else
    %     aux=[]; aux.vox2ras0=eye(4); aux.volres=ones(1,3);
    %     aux.vol = vol_pad;
    %     myMRIwrite(aux,char([outputDir 'vol.nii.gz']));
    %     for m=1:length(methods)
    %         aux.vol = lab_pad_methods{m};
    %         myMRIwrite(aux,char([outputDir 'volSeg.' methods{m} '.nii.gz']));
    %     end
end

t=toc;
fprintf('All done! \n Execution date %s , running time %s \n',p.Results.execution_date,num2str(t));
end
