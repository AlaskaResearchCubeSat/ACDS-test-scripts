function asyncOpen(sobj,sys,output)
    %no output if argument not given
    if nargin<3
        output=false;
    end
    %set timeout to 5 tries
    timeout = 5;
    %success message to look for
    wmsg='Using Address ';
    %unknown command message
    umsg='unknown command ''async''';
    %send command
    m=command(sobj,'async %s',sys);
    %output message if requested
    if output
        fprintf('%s',m);
    end
    msg=[];
    %wait for success message
    while ~strncmp(wmsg,msg,length(wmsg)) && timeout>0
        %get a line
        msg=fgetl(sobj);
        %output line if requested
        if output
            fprintf('%s',msg);
        end
        %check if message is an error
        if(strncmpi('Error',msg,length('Error')))
            %clear remaining lines
            waitReady(sobj);
            %throw error
            error('Error while opening async connection ''%s''',msg);
        end
        %check if message is unknown command
        if(strncmp(umsg,msg,length(umsg)))
            %clear remaining lines
            waitReady(sobj);
            %throw error
            error('async command not avaliable on microcontroller');
        end
        %update timeout
        timeout=timeout-1;
    end
end