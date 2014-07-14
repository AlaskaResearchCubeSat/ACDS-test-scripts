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
    tmp=zeros(102,1,'single');
    dat(1:4)='COR ';
    dat(5:6)=axis;
    %correction scale values
    tmp(1:2)=cast(cor(1:2,1),'single');
    tmp(3:4)=cast(cor(1:2,2),'single');
    %base offset
    tmp(5)=cast(cor(3,1),'single');
    tmp(6)=cast(cor(3,2),'single');
    %offsets for each set of torquer states
    tmp(7:54)=cast(cor(4:51,1),'single');
    tmp(55:102)=cast(cor(4:51,2),'single');
    %testing put consectuive numbers in for tmp
    %tmp=cast(1:102,'single');
    dat(7:414)=typecast(tmp,'uint8');
    %calculate checksum for data
    check=mod(sum(dat(1:510)),2^16);
    dat(511:512)=typecast(cast(check,'uint16'),'uint8');
end