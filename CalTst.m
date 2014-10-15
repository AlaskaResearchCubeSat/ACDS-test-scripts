function tCalTst(cor,com,baud)
    %test torquer calibration by running through a fileld sequenc and
    %flipping random torquers
    if(~exist('baud','var') || isempty(baud))
        baud=57600;
    end
    if(~exist('com','var') || isempty(com))
        com='COM3';
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

        %disable terminator
        set(ser,'Terminator','');
        %print ^C to exit async connection
        fprintf(ser,03);
        pause(1)
        %set terminator to CR/LF
        set(ser,'Terminator','LF');
        %connect to ACDS board
        fprintf(ser,'async ACDS');
        fgetl(ser);
        fgetl(ser);
        pause(1);
        %set to machine readable opperation
        %fprintf(ser,'output machine');
        
        pause(1);
        %initialize torquers to a known state
        fprintf(ser,'reinit');
        
        if ~waitReady(ser,30,true)
            error('Error : Could not communicate with prototype. Check connections');
        end
        
        %set the ACDS to only print messages for errors
        fprintf(ser,'log error');
        
        if ~waitReady(ser,30,true)
            error('Error : Could not communicate with prototype. Check connections');
        end
        
        %print ^C to exit async connection
        fprintf(ser,03);
        fgetl(ser);
        fgetl(ser);
        
        %set the Sensor Proxy to only print messages for errors
       % fprintf(ser,'log error');
        
        %if ~waitReady(ser,30,true)
         %   error('Error : Could not communicate with prototype. Check connections');
        %end
        
        theta=linspace(0,2*pi,500);
        %Bs=1*[sin(theta);cos(theta);0*theta];
        %d=2;
        %ec=0.5;
        %Bs=0.1*[d./(1+ec*cos(theta)).*sin(theta);d./(1+ec*cos(theta)).*cos(theta);0*theta];
        
        Bs=0.3*(1.5-[1;1;0]*cos(10*theta)).*[sin(theta);cos(theta);0*theta];
        
        
        %theta=linspace(0,8*pi,300);
        %Bs=1/30*[theta.*sin(theta);theta.*cos(theta);0*theta];
        
        
        %torquer flip array
        tq={'00' '+1' '+2' '-1' '-2'};
        
        %allocate for sensor
        sensor=zeros(size(Bs));
        %allocate for prototype
        meas=zeros(size(Bs));
        %set initial field
        cc.Bs=Bs(:,1);
        %give extra settaling time
        pause(1);
        
        %current torquer field offset
        curOS=cor(3,:);
        
        Xc=zeros(1,length(Bs));
        Yc=zeros(1,length(Bs));
        
        for k=1:length(Bs)
            cc.Bs=Bs(:,k);
            %pause to let the supply settle
            pause(0.01);
            %tell prototype to take a single measurment
            fprintf(ser,'mag single');
            %make measurment using sensor
            sensor(:,k)=cc.Bm';
            %read echoed line
            fgetl(ser);
            %read measurments from prototype
            line=fgetl(ser);
            try
                lastwarn('');
                dat=sscanf(line,'%i %i');
                if(~isempty(lastwarn))
                    [warn,id]=lastwarn
                    error(id,warn);
                end
                meas(1:2,k)=dat;
            catch err
                fprintf(2,'Error : Could not parse measurments \"%s\"\n',line(1:end-1));
                rethrow(err);
            end
            meas(1:2,k)=dat;
            meas(3,k)=0;
            %Calculate Corrected Field
            Xc(k)=dat'*cor(1:2,1)+curOS(1);
            Yc(k)=dat'*cor(1:2,2)+curOS(2);
            %do a random flip every 10 samples
            if mod(k,10)==0
                if ~waitReady(ser,30)
                    error('Prototype not responding\n');
                end
                %connect to ACDS board
                fprintf(ser,'async ACDS');
                %wait a bit
                pause(1);
                %clear buffer
                if(ser.BytesAvailable)
                    fread(ser,ser.BytesAvailable);
                end
            
                %random torquer flip
                cmd=sprintf('flip %s %s %s',tq{randi(end)},tq{randi(end)},tq{randi(end)});
                fprintf(ser,'%s\n',cmd);
                %get line for echo
                fgetl(ser);
                %get line for status
                line=fgetl(ser);
                %parse status
                try
                    stat=sscanf(line,'%s %s %s %s %i %i %i  ',10);
                    stat=(stat(2:7)-43)/2;
                    idx=statIdx(stat(1:2))+4*statIdx(stat(3:4))+16*statIdx(stat(5:6));
                    curOS=cor(3+idx,:);
                catch err
                    fprintf(2,'Error : Could not parse torquer status \"%s\"\n',line(1:end-1));
                    rethrow(err);
                end
                if ~waitReady(ser,30)
                    error('Prototype not responding\n');
                end
                %print ^C to exit async connection
                fprintf(ser,03);
                %clear buffer
                fgetl(ser);
                fgetl(ser);
            end
        end
        figure(1);
        clf
        hold on
        %plot measured field
        plot(sensor(1,:),sensor(2,:),'b');
        %plot commanded field
        plot(Bs(1,:),Bs(2,:),'r');
        %Calculate Scale only corrected values
        Xsc=meas(1:2,:)'*cor(1:2,1);
        Ysc=meas(1:2,:)'*cor(1:2,2);
        plot(Xsc,Ysc,'m');
        %plot corrected values
        plot(Xc,Yc,'g');
        %calculate center
        c(1)=mean(Xc);
        c(2)=mean(Yc);
        %plot corrected center
        hc=plot(c(1),c(2),'go');
        set(get(get(hc,'Annotation'),'LegendInformation'),'IconDisplayStyle','off');
        %calculate center
        c=mean(sensor,2);
        %plot centers for measured
        hc=plot(c(1),c(2),'b+');
        set(get(get(hc,'Annotation'),'LegendInformation'),'IconDisplayStyle','off');
        %calculate center
        c=mean(Bs,2);
        %plot centers for commanded
        hc=plot(c(1),c(2),'rx');
        set(get(get(hc,'Annotation'),'LegendInformation'),'IconDisplayStyle','off');
        hold off
        ylabel('Magnetic Field [gauss]');
        xlabel('Magnetic Field [gauss]');
        legend('Measured','Commanded','Scale only Corrected','Corrected');
        legend('Location','NorthEastOutside');
        axis('equal');
        axis('square');
        fig_export('Z:\ADCS\figures\torqueCalTst.pdf');
        figure(2);
        clf
        %calculate error magnitude
        err=sum(([Xc;Yc]-Bs(1:2,:)).^2);
        fprintf('RMS Error = %f\n',sqrt(mean(err)));
        plot(sqrt(err));
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

function [success]=waitReady(sobj,timeout,output)
    if nargin<3
        output=false;
    end
    if nargin<2
        timeout=5;
    end
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
        if output
            fprintf('%s\n',char(msg'));
        end
    end
    success=true;
end

function k=statIdx(s)
    sc=reshape(s,1,[])*[1;2];
    switch(sc)
        case 0
            k=1;
        case 1
            k=2;
        case 2
            k=0;
        case 3
            k=3;
        otherwise
            k=NaN;
    end
end
