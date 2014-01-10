function [p,m] = offset_test(mag_axis,com,baud,torquer,gain,ADCgain,a)
    %flip a given torquer multiple times and calibrate after each flip to
    %see how repeatable the torquer offsets are
    if(~exist('mag_axis','var') || isempty(mag_axis))
        mag_axis='';
    end
    if(~exist('baud','var') || isempty(baud))
        baud=57600;
    end
    if(~exist('com','var') || isempty(com))
        com='COM3';
    end
    if(~exist('torquer','var') || isempty(torquer))
        torquer=[0 0 1];
    end
    if (~exist('gain','var'))
        gain=[];
    end
    if (~exist('ADCgain','var'))
        ADCgain=[];
    end
    if (~exist('a','var'))
        a=[];
    end
    try
        %open serial port
        ser=serial(com,'BaudRate',baud);
       
        %set timeout to 5s
        set(ser,'Timeout',15);        %open port
        fopen(ser);

        %disable terminator
        set(ser,'Terminator','');
        %print ^C to exit async connection
        fprintf(ser,03);
        %set terminator to CR/LF
        set(ser,'Terminator','LF');
        %connect to ACDS board
        asyncOpen(ser,'ACDS');
        pause(1);  
        %only show error messages
        fprintf(ser,'log error');
        if ~waitReady(ser,30)
            error('Error : Could not communicate with prototype. Check connections');
        end
        pause(1);
        %initialize torquers to a known state
        fprintf(ser,'init');
        
        if ~waitReady(ser,30)
            error('Error : Could not communicate with prototype. Check connections');
        end
        
        %print ^C to exit async connection
        fprintf(ser,03);
            
        %run for 10 iterations
        num=20;
        %init p array
        p=zeros(num,6);
        %init m array
        m=zeros(num,6);
        
        pause(1);
        
        cstart=fix(clock);
        fprintf('Starting Test at %i:%02i:%02i\nSimulation Running Please Wait\n',cstart(4:6));

        %get start time to calculate elapsed time
        Tstart=tic();
        
        for k=1:num
            
            fprintf('Running Test %i of %i\n',k,num);
            
            pause(1);
            %connect to ACDS board
            asyncOpen(ser,'ACDS');
            pause(1);  
            
            pause(1);
            %flip torquers to + state
            fprintf(ser,'flip +%i +%i +%i\n',torquer);
            %wait for completion
            waitReady(ser,5);
            %print ^C to exit async connection
            fprintf(ser,03);
            %wait for completion
            waitReady(ser,5);
            
            %run a calibration
            p(k,:)=magSclCalc(mag_axis,ser,baud,gain,ADCgain,a);
            
            %connect to ACDS board
            asyncOpen(ser,'ACDS');
            pause(1); 
            %flip torquers to + state
            fprintf(ser,'flip -%i -%i -%i\n',torquer);
            %wait for completion
            waitReady(ser,5);
            %print ^C to exit async connection
            fprintf(ser,03);
            %wait for completion
            waitReady(ser,5);
            
            %run a calibration
            m(k,:)=magSclCalc(mag_axis,ser,baud,gain,ADCgain);
            
            %===[estimate completeion time]===
            %calculate done fraction
            df=k/num;
            %get elapsed time
            Te=toc(Tstart);%get remaining time
            %calculate remaining time
            Tr=Te*(df^-1-1);
            %calculate completion estimate
            tcomp=clock+[0 0 0 0 0 Tr];
            %normalize completion estimate
            tcomp=fix(datevec(datenum(tcomp)));
            %get AM or PM
            %AM=tcomp(4)>12;
            %tcomp(4)=mod(tcomp(4),12);
            %print new completion estimate
            fprintf('Completion Estimate : %i:%02i\n',tcomp(4:5));
            
        end
        
        fprintf('Testing Complete\n');
        %print ^C to exit async connection
        fprintf(ser,03);
        
        %create new figure
        figure(1);
        %clear figure
        clf;
        %Titles for each plot
        titles={'C_1','C_2','C_3','C_4','C_5','C_6'};
        %lables for y-axis
        ylab={'Gauss/count','Gauss/count','Gauss','Gauss/count','Gauss/count','Gauss'};
        %make box plots
        for k=1:6
            %select plot
            subplot(1,6,k);
            %boxplot
            boxplot([p(:,k),m(:,k)],{'+','-'});
            %set title
            title(titles{k});
            %set y-axis label
            ylabel(ylab{k});
        end
        %create new figure
        figure(2);
        %clear figure
        clf;
        %lables for y-axis
        ylab={'C_1 [Gauss/count]','C_2 [Gauss/count]','C_3 [Gauss]','C_4 [Gauss/count]','C_5 [Gauss/count]','C_6 [Gauss]'};
        %generate run number vector
        n=1:length(m(:,1));
        %make box plots
        for k=1:6
            %select plot
            subplot(6,1,k);
            %boxplot
            plot(n,p(:,k),n,m(:,k));
            %add legend
            legend('+','-');
            %set title
            title(titles{k});
            %set y-axis label
            ylabel(ylab{k});
            %set x-axis label
            xlabel('Run Number');
        end
        
     catch err
        if exist('cc','var')
            delete(cc);
        end
        if exist('ser','var')
            if strcmp(ser.Status,'open')
                %print ^C to exit async connection
                fprintf(ser,03);
                %close port
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
            %print ^C to exit async connection
            fprintf(ser,03);
            while ser.BytesToOutput
            end
            fclose(ser);
        end
        delete(ser);
    end
end

function asyncOpen(sobj,sys)
    %wmsg='async open use ^C to force quit';
    wmsg='Using Address 0x12';
    fprintf(sobj,'async %s\n',sys);
    msg=[];
    fgetl(sobj);
    while ~strncmp(wmsg,msg,length(wmsg))
        msg=fgetl(sobj);
        if(strncmpi('Error',msg,length('Error')))
            error(msg);
        end
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

