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
        clf
        hold on
        if(show_meas)
            %plot measured field
            plot(sensor(1,:),sensor(2,:),'m');
            %calculate center
            cm=mean(sensor,2);
            %plot center for measured
            hc=plot(cm(1),cm(2),'b+');
            %turn off legend entry
            set(get(get(hc,'Annotation'),'LegendInformation'),'IconDisplayStyle','off');
        end
        %plot commanded field
        plot(Bs(1,:),Bs(2,:),'r');
        %calculate center
        c=mean(magScale*meas,2);
        %plot uncorrected measured field
        plot(magScale*meas(1,:),magScale*meas(2,:),'g');
        %plot uncorrected center
        hc=plot(c(1),c(2),'go');
        %turn off legend entry
        set(get(get(hc,'Annotation'),'LegendInformation'),'IconDisplayStyle','off');
        %calculate correction values
        len=length(meas);
        A=[meas(1:2,:)',ones(len,1)];
        As=(A'*A)^-1*A';
        cor(1:3)=As*(Bs(1,:)');
        cor(4:6)=As*(Bs(2,:)');
        %calculate error
        erms=sqrt(sum(mean([Bs(1,:)'-A*(cor(1:3)'),Bs(2,:)'-A*(cor(4:6)')].^2)));
        %calculate corrected values
        Xc=[meas(1:2,:)',ones(len,1)]*(cor(1:3)');
        Yc=[meas(1:2,:)',ones(len,1)]*(cor(4:6)');
        %plot corrected values
        plot(Xc,Yc,'b');
        %calculate center
        c(1)=mean(Xc);
        c(2)=mean(Yc);
        %plot corrected center
        hc=plot(c(1),c(2),'b*');
        %turn off legend entry
        set(get(get(hc,'Annotation'),'LegendInformation'),'IconDisplayStyle','off');
        %calculate center
        cs=mean(Bs,2);
        %plot center for commanded
        hc=plot(cs(1),cs(2),'xr');
        %turn off legend entry
        set(get(get(hc,'Annotation'),'LegendInformation'),'IconDisplayStyle','off');
        hold off
        ylabel('Magnetic Field [gauss]');
        xlabel('Magnetic Field [gauss]');
        if(show_meas)
            legend('Measured','Commanded','Uncorrected','Corrected');
        else
            legend('Commanded','Uncorrected','Corrected');
        end
        legend('Location','NorthEastOutside');
        axis('square');
        axis('equal');
        %add functions folder to path
        oldp=addpath('Z:\ADCS\functions');
        %save plot
        fig_export('Z:\ADCS\figures\cor.eps');
        %restore path
        path(oldp);
    catch err
        if exist('ser','var')
            if strcmp(ser.Status,'open') && ~isa(com,'serial')
                fclose(ser);
            end
            %check if port was open
            if(~isa(com,'serial'))
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
            %print ^c to stop running
            fprintf(ser,'%c',03);
            while ser.BytesToOutput
            end
            if(~isa(com,'serial'))
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
