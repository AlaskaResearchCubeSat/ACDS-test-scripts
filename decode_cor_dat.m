function [cor]=decode_cor_dat(dat)
    cor=zeros(51,2);
    base=double(dat(1:2));
    n=2.^base-1;
    cor(1:2,1)=double(typecast(dat(3:6),'int16'))/n(1);
    cor(1:2,2)=double(typecast(dat(7:10),'int16'))/n(1);
    cor(3:51,1)=double(typecast(dat(11:108),'int16'))/n(2);
    cor(3:51,2)=double(typecast(dat(109:206),'int16'))/n(2);
end