function torquer_fail(com,baud)
    %Flip torquers until an error is encountered. Connects to
    %ACDS board using async connection to sensor proxy
    if(~exist('baud','var') || isempty(baud))
        baud=57600;
    end
    if(~exist('com','var') || isempty(com))
        com='COM3';
    end
    try
        %open serial port
        ser=serial(com,'BaudRate',baud);
       
        %set timeout to 5s
        set(ser,'Timeout',5);        %open port
        fopen(ser);

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
        command(ser,'init');
        
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
            error('Prototype not responding\n');
        end
        stat=stat_dat(stat);
        %check for status errors
        statchk(stat);
        
        for k=1:80000
            fprintf('Num = %i\n',k);
            %flip a random torquer
            command(ser,'rndt');
            %wait for command to finish
            if ~waitReady(ser,30)
                error('Prototype not responding\n');
            end
            
            %get torquer status
            command(ser,'statcode');
            %read status
            stat=fgetl(ser);
            
            fprintf('%s',stat);
            %wait for command to finish
            if ~waitReady(ser,30)
                error('Prototype not responding\n');
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
        rethrow(err);
    end
    if exist('cc','var')
        delete(cc);
    end
    if exist('ser','var')
        if strcmp(ser.Status,'open')
            %print ^c to stop simulation
            fprintf(ser,'%c',03);
            while ser.BytesToOutput
            end
            fclose(ser);
        end
        delete(ser);
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
    %number of re-reads
    num=3;
    %number of retries
    ntry=2;
    while ~strcmp(cmd,line(1:end-1))
        num=num-1;
        if num<=0
            if ntry>0
                ntry=ntry-1;
                %reset number of reads
                num=3;
                %send command again
                fprintf(sobj,'%s\n',cmd);
            else
                error('Command ''%s'' failed. Echo : ''%s''',cmd,line(1:end-1));
            end
        end
        line=fgetl(sobj);
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

function asyncClose(sobj)
    %get number of bytes in buffer
    n=sobj.BytesAvailable;
    if(n)
        %read all bytes
        fread(sobj,n);
    end
    %send ^C
    fprintf(sobj,'%c',03);
    %wait for completion
    waitReady(sobj,5);
    %print for debugging
    %fprintf('async Closed\n');
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
