function tCalTstFull_plot(savefile)
    %plot data from tCalTstFull function stored in savefile

    %load data
    load(savefile);
    %get base filename
    [~,basename,~]=fileparts(savefile);
    %make figures directory
    quiet_mkdir(fullfile('.','figures'));
    %new figure
    figure(1);
    clf
    %set measured
    show_meas=0;
    hold on
    %plot measured field
    if(show_meas)
        plot(sensor(1,:),sensor(2,:),'b');
    end
    %plot commanded field
    plot(Bs(1,:),Bs(2,:),'r');
    %Calculate Scale only corrected values
    Xsc=meas(1:2,:)'*cor(1:2,1);
    Ysc=meas(1:2,:)'*cor(1:2,2);
    plot(Xsc,Ysc,'g');
    %calculate center
    sc(1)=mean(Xsc);
    sc(2)=mean(Ysc);
    %plot scale only corrected center
    hc=plot(sc(1),sc(2),'go');
    set(get(get(hc,'Annotation'),'LegendInformation'),'IconDisplayStyle','off');
    %plot corrected values
    plot(Xc,Yc,'b');
    %calculate center
    c(1)=mean(Xc);
    c(2)=mean(Yc);
    %plot corrected center
    hc=plot(c(1),c(2),'bo');
    set(get(get(hc,'Annotation'),'LegendInformation'),'IconDisplayStyle','off');
    if(show_meas)
        %calculate center
        c=mean(sensor,2);
        %plot centers for measured
        hc=plot(c(1),c(2),'b+');
        set(get(get(hc,'Annotation'),'LegendInformation'),'IconDisplayStyle','off');
    end
    %calculate center
    c=mean(Bs,2);
    %plot centers for commanded
    hc=plot(c(1),c(2),'rx');
    set(get(get(hc,'Annotation'),'LegendInformation'),'IconDisplayStyle','off');
    hold off
    ylabel('Magnetic Field [gauss]');
    xlabel('Magnetic Field [gauss]');
    if(show_meas)
        legend('Measured','Commanded','Scale only Corrected','Corrected');
    else
        legend('Commanded','Scale only Corrected','Corrected');
    end
    legend('Location','NorthEast');
    %set both axes equaly spaced
    set(gca,'DataAspectRatio',[1 1 1]);
    %get axis limits
    lim=get(gca,{'Xlim','Ylim'});
    %get new limits from extents of the old limits
    lim=max(abs([lim{:}]));
    %set new limits to both axes
    axis([-lim lim -lim lim]);
    %export figure
    fig_export(fullfile('.','figures',[basename,'.pdf']));
    figure(2);
    clf
    %sample number
    sn=1:length(Xc);
    %calculate error magnitude
    err=[Xc;Yc]-Bs(1:2,:);
    err_s=sum(err.^2);
    %print out error
    fprintf('RMS Error = %f mGauss\n',sqrt(mean(err_s))*1e3);
    fprintf('Max Error = %f mGauss\n',max(sqrt(err_s))*1e3);
    %plot errors
    plot(sn,err(1,:),sn,err(2,:),sn,sqrt(err_s));
    %legend
    legend('X error','Y error','error magnitude');
    xlabel('Sample Number');
    ylabel('Error [Gauss]');
    
    %save plot
    fig_export(fullfile('.','figures',[basename,'-err.pdf']));
    %create new figure and add torquer status subplot
    figure(3);
    clf
    s1=subplot(2,1,1);
    %plot errors
    plot(sn,err(1,:),sn,err(2,:),sn,sqrt(err_s));
    %legend
    legend('X error','Y error','error magnitude');
    xlabel('Sample Number');
    ylabel('Error [Gauss]');

    sn=10*(0:length(stat)-1);
    tstat=zeros(stlen*3,length(stat));
    %parse torquer statuses
    for k=1:length(stat)
        s=stat_dat(stat{k});
        tstat(:,k)=reshape((s'-'+')/2,[],1);
    end

    %plot for torquer status
    s2=subplot(2,1,2);
    hold on;
    stairs(sn,2*tstat(stlen*(0)+1,:)+3,'r')
    stairs(sn,2*tstat(stlen*(0)+2,:)+6,'g')
    stairs(sn,2*tstat(stlen*(0)+3,:)+9,'b')
    stairs(sn,2*tstat(stlen*(0)+4,:)+12,'m')

    stairs(sn,2*tstat(stlen*(1)+1,:)+16,'r')
    stairs(sn,2*tstat(stlen*(1)+2,:)+19,'g')
    stairs(sn,2*tstat(stlen*(1)+3,:)+22,'b')
    stairs(sn,2*tstat(stlen*(1)+4,:)+25,'m')

    stairs(sn,2*tstat(stlen*(2)+1,:)+29,'r')
    stairs(sn,2*tstat(stlen*(2)+2,:)+32,'g')
    stairs(sn,2*tstat(stlen*(2)+3,:)+35,'b')
    stairs(sn,2*tstat(stlen*(2)+4,:)+39,'m')

    %stairs(sn,stat_index,'k');
    hold off;

    legend('X1','X2','X3','X4',...
           'Y1','Y2','Y3','Y4',...
           'Z1','Z2','Z3','Z4');
    %link subplots x-axis
    linkaxes([s1,s2],'x');
    %save plot
    fig_export(fullfile('.','figures',[basename,'-flips.pdf']));
end
