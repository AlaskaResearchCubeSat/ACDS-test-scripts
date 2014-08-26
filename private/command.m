function [cmd]=command(sobj,cmd,varargin)
    %first flush buffer    
    %get number of bytes in buffer
    n=sobj.BytesAvailable;
    if(n)
        %read all bytes
        fread(sobj,n,'char');
    end
    %generate command
    cmd=sprintf(cmd,varargin{:});
    %send command
    fprintf(sobj,'%s\n',cmd);
    %get line for echo
    line=fgetl(sobj);
    %number of re-reads
    num=3;
    %number of retries
    ntry=2;
    while ~strcmp(cmd,line(1:end-1))
        line(1:end-1)
        num=num-1;
        if num<=0
            if ntry>0
                ntry=ntry-1;
                %reset number of reads
                num=3;
                %send command again
                fprintf(sobj,'%s\n',cmd);
            else
                error('Command ''%s'' failed. Echo : ''%s''',cmd,line(1:end-1));
            end
        end
        line=fgetl(sobj);
    end
end