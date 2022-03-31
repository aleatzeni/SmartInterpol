function Iaug = random_contrast_augmentation(I)


% Eugenio: new function for random contrast/brightness augmentation

% Normalize to 0,1
mini = min(I(:));
maxi = max(I(:));
Iaug = (I - mini) / (maxi - mini);

% sample random contast and brightness
brightness = -0.2 + 0.4 * rand(1);
contrast = 0.75 + 0.5 * rand(1);

% Augment
Iaug = 0.5 + brightness + contrast * (Iaug - 0.5);
Iaug(Iaug<0)=0;
Iaug(Iaug>1)=1;

% Undo normalization
Iaug = mini + (maxi - mini) * Iaug;


