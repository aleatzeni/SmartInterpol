function finalList=cleanDirList(imList)
finalList={};
for i=1:length(imList)
   if (strcmp(imList(i).name(1:2),'._') || strcmp(imList(i).name(1:2),'..') || strcmp(imList(i).name(1),'.')) 
       continue
   else
       finalList{end+1}=imList(i);
   end
end
