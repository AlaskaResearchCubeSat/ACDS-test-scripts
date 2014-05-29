%get length of voltage vector
l=length(Vb);
%initialize voltage data
V=[-Vb(end:-1:1) Vb];
%initialize magnetic field data
B=zeros(size(V));
Imax=zeros(size(V));
Bmax=zeros(size(V));
%extract data from traces
for k=1:length(traces)
    %get data from before the torquer is flipped
    idx=find(traces{k}(1,:)<5e-6);
    %check if positive or negative flip
    if(mod(k,2)==0)
        %Waveform was for negative flip
        %get data for positive flip
        B(k/2+l)=mean(traces{k}(3,idx));
        %get maximum current
        Imax(l-k/2+1)=min(traces{k}(2,:));
        %get maximum magnetic field
        Bmax(l-k/2+1)=min(traces{k}(3,:));
    else
        %Waveform was for positive flip
        %get data for negitave flip
        B(l-(k+1)/2+1)=mean(traces{k}(3,idx));
        %get maximum current
        Imax(l+(k+1)/2)=max(traces{k}(2,:));
        %get maximum magnetic field
        Bmax(l+(k+1)/2)=max(traces{k}(3,:));
    end
end
%create new figure
figure;
%plot data
plot(V,Imax);
ylabel('Maximum Current [A]');
xlabel('Voltage [V]');
