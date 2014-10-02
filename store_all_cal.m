function cor=store_all_cal(com,baud,gain,ADCgain,store_axis)
    axis_names={'X+','X-','Y+','Y-','Z+','Z-'};
    %give default values if arguments are not given
    if(~exist('baud','var') || isempty(baud))
        baud=57600;
    end
    if(~exist('com','var') || isempty(com))
        com='COM3';
    end
    if (~exist('gain','var') || isempty(gain))
        gain=1;
    end
    if (~exist('ADCgain','var') || isempty(ADCgain))
        ADCgain=1;
    end
    if (~exist('store_axis','var') || isempty(store_axis))
        store_axis=axis_names;
    end
    
    %rotation matricies for SPB's
    a={make_spb_rot([0  -1 0],[0 0 -1]),make_spb_rot([0  1 0],[0 0 -1]),...           %X +/-
       make_spb_rot([ 1 0 0],[0 0 -1]),make_spb_rot([-1 0 0],[0 0 -1]),...             %Y +/-
       make_spb_rot([0  1 0],[-1  0 0]),make_spb_rot([-1 0 0],[0 1 0]),...             %Z +/-
       };
    
    try
        %open serial port
        ser=serial(com,'BaudRate',baud);
        %set input buffer size
        set(ser,'InputBufferSize',2000)
        set(ser,'OutputBufferSize',2000)
        %set timeout to 5s
        set(ser,'Timeout',5);        %open port
        fopen(ser);
        
        %set log level to only log errors this prevents unnessisary
        %warnings from confusing Matlab if they are dumped to UART
        command(ser,'log error');
        waitReady(ser);
        
        %connect to ACDS
        asyncOpen(ser,'ACDS');
        %get first avalible sector on the SD card
        command(ser,'ffsector');
        %read line
        line=fgetl(ser);
        %parse line
        SD_sector=str2double(line);
        %wait for command to finish
        waitReady(ser);
        %close async
        asyncClose(ser);
        
        cor=cell(1,length(store_axis));

        for k=1:length(store_axis)
            %find axis in the list of axis names
            idx=strcmp(store_axis{k},axis_names);
            %print name of SPB that is used
            fprintf('Calibrating the %s SPB\n',axis_names{idx});
            %calculate correction values
            cor{k}=calall(axis_names{idx},ser,baud,gain,ADCgain,a{idx});
            %TESTING: generate random data
            %cor{k}=rand(51,2);
            %print out datasheet like values for comparison
            mag_parm(reshape(cor{1}(1:3,1:2),1,[]),gain*ADCgain);
            
            asyncClose(ser);
            %make data to send to ACDS
            dat=make_cor_dat(cor{k},axis_names{idx});
            try
                %send data to ACDS
                SPI_write(ser,'ACDS',SD_sector+k-1,dat); 
            catch err
                fprintf(2,'Error : sending data "%s"\n',err.message);
            end
        end
        %connect to the ACDS board
        asyncOpen(ser,'ACDS');
        
        %create dat directory
        quiet_mkdir(fullfile('.','dat'));
        %save correction data to file as well as the axes used and gains
        save(fullfile('.','dat','cor.mat'),'cor','store_axis','gain','ADCgain');
        
        fprintf('Unpacking correction data\n');
        
        for k=1:length(store_axis)
            command(ser,'unpack %i',SD_sector+k-1);
            %wait for command to finish
            waitReady(ser,[],true);
        end
        %close async
        asyncClose(ser);
    catch err
        if exist('ser','var') && isvalid(ser)
            if strcmp(ser.Status,'open')
                fclose(ser);
            end
            delete(ser);
        end
        rethrow(err);
    end
    if exist('ser','var')
        if strcmp(ser.Status,'open')
            fclose(ser);
        end
        delete(ser);
    end
end