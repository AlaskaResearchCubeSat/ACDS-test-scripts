function trig_wait(obj)
    for k=1:10
        fprintf(obj,'OPER?');
        line=fgetl(obj);
        reg=sscanf(line,'%d');
        run=bitand(reg,8);
        if ~run
            break;
        end
        pause(0.1);
    end

    if k==10
        error('Trigger Not reached');
    end
end