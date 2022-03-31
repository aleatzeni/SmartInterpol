function Y=reversemap(X,llist)

map=zeros(1,max(llist));
map(llist+1)=0:length(llist)-1;

Y=map(1+X);


