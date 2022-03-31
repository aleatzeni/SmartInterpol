function reconstructVolume(origVolPath,labDir,Nimgs,permutation,outDir,lab_name_base,methods, skip_first_slice, skip_last_slice)

% Eugenio added arguments skip_first_slice, skip_last_slice to skip first
% and last slices if needed (when artificially copied)

Nmethods=length(methods);

origMRI = myMRIread(char(origVolPath));
volume=cell(Nmethods,1);

for i=1:Nimgs
    manual_name = char([labDir filesep lab_name_base num2str(i,'%.4d') '.nii.gz']);
    for m=1:length(methods)
        out = char(strcat(outDir, filesep, 'tmp',filesep,'single_slice_res', filesep, lab_name_base, num2str(i,'%.4d'), '.', methods(m), '.nii.gz'));
        if exist(out,'file')
            mri=myMRIread(out);
            volume{m,1}(:,:,i)=mri.vol;
        else
            mri=myMRIread(manual_name);
            % Eugenio: I don't think you need remapping here
%             mri_remapped = zeros(size(mri.vol));
%             for l=1:length(lab_list)
%                 mri_remapped(mri.vol==l-1) = lab_list(l);
%             end
%             volume{m,1}(:,:,i)=mri_remapped;
            volume{m,1}(:,:,i)=mri.vol;
            
        end
    end
end

% Added by Eugenio
for m=1:length(methods)
    if skip_first_slice
        volume{m,1} = volume{m,1}(:,:,2:end);
    end
    if skip_last_slice
        volume{m,1} = volume{m,1}(:,:,1:end-1);
    end
end


permute2=zeros(1,3);
permute2(permutation)=1:3;
finalSEG = origMRI;
 for m=1:length(methods)
    finalSEG.vol=permute(volume{m},permute2);
    fileSEG_name = char(strcat(outDir,'vol.',methods(m),'.nii.gz'));
    myMRIwrite(finalSEG,fileSEG_name);
 end
