function [cor,erms]=magSclCalc_plot(savefile)
    %plot data from magSclCalc function stored in savefile

    %load data
    load(savefile);
    %get base filename
    [~,basename,~]=fileparts(savefile);
    %make figures directory
    quiet_mkdir(fullfile('.','figures'));
    %clear figure data
    clf
    hold on
    if(show_meas)
        %plot measured field
        plot(sensor(1,:),sensor(2,:),'m');
        %calculate center
        cm=mean(sensor,2);
        %plot center for measured
        hc=plot(cm(1),cm(2),'b+');
        %turn off legend entry
        set(get(get(hc,'Annotation'),'LegendInformation'),'IconDisplayStyle','off');
    end
    %plot commanded field
    plot(Bs(1,:),Bs(2,:),'r');
    %calculate center
    c=mean(magScale*meas,2);
    %plot uncorrected measured field
    plot(magScale*meas(1,:),magScale*meas(2,:),'g');
    %plot uncorrected center
    hc=plot(c(1),c(2),'go');
    %turn off legend entry
    set(get(get(hc,'Annotation'),'LegendInformation'),'IconDisplayStyle','off');
    %calculate correction values
    len=length(meas);
    A=[meas(1:2,:)',ones(len,1)];
    As=(A'*A)^-1*A';
    cor(1:3)=As*(Bs(1,:)');
    cor(4:6)=As*(Bs(2,:)');
    %calculate error
    erms=sqrt(sum(mean([Bs(1,:)'-A*(cor(1:3)'),Bs(2,:)'-A*(cor(4:6)')].^2)));
    %calculate corrected values
    Xc=[meas(1:2,:)',ones(len,1)]*(cor(1:3)');
    Yc=[meas(1:2,:)',ones(len,1)]*(cor(4:6)');
    %plot corrected values
    plot(Xc,Yc,'b');
    %calculate center
    c(1)=mean(Xc);
    c(2)=mean(Yc);
    %plot corrected center
    hc=plot(c(1),c(2),'b*');
    %turn off legend entry
    set(get(get(hc,'Annotation'),'LegendInformation'),'IconDisplayStyle','off');
    %calculate center
    cs=mean(Bs,2);
    %plot center for commanded
    hc=plot(cs(1),cs(2),'xr');
    %turn off legend entry
    set(get(get(hc,'Annotation'),'LegendInformation'),'IconDisplayStyle','off');
    hold off
    ylabel('Magnetic Field [gauss]');
    xlabel('Magnetic Field [gauss]');
    if(show_meas)
        legend('Measured','Commanded','Uncorrected','Corrected');
    else
        legend('Commanded','Uncorrected','Corrected');
    end
    legend('Location','NorthEastOutside');
    axis('square');
    axis('equal');
    %save plot
    fig_export(fullfile('.','figures',[basename,'.pdf']));
end