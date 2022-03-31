function ssd = get_ssd(ref_img,war_img)
    ref=double(ref_img);
    war=double(war_img);
    ssd=(ref-war).^2;
end

