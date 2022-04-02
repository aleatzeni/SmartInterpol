function permutation=detectLabPlane(lab_filename)

    mri=myMRIread(char(lab_filename));
    M=mri.vol>0;

    % Eugenio: we now use ratio of labeled planes over total planes
    X=squeeze(sum(sum(M,2),3))>0;
    Y=squeeze(sum(sum(M,1),3))>0;
    Z=squeeze(sum(sum(M,1),2))>0;
    
    nX=sum(abs(diff(X)))/numel(X);
    nY=sum(abs(diff(Y)))/numel(Y);
    nZ=sum(abs(diff(Z)))/numel(Z);

    [~,permutation]=sort([nX nY nZ],'ascend');
    

end

