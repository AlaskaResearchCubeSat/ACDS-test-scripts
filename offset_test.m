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
        
    %use fewer field points so it dosn't take so darn long
    theta=linspace(0,8*pi,100);
    Bs=1/30*[theta.*sin(theta);theta.*cos(theta);0*theta];
    %current number of retries
    retry=0;
    try
        %open serial port
        ser=serial(com,'BaudRate',baud);
       
        %set timeout to 15s
        set(ser,'Timeout',15);        %open port
        fopen(ser);

        %set terminator to LF
        set(ser,'Terminator','LF');
        %exit async connection
        asyncClose(ser);
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
        command(ser,'reinit');
        
        if ~waitReady(ser,30)
            error('Error : Could not communicate with prototype. Check connections');
        end
        
        %exit async connection
        asyncClose(ser);
            
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
        
        %acceptable error level
        %good_err=0.006;
        good_err=0.007;
        %maximum number of retries
        max_retry=15;
        
        for k=1:num
            
            fprintf('Running Test %i of %i\n',k,num);
            
            pause(1);
            %connect to ACDS board
            asyncOpen(ser,'ACDS');
            pause(1);  
            
            pause(1);
            %flip torquers to + state
            command(ser,'flip +%i +%i +%i',torquer);
            %wait for completion
            waitReady(ser,5);
            %exit async connection
            asyncClose(ser);
            
            %force entry into the loop
            erms=Inf;
            %re run the test until the error is low but don't allow too
            %many failed tests
            while(erms>good_err)
                %run a calibration
                [p(k,:),erms]=magSclCalc(mag_axis,ser,baud,gain,ADCgain,a,Bs,0.5);

                %check error for problems
                if(erms>good_err)
                    %check if maximum number of retries has been exceded
                    if(retry>max_retry)
                        %Throw an error, aborting the test
                        error('Large calibration error of %f. Number of retries exceded aborting.',erms);
                    else
                        %give a warning with the test error
                        warning('Large calibration error of %f. Redoing measurment.',erms);
                        %Beep to notify the user TODO: is this needed/usefull?
                        beep;
                    end
                    %increment number of retries
                    retry=retry+1;
                end
            end
            
            %connect to ACDS board
            asyncOpen(ser,'ACDS');
            pause(1); 
            %flip torquers to + state
            command(ser,'flip -%i -%i -%i',torquer);
            %wait for completion
            waitReady(ser,5);
            %print ^C to exit async connection
            fprintf(ser,03);
            %wait for completion
            waitReady(ser,5);
            
            %force entry into the loop
            erms=Inf;
            %re run the test until the error is low but don't allow too
            %many failed tests
            while(erms>good_err)
                %run a calibration
                [m(k,:),erms]=magSclCalc(mag_axis,ser,baud,gain,ADCgain,a,Bs,0.5);

                %check error for problems
                if(erms>good_err)
                    %check if maximum number of retries has been exceded
                    if(retry>max_retry)
                        %Throw an error, aborting the test
                        error('Large calibration error of %f. Number of retries exceded aborting.',erms);
                    else
                        %give a warning with the test error
                        warning('Large calibration error of %f. Redoing measurment.',erms);
                         %Beep to notify the user TODO: is this needed/usefull?
                        beep;
                    end
                    %increment number of retries
                    retry=retry+1;
                end
            end
            
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
               %exit async connection
                asyncClose(ser);
                %close port
                fclose(ser);
            end
            delete(ser);
        end
        fprintf('Total Number of retries %i\n',retry+1);
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
    fprintf('Total Number of retries %i\n',retry+1);
end
