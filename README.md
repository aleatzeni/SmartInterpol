
### **SMART-INTERPOL**
*********************************************************

Authors: **Alessia Atzeni** and **Juan Eugenio Iglesias**

Date: 1st October 2019

Associated Article:  Atzeni, A., Jansen, M., Ourselin, S. and Iglesias, J.E., 
2018, September. A Probabilistic Model Combining Deep Learning and Multi-atlas 
Segmentation for Semi-automated Labelling of Histology. In International 
Conference on Medical Image Computing and Computer-Assisted Intervention 
(pp. 219-227). Springer, Cham.

Please cite this paper if you use this software for your research!




*********************************************************
Summary
*********************************************************

Smart Interpol is a semi-automated segmentation tool which, starting from a
volume with a sparse subset of manually labelled slices, estimates the 
corresponding dense segmentation in an automated fashion. The tool has been 
created to speed-up the segmentation of modalities in which a large amount 
of thin and highly correlated slices has to be labelled, and has the advantage 
that the final volumetric segmentations are inherently smooth, so the labeller 
does not need to worry about consistency in orthogonal views. The underlying model 
integrates Deep Learning (DL) and Multi Atlas Segmentation (MAS), into a joint 
probabilistic framework: the DL module is robust to registration errors which 
might happen due to artefacts or large separation between sections to register; 
the MAS module is able to preserve anatomical shape, including faint boundaries 
that rely on prior knowledge.


*********************************************************
Requirements
*********************************************************

* A machine with a GPU - GPU memory requirements depend on size of input volume.

* An installation of Matlab version R2019a/9.6 (newer and/or slightly older 
version may also work, but have not been tried extensively).


*********************************************************
Super-simple use with Matlab GUI 
*********************************************************

Simply run the following command from your Matlab terminal:

SmartInterpol_GUI

You will be propmted to provide:

* An image volume
* A corresponding label volume, where only a subset of slices has been labeled 
    (see example ./inputIM.nii.gz and ./inputLAB.nii.gz); note that the first and 
    last slice must be labeled.
* An output directory where results will be written.
* If the first or last slice of your volume are not labelled, a dialog box will
    ask whether those slices should be treated as labelled (i.e., there is actually
    no tissue there) or unlabeled (i.e., there is tissue and you want to segment it
    with information from the labelled slices).

The output of the algorithm will be a set of volumes containing the dense 
segmentation of the input estimated with label fusion (vol.LF.nii.gz), 
deep learning (vol.DL.nii.gz), product rule between label fusion and deep 
learning (vol.adHoc.nii.gz). The product rule (vol.adHoc.nii.gz) normally
produces the best results.

The output volumes will be at the same resolution of the input volume.


*********************************************************
Simple use from Matlab command line 
*********************************************************

The main entry point of the code is SmartInterpol.m, which is a function that 
requires four arguments:

1. input_image_volume:
This is a string containing the full path of the image volume. Please note that 
the algorithms have only been tested with nifti files (e.g., .nii or .nii.gz), 
but may work with FreeSurfer files (mgh/mgz). 

2. input_label_volume:
This is a string containing the full path of the labels volume. It has to be the 
same size in pixel as the intensities volumes. Again, please note that the algorithms 
have only been tested with nifti files (e.g., .nii or .nii.gz), but may work 
with mgh/mgz as well.

3. results_path:
This is a string containing the path of the directory where the results will be saved.

4. trained_net_file:
This is a .mat file with the "global" weights of the network. If the file does not exist, 
the network will be initialised with VGG16 weights, and the  final (trained) weights will 
be saved to this .mat file. If the file already exists, the algorithm will use the weights 
in the file as initialisation; this is useful if you've already run SmartInterpol on a 
similar kind of volume (e.g., of the same imaging modality).


We provide sample input data ./inputIM.nii.gz and ./inputLAB.nii.gz. You can run this
example as follows:

_im_vol = '../sample_data/inputIM.nii.gz';  
lab_vol = '../sample_data/inputLAB.nii.gz';  
result_path = '../testLAB/'; % does not exist, will be created  
trained_net_file = '../testLAB/trained_net.mat';  % does not exist, will be created  
SmartInterpol(im_vol, lab_vol, result_path, trained_net_file)_


NOTE: RUNNING THIS EXAMPLE TAKES ABOUT 2 HOURS, DEPENDING ON THE MACHINE / GPU,
SO YOU CAN GO GRAB LUNCH AND COME BACK TO CHECK THE RESULT

If the results_path already exists and is not empty the user is required to follow 
the instructions on the screen.
Also, if the first or last slice are not labeled, the user is also required to 
follow the instructions on the screen.


***********************************************
* ADVANCED OPTIONS (from Matlab command line)
***********************************************

The function also accept optional parameters stored as Name-Value pairs:

- **LUT_path:**  
This is the path to the text file containing the look up table (LUT). The LUT 
can be customised or you can use the freesurfer LUT contained in the folder.    
-_Default:_ './fsLUT.txt'  
-_Example:_  SmartInterpol(im_vol, lab_vol, result_path, trained_net_file, 'LUT_path', './simpleLUT.txt' )

- **downsampling_factor:**  
Resizing factor, specified as a positive scalar.   
If downsampling_factor<1, then the output image is smaller the input image.   
If downsampling_factor=1, the input image will not be downsampled.  
Please note that downsampling may be necessary for memory reasons. The registration
 algorithm has a size limit of 2048 pixels per dimension. If after downsampling your 
image will exceed such limit you'll be asked to decrease the downsampling factor.  
-_Default:_ 0.5  
-_Example:_ SmartInterpol(im_vol, lab_vol, result_path, trained_net_file,'downsampling_factor', 0.2) This means that each dimension will be resized to 20% of its original size.

- **reg_aladin_optional:**  
This is a string containing optional parameters used for the affine registration. 
Please note that all registration are executed with NiftyReg 
(http://cmictig.cs.ucl.ac.uk/wiki/index.php/NiftyReg). 
Refer to NiftyReg documentation for the meaning of the additional parameters.  
-_Default:_ '-omp 4 -speeeeed'  
-_Example:_ SmartInterpol(im_vol, lab_vol, result_path, trained_net_file, 'reg_aladin_optional', ' -omp 8 ')

- **reg_f3d_optional:**  
This is a string containing optional parameters used for the nonlinear registration. 
Please note that all registration are executed with NiftyReg 
(http://cmictig.cs.ucl.ac.uk/wiki/index.php/NiftyReg). Refer to NiftyReg documentation
for the meaning of the additional parameters.  
-_Default:_ '-vel  --lncc 6 -sx -5 -sy -5 -omp 4'  
-_Example:_ SmartInterpol(im_vol, lab_vol, result_path, trained_net_file, 'reg_f3d_optional', '-vel  --lncc 5 -sx -4 -sy -4')

- **lhood_variance:**  
Variance of the Gaussian distribution used to compute the image likelihood, specified as 
a scalar. Please note that the intensities are normalised between 0 and 255, therefore 
reasonable values are in the range [10^2,30^2].  
-_Default:_ 20^2  
-_Example:_ SmartInterpol(im_vol, lab_vol, result_path, trained_net_file,'lhood_variance', 25^2)
 
- **alpha:**  
Constant controlling the sharpness of the prior based on slice distance, specified in 
pixels (scalar). Higher values give more importance to one slice (the closer one); 
lower values give more similar importance to the two labeled slices around the current slice.  
-_Default:_ 0.05  
-_Example:_ SmartInterpol(im_vol, lab_vol, result_path, trained_net_file,'alpha', 0.01)

- **lambda_DL:**  
Constant that weights the importance of the neural network with respect to the label fusion, 
specified as a scalar. Reasonable range of values [0.1,2]. Values >1 give more importance to 
the neural network  
-_Default:_ 0.5  
-_Example:_ SmartInterpol(im_vol, lab_vol, result_path, trained_net_file,'lambda_DL', 2)

- **rho:**  
Constant controlling the sharpness of the prior based on the LogOdds. Reasonable range of 
values [0.1,2]. Higher value is sharper.  
-_Default:_ 0.5  
-_Example:_ SmartInterpol(im_vol, lab_vol, result_path, trained_net_file,'rho', 1)

- **EM:**  
Flag to activate or deactivate the Generalised Expectation-Maximisation algorithm described 
in the paper associated to this tool, specified as a logical value. If 'true' estimates dense 
segmentation with EM. If 'false' estimates dense segmentation with product rule (much faster).
The EM option is useful only if the images are difficult to register (some cases of 
histological sections).  
-_Default:_ false  
-_Example:_ SmartInterpol(im_vol, lab_vol, result_path, trained_net_file,'EM', true)

- **EMIter:**  
Number of iterations to use with the EM. Note that for each iteration a network is fine-tuned
to the current block, specified as a scalar.  
-_Default:_ 5  
-_Example:_ SmartInterpol(im_vol, lab_vol, result_path, trained_net_file,'EMIter', 2)

- **multiscale:**  
Flag to activate or deactivate the multiscale option for the training of the network, 
specified as a logical value. If 'true'  the second and third channel of the input 
image contain a blurred version of itself. If 'false' the second and third channel 
contain a copy of the input image.  
-_Default:_ true  
-_Example:_ SmartInterpol(im_vol, lab_vol, result_path, trained_net_file,'multiscale', false)

- **multiscale_sigma1:**  
Standard deviation of the Gaussian distribution used as kernel to blur the input 
image in channel 2, specified in pixels (scalar).  
-_Default:_ 2  
-_Example:_ SmartInterpol(im_vol, lab_vol, result_path, trained_net_file,'multiscale_sigma1', 3)

- **multiscale_sigma2:**  
Standard deviation of the Gaussian distribution used as kernel to blur the input
image in channel 3, specified in pixels (scalar).  
-_Default:_ 5  
-_Example:_ SmartInterpol(im_vol, lab_vol, result_path, trained_net_file,'multiscale_sigma2', 4)

- **LR_global:**  
Initial learning rate create used for global training, specified as a scalar.  
-_Default:_ 0.01  
-_Example:_ SmartInterpol(im_vol, lab_vol, result_path, trained_net_file,'LR_global', 0.05)

- **minibatch_global:**  
Size of the mini batch used for global training, specified as a scalar.  
-_Default:_ 2  
-_Example:_ SmartInterpol(im_vol, lab_vol, result_path, trained_net_file,'minibatch_global', 1)

- **maxepoch_global:**  
Maximum number of epochs for global training, specified as a scalar  
-_Default:_ 300  
-_Example:_ SmartInterpol(im_vol, lab_vol, result_path, trained_net_file,'maxepoch_global', 200)

- **LR_local:**  
Initial learning create used for local training (fine-tuning to the a specific block), 
specified as a scalar.  
-_Default:_ 0.05  
-_Example:_ SmartInterpol(iim_vol, lab_vol, result_path, trained_net_file,'LR_local', 0.01)

- **minibatch_local:**  
Size of the mini batch used for local training (fine-tuning to the a specific block), 
specified as a scalar.  
-_Default:_ 4  
-_Example:_ SmartInterpol(im_vol, lab_vol, result_path, trained_net_file,'minibatch_local', 2)

- **maxepoch_local:**  
Maximum number of epochs for global training (fine-tuning to the a specific block), 
specified as a scalar.  
-_Default:_ 200  
-_Example:_ SmartInterpol(im_vol, lab_vol, result_path, trained_net_file,'maxepoch_local', 150)

- **minibatch_EM:**  
Size of the mini batch used for local training (fine-tuning to the a specific block) 
on M step of GEM, specified as a scalar.  
-_Default:_ 4  
-_Example:_ SmartInterpol(im_vol, lab_vol, result_path, trained_net_file,'minibatch_EM',2)

- **firstSliceOption:**  
Specifies what to do with the first slice when no labels are provided for it. There are
two options:  
1: Consider the first slice annotated, i.e., there is no tissue in it.  
2: Consider the first slice unlabelled, such that it will be automatically labelled
   with information from other (labelled) slices.  
-_Default:_ 0  (ask interactively if needed)  
-_Example:_ SmartInterpol(im_vol, lab_vol, result_path, trained_net_file,'firstSliceOption', 1)

- **lastSliceOption:**  
Specifies what to do with the last slice when no labels are provided for it. There are
two options:  
1: Consider the last slice annotated, i.e., there is no tissue in it.  
2: Consider the last slice unlabelled, such that it will be automatically labelled
   with information from other (labelled) slices.  
-_Default:_ 0  (ask interactively if needed)  
-_Example:_ SmartInterpol(im_vol, lab_vol, result_path, trained_net_file,'lastSliceOption', 1)


