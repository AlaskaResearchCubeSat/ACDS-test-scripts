function dat=magSclTst(cor,mag_axis,com,baud,gain,ADCgain)
    %test magnetometer calibration by running the Helmholtz cage through a
    %field sequence and comparing the results to the field sequence
    if(~exist('cor','var') || isempty(cor))
        error('Correction Values not provided');
    end
    if(~exist('mag_axis','var') || isempty(mag_axis))
        mag_axis='';
    end
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
        ADCgain=64;
    end
    try
        cc=cage_control();
        cc.loadCal('calibration.cal');
        %open serial port
        ser=serial(com,'BaudRate',baud);
        %set timeout to 15s
        set(ser,'Timeout',15);
        %open port
        fopen(ser);

        %set ADC gain for magnetomitor
        fprintf(ser,sprintf('gain %i',ADCgain));
        %get echoed line
        fgetl(ser);
        %get output line
        gs=fgetl(ser);
        %make sure that gain is correct
        if(ADCgain~=sscanf(gs,'ADC gain = %i'))
            error('magcal','Failed to set ADC gain to %i',ADCgain);
        end
        if ~waitReady(ser,10)
            error('magcal','Could not communicate with prototype. Check connections');
        end
        
        magScale=1/(65535*1e-3*gain*ADCgain);
        
        %disable terminator
        set(ser,'Terminator','');
        %print ^C to stop running commands
        fprintf(ser,'%c',03);
        %set terminator to LF
        set(ser,'Terminator','LF');
        
        %theta=linspace(0,2*pi,60);
        %Bs=0.5*[sin(theta);cos(theta);0*theta];
        
        %theta=linspace(0,8*pi,300);
        %Bs=1/30*[theta.*sin(theta);theta.*cos(theta);0*theta];
        theta=linspace(0,2*pi,600);
        Bs=0.3*(1.5-[1;1;0]*cos(10*theta)).*[sin(theta);cos(theta);0*theta];
        
        %allocate for sensor
        sensor=zeros(size(Bs));
        %allocate for prototype
        meas=zeros(size(Bs));
        %set initial field
        cc.Bs=Bs(:,1);
        %give extra settaling time
        pause(1);
        
        for k=1:length(Bs)
            cc.Bs=Bs(:,k);
            %pause to let the supply settle
            pause(0.1);
            %tell prototype to take a single measurment
            fprintf(ser,sprintf('mag single %s',mag_axis));
            %make measurment using sensor
            sensor(:,k)=cc.Bm';
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
        figure(1);
        clf
        hold on
        %plot measured field
        %plot(sensor(1,:),sensor(2,:),'m');
        %plot commanded field
        plot(Bs(1,:),Bs(2,:),'r');
        %calculate center
        c=mean(magScale*meas,2);
        %plot prototype measured field
        plot(magScale*meas(1,:),magScale*meas(2,:),'g');
        %plot prototype center
        hc=plot(c(1),c(2),'go');
        %turn off legend entry
        set(get(get(hc,'Annotation'),'LegendInformation'),'IconDisplayStyle','off');
        %calculate correction values
        len=length(meas);
    
        Xc=[meas(1:2,:)',ones(len,1)]*(cor(1:3)');
        Yc=[meas(1:2,:)',ones(len,1)]*(cor(4:6)');
        %plot corrected values
        pcor=plot(Xc,Yc,'b');
        %calculate center
        c(1)=mean(Xc);
        c(2)=mean(Yc);
        %plot corrected center
        hc=plot(c(1),c(2),'b*');
        %turn off legend entry
        set(get(get(hc,'Annotation'),'LegendInformation'),'IconDisplayStyle','off');
        %calculate center
        %cm=mean(sensor,2);
        cs=mean(Bs,2);
        %plot center for measured
        %hc=plot(cm(1),cm(2),'b+');
        %turn off legend entry
        %set(get(get(hc,'Annotation'),'LegendInformation'),'IconDisplayStyle','off');
        %plot center for commanded
        hc=plot(cs(1),cs(2),'xr');
        %turn off legend entry
        set(get(get(hc,'Annotation'),'LegendInformation'),'IconDisplayStyle','off');
        hold off
        %add axis lables
        ylabel('Magnetic Field [gauss]');
        xlabel('Magnetic Field [gauss]');
        %add legend
        %legend('Measured','Commanded','Uncorrected','Corrected');
        legend('Commanded','Uncorrected','Corrected');
        legend('Location','NorthEastOutside');
        axis('square');
        axis('equal');
        
        %save plot
        fig_export('Z:\ADCS\figures\cor-tst.pdf');
        %create a new figure
        figure(2);
        clf
        sn=1:len;
        %package results
        dat=[Xc,Yc,Bs'];
        %calcualte error
        err=[Xc,Yc]-Bs(1:2,:)';
        err_s=sum(err.^2,2);
        %compute RMS error
        erms=sqrt(mean(err.^2));
        %print out error
        %print RMS error
        fprintf('RMS error:\n\tX = %f mGauss\n\tY = %f mGauss\n',erms*1e3);
        fprintf('\tMagnitude = %f mGauss\n',sqrt(mean(err_s))*1e3);
        %print Absolute error
        fprintf('Maximum Absolute Error:\nX = %f mGauss\nY = %f mGauss\n',1e3*max(abs(err)));
        fprintf('\tMagnitude = %f mGauss\n',max(sqrt(err_s))*1e3);
        %plot error
        plot(sn,err(:,1),sn,err(:,2),sn,sqrt(err_s)');
        legend('X error','Y error','Magnitude');
        xlabel('Sample');
        ylabel('Error [Gauss]');
        %save plot
        fig_export('Z:\ADCS\figures\cor-tst-err.pdf');
    catch err
        if exist('ser','var')
            if strcmp(ser.Status,'open')
                fclose(ser);
            end
            delete(ser);
        end
        if exist('cc','var')
            delete(cc);
        end
        rethrow(err);
    end
    if exist('ser','var')
        if strcmp(ser.Status,'open')
            %print Q to stop simulation
            fprintf(ser,'Q');
            while ser.BytesToOutput
            end
            fclose(ser);
        end
        delete(ser);
    end
    if exist('cc','var')
        delete(cc);
    end
end

function [success]=waitReady(sobj,timeout)
    msg=0;
    count=0;
    while msg(end)~='>'
        len=sobj.BytesAvailable;
        if len==0
            if count*3>=timeout
                success=false;
                return
            end
            pause(3);
            count=count+1;
            continue;
        end
        [msg,~,~]=fread(sobj,len);
        %char(msg')
    end
    success=true;
end
