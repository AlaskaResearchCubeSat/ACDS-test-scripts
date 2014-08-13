function [I,B,t]=flipWaveform(com,Os_addr,axis,num,dir,inst_setup,baud)
    if(~exist('com','var') || isempty(com))
        com='COM3';
    end
    if ~exist('Os_addr','var') || isempty(Os_addr)
        %Os_addr=6;
        Os_addr='COM1';
    end
    if(~exist('axis','var') || isempty(axis))
        axis='X';
    end
    if(~exist('num','var') || isempty(num))
        num=1;
    end
    if(~exist('dir','var') || isempty(dir))
        dir='-';
    end
    if(~exist('baud','var') || isempty(baud))
        baud=57600;
    end
    if ~exist('inst_setup','var') || isempty(inst_setup)
        inst_setup=true;
    end
    mag_sens=3.125e-3;    %sensitivity of magnetomitor [V/G]
    %mag_offset=2.5;       %offset of magnetomitor [V]
    mag_offset=2.49;       %offset of magnetomitor [V]
    Gm=10e-3;               %Transconductance of current amplifier
    Rs=5e-3;                %sense resistor in ohms
    Ro=3e3;                 %output resistor in ohms
    cur_sens=1/(Gm*Rs*Ro);  %current sensor sensitivity
    VtoI=inline(['v*' num2str(cur_sens)],'v');
    VtoB=inline(['(v-' num2str(mag_offset) ')/' num2str(mag_sens)],'v');
    
    %filters for cleaning up outputs
    Ifilt=fir1(30,0.9);
    Bfilt=fir1(30,0.5);

    try
        %add functions from commandlib
        oldpath=addpath('Z:\Software\Libraries\commands\Matlab','-end');
        %check if a serial object was given instead of a port name
        if(isa(com,'serial'))
            %use already open port
            ser=com;
            %check for bytes in buffer
            bytes=ser.BytesAvailable;
            if(bytes~=0)
                %read all available bytes to flush buffer
                fread(ser,bytes);
            end
        else
            %open serial port
            ser=serial(com,'BaudRate',baud);
            %set timeout to 15s
            set(ser,'Timeout',15);
            %open port
            fopen(ser);
            %send ^C to close async
            fprintf(ser,'%c',3);  
            %connect to the ACDS board
            asyncOpen(ser,'ACDS');
            %initialize torquers
            command(ser,'reinit');
            waitReady(ser);
        end
        
        %check form of address
        if(isa(Os_addr,'char'))
            %string, open serial port
            Os_control=serial(Os_addr,'BaudRate',38400,'FlowControl','Hardware');
            %Os_control=serial(Os_addr,'BaudRate',57600,'FlowControl','Hardware');
            set(Os_control,'OutputBufferSize',1024);
            fopen(Os_control);
        %check if class is an open instrament control
        elseif(isa(Os_addr,'icinterface'))
            Os_control=Os_addr;
        else
            %otherwise open GPIB port
            Os_control=gpib('ni',0,Os_addr);
        end

        %clear stuff
        fprintf(Os_control,'*CLS');
        %in theory this could save time if mutiple runs are done
        if(inst_setup)
            %reset scope to factory settings and lock controls
            setup_str='*RST;:SYSTEM:LOCK ON;';
            setup_str=horzcat(setup_str,':TIM:MODE MAIN;');
            setup_str=horzcat(setup_str,':TIM:POS 0;');                %set time pos to zero (no offset)
            setup_str=horzcat(setup_str,':TIM:RANG 1e-3;');            %set timespan for data
            setup_str=horzcat(setup_str,':TIM:REF LEFT;');            %set time origin to left side of the screen

            setup_str=horzcat(setup_str,':TRIG:SWE NORM;');           %set trigger sweep mode to normal
            setup_str=horzcat(setup_str,':TRIG:MODE EDGE;');           %set to edge triggered
            setup_str=horzcat(setup_str,':TRIG:SOUR DIG9;');           %trigger off of d0
            setup_str=horzcat(setup_str,':TRIG:SLOP POS;');            %trigger on rising edge


            setup_str=horzcat(setup_str,':CHAN1:DISP ON;');            %Turn on CH1
            setup_str=horzcat(setup_str,':CHAN2:DISP ON;');            %Turn on CH2
            setup_str=horzcat(setup_str,':CHAN1:COUP DC;');            %DC couple CH1
            setup_str=horzcat(setup_str,':CHAN2:COUP DC;');            %DC couple CH2
            setup_str=horzcat(setup_str,':CHAN1:IMP ONEM;');           %High Impedance CH1
            setup_str=horzcat(setup_str,':CHAN2:IMP ONEM;');           %High Impedance CH2
            %setup_str=horzcat(setup_str,':CHAN1:LAB "Cur";');          %Label CH1
            %setup_str=horzcat(setup_str,':CHAN2:LAB "Field";');        %Label CH2
            %TODO: Verify Range
            setup_str=horzcat(setup_str,':CHAN2:PROBE 1;');             %Set attenuation to 1:1
            %setup_str=horzcat(setup_str,':CHAN1:RANG 4V;');            %Range for CH1
            %setup_str=horzcat(setup_str,':CHAN2:RANG 2V;');            %Range for CH2
            setup_str=horzcat(setup_str,':CHAN1:SCALE 500 mV;');            %Range for CH1
            setup_str=horzcat(setup_str,':CHAN2:SCALE 800 mV;');            %Range for CH2
            %TODO: find good offsets
            setup_str=horzcat(setup_str,':CHAN1:OFFS 1.8 V;');             %Offset for CH1
            setup_str=horzcat(setup_str,sprintf(':CHAN2:OFFS %E V;',mag_offset));           %Offset for CH2
            
            %Get Byte Order
            [~,~,e]=computer();
            if e=='B'
                %Big endian
                setup_str=horzcat(setup_str,':WAV:BYT MSBF;');
            else
                %Little endian
                setup_str=horzcat(setup_str,':WAV:BYT LSBF;');
            end

            %set output to signed
            setup_str=horzcat(setup_str,':WAV:UNS 0;');

            %set word output
            setup_str=horzcat(setup_str,':WAV:FORM WORD;');

            setup_str=horzcat(setup_str,':WAV:POIN 2000;');             %Set to maximum # of points
            %setup_str=horzcat(setup_str,':WAV:POIN MAX;');             %Set to
            %maximum # of points
            fprintf(Os_control,setup_str);
        end

        %set for single picture
        trig_single(Os_control);
        
        command(ser,'drive %s %d %c',axis,num,dir);
        
        %wait for trigger
        trig_wait(Os_control);
        
        %get data
        dat=get_chans(Os_control,{'CHAN1','CHAN2'});

        %run scope again to show waveforms
        fprintf(Os_control,'RUN');
        
        %convert from volts to current
        dat(2,:)=filter(Ifilt,1,VtoI(dat(2,:)));
        %convert from volts to magnetic field
        dat(3,:)=filter(Bfilt,1,VtoB(dat(3,:)));
        
        %find the start of time
        idx=find(dat(1,:)>-0.05e-3);
        
        if(nargout>0)
            subplot(2,1,2);
            plot(dat(1,idx)*1e3,dat(2,idx));
            ylabel('Current [A]');
            xlabel('Time [msec]');
            %set y-axis ticks to a reasonable value
            Itick=0:(round(max(dat(2,:))+0.9));
            set(gca,'YTick',Itick);
            set(gca,'Ylim',Itick([1,end]));
            %set x-axis limits
            set(gca,'Xlim',1e3*dat(1,idx([1,end])));
            %plot magnetic field
            subplot(2,1,1);
            plot(dat(1,idx)*1e3,dat(3,idx));
            ylabel('Magnetic Field [Gauss]');
            xlabel('Time [msec]');
            %set x-axis limits
            set(gca,'Xlim',1e3*dat(1,idx([1,end])));
            %save plot
            fig_export('Z:\ADCS\figures\flip-waveform.eps');
        end
        %if three output arguments given then split out dat
        if(nargout>=3)
            I=dat(2,idx);
            B=dat(3,idx);
            t=dat(1,idx);
        else
            %otherwise give as one array
            I=dat(:,idx);
        end
    catch err
        if exist('ser','var')
            record(ser,'off');
            if strcmp(ser.Status,'open') && ~isa(com,'serial')
                fclose(ser);
            end
            if(~isa(com,'serial'))
                delete(ser);
            end
        end
        %Close Scope communication if open
        if exist('Os_control','var') && ~isa(Os_addr,'icinterface')
            if strcmp(Os_control.Status,'open')
                %restore front pannel controls
                fprintf(Os_control,'SYSTEM:LOCK OFF');
                fclose(Os_control);
            end
            delete(Os_control);
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
            record(ser,'off');
            %check if port was open
            if(~isa(com,'serial'))
                %exit async connection
                asyncClose(ser);
                fclose(ser);
            end
        end
        %check if port was open
        if(~isa(com,'serial'))
            delete(ser);
        end
    end
    %Close Scope communication if open
    if exist('Os_control','var') && ~isa(Os_addr,'icinterface')
        if strcmp(Os_control.Status,'open')
            %restore front pannel controls
            fprintf(Os_control,'SYSTEM:LOCK OFF');
            fclose(Os_control);
        end
        delete(Os_control);
    end
    if exist('cc','var')
        delete(cc);
    end
    %restore old path
    path(oldpath);
end