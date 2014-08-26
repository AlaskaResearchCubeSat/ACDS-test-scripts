function [ dat ] = mmc_get_blocks(sobj,sector,num)
%mmc_get_block - Get blocks of data from the SD card on the MSP
%   sobj - an open serial object that talks to the MSP
%   sector - the sector to get
    command(sobj,'mmcdat %li %li',sector,num);
    %fill dat with zeros
    dat=zeros(1,512*num,'uint8');
    %read all sectors requested
    for k=1:num 
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
        if(k==1 && strncmpi(umsg,line,length(umsg)))
            %wait for command to finish
            waitReady(sobj);
            error('mmcdat command not avaliable on microcontroller');
        end
        s=sscanf(line,'Sending MMC block %lu');
        %check to see if data was parsed
        if ~all(size(s)==[1,1])
            %wait for command to finish
            waitReady(sobj);
            error('Error reading block number for block #%i. failed to parse "%s"',k,deblank(line));
        end
        %check that sectors match
        if s~=sector+(k-1)
            waitReady(sobj);
            error('Error sector mismatch. Expected %lu got %lu',sector+(k-1),s)
        end
        %read data
        [rec,count]=fread(sobj,512,'uint8');
        %check that all bytes were read
        if(count~=512)
            %wait for command to finish
            waitReady(sobj);
            error('Error reading block #%i data only %i bytes read',k,count);
        end
        %get check line
        line=fgetl(sobj);
        %parse check
        check=sscanf(line,'Check =  %u');
        %chekc that data was parsed
        if ~all(size(check)==[1 1])
            %wait for command to finish
            waitReady(sobj);
            error('Error reading check for block #%i. failed to parse "%s"',k,deblank(line));
        end
        %calculate check
        calc=mod(sum(rec),2^16);
        %check that check and calculated check match
        if check~=calc
            %wait for command to finish
            waitReady(sobj);
            error('Error Check failed for block #%i. Check = %u Calculated = %u',k,check,calc);
        end
        %convert to uint8 so that typecast works
        dat(((512*(k-1))+1):(512*k))=uint8(rec);
    end
    %wait for command to finish
    waitReady(sobj);
end

