function returnCode = call_reg_resample(resample,reference,floating,result,nonlin_transform,interpMode)
     if strcmp(interpMode,'labels')
        interpolation=num2str(0);
     elseif strcmp(interpMode,'prob')
        interpolation=num2str(1);
     elseif strcmp(interpMode,'images')
        interpolation=num2str(2);
     else
         error('Interpolation mode not supported');
     end
     
     if nargin>6
     	padding = ' -pad nan';
     else
         padding = [];
     end
 
    cmd = [resample ' -ref ' reference ' -flo ' floating ' -res ' result ' -trans ' nonlin_transform ' -inter ' interpolation padding]; 
    returnCode=system([cmd  ' >/dev/null']); %execute operating system command and return output
    
end
