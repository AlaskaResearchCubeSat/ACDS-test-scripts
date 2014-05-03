function [dat]=make_cor_dat(cor)
    base=zeros(2,1);
    dat=zeros(512,1,'uint8');
    base(1)=15-ceil(log2(max(max(abs(cor(1:2,:))))));
    base(2)=15-ceil(log2(max(max(abs(cor(3:51,:))))));
    base=cast(base,'uint8');
    n=2.^double(base)-1;
    dat(1:2)=base;
    dat(3:6)=typecast(cast(round(cor(1:2,1)*n(1)),'int16'),'uint8');
    dat(7:10)=typecast(cast(round(cor(1:2,2)*n(1)),'int16'),'uint8');
    dat(11:108)=typecast(cast(round(cor(3:51,1)*n(2)),'int16'),'uint8');
    dat(109:206)=typecast(cast(round(cor(3:51,2)*n(2)),'int16'),'uint8');
end