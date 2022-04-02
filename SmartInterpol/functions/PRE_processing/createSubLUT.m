function subLUT_filename = createSubLUT(fullLUTpath,blockLab,outputDir)
fileID=fopen(fullLUTpath);
count=1;
Data={};
while ~feof(fileID)
    linedata=fgetl(fileID);
    if ~isempty(linedata)
        Data{count,1}=linedata;
        count=count+1;
    end
end
fclose(fileID);
line_num=[];
for line=1:length(Data)
    for lab=1:length(blockLab)
        labnum=split(Data{line,1},' ');
        if cell2mat(labnum(1))==string(blockLab(lab))
            line_num=[line_num,line];
        end
    end
end

subLUT_filename = [outputDir '/subLUT.txt'];
fid_sub = fopen(subLUT_filename, 'w');
for l=1:length(line_num)
    labnum=split(Data(line_num(l),:),' ');
    labnum{1,1}=string(l-1);
    newLine=[];
    for i=1:length(labnum)
        if ~isempty(labnum{i,:})
            newLine=strjoin([newLine,labnum{i,:},'  ']);
        end
    end
    fprintf(fid_sub,'%s\n',newLine);
end
fclose(fid_sub);