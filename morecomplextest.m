function [xdat,ydat,zdat] = morecomplextest(com,baud)
    %test to calcualte torquer offsets for multiple boards and plot them on
    %a common set of axis
    if(~exist('baud','var') || isempty(baud))
        baud=57600;
        fprintf('Baud rate not specified using %i\n',baud);
    end
    if(~exist('com','var') || isempty(com))
        com='COM6';
        fprintf('Port not specified using %s\n',com);
    end
    ax_names={'X','Y','Z'};

    board_names={'X+','X-','Y+','Y-'};
    
    %AM or PM strings for time display
    ampm={'AM','PM'};

    a={[0 0 1;-1 0 0;0 1 0],[0 0 1;-1 0 0;0 -1 0],...
       [1 0 0;0 0 1;0 -1 0],[1 0 0;0 0 1;0 1 0]};

    gain={[1,64],[-95.3,1],[1,64],[1,64]};
    
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

    %TODO: pull from ACDS
    states=cell(1,length(table));

    cor=zeros(length(board_names),6);


    xdat=zeros(length(board_names),length(table));
    ydat=zeros(length(board_names),length(table));
    zdat=zeros(length(board_names),length(table));
    
    try
        %open serial port
        ser=serial(com,'BaudRate',baud);
       
        %set timeout to 5s
        set(ser,'Timeout',15);        %open port
        fopen(ser);
        
        %print ^C to exit async connection
        fprintf(ser,'%c',03);
        %check for bytes in buffer
        bytes=ser.BytesAvailable;
        if(bytes~=0)
            %read all available bytes to flush buffer
            fread(ser,bytes);
        end
        %set terminator to CR/LF
        set(ser,'Terminator','LF');
        %pause a bit
        pause(1);
        %flush buffer
        len=ser.BytesAvailable;
        if len~=0
            [~]=fread(ser,len);
        end
        %connect to ACDS board
        asyncOpen(ser,'ACDS');
        pause(1);  
        %only show error messages
        fprintf(ser,'log error');
        if ~waitReady(ser,30)
            error('Error : Could not communicate with prototype. Check connections');
        end
        pause(1);  
        %output data in machine readable mode
        fprintf(ser,'output machine');
        if ~waitReady(ser,30)
            error('Error : Could not communicate with prototype. Check connections');
        end
        pause(1);
        %initialize torquers to a known state
        fprintf(ser,'init');
        
        if ~waitReady(ser,30)
            error('Error : Could not communicate with prototype. Check connections');
        end
        
        %exit async connection
        asyncClose(ser);
            
        pause(1);
        
        cstart=fix(clock);
        fprintf('Starting Test at %i/%i %i:%02i:%02i\nSimulation Running Please Wait\n',cstart(2:6));

        %get start time to calculate elapsed time
        Tstart=tic();
        
        for kk=1:length(table)
            fprintf('Running Test %i of %i\n',kk,length(table));
            
            %reset offset
            off=zeros(3,length(board_names));
    
            for k=1:length(board_names)
                %calculate offset
                cor(k,:)=magSclCalc(board_names{k},ser,baud,gain{k}(1),gain{k}(2),a{k});
                %extract offset
                off(1:2,k)=cor(k,[3 6]);
                %convert to sattelite coordinates
                off(:,k)=a{k}*off(:,k);
            end
            %seperate offsets
            xdat(:,kk)=off(1,:);
            ydat(:,kk)=off(2,:);
            zdat(:,kk)=off(3,:);
            
            %save in case there are problems
            save('Z:\ADCS\figures\morecomplextest','xdat','ydat','zdat','states');
            
            pause(1);
            %connect to ACDS board
            asyncOpen(ser,'ACDS');
            pause(1);  
         
            %flip torquers
            fprintf(ser,'flip %c%i %c%i %c%i\n',table(kk,:));
            %read echoed line
            fgetl(ser);
            %get status line
            stline=fgetl(ser);
            %strip out status
            %sts=sscanf(stline,'B\t%s %s %s %*i %*i %*i',[3,4]);
            stsx=sscanf(stline,'B\t%[+-] %*[+-] %*[+-] %*i %*i %*i');
            stsy=sscanf(stline,'B\t%*[+-] %[+-] %*[+-] %*i %*i %*i');
            stsz=sscanf(stline,'B\t%*[+-] %*[+-] %[+-] %*i %*i %*i');
            %reformat status
            states{kk}=sprintf('%s  %s  %s',stsx,stsy,stsz);
            %wait for completion
            waitReady(ser,5);
            %print ^C to exit async connection
            asyncClose(ser); 
            
             %===[estimate completeion time]===
            %calculate done fraction
            df=kk/length(table);
            %get elapsed time
            Te=toc(Tstart);
            %calculate remaining time
            Tr=Te*(df^-1-1);
            %calculate completion estimate
            tcomp=clock+[0 0 0 0 0 Tr];
            %normalize completion estimate
            tcomp=fix(datevec(datenum(tcomp)));
            %get AM or PM
            AMPM_idx=(tcomp(4)>12)+1;
            if(AMPM_idx==2)
                tcomp(4)=tcomp(4)-12;
            end
            fprintf('Completion estimate : %i/%i %i:%02i %s\n',tcomp(2:5),ampm{AMPM_idx});
            
        end
        fprintf('Testing Complete\n');
    catch err
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
    %plot data
    subplot(3,1,1);
    plot(xdat');
    ax(1)=gca;
    legend(board_names{:});
   
    set(gca,'XTick',1:length(states));
    set(gca,'XTickLabel',[]);
    ylabel('X Field Offset');

    subplot(3,1,2);
    plot(ydat');
    ax(2)=gca;
    set(gca,'XTick',1:length(states));
    set(gca,'XTickLabel',[]);
    ylabel('Y Field Offset');

    subplot(3,1,3);
    plot(zdat');
    ax(3)=gca;
    set(gca,'XTick',1:length(states));
    
    set(gca,'XTickLabel',states)
    xlabel('Torquer Status');
    ylabel('Z Field Offset');
    linkaxes(ax,'x');
    
    axis('tight');
    
    rotateXLabels(gca,45);
    
    saveas(gcf(),['Z:\ADCS\figures\morecomplextest'],'fig');
    
    save('Z:\ADCS\figures\morecomplextest','xdat','ydat','zdat','states');
    
    
    
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
    %send ^C
    fprintf(sobj,03);
    %wait for completion
    waitReady(sobj,5);
    %print for debugging
    %fprintf('async Closed\n');
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