function [ dat ] = mmc_get_block(sobj,sector)
%mmc_get_block - Get a block of data from the SD card on the MSP
%   sobj - an open serial object that talks to the MSP
%   sector - the sector to get
    command(sobj,'mmcdat %li',sector);
    %get line with error or sector confermation
    line=fgetl(sobj);
    %check for error
    if(strncmpi('Error',line,length('Error')))    
        %wait for command to finish
        waitReady(sobj);
        error('Failed to read data: ''%s''',deblank(line))
    end
    %unknown command message
    umsg='unknown command ''mmcdat''';
    %check for unknown command
    if(strncmpi(umsg,line,length(umsg)))
        %wait for command to finish
        waitReady(sobj);
        error('mmcdat command not avaliable on microcontroller');
    end
    s=sscanf(line,'Sending MMC block %lu');
    %check to see if data was parsed
    if ~all(size(s)==[1,1])
        %wait for command to finish
        waitReady(sobj);
        error('Error reading block number. failed to parse "%s"',deblank(line));
    end
    %check that sectors match
    if s~=sector
        waitReady(sobj);
        error('Error sector mismatch. Expected %lu got %lu',sector,s)
    end
    %read data
    [dat,count]=fread(sobj,512,'uint8');
    %check that all bytes were read
    if(count~=512)
        error('Error reading data only %i bytes read',count);
    end
    %get check line
    line=fgetl(sobj);
    %parse check
    check=sscanf(line,'Check =  %u');
    %chekc that data was parsed
    if ~all(size(check)==[1 1])
        %wait for command to finish
        waitReady(sobj);
        error('Error reading check. failed to parse "%s"',deblank(line));
    end
    %calculate check
    calc=mod(sum(dat),2^16);
    %check that check and calculated check match
    if check~=calc
        %wait for command to finish
        waitReady(sobj);
        error('Error Check failed. Check = %u Calculated = %u',check,calc);
    end
    %convert to uint8 so that typecast works
    dat=uint8(dat);
    %wait for command to finish
    waitReady(sobj);
end

