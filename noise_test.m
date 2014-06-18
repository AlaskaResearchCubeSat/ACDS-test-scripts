function [p] = noise_test(mag_axis,com,baud,gain,ADCgain)
    %Run calibration multiple times to get variation
    if(~exist('mag_axis','var') || isempty(mag_axis))
        mag_axis='';
    end
    if(~exist('baud','var') || isempty(baud))
        baud=57600;
    end
    if(~exist('com','var') || isempty(com))
        com='COM3';
    end
    if (~exist('gain','var') || isempty(gain))
        gain=[];
    end
    if (~exist('ADCgain','var') || isempty(ADCgain))
        ADCgain=[];
    end
    try
        %add functions from commandlib
        oldpath=addpath('Z:\Software\Libraries\commands\Matlab','-end');
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
        %only show error messages
        
        %run for 20 iterations
        num=20;
        %init p array
        p=zeros(num,6);
        
        pause(1);
        
        cstart=fix(clock);
        fprintf('Starting Test at %i:%02i:%02i\nSimulation Running Please Wait\n',cstart(4:6));

        %get start time to calculate elapsed time
        Tstart=tic();
        
        for k=1:num
            pause(1);
            fprintf('Running Test %i of %i\n',k,num);
            
          
            %run a calibration
            p(k,:)=magSclCalc(mag_axis,ser,baud,gain,ADCgain);
            
          
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
     catch err
        if exist('cc','var')
            delete(cc);
        end
        if exist('ser','var')
            if strcmp(ser.Status,'open')
                %exit async connection
                asyncClose(ser);
                %close port
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
            while ser.BytesToOutput
            end
            fclose(ser);
        end
        delete(ser);
    end
    %restore old path
    path(oldpath);
end
