function cor=store_all_cal(com,baud,gain,ADCgain)
    axis_names={'X+','X-','Y+','Y-','Z+','Z-'};
    
    store_axis={'Y-','Y+','Z+'};
    
    a={[0 0 1;-1 0 0;0 1 0],[0 0 1;-1 0 0;0 -1 0],...           %X +/-
       [1 0 0;0 0 -1;0 -1 0],[-1 0  0;0 0 1;0 -1 0],...             %Y +/-
       [0 -1 0;-1 0 0;0 0 1],[1 0 0;0 1 0;0 0 1],...             %Z +/-
       };
   
    try
        %add functions from commandlib
        oldpath=addpath('Z:\ADCS\functions','Z:\Software\Libraries\commands\Matlab','-end');
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
        
        cor=cell(1,length(store_axis));

        for k=1:length(store_axis)
            %find axis in the list of axis names
            idx=strcmp(store_axis{k},axis_names);
            %calculate correction values
            cor{k}=calall(axis_names{idx},ser,baud,gain,ADCgain,a{idx});
            %TESTING: generate random data
            %cor{k}=rand(51,2);
            %print out datasheet like values for comparison
            mag_parm(reshape(cor{1}(1:3,[2,1]),1,[]),gain*ADCgain);
            
            asyncClose(ser);
            %make data to send to ACDS
            dat=make_cor_dat(cor{k},axis_names{k});
            try
                %send data to ACDS
                SPI_write(ser,'ACDS',89+k,dat); 
            catch err
                fprintf(2,'Error : sending data "%s"\n',err.message);
            end
        end
        %connect to the ACDS board
        asyncOpen(ser,'ACDS');
        
        fprintf('Unpacking correction data\n');
        
        for k=1:length(store_axis)
            command(ser,'unpack %i',89+k);
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
        %restore old path
        path(oldpath);
        rethrow(err);
    end
    if exist('ser','var')
        if strcmp(ser.Status,'open')
            fclose(ser);
        end
        delete(ser);
    end
    %restore old path
    path(oldpath);
end