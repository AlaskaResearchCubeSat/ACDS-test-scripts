function name=unique_fliename(name)
    %seperate name from path and extension
    [ps,n,e]=fileparts(name);
    %find files in path
    %files=cellstr(ls(ps))
    %add date and extension to name
    name=sprintf('%s_%s%s',n,datestr(clock,'dd-mm-yy_HH-MM'),e);
    %reassemble file name
    name=fullfile(ps,name);
end
    