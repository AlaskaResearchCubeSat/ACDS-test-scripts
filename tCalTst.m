function [flips,stat,stat_index]=tCalTst(stable,mag_axis,cor,com,baud,gain,ADCgain,a)
    if(nargin<3)
        baud=57600;
    end
    if(~exist('stable','var') || isempty(stable))
        error('stable must be given')
    end
    if(~exist('mag_axis','var') || isempty(mag_axis))
        mag_axis='';
    end
    if(nargin<2)
        com='COM3';
    end
    if (~exist('gain','var') || isempty(gain))
        gain=1;
    end
    if (~exist('ADCgain','var') || isempty(ADCgain))
        ADCgain=64;
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
    try
        cc=cage_control();
        cc.loadCal('calibration.cal');
        %open serial port
        ser=serial(com,'BaudRate',baud);
        %set timeout to 15s
        set(ser,'Timeout',15);
        
        %setup recording for debugging
        ser.RecordName='tCalTst-debug.txt';
        ser.RecordMode='overwrite';
        ser.RecordDetail='verbose';
        
        %open port
        fopen(ser);
        %start recording
        record(ser,'on');

        %disable terminator
        set(ser,'Terminator','');
        %print ^C to exit async connection
        fprintf(ser,03);
        pause(1)
        %set terminator to CR/LF
        set(ser,'Terminator','LF');
        
        %set ADC gain for magnetomitor
        fprintf(ser,sprintf('gain %i',ADCgain));
        %get echoed line
        fgetl(ser);
        %get output line
        gs=fgetl(ser);
        %make sure that gain is correct
        if(ADCgain~=sscanf(gs,'ADC gain = %i'))
            error('Failed to set ADC gain to %i',ADCgain);
        end
        if ~waitReady(ser,10)
            error('Could not communicate with prototype. Check connections');
        end
        
        %connect to ACDS board
        asyncOpen(ser,'ACDS');
        %set to machine readable opperation
        fprintf(ser,'output machine');
        
        pause(1);
        %initialize torquers to a known state
        fprintf(ser,'init');
        
        if ~waitReady(ser,30)
            error('Error : Could not communicate with prototype. Check connections');
        end
        
        %set the ACDS to only print messages for errors
        fprintf(ser,'log error');
        
        if ~waitReady(ser,30)
            error('Error : Could not communicate with prototype. Check connections');
        end
        
        %get torquer status
        fprintf(ser,'statcode');
        %get echoed line
        fgetl(ser);
        %get status line
        stline=fgetl(ser); 
        %strip out status
        tqstat=stat_dat(stline);
        stlen=stat_length(stline);
        
        
        %exit async connection
        asyncClose(ser);
        
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
        tq={'0' '+1' '+2';
            '0' '+1' '-2';
            '0' '+2' '-1' ;
            '0' '-1' '-2'};
        
        %allocate for sensor
        sensor=zeros(size(Bs));
        %allocate for prototype
        meas=zeros(size(Bs));
        %set initial field
        cc.Bs=a*Bs(:,1);
        %give extra settaling time
        pause(1);
        
        %current torquer field offset
        curOS=cor(3,:);
        
        Xc=zeros(1,length(Bs));
        Yc=zeros(1,length(Bs));
        
        flips=cell(floor(length(Bs)/10),1);
        stat=cell(floor(length(Bs)/10),1);
        stat_index=zeros(floor(length(Bs)/10),1);
        tqs=[1,-1,1,-1,1,-1];
        
        for k=1:length(Bs)
            cc.Bs=a*Bs(:,k);
            %pause to let the supply settle
            pause(0.01);
            %tell prototype to take a single measurment
            command(ser,sprintf('mag single %s',mag_axis));
            %make measurment using sensor
            sensor(:,k)=inva*cc.Bm';
            %read measurments from prototype
            line=fgetl(ser);
            try
                lastwarn('');
                dat=sscanf(line,'%i %i');
                if(~isempty(lastwarn))
                    [warn,id]=lastwarn;
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
                asyncOpen(ser,'ACDS');
                pause(2);
                [tqx,dirx]=random_flip(tqstat(:,1));
                [tqy,diry]=random_flip(tqstat(:,2));
                [tqz,dirz]=random_flip(tqstat(:,3));
                %random torquer flip
                cmd=command(ser,'flip 0 0 %c%i',dirz,tqz);
                %save flips
                flips{k/10}=cmd;
                if ~waitReady(ser,30)
                    error('Prototype not responding\n');
                end
                pause(1);
                %get torquer status
                command(ser,'statcode');
                %get line for status
                stline=fgetl(ser);
                %save status
                stat{k/10}=stline(1:end-1);
                %parse status
                try
                    idx=stat2Idx(stline,stable);
                    %save index
                    stat_index(k/10)=idx;
                    curOS=cor(3+idx,:);
                    %parse current status
                    tqstat=stat_dat(stline);
                catch err
                    fprintf(2,'Error : Could not parse torquer status \"%s\"\n',stline(1:end-1));
                    rethrow(err);
                end
                if ~waitReady(ser,30)
                    error('Prototype not responding\n');
                end
                %exit async connection
                asyncClose(ser);
            end
        end
        figure(1);
        clf
        hold on
        %plot measured field
        %plot(sensor(1,:),sensor(2,:),'b');
        %plot commanded field
        plot(Bs(1,:),Bs(2,:),'r');
        %Calculate Scale only corrected values
        Xsc=meas(1:2,:)'*cor(1:2,1);
        Ysc=meas(1:2,:)'*cor(1:2,2);
        plot(Xsc,Ysc,'g');
        %calculate center
        sc(1)=mean(Xsc);
        sc(2)=mean(Ysc);
        %plot scale only corrected center
        hc=plot(sc(1),sc(2),'go');
        set(get(get(hc,'Annotation'),'LegendInformation'),'IconDisplayStyle','off');
        %plot corrected values
        plot(Xc,Yc,'b');
        %calculate center
        c(1)=mean(Xc);
        c(2)=mean(Yc);
        %plot corrected center
        hc=plot(c(1),c(2),'bo');
        set(get(get(hc,'Annotation'),'LegendInformation'),'IconDisplayStyle','off');
        %calculate center
        c=mean(sensor,2);
        %plot centers for measured
        %hc=plot(c(1),c(2),'b+');
        %set(get(get(hc,'Annotation'),'LegendInformation'),'IconDisplayStyle','off');
        %calculate center
        c=mean(Bs,2);
        %plot centers for commanded
        hc=plot(c(1),c(2),'rx');
        set(get(get(hc,'Annotation'),'LegendInformation'),'IconDisplayStyle','off');
        hold off
        ylabel('Magnetic Field [gauss]');
        xlabel('Magnetic Field [gauss]');
        %legend('Measured','Commanded','Scale only Corrected','Corrected');
        legend('Commanded','Scale only Corrected','Corrected');
        legend('Location','NorthEastOutside');
        axis('square');
        axis('equal');
        oldp=addpath('Z:\ADCS\functions');
        fig_export('Z:\ADCS\figures\torqueCalTst.eps');
        path(oldp);
        figure(2);
        clf
        %sample number
        sn=1:length(Xc);
        %calculate error magnitude
        err=[Xc;Yc]-Bs(1:2,:);
        err_s=sum(err.^2);
        %print out error
        fprintf('RMS Error = %f mGauss\n',sqrt(mean(err_s))*1e3);
        fprintf('Max Error = %f mGauss\n',max(sqrt(err_s))*1e3);
        %plot errors
        plot(sn,err(1,:),sn,err(2,:),sn,sqrt(err_s));
        %legend
        legend('X error','Y error','error magnitude');
        xlabel('Sample Number');
        ylabel('Error [Gauss]');
        
        %add functions folder to path
        oldp=addpath('Z:\ADCS\functions');
        %save plot
        fig_export('Z:\ADCS\figures\torqueCalTst-err.eps');
        %restore path
        path(oldp);
        %create new figure and add torquer status subplot
        figure(3);
        clf
        s1=subplot(2,1,1);
        %plot errors
        plot(sn,err(1,:),sn,err(2,:),sn,sqrt(err_s));
        %legend
        legend('X error','Y error','error magnitude');
        xlabel('Sample Number');
        ylabel('Error [Gauss]');
        
        sn=10*(1:length(stat));
        tstat=zeros(stlen*3,length(stat));
        %parse torquer statuses
        for k=1:length(stat)
            s=stat_dat(stat{k});
            tstat(:,k)=reshape((s-'+')/2,[],1);
        end
        %plot for torquer status
        s2=subplot(2,1,2);
        hold on;
        stairs(sn,3*tstat(1,:)+4,'r')
        stairs(sn,3*tstat(2,:)+12,'g')
        stairs(sn,3*tstat(3,:)+20,'b')
        stairs(sn,3*tstat(4,:)+28,'m')
        stairs(sn,3*tstat(5,:)+36,'c')
        stairs(sn,3*tstat(6,:)+44,'y')
        stairs(sn,stat_index,'k');
        hold off;
        legend('X1','X2','Y1','Y2','Z1','Z2','Index');
        %link subplots x-axis
        linkaxes([s1,s2],'x');
        %add functions folder to path
        oldp=addpath('Z:\ADCS\functions');
        %save plot
        fig_export('Z:\ADCS\figures\torqueCalTst-err-flips.eps');
        %restore path
        path(oldp);
    catch err
        if exist('ser','var')
            record(ser,'off');
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
            record(ser,'off');
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
        [msg,~,~]=fread(sobj,len,'char');
        if output
            fprintf('%s\n',char(msg'));
        end
    end
    success=true;
end

function asyncOpen(sobj,sys)
    timeout = 5;
    %wmsg='async open use ^C to force quit';
    wmsg='Using Address 0x12';
    fprintf(sobj,'async %s\n',sys);
    msg=[];
    m=fgetl(sobj);
    %fprintf('%s',m);
    while ~strncmp(wmsg,msg,length(wmsg)) && timeout>0
        msg=fgetl(sobj);
        %fprintf('%s',msg);
        if(strncmpi('Error',msg,length('Error')))
            error(msg);
        end
        timeout=timeout-1;
    end
end

function asyncClose(sobj)
    %get number of bytes in buffer
    n=sobj.BytesAvailable;
    if(n)
        %read all bytes
        fread(sobj,n,'char');
    end
    %send ^C
    fprintf(sobj,'%c',03);
    %wait for completion
    waitReady(sobj,5);
    %print for debugging
    %fprintf('async Closed\n');
end

function [stat]=stat_strip(line)
    stsx=sscanf(line,'%[+-] %*[+-] %*[+-] %*i %*i %*i');
    stsy=sscanf(line,'%*[+-] %[+-] %*[+-] %*i %*i %*i');
    stsz=sscanf(line,'%*[+-] %*[+-] %[+-] %*i %*i %*i');
    %get lengths of each status
    lx=length(stsx);
    ly=length(stsy);
    lz=length(stsz);
    %check if status was read
    if(lx==0)
        error('Failed to parse status from line ''%s''',line);
    end
    %check lengths
    if(lx~=ly || ly~=lz)
        error('Inconsistant status lengths %i %i %i while parsing ''%s''',lx,ly,lz,line);
    end
    %reformat status
    stat=sprintf('%s %s %s',stsx,stsy,stsz);
end

function [dat]=stat_dat(line)
    stsx=sscanf(line,'%[+-] %*[+-] %*[+-] %*i %*i %*i');
    stsy=sscanf(line,'%*[+-] %[+-] %*[+-] %*i %*i %*i');
    stsz=sscanf(line,'%*[+-] %*[+-] %[+-] %*i %*i %*i');
    %get lengths of each status
    lx=length(stsx);
    ly=length(stsy);
    lz=length(stsz);
    %check if status was read
    if(lx==0)
        error('Failed to parse status from line ''%s''',line);
    end
    %check lengths
    if(lx~=ly || ly~=lz)
        error('Inconsistant status lengths %i %i %i while parsing ''%s''',lx,ly,lz,line);
    end
    stsx=reshape(stsx,1,[]);
    stsy=reshape(stsy,1,[]);
    stsz=reshape(stsz,1,[]);
    %reformat status
    dat=[stsx;stsy;stsz];
end

function [len]=stat_length(line)
    lx=length(sscanf(line,'%[+-] %*[+-] %*[+-] %*i %*i %*i'));
    ly=length(sscanf(line,'%*[+-] %[+-] %*[+-] %*i %*i %*i'));
    lz=length(sscanf(line,'%*[+-] %*[+-] %[+-] %*i %*i %*i'));
    %check if status was read
    if(lx==0)
        error('Failed to parse status from line ''%s''',line);
    end
    %make sure lenghts are consistant
    if(lx~=ly || ly~=lz)
        error('Inconsistant status lengths %i %i %i while parsing ''%s''',lx,ly,lz,line);
    end
    len=lx;
end

function [tq,dir]=random_flip(stat)
    l=length(stat);
    tq=randi([0,l]);
    if l==0
        dir='';
    else
        %get current status
        d=stat(tq);
        if(d=='+')
            dir='-';
        elseif(d=='-')
            dir='+';
        else
            error('Unknown torquer direction ''%c''',d)
        end
    end
end
      
function [cmd]=command(sobj,cmd,varargin)
    %first flush buffer    
    %get number of bytes in buffer
    n=sobj.BytesAvailable;
    if(n)
        %read all bytes
        fread(sobj,n,'char');
    end
    %generate command
    cmd=sprintf(cmd,varargin{:});
    %send command
    fprintf(sobj,'%s\n',cmd);
    %get line for echo
    line=fgetl(sobj);
    num=5;
    %number of retries
    ntry=0;
    %maximum number of retries
    maxtry=2;
    while ~strcmp(cmd,line(1:end-1))
        num=num-1;
        if num==0
            if ntry<maxtry
                ntry=ntry+1;
                %send command again
                fprintf(sobj,'%s\n',cmd);
            else
                error('Command ''%s'' failed. Echo : ''%s''',cmd,line(1:end-1));
            end
        end
        line=fgetl(sobj);
    end
end


function idx=stat2Idx(stat,table)
    %strip status info
    stat=stat_dat(stat);
    %only include the z-axis
    idx=sum((('-'-stat(3,:))/2).*2.^(0:3))+1;
end
