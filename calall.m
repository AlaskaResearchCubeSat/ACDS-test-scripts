[corx,measx]=tCal('Y-','X','COM6',57600,1,64,[1 0 0;0 0 1;0 1 0]);
[cory,measy]=tCal('Y-','Y','COM6',57600,1,64,[1 0 0;0 0 1;0 1 0]);
[corz,measz,Bs]=tCal('Y-','Z','COM6',57600,1,64,[1 0 0;0 0 1;0 1 0]);

c=mean([corx(7,:);cory(7,:);corz(7,:)]);