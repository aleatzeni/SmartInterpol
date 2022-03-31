function [POSTrgb,SEGrgb]=createPostImage(POST,lutColors)

siz=[size(POST,1) size(POST,2)]
POSTrgb=zeros([siz,3]);
LC=double(lutColors)/255;

for l=1:size(lutColors,1)
    for c=1:3
        POSTrgb(:,:,c)=POSTrgb(:,:,c)+POST(:,:,l)*LC(l,c);
    end
end
POSTrgb=uint8(255*POSTrgb);

[~,idx]=max(POST,[],3);
SEGrgb=zeros([siz,3]);
for c=1:3
    aux=LC(:,c);
    SEGrgb(:,:,c)=aux(idx);
end
SEGrgb=uint8(255*SEGrgb);





