function [cor]=spbMag(mag_axis,com,baud,gain,ADCgain,a)
    if(~exist('mag_axis','var') || isempty(mag_axis))
        mag_axis='';
    end
    if(~exist('baud','var') || isempty(baud))
        baud=57600;cal
    end
    if(~exist('com','var') || isempty(com))
        com='COM3';
    end
    if(~exist('a','var') || isempty(a))
        a=[];
    else
        if size(a)~=[3 3]
            error('a must be a 3x3 matrix')
        end
    end
    if (~exist('gain','var') || isempty(gain))
        gain=-95.3;
    end
    if (~exist('ADCgain','var') || isempty(ADCgain))
        ADCgain=1;
    end 
    %limits from datasheet
    lim=[0.8 1.2;
         %-3 3;
         -10 10;
         -1.25 1.25];
    check={{'X  Ss',1,1,' mV/V/Gauss'},{'X  Ds',2,2,'%'},{'X Vos',3,3,' mV/V'},...
           {'Y  Ss',1,4,' mV/V/Gauss'},{'Y  Ds',2,5,'%'},{'Y Vos',3,6,' mV/V'}};
    pf={'Fail','Pass'};
    %add detumble test folder to paht for usefull functions
    cor=magSclCalc(mag_axis,com,baud,gain,ADCgain,a);
    parm=mag_parm(cor,gain*ADCgain);
    pass=zeros(1,6);
    for k=1:length(check)
        idx=check{k}{3};
        limidx=check{k}{2};
        pass(k)=parm(1,idx)>lim(limidx,1)&&parm(1,idx)<lim(limidx,2);
        fprintf('%s % 10.4f%-15s%s\n',char(check{k}{1}),parm(1,idx),check{k}{4},pf{pass(k)+1});
    end
    if(all(pass))
        fprintf('All Tests Passed!!!\n');
    else
        num=length(find(pass==0));
        fprintf('SPB test failed.\nThere are %i out of spec paramiters\n',num);
    end

    beep;
end
