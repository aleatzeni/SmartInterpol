function returnCode=call_reg_transform(transform, reference,cpp,result)
    cmd = [transform ' -ref ' reference ' -def ' cpp ' ' result];

    returnCode=system([cmd ' >/dev/null']); %execute operating system command and return output

end

