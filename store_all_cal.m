function store_all_cal(com,baud,gain,ADCgain,a)
    axis_names={'X+','X-','Y+','Y-','Z-','Z+'};
    try
        %add functions from commandlib
        oldpath=addpath('Z:\ADCS\functions','Z:\Software\Libraries\commands\Matlab','-end');
        %open serial port
        ser=serial(com,'BaudRate',baud);
        %set timeout to 5s
        set(ser,'Timeout',5);        %open port
        fopen(ser);
        
        %set log level to only log errors this prevents unnessisary
        %warnings from confusing Matlab if they are dumped to UART
        command(ser,'log error');
        waitReady(ser);

        for k=1:length(axis_names)
            %calculate correction values
            %cor=calall(axis_names{k},com,baud,gain,ADCgain,a);
            %TESTING: generate random data
            cor=rand(51,2);
            %make data to send to ACDS
            dat=make_cor_dat(cor,axis_names{k});
            %send data to ACDS
            SPI_write(ser,'ACDS',89+k,dat);
        end
        %connect to the ACDS board
        asyncOpen(ser,'ACDS');
        for k=1:6
            command(ser,'unpack %i',89+k);
            %wait for command to finish
            waitReady(ser,[],true);
        end
        %close async
        asyncClose(ser);
    catch err
        if exist('ser','var')
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