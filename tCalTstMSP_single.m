function [flips,stat,stat_index,lines]=tCalTstMSP_single(mag_axis,com,baud,a,flip)
    if(nargin<3)
        baud=57600;
    end
    if(nargin<2)
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
    if(~exist('mag_axis','var') || isempty(mag_axis))
        mag_axis='';
    end
    if(~exist('flip','var') || isempty(flip))
        flip=true;
    end
    %setup magnetic field
    %theta=linspace(0,2*pi,500);
    %Bs=1*[sin(theta);cos(theta);0*theta];
    %d=2;
    %ec=0.5;
    %Bs=0.1*[d./(1+ec*cos(theta)).*sin(theta);d./(1+ec*cos(theta)).*cos(theta);0*theta];

    %flower
    %theta=linspace(0,2*pi,500);
    %Bs=0.3*(1.5-[1;1;0]*cos(10*theta)).*[sin(theta);cos(theta);0*theta];
    theta=linspace(0,2*pi,500);
    Bs=0.3*(1.5-[1;1;0]*cos(3*theta)).*[sin(theta);cos(theta);0*theta];


    %spirial
    %theta=linspace(0,8*pi,500);
    %Bs=1/30*[theta.*sin(theta);theta.*cos(theta);0*theta];

    %allocate for sensor
    sensor=zeros(size(Bs));
    %allocate for prototype
    meas=zeros(size(Bs));

    flips=cell(floor(length(Bs)/10)+1,1);
    stat=cell(floor(length(Bs)/10)+1,1);
    stat_index=zeros(floor(length(Bs)/10)+1,3);
    lines=cell(length(Bs),1);

    try
        %add functions from commandlib
        oldpath=addpath('Z:\Software\Libraries\commands\Matlab','-end');
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

        %set terminator to CR/LF
        set(ser,'Terminator','LF');
        
        %exit async connection if open
        asyncClose(ser);
        pause(1)
        
        %connect to ACDS board
        asyncOpen(ser,'ACDS');
        %set to machine readable opperation
        fprintf(ser,'output machine');
        if ~waitReady(ser,30)
            error('Error : Could not communicate with prototype. Check connections');
        end
        
        pause(1);
        
        %set the ACDS to only print messages for errors
        fprintf(ser,'log error');
        
        if ~waitReady(ser,30)
            error('Error : Could not communicate with prototype. Check connections');
        end
        pause(1);
        
        if flip
            %make sure torquers are initialized
            command(ser,'reinit');
            if ~waitReady(ser,30)
                error('Error : Could not communicate with prototype. Check connections');
            end
        end
        %get torquer status
        command(ser,'statcode');
        %get status line
        stline=fgetl(ser); 
        %get length of status info
        stlen=stat_length(stline);
        
        %save status
        stat{1}=stline(1:end-1);
        %parse status
        try
            idxX=stat2Idx(stline,1);
            idxY=stat2Idx(stline,2);
            idxZ=stat2Idx(stline,3);
            %save index
            stat_index(1,:)=[idxX,idxY,idxZ];
            %parse current status
            tqstat=stat_dat(stline);
        catch err
            fprintf(2,'Error : Could not parse torquer status \"%s\"\n',stline(1:end-1));
            rethrow(err);
        end
        if ~waitReady(ser,30)
            error('Prototype not responding\n');
        end
        
        %set the Sensor Proxy to only print messages for errors
       % fprintf(ser,'log error');
        
        %if ~waitReady(ser,30,true)
         %   error('Error : Could not communicate with prototype. Check connections');
        %end
        
        %set initial field
        cc.Bs=a*Bs(:,1);
        %give extra settaling time
        pause(1);

        for k=1:length(Bs)
            cc.Bs=a*Bs(:,k);
            %pause to let the supply settle
            pause(0.01);
            %tell prototype to take a single measurment
            command(ser,'mag single %s',mag_axis);
            %make measurment using sensor
            sensor(:,k)=inva*cc.Bm';
            %clear warining
            lastwarn('');
            to=0;le=false;
            while to<5 && ~le
                try
                    %read measurments from prototype
                    line=fgetl(ser);
                    %save line
                    lines{k}=line;
                    %check warning
                    if(~isempty(lastwarn))
                        [warn,id]=lastwarn;
                        waitReady(ser,30);
                        error(id,warn);
                    end
                    %wait for command to complete
                    if ~waitReady(ser,30)
                        error('Prototype not responding\n');
                    end
                    [dat,count,err]=sscanf(line,'%f %f');
                    %check if data was parsed
                    if(count~=2)
                        waitReady(ser,30);
                        if(isempty(err))
                            error('failed to parse "%s". no error.',deblank(line));
                        end
                        %throw error
                        error(err);
                    end
                    %get measurment
                    meas(1:2,k)=dat;
                    meas(3,k)=0;
                    le=true;
                catch err
                    fprintf(2,'Error : Could not parse measurment #%i \"%s\"\n',k,deblank(line));
                    %rethrow(err);
                    fprintf(2,'%s\n',err.message);
                    to=to+1;
                    command(ser,'mag single %s',mag_axis);
                end
            end
            if ~le
                waitReady(ser,30);
                rethrow(err)
            end
            %do a random flip every 10 samples
            if mod(k,10)==0
                if flip
                    %random flip in each axis
                    [tqx,dirx]=random_flip(tqstat(1,:));
                    [tqy,diry]=random_flip(tqstat(2,:));
                    [tqz,dirz]=random_flip(tqstat(3,:));
                    %random torquer flip
                    cmd=command(ser,'flip %c%i %c%i %c%i',dirx,tqx,diry,tqy,dirz,tqz);
                    %save flips
                    flips{k/10+1}=cmd;
                    if ~waitReady(ser,30)
                        error('Prototype not responding\n');
                    end
                    pause(1);
                end
                %get torquer status
                command(ser,'statcode');
                %get line for status
                stline=fgetl(ser);
                %wait for command to complete
                if ~waitReady(ser,30)
                    error('Prototype not responding\n');
                end
                %save status
                stat{k/10+1}=stline(1:end-1);
                %parse status
                try
                    idxX=stat2Idx(stline,1);
                    idxY=stat2Idx(stline,2);
                    idxZ=stat2Idx(stline,3);
                    %save index
                    stat_index(k/10+1,:)=[idxX,idxY,idxZ];
                    %parse current status
                    tqstat=stat_dat(stline);
                catch err
                    fprintf(2,'Error : Could not parse torquer status \"%s\" for flip #%i\n',deblank(stline),mod(k,10));
                    rethrow(err);
                end
            end
        end
        %exit async connection
        asyncClose(ser);
        %create figure
        figure(1);
        clf
        hold on
        %plot measured field
        plot(sensor(1,:),sensor(2,:),'b');
        %plot commanded field
        plot(Bs(1,:),Bs(2,:),'r');
        %plot corrected values
        plot(meas(1,:),meas(2,:),'m');
        %calculate center
        c(1)=mean(meas(1,:));
        c(2)=mean(meas(2,:));
        %plot corrected center
        hc=plot(c(1),c(2),'mo');
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
        legend('Measured','Commanded','Corrected');
        legend('Location','NorthEastOutside');
        axis('square');
        axis('equal');
        fig_export('Z:\ADCS\figures\torqueCalTst.eps');
        figure(2);
        clf
        %sample number
        sn=1:length(meas(1,:));
        %calculate error magnitude
        err=[meas(1,:);meas(2,:)]-Bs(1:2,:);
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
        
        %save plot
        fig_export('Z:\ADCS\figures\torqueCalTst-err.eps');
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
        
        sn=10*(0:length(stat)-1);
        tstat=zeros(stlen*3,length(stat));
        %parse torquer statuses
        for k=1:length(stat)
            s=stat_dat(stat{k});
            tstat(:,k)=reshape((s'-'+')/2,[],1);
        end
        
        %plot for torquer status
        s2=subplot(2,1,2);
        hold on;
        stairs(sn,2*tstat(stlen*(0)+1,:)+3,'r')
        stairs(sn,2*tstat(stlen*(0)+2,:)+6,'g')
        stairs(sn,2*tstat(stlen*(0)+3,:)+9,'b')
        stairs(sn,2*tstat(stlen*(0)+4,:)+12,'m')
        
        stairs(sn,2*tstat(stlen*(1)+1,:)+16,'r')
        stairs(sn,2*tstat(stlen*(1)+2,:)+19,'g')
        stairs(sn,2*tstat(stlen*(1)+3,:)+22,'b')
        stairs(sn,2*tstat(stlen*(1)+4,:)+25,'m')
        
        stairs(sn,2*tstat(stlen*(2)+1,:)+29,'r')
        stairs(sn,2*tstat(stlen*(2)+2,:)+32,'g')
        stairs(sn,2*tstat(stlen*(2)+3,:)+35,'b')
        stairs(sn,2*tstat(stlen*(2)+4,:)+39,'m')
        
        %stairs(sn,stat_index,'k');
        hold off;
        
        legend('X1','X2','X3','X4',...
               'Y1','Y2','Y3','Y4',...
               'Z1','Z2','Z3','Z4');
        %link subplots x-axis
        linkaxes([s1,s2],'x');
        %save plot
        fig_export('Z:\ADCS\figures\torqueCalTst-err-flips.eps');
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
        %restore old path
        path(oldpath);
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
    %restore old path
    path(oldpath);
end

function [stat]=stat_strip(line)
    sts=textscan(line,'%[+-?!?] %[+-!?] %[+-!?] %*d %*d %*d');  
    %get lengths of each status
    lx=length(sts{1});
    ly=length(sts{2});
    lz=length(sts{3});
    %check if status was read
    if(lx==0)
        error('Failed to parse status from line ''%s''',line);
    end
    %check lengths
    if(lx~=ly || ly~=lz)
        error('Inconsistant status lengths %i %i %i',lx,ly,lz);
    end
    %reformat status
    stat=sprintf('%s %s %s',sts{1},sts{2},sts{3});
end

function [dat]=stat_dat(line)
    sts=textscan(line,'%[+-?!?] %[+-!?] %[+-!?] %*d %*d %*d');  
    %get lengths of each status
    lx=length(sts{1});
    ly=length(sts{2});
    lz=length(sts{3});
    %check if status was read
    if(lx==0)
        error('Failed to parse status from line ''%s''',line);
    end
    %check lengths
    if(lx~=ly || ly~=lz)
        error('Inconsistant status lengths %i %i %i',lx,ly,lz);
    end
    stsx=reshape(char(sts{1}),1,[]);
    stsy=reshape(char(sts{2}),1,[]);
    stsz=reshape(char(sts{3}),1,[]);
    %reformat status
    dat=[stsx;stsy;stsz];
end

function [len]=stat_length(line)
    sts=textscan(line,'%[?!+-] %[+-!?] %[!?+-] %*d %*d %*d');
    %check for errors
    if(isempty(sts{1}) || isempty(sts{2}) || isempty(sts{3}))
        error('Failed to parse status from line ''%s''',line);
    end
    lx=length(sts{1}{:});
    ly=length(sts{2}{:});
    lz=length(sts{3}{:});
    %check if status was read
    if(lx==0)
        error('Failed to parse status from line ''%s''',line);
    end
    %make sure lenghts are consistant
    if(lx~=ly || ly~=lz)
        error('Inconsistant status lengths %i %i %i',lx,ly,lz);
    end
    len=lx;
end

function [tq,dir]=random_flip(stat)
    l=length(stat);
    tq=randi([0,l]);
    if tq==0
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

function statchk(stat)
    axis={'X','Y','Z'};
    for k=1:3
        err=strfind(stat(k,:),'!');
        if ~isempty(err)
            error('Error with %s-Axis torquer #%d.',axis{k},err(1));
        end
        err=strfind(stat(k,:),'?');
        if ~isempty(err)
            error('%s-Axis torquer #%d is uninitialized.',axis{k},err(1));
        end
    end
end


function idx=stat2Idx(stat,idx)
    %strip status info
    stat=stat_dat(stat);
    %check for torquer errors
    statchk(stat);
    %only include the z-axis
    idx=sum((('-'-stat(idx,:))/2).*2.^(0:3))+1;
end
