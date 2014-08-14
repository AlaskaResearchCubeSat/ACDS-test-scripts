function multiflip_plot(savefile)
    %plot data from multiflip function stored in savefile

    %load data
    load(savefile);
    %get base filename
    [~,basename,~]=fileparts(savefile);
    %create figure
    figure

    if length(dat)<=7
        cmap=lines(length(dat));
    else
        cmap=jet(length(dat));
    end

    subplot(2,1,1);
    Binitial=mean(dat{1}(3,1:20));
    B=[Binitial Bfinal]-Binitial;
    B=100*B/mean(B(3:end));
    plot(0:length(dat),B);
    hold on;
    for k=1:length(dat)
        plot(k,B(k+1),'sk','MarkerFaceColor',cmap(k,:));
    end
    hold off;
    xlabel('Flip number');
    ylabel('%of final value');

    subplot(2,1,2);
    plot(1:length(dat),B(2:end));
    hold on;
    for k=1:length(dat)
        plot(k,B(k+1),'sk','MarkerFaceColor',cmap(k,:));
    end
    hold off;
    xlabel('Flip number');
    ylabel('%of final value');
    set(gca,'Xlim',[0 length(dat)]);
    fig_export(fulfile('.','figures',[basename,'.eps']));

    figure

    %plot current
    subplot(2,1,2);
    hold('on');
    for k=1:length(dat)
        plot(dat{k}(1,:)*1e3,dat{k}(2,:),'Color',cmap(k,:));
    end
    hold('off');
    ylabel('Current [A]');
    xlabel('Time [msec]');
    colormap(cmap);
    colorbar('location','southoutside','XTickLabel',{'First','Last'},'XTick',[1,length(dat)]);
    %plot magnetic field
    subplot(2,1,1);
    hold('on');
    for k=1:length(dat)
        plot(dat{k}(1,:)*1e3,dat{k}(3,:),'Color',cmap(k,:));
    end
    hold('off');
    ylabel('Magnetic Field [Gauss]');
    xlabel('Time [msec]')
    fig_export(fulfile('.','figures',[basename,'-waveforms.eps']));
end