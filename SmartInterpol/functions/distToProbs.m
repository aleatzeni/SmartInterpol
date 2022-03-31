function probs=distToProbs(dist,rho)
    dist_size=size(dist);
    probs=zeros(dist_size);
    normalizer=zeros(dist_size(1),dist_size(2))+eps;
    for l=1:dist_size(4)
        probs(:,:,1,l)=exp(rho*dist(:,:,1,l));
        normalizer=probs(:,:,1,l)+normalizer;
    end
        
    for l=1:dist_size(4)
        probs(:,:,1,l)=probs(:,:,1,l)./normalizer;
    end
    
    % Taking care of possible Nans in background due to distance maps
    probs(isnan(probs(:,:,1,1)))=1;
end

