function multiflip(com,Os_addr,axis,num,dir,baud)
    if(~exist('com','var') || isempty(com))
        com='COM3';
    end
    if ~exist('Os_addr','var') || isempty(Os_addr)
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
    %close plots
    close all;
    mag_offset=2.49;       %offset of magnetomitor [V]
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

        dat=cell(1,15);
        Bfinal=zeros(1,length(dat));
        
        for k=1:length(dat)
            dat{k}=flipWaveform(ser,Os_control,axis,num,dir,false);
            Bfinal(k)=mean(dat{k}(3,(end-20):end));
        end
        
        
        %get unique file name
        savename=unique_fliename(fullfile('.','dat','multiflip.mat'));
        %save data
        save(savename);
        %generate plots from datafile
        multiflip_plot(savename);
        
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
           %exit async connection
            asyncClose(ser);
            record(ser,'off');
            %check if port was open
            if(~isa(com,'serial'))
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