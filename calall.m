function cor=calall(mag_axis,com,baud,gain,ADCgain,a)
    %acceptable error level
    good_err=0.015;
    
    [corx,ermsx]=tCal(mag_axis,'X',com,baud,gain,ADCgain,a);
    if ermsx>good_err
        error('Large calibration error of %f.',ermsx);
    end
    [cory,ermsy]=tCal(mag_axis,'Y',com,baud,gain,ADCgain,a);
    if ermsy>good_err
        error('Large calibration error of %f.',ermsy);
    end
    [corz,ermsz]=tCal(mag_axis,'Z',com,baud,gain,ADCgain,a);
    if ermsz>good_err
        error('Large calibration error of %f.',ermsz);
    end

    %initialize full compensation data set
    cor=zeros(51,2);

    %add sensor scaling factors
    for k=1:2
        cor(k,:)=mean([corx(k,:);cory(k,:);corz(k,:)]);
    end
    %calculate static offsets
    cor(3,:)=mean([corx(7,:);cory(7,:);corz(7,:)]);

    cor( 4:19,:)=corx(4:end,:)-ones(16,1)*cor(3,:);
    cor(20:35,:)=cory(4:end,:)-ones(16,1)*cor(3,:);
    cor(36:51,:)=corz(4:end,:)-ones(16,1)*cor(3,:);
end
