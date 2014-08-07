function magtst(com,baud)
    if(~exist('baud','var') || isempty(baud))
        baud=57600;
    end
    if(~exist('com','var') || isempty(com))
        com='COM3';
    end
    
    try
        %add functions from commandlib
        oldpath=addpath('Z:\ADCS\functions','Z:\Software\Libraries\commands\Matlab','-end');
        %open serial port
        ser=serial(com,'BaudRate',baud);
        %set input buffer size
        set(ser,'InputBufferSize',2000)
        set(ser,'OutputBufferSize',2000)
        %set timeout
        set(ser,'Timeout',6);        
        %open port
        fopen(ser);
        %close async if open
        asyncClose(ser);
        
        %open connection to ACDS
        asyncOpen(ser,'ACDS');
        %set log level to only log errors this prevents unnessisary
        %warnings from confusing Matlab if they are dumped to UART
        command(ser,'log error');
        waitReady(ser);
        %set output type to machine, makes things easier to parse
        command(ser,'output machine');
        waitReady(ser);

        command(ser,'mag');
        
        %get first line
        line=fgetl(ser);
        %strip newlines
        line=deblank(line);
        if(~strcmp(line,'Reading Magnetometer, press any key to stop'))
            error('Mag command failed %s',line);
        end
        
        %create figure
        figh=figure();
        %create axis
        axh=axes();
        %attach to figure
        set(figh,'CurrentAxes',axh)
        %generate data
        dat=zeros(3,50)*NaN;
        %generate range
        rng=1:length(dat);
        %plot
        plot(axh,rng,dat(1,:),rng,dat(2,:),rng,dat(3,:));
        %set index
        idx=1;
        
        while(ishghandle(figh))
            line=fgetl(ser);
            B=sscanf(line,'%f\t%f\t%f');
            if(any(size(B)~=[3,1]))
                fprintf(2,'Error reading line "%s"\n',deblank(line));
                B=[NaN;NaN;NaN];
            end
            if idx<=length(dat)
                dat(:,idx)=B';
            else
                B
                dat=[dat(:,2:end),B];
                rng=[rng(2:end),idx];
            end
            %increment index
            idx=idx+1;
            %plot
            plot(axh,rng,dat(1,:),rng,dat(2,:),rng,dat(3,:));
            %force update
            drawnow();
        end
        
        %send 's' to stop
        fprintf(ser,'%c','s');
        %close async
        asyncClose(ser);
    catch err
        if exist('ser','var') && isvalid(ser)
            if strcmp(ser.Status,'open')
                %close async
                asyncClose(ser);
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
