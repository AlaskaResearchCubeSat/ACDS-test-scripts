function [B]=doubleFlip(mag_axis,tq_axis,tq_num,com,baud,gain,ADCgain)
    if(~exist('baud','var') || isempty(baud))
        baud=57600;
    end
    if(~exist('mag_axis','var') || isempty(mag_axis))
        mag_axis='';
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
    if (~exist('tq_num','var') || isempty(tq_num))
        tq_num=1;
    end
    if (~exist('tq_axis','var') || isempty(tq_axis))
        tq_axis=3;
    else
        if isa(tq_axis,'char')
            switch tq_axis
                case 'X'
                    tq_axis=1;
                case 'Y'
                    tq_axis=2;
                case 'Z'
                    tq_axis=3;
                otherwise
                    error('Unknown torquer axis ''%s''.',tq_axis);
            end
        else
            if size(tq_axis)~=1
                error('tq_axis must be a scalar.');
            end
            if tq_axis<1 || tq_axis>3
                error('Invalid value for tq_axis ''%s''.',tq_axis);
            end
        end
    end
    magScale=1/(65535*1e-3*gain*ADCgain);
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
        ser.RecordName='doubleFlip-debug.txt';
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
        pause(1);
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
        
        %set the ACDS to only print messages for errors
        fprintf(ser,'reinit');
        
        if ~waitReady(ser,30)
            error('Error : Could not communicate with prototype. Check connections');
        end       
        pause(1); 
        %exit async connection
        asyncClose(ser);

        %set field to zero
        cc.Bs=[0 0 0];
        
        num=10;
        os=50;
        B=zeros(2,num*os);
        
        dir='+'*ones(1,num);
        dir(1:4)=['+','-','+','-'];
        
        for k=1:num
            %connect to ACDS board
            asyncOpen(ser,'ACDS');
            pause(2);
            switch(tq_axis)
                case 1
                    tqx=tq_num;
                    %TODO: make direction changable
                    dirx=dir(k);
                    diry='';
                    tqy=0;
                    dirz='';
                    tqz=0;
                case 2
                    dirx='';
                    tqx=0;
                    %TODO: make direction changable
                    tqy=tq_num;
                    diry=dir(k);
                    dirz='';
                    tqz=0;
                case 3
                    dirx='';
                    tqx=0;
                    diry='';
                    tqy=0;
                    tqz=tq_num;
                    dirz=dir(k);
            end
            %torquer flip
            cmd=command(ser,'flip %c%i %c%i %c%i',dirx,tqx,diry,tqy,dirz,tqz);
            if ~waitReady(ser,30)
                error('Prototype not responding\n');
            end               
            %exit async connection
            asyncClose(ser);
            pause(1);
            for kk=1:os
                %tell prototype to take a single measurment
                command(ser,sprintf('mag single %s',mag_axis));
                pause(1);
                %read measurments from prototype
                line=fgetl(ser);
                try
                    lastwarn('');
                    dat=sscanf(line,'%i %i');
                    if(~isempty(lastwarn))
                        [warn,id]=lastwarn;
                        error(id,warn);
                    end
                    B(:,(k-1)*os+kk)=dat*magScale;
                catch err
                    fprintf(2,'Error : Could not parse measurments \"%s\"\n',line(1:end-1));
                    rethrow(err);
                end
            end
        end
        rng=reshape(ones(os,1)*(1:num)+linspace(0,0.4,os)'*ones(1,num),1,[]);
        figure(1);
        stairs(rng,B(1,:));
        xlabel('Flip Number');
        ylabel('Magnetic Field [Gauss]');
        Title('X Sensor');
        figure(2);
        stairs(rng,B(2,:));
        xlabel('Flip Number');
        ylabel('Magnetic Field [Gauss]');
        Title('Y Sensor');
        %add functions folder to path
        oldp=addpath('Z:\ADCS\functions');
        %save plot
        fig_export('Z:\ADCS\figures\soubleFlip.eps');
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
        %restore old path
        path(oldpath);
        rethrow(err);
    end
    if exist('ser','var')
        if strcmp(ser.Status,'open')
           %exit async connection
            asyncClose(ser);
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


