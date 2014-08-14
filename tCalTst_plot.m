function tCalTst_plot(savefile)
    %plot data from tCalTst function stored in savefile

    %load data
    load(savefile);
    %get base filename
    [~,basename,~]=fileparts(savefile);
    %make figures directory
    quiet_mkdir(fullfile('.','figures'));
    %create figure
    figure(1);
    clf
    hold on
    %plot measured field
    %plot(sensor(1,:),sensor(2,:),'b');
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
    %calculate center
    c=mean(sensor,2);
    %plot centers for measured
    %hc=plot(c(1),c(2),'b+');
    %set(get(get(hc,'Annotation'),'LegendInformation'),'IconDisplayStyle','off');
    %calculate center
    c=mean(Bs,2);
    %plot centers for commanded
    hc=plot(c(1),c(2),'rx');
    set(get(get(hc,'Annotation'),'LegendInformation'),'IconDisplayStyle','off');
    hold off
    ylabel('Magnetic Field [gauss]');
    xlabel('Magnetic Field [gauss]');
    %legend('Measured','Commanded','Scale only Corrected','Corrected');
    legend('Commanded','Scale only Corrected','Corrected');
    legend('Location','NorthEastOutside');
    axis('square');
    axis('equal');
    fig_export(fullfile('.','figures',[basename,'.eps']));
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
    fig_export(fullfile('.','figures',[basename,'-err.eps']));
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
    stairs(sn,2*tstat(stlen*(tq_axis-1)+1,:)+3,'r')
    stairs(sn,2*tstat(stlen*(tq_axis-1)+2,:)+6,'g')
    stairs(sn,2*tstat(stlen*(tq_axis-1)+3,:)+9,'b')
    stairs(sn,2*tstat(stlen*(tq_axis-1)+4,:)+12,'m')
    stairs(sn,stat_index,'k');
    hold off;
    switch tq_axis
        case 1
            legend('X1','X2','X3','X4','Index');
        case 2
            legend('Y1','Y2','Y3','Y4','Index');
        case 3
            legend('Z1','Z2','Z3','Z4','Index');
    end
    %link subplots x-axis
    linkaxes([s1,s2],'x');
    %save plot
    fig_export(fullfile('.','figures',[basename,'-err-flips.eps']));
end