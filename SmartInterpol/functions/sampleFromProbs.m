function L = sampleFromProbs(W)

CS=cumsum(W,3);
R=rand(size(W,1),size(W,2));

L=ones(size(W,1),size(W,2));

for l=1:size(W,3)-1
    M=R>CS(:,:,l);
    L(M)=l+1;
end


