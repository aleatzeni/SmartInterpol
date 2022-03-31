function lhood = get_lhood(ref_img,war_img,var)
    ssd = get_ssd(ref_img,war_img);
    lhood=1/sqrt(2*pi*var)*exp(-ssd/2/var);
end

