function [dat]=make_cor_dat(cor,axis)
    if ~all(size(axis)==[1 2])
        error('Incorrect axis name length');
    end
    if ~any(axis(1)==['X' 'Y' 'Z'])
        error('Axis name must be "X" "Y" or "Z"');
    end
    if ~any(axis(2)==['+' '-'])
        error('Axis direction must be "+" or "-"');
    end
    dat=zeros(512,1,'uint8');
    dat(1:4)='COR ';
    dat(5:6)=axis;
    %correction scale values
    dat(7:14)=typecast(cast(cor(1:2,1),'single'),'uint8');
    dat(15:22)=typecast(cast(cor(1:2,2),'single'),'uint8');
    %base offset
    dat(23:26)=typecast(cast(cor(3,1),'single'),'uint8');
    dat(27:30)=typecast(cast(cor(3,2),'single'),'uint8');
    %offsets for each set of torquer states
    dat(31:222)=typecast(cast(cor(4:51,1),'single'),'uint8');
    dat(223:414)=typecast(cast(cor(4:51,2),'single'),'uint8');
    %calculate checksum for data
    check=mod(sum(dat(1:510)),2^16);
    dat(511:512)=typecast(cast(check,'uint16'),'uint8');
end