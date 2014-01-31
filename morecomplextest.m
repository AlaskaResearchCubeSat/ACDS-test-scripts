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

    cor=zeros(length(board_names),6);
    
    %current number of retries
    retry=0;
    
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
        %get torquer status
        fprintf(ser,'statcode');
        %get echoed line
        fgetl(ser);
        %get status line
        stline=fgetl(ser); 
        %strip out status
        stdat=stat_dat(stline);
        stlen=stat_length(stline);
        
        initial=stdat;
        
        tmp=(initial-'+')/2+'0';
        tmp=tmp(:,end:-1:1);
        tmp=char(reshape(tmp',1,[]));
        
        if 0
            %generate table for all states
            %generate status table from graycode values
            stable=graycode(3*stlen);
            %find starting index
            k=find(all(char(ones(length(stable),1)*tmp)==stable,2));
            %rotate table so that k is first
            stable=stable(mod((k:(k+length(stable)))-1,length(stable))+1,:);
        else
            %generate a table for only flipping Z-axis torquers
            %generate partial status table from graycode values
            stable=graycode(stlen);
            %find starting index
            k=find(all(char(ones(length(stable),1)*tmp(1:4))==stable,2));
            %rotate table so that k is first
            stable=stable(mod((k:(k+length(stable)))-1,length(stable))+1,:);
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
        
        states=cell(1,length(table));

        %exit async connection
        asyncClose(ser);
            
        pause(1);
        
        %acceptable error level
        good_err=0.010;
        %maximum number of retries
        max_retry=5;
        
        %initialize data arrays
        xdat=zeros(length(board_names),length(table));
        ydat=zeros(length(board_names),length(table));
        zdat=zeros(length(board_names),length(table));
        
        cstart=fix(clock);
        fprintf('Starting Test at %i/%i %i:%02i:%02i\nSimulation Running Please Wait\n',cstart(2:6));

        %get start time to calculate elapsed time
        Tstart=tic();
        
        for kk=1:length(table)
            fprintf('Running Test %i of %i\n',kk,length(table));
            
            %reset offset
            off=zeros(3,length(board_names));
    
            for k=1:length(board_names)
                %force entry into the loop
                erms=Inf;
                %re run the test until the error is low but don't allow too
                %many failed tests
                while(erms>good_err)
                    %calculate offset
                    [cor(k,:),erms]=magSclCalc(board_names{k},ser,baud,gain{k}(1),gain{k}(2),a{k});%check error for problems
                    
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
            
            %get torquer status
            fprintf(ser,'statcode');
            %get echoed line
            fgetl(ser);
            %get status line
            stline=fgetl(ser); 
            %strip out status
            states{kk}=stat_strip(stline);
            
            %flip torquers
            fprintf(ser,'flip %c%i %c%i %c%i\n',table(kk,:));
            %read echoed line
            fgetl(ser);
            %get status line
            stline=fgetl(ser) 
            %check if state changed
            if(any(table(kk,2:2:6)) && all(stat_strip(stline)==states{kk}))
                error('Torquer Flip Failed')
            end
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
        fprintf('Total Number of retries %i\n',retry);
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
    fprintf('Total Number of retries %i\n',retry);
    
    clf;
    %plot data
    subplot(4,1,1);
    plot(xdat');
    ax(1)=gca;
    legend(board_names{:});
   
    set(gca,'XTick',1:length(states));
    set(gca,'XTickLabel',[]);
    ylabel('X Field Offset');
    set(gca(),'XGrid','on')

    subplot(4,1,2);
    plot(ydat');
    ax(2)=gca;
    set(gca,'XTick',1:length(states));
    set(gca,'XTickLabel',[]);
    ylabel('Y Field Offset');
    set(gca(),'XGrid','on')

    subplot(4,1,3);
    plot(zdat');
    ax(3)=gca;
    set(gca,'XTick',1:length(states));
    
    set(gca,'XTickLabel',[])
    xlabel('Torquer Status');
    ylabel('Z Field Offset');
    set(gca(),'XGrid','on');
    
    subplot(4,1,4);
    %initialized status plot data
    stp=zeros(length(states),stlen);
    %strip out Z - axis status data
    for k=1:length(states)
        dat=stat_dat(states{k});
        stp(k,:)=dat(3,:);
    end
    %convert to numerical values and offset each line
    stp=((1:stlen)'*ones(1,length(states)))'+0.4*(1-(stp-'+'));
    
    
    stairs(stp);
    ax(4)=gca;
    set(gca,'XTick',1:length(states));
    
    set(gca,'XTickLabel',states);
    set(gca,'YTick',1:stlen);
    xlabel('Torquer Status');
    ylabel('Torquer States');
    set(gca(),'XGrid','on');
    
    linkaxes(ax,'x');
    
    axis('tight');
    %set limits for torquer states plot
    set(gca,'Ylim',[0 5])
    
    rotateXLabels(gca,45);
    
    
    saveas(gcf(),['Z:\ADCS\figures\morecomplextest'],'fig');
    
    save('Z:\ADCS\figures\morecomplextest','xdat','ydat','zdat','states');
    
    
    
end

function [stat]=stat_strip(line)
    stsx=sscanf(line,'%[+-] %*[+-] %*[+-] %*i %*i %*i');
    stsy=sscanf(line,'%*[+-] %[+-] %*[+-] %*i %*i %*i');
    stsz=sscanf(line,'%*[+-] %*[+-] %[+-] %*i %*i %*i');
    %get lengths of each status
    lx=length(stsx);
    ly=length(stsy);
    lz=length(stsz);
    %check if status was read
    if(lx==0)
        error('Failed to parse status from line ''%s''',line);
    end
    %check lengths
    if(lx~=ly || ly~=lz)
        error('Inconsistant status lengths %i %i %i',lx,ly,lz);
    end
    %reformat status
    stat=sprintf('%s  %s  %s',stsx,stsy,stsz);
end

function [dat]=stat_dat(line)
    stsx=sscanf(line,'%[+-] %*[+-] %*[+-] %*i %*i %*i');
    stsy=sscanf(line,'%*[+-] %[+-] %*[+-] %*i %*i %*i');
    stsz=sscanf(line,'%*[+-] %*[+-] %[+-] %*i %*i %*i');
    %get lengths of each status
    lx=length(stsx);
    ly=length(stsy);
    lz=length(stsz);
    %check if status was read
    if(lx==0)
        error('Failed to parse status from line ''%s''',line);
    end
    %check lengths
    if(lx~=ly || ly~=lz)
        error('Inconsistant status lengths %i %i %i',lx,ly,lz);
    end
    stsx=reshape(stsx,1,[]);
    stsy=reshape(stsy,1,[]);
    stsz=reshape(stsz,1,[]);
    %reformat status
    dat=[stsx;stsy;stsz];
end
function [len]=stat_length(line)
    lx=length(sscanf(line,'%[+-] %*[+-] %*[+-] %*i %*i %*i'));
    ly=length(sscanf(line,'%*[+-] %[+-] %*[+-] %*i %*i %*i'));
    lz=length(sscanf(line,'%*[+-] %*[+-] %[+-] %*i %*i %*i'));
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
    
