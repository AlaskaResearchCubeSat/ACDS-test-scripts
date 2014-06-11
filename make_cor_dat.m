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
    base=zeros(2,1);
    dat=zeros(512,1,'uint8');
    base(1)=15-ceil(log2(max(max(abs(cor(1:2,:))))));
    base(2)=15-ceil(log2(max(max(abs(cor(3:51,:))))));
    base=cast(base,'uint8');
    n=2.^double(base);
    dat(1:4)='COR ';
    dat(5:6)=axis;
    dat(7:8)=base;
    dat(9:12)=typecast(cast(round(cor(1:2,1)*n(1)),'int16'),'uint8');
    dat(13:16)=typecast(cast(round(cor(1:2,2)*n(1)),'int16'),'uint8');
    dat(17:114)=typecast(cast(round(cor(3:51,1)*n(2)),'int16'),'uint8');
    dat(115:212)=typecast(cast(round(cor(3:51,2)*n(2)),'int16'),'uint8');
    %calculate checksum for data
    check=mod(sum(dat(1:510)),2^16);
    dat(511:512)=typecast(cast(check,'uint16'),'uint8');
end