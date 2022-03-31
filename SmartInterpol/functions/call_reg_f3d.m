function returnCode=call_reg_f3d(f3d,reference,floating,result,affine_transform,nonlin_transform,extra_options)

    cmd = [f3d ' -ref ' reference ' -flo ' floating ' -res ' result  ' -aff ' affine_transform ' -cpp  ' nonlin_transform ' ' extra_options];

    returnCode=system([cmd ' >/dev/null']); %execute operating system command and return output
    % returnCode=system(cmd); %execute operating system command and return output

end


