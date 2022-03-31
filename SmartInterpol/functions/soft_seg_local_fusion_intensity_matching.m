function post_labels= soft_seg_local_fusion_intensity_matching(TESTimage,prob_warpedI,prob_warpedJ,warped_imageI,warped_imageJ,disti,distj,Lambda,Var,muI,muJ,muTEST)

    warped_imageI(isnan(warped_imageI))=0;
    warped_imageJ(isnan(warped_imageJ))=0;

    if nargin<10
        mask=warped_imageI>0 & warped_imageJ>0 & TESTimage>0;
        muI=mean(warped_imageI(mask));
        muJ=mean(warped_imageJ(mask));
        muTEST=mean(TESTimage(mask));
    end
    
    % Gaussian likelihood
    lhoodI=get_lhood(double(TESTimage)-muTEST,double(warped_imageI)-muI,Var);
    lhoodJ=get_lhood(double(TESTimage)-muTEST,double(warped_imageJ)-muJ,Var);

    % Prior based on distance to labeled sections
    priorI=exp(-double(Lambda*disti));
    priorJ=exp(-double(Lambda*distj));
    
    % Posterior of membership
    probI=priorI*lhoodI;
    probJ=priorJ*lhoodJ;

    % I don't want to get into numerical trouble...)
    probI(probI<eps)=eps;
    probJ(probJ<eps)=eps;
    
    normaliser=probI+probJ;
    
    postI=probI./normaliser;
    postJ=probJ./normaliser;
    
    % Posteriors of labels 
    post_labels=zeros(size(prob_warpedI,1),size(prob_warpedI,2),1,size(prob_warpedI,4));
    normaliser=zeros(size(prob_warpedI,1),size(prob_warpedI,2));

    for l=1:size(prob_warpedI,4)
        post_labels(:,:,1,l)=(prob_warpedI(:,:,1,l).*postI)+(prob_warpedJ(:,:,1,l).*postJ);
        normaliser=normaliser+post_labels(:,:,1,l);  
    end  
    
end

