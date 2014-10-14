files=ls('dat\magSclCalc*');

numfiles=size(files,1);

for k=1:numfiles
    s=load(fullfile('dat\',deblank(files(k,:))),'mag_axis');
    if(strcmp(s.mag_axis,'Y+'))
        fprintf('\t%s\n',deblank(files(k,:)));
    end
end
