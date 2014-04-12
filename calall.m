[corx,measx]=tCal('Y-','X','COM6',57600,-95.3,1,[1 0 0;0 0 1;0 1 0]);
[cory,measy]=tCal('Y-','Y','COM6',57600,-95.3,1,[1 0 0;0 0 1;0 1 0]);
[corz,measz,Bs]=tCal('Y-','Z','COM6',57600,-95.3,1,[1 0 0;0 0 1;0 1 0]);

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

