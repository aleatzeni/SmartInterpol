function extract2DfromVol(intentisitesRearranged,labelsRearranged,imgFolder,trainingLabFolder,img_name_base,lab_name_base,firstSliceOption,lastSliceOption)

%
% Eugenio modiefied parameters to have access to firstSliceOption/lastSliceOption
%

%     vol_filename='inputIM.nii.gz';
%     lab_filename='inputLAB.nii.gz';
%     imgFolder='./imgs/';
%     trainingLabFolder='./training_labs/';
%     img_name_base='slice_';
%     lab_name_base='lab_';
    
    mkdir(imgFolder)
    mkdir(trainingLabFolder)
    
    Nimg = size(intentisitesRearranged,3);
    
    maxIntensity = max(intentisitesRearranged(:));
    
    mri=[]; mri.vox2ras0=eye(4); mri.volres=ones(1,3);
    
    for i=1:Nimg
        mri.vol=intentisitesRearranged(:,:,i);
        mri.vol=mri.vol/maxIntensity*255;
        MRIwrite(mri,char([imgFolder filesep img_name_base num2str(i,'%.4d') '.nii.gz']));
        
        % Eugenio: we now write labels for first or last slice when they
        % are empty but the user told us that they should be empty
        writeLabels = 0;
        if any(any(labelsRearranged(:,:,i)>0))
            writeLabels = 1;
        elseif (firstSliceOption==1 && i==1)
            writeLabels = 1;
        elseif (lastSliceOption==1 && i==Nimg)
            writeLabels = 1;
        end
        if writeLabels
            mri.vol=labelsRearranged(:,:,i);
            MRIwrite(mri,char([trainingLabFolder filesep lab_name_base num2str(i,'%.4d') '.nii.gz']));
        end
    end
end
