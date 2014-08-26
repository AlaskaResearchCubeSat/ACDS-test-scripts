function asyncClose(sobj)
    %get number of bytes in buffer
    n=sobj.BytesAvailable;
    if(n)
        %read all bytes
        fread(sobj,n);
    end
    %send ^C
    fprintf(sobj,'%c',03);
    %wait for completion
    waitReady(sobj,5);
end