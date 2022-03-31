function returnCode=call_reg_f3d_EM(f3d,reference,floating,result,nonlin_transform,extra_options,VERBOSE)
    
    if exist('VERBOSE','var')==0
        VERBOSE=0;
    end

    cmd = [f3d ' -ref ' reference ' -flo ' floating ' -res ' result   ' -cpp  ' nonlin_transform extra_options];

    if VERBOSE
        returnCode=system(cmd); %execute operating system command and return output
    else
        returnCode=system([cmd ' >/dev/null']); 
    end

end


