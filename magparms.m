%script to read parameters from multiple boards
clear parms cor mag_names
k=1;
mag='X+';
%first calibrate cage
calHC;
%read data from all SPB's
while(~isempty(mag))
    mag=input('Enter Mag Axis (empty exits):\n','s');
    if(isempty(mag))
        break;
    end
    %new figure
    figure(k);
    %do calibration
    cor(k,:)=magSclCalc(mag,'COM3');
    %ring bell when things are done
    beep
    %set title
    title([mag,' Axis']);
    %save name
    mag_names{k}=mag;
    %calculate data sheet parms
    parms(k,:)=mag_parm(cor,64);
    %inc index
    k=k+1;
end

%calcuate number of plots
num=k-1;
%new figure
figure(k);
%clear figure
clf;
%limits from datasheet
lim={[0.8 1 1.2],...
     [-3 -3 0 3 3],...     
     [-1.25 -0.5 -0.5 0 0.5 0.5 1.25],...
     [0.8 1 1.2],...
     [-3 -3 0 3 3],...
     [-1.25 -0.5 -0.5 0 0.5 0.5 1.25]};
 %Titles for each plot
 titles={'X Sensitivity','X cross','X offset','Y Sensitivity','Y cross','Y offset'};
 %lables for y-axis
 ylab={'mV/V/Gauss','%FS','mV/V','mV/V/Gauss','%FS','mV/V'};
 %group names
 names={'Measured','Datasheet'};
%make box plots
for k=1:6
    %select plot
    subplot(1,6,k);
    %boxplot
    boxplot([parms(:,k);lim{k}'],{names{[ones(1,length(parms(:,k))),2*ones(1,length(lim{k}))]}});
    %set title
    title(titles{k});
    %set y-axis label
    ylabel(ylab{k});
end
    
