function status_fail(com,baud,num)
    %Get torquer status until an error is encountered. Connects to
    %ACDS board using async connection to sensor proxy
    if(~exist('baud','var') || isempty(baud))
        baud=57600;
    end
    if(~exist('com','var') || isempty(com))
        com='COM3';
    end
    if(~exist('num','var') || isempty(num))
        num=80000;
    end
    try
        %add functions from commandlib
        oldpath=addpath('Z:\Software\Libraries\commands\Matlab','-end');
        %open serial port
        ser=serial(com,'BaudRate',baud);
       
        %set timeout to 5s
        set(ser,'Timeout',5);        %open port
        
        %setup recording for debugging
        ser.RecordName='fail-debug.txt';
        ser.RecordMode='overwrite';
        ser.RecordDetail='verbose';
        
        fopen(ser);
        %start recording
        record(ser,'on');

        %disable terminator
        set(ser,'Terminator','');
        %print ^C to exit async connection
        fprintf(ser,03);
        %set terminator to CR/LF
        set(ser,'Terminator','LF');
        
        %connect to ACDS board
        asyncOpen(ser,'ACDS');
        %use machine readable output
        command(ser,'output machine');
        if ~waitReady(ser,30)
            error('Error : Could not communicate with prototype. Check connections');
        end
      
        %initialize torquers to a known state
        command(ser,'reinit');
        
        if ~waitReady(ser,30)
            error('Error : Could not communicate with prototype. Check connections');
        end
        
        %get torquer status
        command(ser,'statcode');
        %read status
        stat=fgetl(ser);
       
        fprintf('%s',stat);
        %wait for command to finish
        if ~waitReady(ser,30)
            error('Prototype not responding');
        end
        stat=stat_dat(stat);
        %check for status errors
        statchk(stat);
        
        for k=1:num
            fprintf('Num = %i\n',k);
            
            %get torquer status
            command(ser,'statcode');
            %read status
            stat=fgetl(ser);
            
            fprintf('%s',stat);
            %wait for command to finish
            if ~waitReady(ser,30)
                error('Prototype not responding');
            end
            
            stat=stat_dat(stat);
            %check for status errors
            statchk(stat);
        end
        
        %exit async connection
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
    if exist('cc','var')
        delete(cc);
    end
    if exist('ser','var')
        if strcmp(ser.Status,'open')
            %exit async connection
            asyncClose(ser);
            fclose(ser);
        end
        delete(ser);
    end
    %restore old path
    path(oldpath);
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
