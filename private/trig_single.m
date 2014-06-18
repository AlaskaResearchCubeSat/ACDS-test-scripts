%set scope for single trigger and return when armed
function trig_single(obj)
    fprintf(obj,'*CLS');
    %set scope to trigger
    fprintf(obj,'RUN;:SING');

    %wait until trigger system is armed
    for k=1:10
        fprintf(obj,'AER?');
        line=fgetl(obj);
        armed=sscanf(line,'%d');
        if armed==1
            break;
        end
        pause(0.1);
    end
    if k==10
        %TODO: improve error reporting
        error('Not Armed');
    end
end