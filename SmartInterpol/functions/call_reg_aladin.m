function returnCode=call_reg_aladin(aladin,reference,floating,result,affine_transform,extra_options)
    cmd = [aladin ' -ref ' reference ' -flo ' floating ' -res ' result  ' -aff ' affine_transform ' ' extra_options];

    returnCode=system([cmd ' >/dev/null']); %execute operating system command and return output
    % returnCode=system(cmd); %execute operating system command and return output

end

