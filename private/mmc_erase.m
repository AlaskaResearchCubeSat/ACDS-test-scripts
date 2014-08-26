function mmc_erase(sobj,first,last)
    %send command
    command(sobj,'mmce %lu %lu',first,last);
    %get line with error or sector confermation
    line=fgetl(sobj);
    %check for error
    if(strncmpi('Error',line,length('Error')))    
        %wait for command to finish
        waitReady(sobj);
        error('Failed to erase sectors : ''%s''',deblank(line))
    end
    [s,c,e,n]=sscanf(line,'Erasing from %lu to %lu ');
    %check to see if data was parsed
    if c~=2 || ~isempty(e)
        %wait for command to finish
        waitReady(sobj);
        error('Error reading sector numbers. failed to parse "%s". %s',deblank(line),e);
    end
    %check that sectors match
    if s~=[first;last]
        waitReady(sobj);
        error('Error sector mismatch. Expected %lu to %lu got %lu to %lu',first,last,s(1),s(2));
    end
    %get line to check for success or failure
    line=fgetl(sobj);
    if ~strcmp('SUCCESS',deblank(line))
        %wait for command to finish
        waitReady(sobj);
        error('Failed to erase sectors : ''%s''',deblank(line))
    end
    %wait for command to finish
    waitReady(sobj);
end