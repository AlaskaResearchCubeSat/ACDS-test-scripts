function dat=get_chans(obj,chans)
    if isa(chans,'cell')
        num_chans=length(chans);
    else
        num_chans=1;
    end
    for k=1:num_chans
        %set source to channel
        %fprintf(obj,'*CLS');
        fprintf(obj,sprintf('WAV:SOURCE %s',chans{k}));
        %fprintf(obj,sprintf('WAV:SOURCE %s;PREAMBLE?',chans{k}));
        fprintf(obj,'WAV:PREAMBLE?');
        preamble=fgetl(obj);
        preamble=sscanf(preamble,'%d,%d,%d,%d,%f,%f,%f,%f,%f,%d');
        %check input buffer for correct size
        if((get(obj,'InputBufferSize')+100)<preamble(3)*2+100)
            %temporarly close to change input buffer size
            fclose(obj);
            %set input buffer size
            set(obj,'InputBufferSize',preamble(3)*2+200);
            %set timeout to allow for input buffer to fil
            set(obj,'Timeout',obj.InputBufferSIze/obj.BaudRate+10);
            %reopen port with new input buffer
            fopen(obj);
        end
        switch preamble(1)
            case 0
                blkType='int8';
            case 1
                blkType='int16';
            case 2
                error('ASCII data type not supported')
            otherwise
                error('Unknown data type')
        end
        %get channel data
        fprintf(obj,'WAV:DATA?');
        %chan=get_block(obj,blkType);
        chan=get_block(obj,'int16');
        time=preamble(5)*(1:preamble(3)-preamble(7))+preamble(6);
        %time=1:length(chan);
        %TODO: figure out if this is correct
        chan=preamble(8)*(chan-preamble(10))+preamble(9);
        %TODO: check to make shure that times match?
        dat(1,:)=time';
        dat(k+1,:)=chan;
    end
end
