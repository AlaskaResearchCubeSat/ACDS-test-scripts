function cor=calall(mag_axis,com,baud,gain,ADCgain,a)
    [corx,measx]=tCal(mag_axis,'X',com,baud,gain,ADCgain,a);
    [cory,measy]=tCal(mag_axis,'Y',com,baud,gain,ADCgain,a);
    [corz,measz,Bs]=tCal(mag_axis,'Z',com,baud,gain,ADCgain,a);

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
