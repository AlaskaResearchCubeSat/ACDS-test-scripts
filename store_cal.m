function store_cal(sobj,cor,store_axis)

    %connect to ACDS
    asyncOpen(sobj,'ACDS');
    %get first avalible sector on the SD card
    command(sobj,'ffsector');
    %read line
    line=fgetl(sobj);
    %parse line
    SD_sector=str2double(line);
    %wait for command to finish
    waitReady(sobj);
    %close async
    asyncClose(sobj);
    
    %store calibration data to ACDS
    fprintf('Storing correction data for %i axes\n',length(store_axis));
    for k=1:length(store_axis)
        %make data to send to ACDS
        dat=make_cor_dat(cor{k},store_axis{k});
        try
            %send data to ACDS
            SPI_write(sobj,'ACDS',SD_sector+k-1,dat); 
        catch err
            fprintf(2,'Error : sending data "%s"\n',err.message);
        end
    end
    
    %connect to the ACDS board
    asyncOpen(sobj,'ACDS');
    %print message
    fprintf('Unpacking correction data\n');
    %unpack data
    for k=1:length(store_axis)
        command(sobj,'unpack %i',SD_sector+k-1);
        %wait for command to finish
        waitReady(sobj,[],true);
    end 
    %close async
    asyncClose(sobj);
end