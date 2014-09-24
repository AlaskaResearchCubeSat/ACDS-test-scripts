function [cor,erms]=magSclCalc(mag_axis,com,baud,gain,ADCgain,a)
    %calculate magnetometer scaling and correction factors using the
    %Helmholtz cage
    if(~exist('mag_axis','var') || isempty(mag_axis))
        mag_axis='';
    end
    if(~exist('baud','var') || isempty(baud))
        baud=57600;
    end
    if(~exist('com','var') || isempty(com))
        com='COM3';
    end
    if(~exist('a','var') || isempty(a))
        %if no transform is given then use unity
        %coult use identity matrix but 1 is faster and will work
        a=1;
        inva=1;
    else
        if size(a)~=[3 3]
            error('a must be a 3x3 matrix')
        end
        %calculate inverse to correct for measurments
        inva=inv(a);
    end
    if (~exist('gain','var') || isempty(gain))
        gain=1;
    end
    if (~exist('ADCgain','var') || isempty(ADCgain))
        ADCgain=64;
    end
    show_meas=true;
    try
        cc=cage_control();
        cc.loadCal('calibration.cal');
        %check if com is a serial object
        if(isa(com,'serial'))
            %use already open port
            ser=com;
            %clear com var so it doesn't get saved
            clear com;
            %check for bytes in buffer
            bytes=ser.BytesAvailable;
            if(bytes~=0)
                %read all available bytes to flush buffer
                fread(ser,bytes);
            end
        else
            %open serial port
            ser=serial(com,'BaudRate',baud);
            %set timeout to 15s
            set(ser,'Timeout',15);
            %open port
            fopen(ser);
        end

        %disable terminator
        set(ser,'Terminator','');
        %print ^C to stop running commands
        fprintf(ser,'%c',03);
        %check for bytes in buffer
        bytes=ser.BytesAvailable;
        if(bytes~=0)
            %read all available bytes to flush buffer
            fread(ser,bytes);
        end
        %set terminator to LF
        set(ser,'Terminator','LF');
        %set to machine readable opperation
        %fprintf(ser,'output machine');
        %burn three lines
        %fgetl(ser);
        %fgetl(ser);
        %fgetl(ser);
        
        fprintf(ser,sprintf('gain %i',ADCgain));
        fgetl(ser);
        gs=fgetl(ser);
        if(ADCgain~=sscanf(gs,'ADC gain = %i'))
            fprintf(gs);
            error('Failed to set ADC gain to %i',ADCgain);
        end
        if ~waitReady(ser,10)
            error('Could not communicate with prototype. Check connections');
        end
        
        magScale=1/(65535*1e-3*gain*ADCgain);
        
        %theta=linspace(0,2*pi,60);
        %Bs=0.5*[sin(theta);cos(theta);0*theta];
        
        theta=linspace(0,8*pi,500);
        Bs=1/30*[theta.*sin(theta);theta.*cos(theta);0*theta];
        
        %allocate for sensor
        sensor=zeros(size(Bs));
        %allocate for prototype
        meas=zeros(size(Bs));
        %set initial field
        cc.Bs=Bs(:,1);
        %give extra settaling time
        pause(1);
        
        for k=1:length(Bs)
            cc.Bs=a*Bs(:,k);
            %pause to let the supply settle
            pause(0.1);
            %tell prototype to take a single measurment
            fprintf(ser,sprintf('mag single %s',mag_axis));
            %make measurment using sensor
            sensor(:,k)=inva*cc.Bm';
            %read echoed line
            fgetl(ser);
            %read measurments from prototype
            line=fgetl(ser);
            try
                dat=sscanf(line,'%i %i');
                meas(1:2,k)=dat;
                meas(3,k)=0;
            catch err
               fprintf(2,'Could not parse line \"%s\"\n',line);
               rethrow(err);
            end    
        end
        %create dat directory
        quiet_mkdir(fullfile('.','dat'));
        %get unique file name
        savename=unique_fliename(fullfile('.','dat','magSclCalc.mat'));
        %save data
        save(savename,'-regexp','^(?!(cc|ser)$).');
        %generate plots from datafile
        cor=magSclCalc_plot(savename);
    catch err
        if exist('ser','var')
            if strcmp(ser.Status,'open') && exist('com','var')
                fclose(ser);
            end
            %check if port was open
            if(exist('com','var'))
                delete(ser);
            end
        end
        if exist('cc','var')
            delete(cc);
        end
        rethrow(err);
    end
    if exist('ser','var')
        if strcmp(ser.Status,'open')
            while ser.BytesToOutput
            end
            if(exist('com','var'))
                fclose(ser);
            end
        end
        %check if port was open
        if(~isa(com,'serial'))
            delete(ser);
        end
    end
    if exist('cc','var')
        delete(cc);
    end
end
