function Iaug = random_gamma_augmentation(I)

% Eugenio: new function for random gamma augmentation

% Normalize to 0,1
mini = min(I(:));
maxi = max(I(:));
Iaug = (I - mini) / (maxi - mini);

% sample random gamma
gamma = exp(0.25 * randn(1));

% Augment
Iaug = Iaug .^ gamma;

% Undo normalization
Iaug = mini + (maxi - mini) * Iaug;


