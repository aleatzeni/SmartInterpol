function dist = distance_transform_multilabel(seg,label_list)

n_tot_lab=length(label_list);
dist=[];
% dist=zeros(size(seg,1),size(seg,2),1,n_tot_lab);

for l=1:n_tot_lab
    
    mask=zeros(size(seg,1),size(seg,2));
    lab=label_list(l);
    
    M=seg==lab;
    
    if any(M(:))
        
        mask(M)=1;
        %     mask2=ones(size(seg,1),size(seg,2));
        %     mask2(seg==lab)=0;
        mask2=1-mask;
        
        distIn=bwdist(mask2);
        distOut=bwdist(mask);
        dist(:,:,1,l) =distIn-distOut;
        
    else
        dist(:,:,1,l) = -1e3;
    end
end


