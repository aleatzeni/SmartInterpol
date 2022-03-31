function X = reverse_label_map(X,labShort,labFull)
for lab=1:length(labShort)
    X(X==labShort(lab))=labFull(labShort(lab));

end
