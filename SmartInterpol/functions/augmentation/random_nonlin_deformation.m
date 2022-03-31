function [Iaug, Laug] = random_nonlin_deformation(I, L)

% Eugenio: new function to nonlinearly deform and image and corresponding
% labels

% random control point spacing
cp_sp_x = 15 + 30 * rand(1);
cp_sp_y = 15 + 30 * rand(1);

% random strength of field
stddev = 0.5 + 2.5 * rand(1);

% Create low-resolution field
Fx = stddev * randn( 2 + ceil(size(L,1)/cp_sp_x), 2 + ceil(size(L,2)/cp_sp_y));
Fy = stddev * randn( 2 + ceil(size(L,1)/cp_sp_x), 2 + ceil(size(L,2)/cp_sp_y));
Fx(1,:)=0; Fx(end,:)=0; Fx(:,1)=0; Fx(:,end)=0;
Fy(1,:)=0; Fy(end,:)=0; Fy(:,1)=0; Fy(:,end)=0;

% Upscale field to get full-resolution smooth field
Fx_full = imresize(Fx, size(L));
Fy_full = imresize(Fy, size(L));

% Create meshgrid and apply field
[XX,YY] = ndgrid(1:size(L,1), 1:size(L,2));
XX2 = XX + Fx_full;
YY2 = YY + Fy_full;

Iaug = zeros(size(I));
for c = 1:size(I,3)
    ints = interpn(double(I(:,:,c)), XX2(:), YY2(:), 'cubic', 0);
    Iaug(:,:,c)=reshape(ints,size(L));
end
labs = interpn(L, XX2(:), YY2(:), 'nearest', 0);
Laug = reshape(labs,size(L));

