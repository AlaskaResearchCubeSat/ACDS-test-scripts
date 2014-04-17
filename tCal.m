function [cor,erms]=tCal(mag_axis,tq_axis,com,baud,gain,ADCgain,a)
    %calibrate torquers and magnetomitor using helmholtz cage. Connects to
    %ACDS board using async connection to sensor proxy
    if(~exist('baud','var') || isempty(baud))
        baud=57600;
    end
    if(~exist('com','var') || isempty(com))
        com='COM3';
    end
    if(~exist('mag_axis','var') || isempty(mag_axis))
        mag_axis='';
    end
    if (~exist('gain','var') || isempty(gain))
        gain=1;
    end
    if (~exist('ADCgain','var') || isempty(ADCgain))
        ADCgain=64;
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
    magScale=1/(2*65535*1e-3*gain*ADCgain);
    try
        cc=cage_control();
        cc.loadCal('calibration.cal');
        %open serial port
        ser=serial(com,'BaudRate',baud);
        
        %setup recording for debugging
        ser.RecordName='tCal-debug.txt';
        ser.RecordMode='overwrite';
        ser.RecordDetail='verbose';
       
        %set timeout to 5s
        set(ser,'Timeout',5);        %open port
        fopen(ser);
        %start recording
        record(ser,'on');

        %disable terminator
        set(ser,'Terminator','');
        %print ^C to exit async connection
        fprintf(ser,03);
        %set terminator to CR/LF
        set(ser,'Terminator','LF');
        
         %set ADC gain for magnetomitor
        command(ser,'gain %i',ADCgain);
        %get output line
        gs=fgetl(ser);
        %make sure that gain is correct
        if(ADCgain~=sscanf(gs,'ADC gain = %i'))
            error('Failed to set ADC gain to %i',ADCgain);
        end
        if ~waitReady(ser,10)
            error('Could not communicate with prototype. Check connections');
        end
        
        %set to machine readable opperation
        %command(ser,'output machine');
        %connect to ACDS board
        asyncOpen(ser,'ACDS');
        %only show error messages
        command(ser,'log error');
        if ~waitReady(ser,30)
            error('Error : Could not communicate with prototype. Check connections');
        end
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
        
        %get status line
        stline=fgetl(ser); 
        %strip out status
        stdat=stat_dat(stline);
        stlen=stat_length(stline);
        
        initial=stdat;
        
        %check for torquer errors
        statchk(stdat);
        
        tmp=(initial-'+')/2+'0';
        tmp=tmp(:,end:-1:1);
        tmp=char(reshape(tmp',1,[]));
        
        %generate a table for only flipping torquers in the given axis
        %generate partial status table from graycode values
        stable=graycode(stlen);
        %find starting index
        k=find(all(char(ones(length(stable),1)*tmp(((stlen*(3-tq_axis)):(stlen*(4-tq_axis)-1))+1))==stable,2));
        %rotate table so that k is first
        stable=stable(mod((k:(k+length(stable)))-1,length(stable))+1,:);
        switch tq_axis
            case 1
                %X-axis
                %add extra status bits
                stable=[ones(length(stable),1)*tmp(1:8),stable];
            case 2
                %Y-axis
                %add extra status bits
                stable=[ones(length(stable),1)*tmp(1:4),stable,ones(length(stable),1)*tmp(9:12)];
            case 3
                %Z-axis
                %add extra status bits
                stable=[stable,ones(length(stable),1)*tmp(5:12)];
        end
        
        %initialize flip table
        table=zeros(length(stable),6);
        
        for k=1:length(table)
            if(k==length(table))
                %wrap around so we end up back where we started
                flip=stable(k,end:-1:1)-stable(1,end:-1:1);
            else
                %find which torquers flipped
                flip=stable(k,end:-1:1)-stable(k+1,end:-1:1);
            end
            for kk=0:2
                idx=find(flip((1:stlen)+kk*stlen));
                if(isempty(idx))
                    %no flip needed fill table with null flip
                    table(k,kk*2+1)=' ';
                    table(k,kk*2+2)=0;
                elseif(length(idx)==1)
                    %flip needed get direction
                    if(flip(kk*stlen+idx)==-1)
                        %flip in negitave direction
                        table(k,kk*2+1)='-';
                    elseif(flip(kk*stlen+idx)==1)
                        %flip in positive direction
                        table(k,kk*2+1)='+';
                    else
                        %error unknown v
                        error('Error In state table: could not filp from ''%s'' to ''%s''',stable(k,end:-1:1),stable(k+1,end:-1:1));
                    end
                    %set index
                    table(k,kk*2+2)=idx;
                else
                    %attempt to flip multiple torquers in one axis
                    error('Error In state table: imposible combination');
                end
            end
        end
        
        %nstable=zeros(length(stable),3*(stlen+1));
        %convert stable to char representation
        %for k=1:length(stable)
        %    nstable(k,:)=sprintf(char(reshape([reshape(('%c')'*ones(1,stlen),1,[]) ' ']'*ones(1,3),1,[])),(stable(k,end:-1:1)'-'0')*2+'+');
        %end
        %stable=nstable(:,1:end-1);
        %print out stable for debugging
        %for k=1:length(stable)
        %    fprintf('%s\n',stable(k,:));
        %end
        
        %print out table for debugging
        %fprintf('flip %c%i %c%i %c%i\n',table');
        
        %theta=linspace(0,2*pi,60);

        %Bs=0.5*[sin(theta);cos(theta);0*theta];
        
        %theta=linspace(0,8*pi,300);
        %Bs=1/30*[theta.*sin(theta);theta.*cos(theta);0*theta];
        
        %theta=linspace(0,8*pi,100);
        theta=linspace(0,8*pi,120);
        Bs=1/30*[theta.*sin(theta);theta.*cos(theta);0*theta];
        
        %allocate for sensor
        sensor=zeros(size(Bs).*[1 length(table)]);
        %allocate for prototype
        meas=zeros(size(Bs).*[1 length(table)]);
        
        %get torquer status
        command(ser,'statcode');
        %get status line
        stline=fgetl(ser); 
        
        %set index to initialized state
        idx=stat2Idx(stline,tq_axis);
        %check for error parsing stat
        if(isnan(idx))
            error('Failed to parse torquer status \"%s\"',stline);
        end
        
        save_idx=zeros(1,length(table));
        
        save_stat=cell(1,length(table));
        
        save_idx(1)=idx;
        
        save_stat{1}=stline;
        
        for kk=1:length(table)
            fprintf('Starting Calibration %i of %i\n',kk,length(table));
            %set initial field
            cc.Bs=a*Bs(:,1);
            %give extra settaling time
            pause(1);
            
            %exit async connection
            asyncClose(ser);
            
            pause(1);

            for k=1:length(Bs)
                cc.Bs=a*Bs(:,k);
                %pause to let the supply settle
                pause(0.01);
                %tell prototype to take a single measurment
                command(ser,'mag single %s',mag_axis);
                %make measurment using sensor
                sensor(:,k+(idx)*length(Bs))=inva*cc.Bm';
                %read measurments from prototype
                line=fgetl(ser);
                try
                    lastwarn('');
                    dat=sscanf(line,'%i %i');
                    if(~isempty(lastwarn))
                        [warn,id]=lastwarn;
                        error(id,warn);
                    end
                    meas(1:2,k+(idx)*length(Bs))=dat;
                catch err
                    fprintf(2,'Error : Could not parse \"%s\"\n',line(1:end-1));
                    rethrow(err);
                end
                %meas(1:2,k+(kk-1)*length(Bs))=dat;
                meas(3,k+(idx)*length(Bs))=0;
            end
            
            %connect to ACDS board
            asyncOpen(ser,'ACDS');
            %clear buffer
            if(ser.BytesAvailable)
                fread(ser,ser.BytesAvailable);
            end
            %flip a torquer
            command(ser,'flip %c%i %c%i %c%i',table(kk,:));
            %read status from prototype
            line=fgetl(ser);
            %plot data with old index
            rng=(((idx)*length(Bs)+1):((idx+1)*length(Bs)));
            plot(Bs(1,:),Bs(2,:),'r',magScale*meas(1,rng),magScale*meas(2,rng),'g');
            axis('equal');
            %parse index
            idx=stat2Idx(line,tq_axis);
            %save idx
            save_idx(kk+1)=idx;
            %save status
            save_stat{kk+1}=line;
            %check for error parsing stat
            if(isnan(idx))
                error('Failed to parse torquer status %s',line(1:end-1));
            end
            
            if ~waitReady(ser,30)
                error('Prototype not responding\n');
            end
            %beep to alert user
            beep;
        end
        %beep when done
        beep;
        pause(1);
        beep;
        %calculate correction values
        len=length(meas);
        tlen=length(table);
        A=[meas(1:2,:)',zeros(len,tlen)];
        for k=1:tlen
            rng=(1:length(Bs))+(k-1)*length(Bs);
            A(rng,2+k)=ones(length(Bs),1);
        end
        As=(A'*A)^-1*A';
        %Create Bs vector
        Bsv1=reshape((ones(tlen,1)*Bs(1,:))',1,[])';
        Bsv2=reshape((ones(tlen,1)*Bs(2,:))',1,[])';
        %calcualate correction values
        corx=As*Bsv1;
        cory=As*Bsv2;
        %calculate error
        erms=sqrt(sum(mean([Bsv1-A*corx,Bsv2-A*cory].^2)));
        cor=[corx cory];
    catch err
        if exist('cc','var')
            delete(cc);
        end
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
        fread(sobj,n);
    end
    %send ^C
    fprintf(sobj,'%c',03);
    %wait for completion
    waitReady(sobj,5);
    %print for debugging
    %fprintf('async Closed\n');
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

function idx=stat2Idx(stat,idx)
    %strip status info
    stat=stat_dat(stat);
    %check for torquer errors
    statchk(stat);
    %only include the z-axis
    idx=sum((('-'-stat(idx,:))/2).*2.^(0:3))+1;
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

function table=graycode(n)
    if(n<=0 || round(n)~=n)
        error('n must be a positive whole number');
    end
    if(n>20)
        error('That''''s a large n did you really want such a big graycode table?');
    end
    if(n==1)
        table=['0';'1'];
        return
    end
    table=graycode(n-1);
    tmp=table(end:-1:1,:);
    table=[['0'*ones(2^(n-1),1),table];['1'*ones(2^(n-1),1),tmp]];
end