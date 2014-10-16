function [erms]=HCtst_plot(savefile)
    %plot data from magSclCalc function stored in savefile

    %load data
    load(savefile);
    %get base filename
    [~,basename,~]=fileparts(savefile);
    %make figures directory
    quiet_mkdir(fullfile('.','figures'));
    %make new figure
    figure;
    %clear figure data
    clf
    hold on
    %plot commanded field
    plot(Bs(1,:),Bs(2,:),'r');
    %calculate center
    c=mean(meas,2);
    %calculate error
    error=(Bs-meas);
    erms=sqrt(mean(sum(error.^2)));
    emag=sqrt(sum(error.^2));
    %plot measured values
    plot(meas(1,:),meas(2,:),'b');
    %plot measured center
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
    legend('Commanded','Measured');
    legend('Location','NorthEastOutside');
    axis('square');
    axis('equal');
    %save plot
    fig_export(fullfile('.','figures',[basename,'.pdf']));
    %make new figure
    figure;
    %clear figure
    clf;
    %make x-axis
    samples=1:length(Bs);
    %plot data
    plot(samples,emag,samples,error);
    %lable axis
    ylabel('Magnetic Field error [gauss]');
    xlabel('Sample Number');
    %add legend
    legend('Magnitude','X','Y','Z');
    legend('Location','NorthEastOutside');
    %save plot
    fig_export(fullfile('.','figures',[basename,'-error.pdf']));
end