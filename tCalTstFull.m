function [flips,stat,stat_index]=tCalTstFull(mag_axis,cor,com,baud,gain,ADCgain,a)
    if(nargin<3)
        baud=57600;
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
    %setup magnetic field
    theta=linspace(0,2*pi,500);
    %Bs=1*[sin(theta);cos(theta);0*theta];
    %d=2;
    %ec=0.5;
    %Bs=0.1*[d./(1+ec*cos(theta)).*sin(theta);d./(1+ec*cos(theta)).*cos(theta);0*theta];

    Bs=0.3*(1.5-[1;1;0]*cos(10*theta)).*[sin(theta);cos(theta);0*theta];


    %theta=linspace(0,8*pi,300);
    %Bs=1/30*[theta.*sin(theta);theta.*cos(theta);0*theta];

    %allocate for sensor
    sensor=zeros(size(Bs));
    %allocate for prototype
    meas=zeros(size(Bs));
    
    Xc=zeros(1,length(Bs));
    Yc=zeros(1,length(Bs));

    flips=cell(floor(length(Bs)/10)+1,1);
    stat=cell(floor(length(Bs)/10)+1,1);
    stat_index=zeros(floor(length(Bs)/10)+1,3);

    try
        %add functions from commandlib
        oldpath=addpath('Z:\Software\Libraries\commands\Matlab','-end');
        cc=cage_control();
        cc.loadCal('calibration.cal');
        %open serial port
        ser=serial(com,'BaudRate',baud);
        %set terminator to CR/LF
        set(ser,'Terminator','LF');
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

        %print ^C to exit async connection
        asyncClose(ser)
        
        %set ADC gain for magnetomitor
        fprintf(ser,sprintf('gain %i',ADCgain));
        %get echoed line
        fgetl(ser);
        %get output line
        gs=deblank(fgetl(ser));
        %parse gain from result
        [gain,elm,err]=sscanf(gs,'ADC gain = %i');
        %make sure that gain is correct
        if(elm~=1 || ~isempty(err))
            error('Failed to parse ADC gain "%s" %s',gs,err);
        end
        if(ADCgain~=gain)
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
        
        %set the ACDS to only print messages for errors
        fprintf(ser,'log error');
        
        if ~waitReady(ser,30)
            error('Error : Could not communicate with prototype. Check connections');
        end
        pause(1);
        
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
            curOS=cor(3,:)+cor(3+idxX,:)+cor(3+16+idxY,:)+cor(3+2*16+idxZ,:);
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
                %get torquer status
                command(ser,'statcode');
                %get line for status
                stline=fgetl(ser);
                %save status
                stat{k/10+1}=stline(1:end-1);
                %parse status
                try
                    idxX=stat2Idx(stline,1);
                    idxY=stat2Idx(stline,2);
                    idxZ=stat2Idx(stline,3);
                    %save index
                    stat_index(k/10+1,:)=[idxX,idxY,idxZ];
                    %calculate offset
                    curOS=cor(3,:)+cor(3+idxX,:)+cor(3+16+idxY,:)+cor(3+2*16+idxZ,:);
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
        %create dat directory
        mkdir(fullfile('.','dat'));
        %get unique file name
        savename=unique_fliename(fullfile('.','dat','torqueCalTst.mat'));
        %save data
        save(savename,'-regexp','^(?!(cc|ser)$).');
        %generate plots from datafile
        tCalTstFull_plot(savename);
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

