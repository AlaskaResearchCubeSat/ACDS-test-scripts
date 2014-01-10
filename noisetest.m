%script to run nois_test multiple times to see if it changes over time
num=16;

%x and y offset values
xos=zeros(num*20,1);
yos=zeros(num*20,1);

%start and end times for test
tstart=zeros(num,1);
tend=zeros(num,1);

for k=1:num
    %capture start time
    tstart(k)=now;
    %run test
    p=noise_test('X-','COM6',9600,-95.3,1);
    xos(20*(k-1)+(1:20))=p(:,3);
    yos(20*(k-1)+(1:20))=p(:,6);
    %capture end time
    tend(k)=now;
    %calculate remaining time
    rem=(tend(k)-tstart(k))*(num-k);
    fprintf('Test %i of %i complete\n%.2f days remaining\n',k,num,rem);
end

idx=num2cell(datestr(reshape(ones(20,1)*(tstart'),1,[]),'(dd) HH:MM PM'),2);

s1=subplot(1,2,1);
boxplot(xos-mean(xos),idx);
%datetick('x','(dd) HH:MM');
title('X-axis');
ylabel('Field offset variation [Gauss]');
axis('auto');

s2=subplot(1,2,2);
boxplot(yos-mean(yos),idx);
%datetick('x','(dd) HH:MM');
title('Z-axis');
axis('auto');

mask=[0 0 -1 1];

newax=max([axis(s1);axis(s2)].*(ones(2,1)*mask)).*mask;

ax=axis(s1);
ax(mask~=0)=newax(mask~=0);
axis(s1,ax);
ax=axis(s1);
ax(mask~=0)=newax(mask~=0);
axis(s1,ax);
linkaxes([s1,s2],'y');

