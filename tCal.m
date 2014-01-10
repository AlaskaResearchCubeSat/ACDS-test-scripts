function [cor,meas,Bs,tlen]=tCal(mag_axis,com,baud,gain,ADCgain)
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
    
    magScale=1/(2*65535*1e-3*gain*ADCgain);
    try
        cc=cage_control();
        cc.loadCal('calibration.cal');
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
        
        %set to machine readable opperation
        %fprintf(ser,'output machine');
        %connect to ACDS board
        fprintf(ser,'async ACDS');
        pause(1);
        %only show error messages
        fprintf(ser,'log error');
        if ~waitReady(ser,30)
            error('Error : Could not communicate with prototype. Check connections');
        end
        %use machine readable output
        fprintf(ser,'output machine');
        if ~waitReady(ser,30)
            error('Error : Could not communicate with prototype. Check connections');
        end
      
        %initialize torquers to a known state
        fprintf(ser,'init');
        
        if ~waitReady(ser,30)
            error('Error : Could not communicate with prototype. Check connections');
        end
        
        fprintf(ser,'flip -1 -1 -1');
        if ~waitReady(ser,30,true)
            error('Error : Could not communicate with prototype. Check connections');
        end
        fprintf(ser,'flip +2 +2 +2');
        if ~waitReady(ser,30,true)
            error('Error : Could not communicate with prototype. Check connections');
        end
        fprintf(ser,'flip +1 +1 +1');
        if ~waitReady(ser,30,true)
            error('Error : Could not communicate with prototype. Check connections');
        end
        fprintf(ser,'flip -2 -2 -2');
        if ~waitReady(ser,30,true)
            error('Error : Could not communicate with prototype. Check connections');
        end
        
        %theta=linspace(0,2*pi,60);

        %Bs=0.5*[sin(theta);cos(theta);0*theta];
        
        %theta=linspace(0,8*pi,300);
        %Bs=1/30*[theta.*sin(theta);theta.*cos(theta);0*theta];
        
        %theta=linspace(0,8*pi,100);
        theta=linspace(0,8*pi,120);
        Bs=1/30*[theta.*sin(theta);theta.*cos(theta);0*theta];
        
        
        p='+';
        m='-';
        z='0';
        table=[                     %+- +- +- 
               p 2 z 0 z 0;         %++ +- +-
               m 1 z 0 z 0;         %-+ +- +-
               m 2 z 0 z 0;         %-- +- +-
               p 1 p 2 z 0;         %+- ++ +-
                
               p 2 z 0 z 0;         %++ ++ +-
               m 1 z 0 z 0;         %-+ ++ +-
               m 2 z 0 z 0;         %-- ++ +-
               p 1 m 1 z 0;         %+- -+ +-
               
               p 2 z 0 z 0;         %++ -+ +-
               m 1 z 0 z 0;         %-+ -+ +-
               m 2 z 0 z 0;         %-- -+ +-
               p 1 m 2 z 0;         %+- -- +-
               
               p 2 z 0 z 0;         %++ -- +-
               m 1 z 0 z 0;         %-+ -- +-
               m 2 z 0 z 0;         %-- -- +-
               p 1 p 1 p 2;         %+- +- ++
               
               
               p 2 z 0 z 0;         %++ +- ++
               m 1 z 0 z 0;         %-+ +- ++
               m 2 z 0 z 0;         %-- +- ++
               p 1 p 2 z 0;         %+- ++ ++
               
               p 2 z 0 z 0;         %++ ++ ++
               m 1 z 0 z 0;         %-+ +- ++
               m 2 z 0 z 0;         %-- +- ++
               p 1 m 1 z 0;         %+- -+ ++
               
               p 2 z 0 z 0;         %++ -+ ++
               m 1 z 0 z 0;         %-+ -+ ++
               m 2 z 0 z 0;         %-- -+ ++
               p 1 m 2 z 0;         %+- -- ++
               
               p 2 z 0 z 0;         %++ -- ++ 
               m 1 z 0 z 0;         %-+ -- ++
               m 2 z 0 z 0;         %-- -- ++
               p 1 p 1 m 1;         %+- +- -+
               
               
               p 2 z 0 z 0;         %++ +- -+
               m 1 z 0 z 0;         %-+ +- -+
               m 2 z 0 z 0;         %-- +- -+
               p 1 p 2 z 0;         %+- ++ -+
               
               p 2 z 0 z 0;         %++ ++ -+
               m 1 z 0 z 0;         %-+ ++ -+
               m 2 z 0 z 0;         %-- ++ -+
               p 1 m 1 z 0;         %+- -+ -+
               
               p 2 z 0 z 0;         %++ -+ -+
               m 1 z 0 z 0;         %-+ -+ -+
               m 2 z 0 z 0;         %-- -+ -+
               p 1 m 2 z 0;         %+- -- -+
               
               p 2 z 0 z 0;         %++ -- -+
               m 1 z 0 z 0;         %-+ -- -+
               m 2 z 0 z 0;         %-- -- -+
               p 1 p 1 m 2;         %+- +- --
               
               
               p 2 z 0 z 0;         %++ +- --
               m 1 z 0 z 0;         %-+ +- --
               m 2 z 0 z 0;         %-- +- --
               p 1 p 2 z 0;         %+- ++ --
               
               p 2 z 0 z 0;         %++ ++ --
               m 1 z 0 z 0;         %-+ ++ --
               m 2 z 0 z 0;         %-- ++ --
               p 1 m 1 z 0;         %+- -+ --
               
               p 2 z 0 z 0;         %++ -+ --
               m 1 z 0 z 0;         %-+ -+ --
               m 2 z 0 z 0;         %-- -+ --
               p 1 m 2 z 0;         %+- -- --
               
               p 2 z 0 z 0;         %++ -- --
               m 1 z 0 z 0;         %-+ -- --
               m 2 z 0 z 0;         %-- -- --
               p 1 p 1 p 1;         %+- +- +-
               
               ];
             
        %allocate for sensor
        sensor=zeros(size(Bs).*[1 length(table)]);
        %allocate for prototype
        meas=zeros(size(Bs).*[1 length(table)]);
        
        %set index to initialized state
        idx=stat2Idx('B +- +- +- 0 0 0');
        %check for error parsing stat
        if(isnan(idx))
            error('Failed to parse torquer status B +- +- +- 0 0 0');
        end
           
        for kk=1:length(table)
            fprintf('Starting Calibration %i of %i\n',kk,length(table));
            %set initial field
            cc.Bs=Bs(:,1);
            %give extra settaling time
            pause(1);
            
            %print ^C to exit async connection
            fprintf(ser,03);
            %clear buffer
            fgetl(ser);
            fgetl(ser);

            for k=1:length(Bs)
                cc.Bs=Bs(:,k);
                %pause to let the supply settle
                pause(0.01);
                %tell prototype to take a single measurment
                fprintf(ser,sprintf('mag single %s',mag_axis));
                %make measurment using sensor
                sensor(:,k+(idx)*length(Bs))=cc.Bm';
                %read echoed line
                fgetl(ser);
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
            fprintf(ser,'async ACDS');
            %wait a bit
            pause(1);
            %clear buffer
            if(ser.BytesAvailable)
                fread(ser,ser.BytesAvailable);
            end
            %flip a torquer
            fprintf(ser,'flip %c%i %c%i %c%i\n',table(kk,:));
            %read echoed line
            fgetl(ser);
            %read status from prototype
            line=fgetl(ser);
            %plot data with old index
            rng=(((idx)*length(Bs)+1):((idx+1)*length(Bs)));
            plot(Bs(1,:),Bs(2,:),'r',magScale*meas(1,rng),magScale*meas(2,rng),'g');
            axis('equal');
            %parse index
            idx=stat2Idx(line);
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
        corx=As*(reshape((ones(tlen,1)*Bs(1,:))',1,[])');
        cory=As*(reshape((ones(tlen,1)*Bs(2,:))',1,[])');
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
            %print Q to stop simulation
            fprintf(ser,'Q');
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