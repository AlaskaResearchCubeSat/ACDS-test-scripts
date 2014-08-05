function [field,bdot,Mcmd,torque]=bdot_test(com,baud,a)
    if(nargin<2)
        baud=57600;
    end
    if(nargin<1)
        com='COM3';
    end
    if(~exist('a','var') || isempty(a))
        %if no transform is given then use unity
        %coult use identity matrix but 1 is faster and will work
        a=1;
    else
        if size(a)~=[3 3]
            error('a must be a 3x3 matrix')
        end
    end
    
    %output sample rate
    T=0.5;
    %rotation rate of field
    rpm=2;
    %setup time
    time=0:T:(60/rpm-T);
    %stup theta
    theta=2*pi*time*rpm/60;
    %setup magnetic field
    Bs=0.3*[sin(theta);cos(theta);0*theta];

    lines=cell(1,50);
    
    try
        %add functions from commandlib
        oldpath=addpath('Z:\Software\Libraries\commands\Matlab','-end');
        cc=cage_control();
        cc.loadCal('calibration.cal');
        
        %setup timer for field sweep
        Btimer=timer('BusyMode','queue','ExecutionMode','fixedRate','Period',T,'TimerFcn',@(o,e)nextField(o,e,Bs,cc,a));
        
        %open serial port
        ser=serial(com,'BaudRate',baud);
        %set timeout to 15s
        set(ser,'Timeout',15);
        
        %setup recording for debugging
        ser.RecordName='tCalTst-debug.txt';
        ser.RecordMode='overwrite';
        ser.RecordDetail='verbose';
        
        %open port
        fopen(ser);
        %start recording
        record(ser,'on');

        %set terminator to CR/LF
        set(ser,'Terminator','LF');
        
        %exit async connection if open
        asyncClose(ser);
        pause(1)
        
        %connect to ACDS board
        asyncOpen(ser,'ACDS');
        %set to machine readable opperation
        fprintf(ser,'output machine');
        if ~waitReady(ser,30)
            error('Error : Could not communicate with prototype. Check connections');
        end
        
        pause(1);
        
        %set the ACDS to only print messages for errors
        fprintf(ser,'log error');
        
        if ~waitReady(ser,30)
            error('Error : Could not communicate with prototype. Check connections');
        end    

        %set initial field
        cc.Bs=a*Bs(:,1);
        
        %start algorithm
        command(ser,'mode 1');
        fgetl(ser)
        
        field=zeros(length(lines),3);
        bdot=zeros(length(lines),3);
        Mcmd=zeros(length(lines),3);
        torque=zeros(length(lines),3);
        
        %start timer
        start(Btimer);
        
        for k=1:length(lines)
            lines{k}=deblank(fgetl(ser));
            %fprintf('%s\n',lines{k});
            try
                data=textscan(lines{k},'M%d %f %f %f %f %f %f %f %f %f %s %s %s %d %d %d','ReturnOnError',false);
            catch err
                warning(err.identifier,err.message);
                field(k,:)=[NaN NaN NaN];
                bdot(k,:)=[NaN NaN NaN];
                Mcmd(k,:)=[NaN NaN NaN];
                torque(k,:)=[NaN NaN NaN];
                continue;
            end
            field(k,:)=[data{2:4}];
            bdot(k,:)=[data{5:7}];
            Mcmd(k,:)=[data{8:10}];
            torque(k,:)=[st2tq(data{11}),st2tq(data{12}),st2tq(data{13})];
        end
        
        %stop timer
        stop(Btimer);
        %delete timer
        delete(Btimer);
        
        
        figure;
        clf;
        
        M_cmd_lim=0.022;
        sn=1:length(lines);
        [x1,y1]=stairs(sn,M_cmd_lim*torque(:,1));
        [x2,y2]=stairs(sn,M_cmd_lim*torque(:,2));
        [x3,y3]=stairs(sn,M_cmd_lim*torque(:,3));
        
        subplot(4,1,1);
        plot(x1,y1,sn,Mcmd(:,1));
        xlabel('Sample Number');
        ylabel({'X-axis Dipole';'Moment [A m^2]'});
        legend('Drive','M_{cmd}');
        
        subplot(4,1,2);
        plot(x2,y2,sn,Mcmd(:,2));
        xlabel('Sample Number');
        ylabel({'Y-axis Dipole';'Moment [A m^2]'});
        legend('Drive','M_{cmd}');
        
        subplot(4,1,3);
        plot(x3,y3,sn,Mcmd(:,3));
        xlabel('Sample Number');
        ylabel({'Z-axis Dipole';'Moment [A m^2]'});
        legend('Drive','M_{cmd}');
        
        subplot(4,1,4);
        plot(sn,field(:,1),sn,field(:,2),sn,field(:,3));
        xlabel('Sample Number');
        ylabel('Magnetic Field [Gauss]');
        legend('X','Y','Z');

        %add functions folder to path
        oldp=addpath('Z:\ADCS\functions');
        
        %save plot
        fig_export('Z:\ADCS\figures\detumble-test.eps');
        %restore path
        path(oldp);
        
    catch err
        if exist('Btimer','var') && isvalid(Btimer)
            delete(Btimer);
        end
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
            %print Q to stop simulation
            fprintf(ser,'Q');
            while ser.BytesToOutput
            end
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

function nextField(obj,~,field,cc,a)
    idx=mod(obj.TasksExecuted,length(field))+1;
    if(~isnan(idx))
        cc.Bs=a*field(:,idx);
    end
end
    

function tq=st2tq(st)
    st=char(st);
    p=st=='+';
    m=st=='-';
    tq=sum(p-m);
end
