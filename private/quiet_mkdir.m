function quiet_mkdir(newdir)
    %call mkdir but turn off DirectoryExists warning
    %warning status is saved and restored
    
    %turn off warning and remeber state
    s=warning('off','MATLAB:MKDIR:DirectoryExists');
    %create directory
    mkdir(newdir)
    %restore warning
    warning(s);
end