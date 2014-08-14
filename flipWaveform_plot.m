function flipWaveform_plot(savefile)
    %plot data from flipWaveform function stored in savefile

    %load data
    load(savefile);
    %get base filename
    [~,basename,~]=fileparts(savefile);
    %create figure
    figure;
    subplot(2,1,2);
    plot(dat(1,idx)*1e3,dat(2,idx));
    ylabel('Current [A]');
    xlabel('Time [msec]');
    %set y-axis ticks to a reasonable value
    Itick=0:(round(max(dat(2,:))+0.9));
    set(gca,'YTick',Itick);
    set(gca,'Ylim',Itick([1,end]));
    %set x-axis limits
    set(gca,'Xlim',1e3*dat(1,idx([1,end])));
    %plot magnetic field
    subplot(2,1,1);
    plot(dat(1,idx)*1e3,dat(3,idx));
    ylabel('Magnetic Field [Gauss]');
    xlabel('Time [msec]');
    %set x-axis limits
    set(gca,'Xlim',1e3*dat(1,idx([1,end])));
    %save plot
    fig_export(fullfile('.','figures',[basename,'.eps']));
end