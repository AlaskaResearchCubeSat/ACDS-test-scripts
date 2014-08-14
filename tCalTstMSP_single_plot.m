function tCalTstMSP_single_plot(savefile)
    %plot data from tCalTstMSP_single function stored in savefile

    %load data
    load(savefile);
    [~,basename,~]=fileparts(savefile);
    %create figure
    figure(1);
    clf
    hold on
    %plot measured field
    plot(sensor(1,:),sensor(2,:),'b');
    %plot commanded field
    plot(Bs(1,:),Bs(2,:),'r');
    %plot corrected values
    plot(meas(1,:),meas(2,:),'m');
    %calculate center
    c(1)=mean(meas(1,:));
    c(2)=mean(meas(2,:));
    %plot corrected center
    hc=plot(c(1),c(2),'mo');
    set(get(get(hc,'Annotation'),'LegendInformation'),'IconDisplayStyle','off');
    %calculate center
    c=mean(sensor,2);
    %plot centers for measured
    hc=plot(c(1),c(2),'b+');
    set(get(get(hc,'Annotation'),'LegendInformation'),'IconDisplayStyle','off');
    %calculate center
    c=mean(Bs,2);
    %plot centers for commanded
    hc=plot(c(1),c(2),'rx');
    set(get(get(hc,'Annotation'),'LegendInformation'),'IconDisplayStyle','off');
    hold off
    ylabel('Magnetic Field [gauss]');
    xlabel('Magnetic Field [gauss]');
    legend('Measured','Commanded','Corrected');
    legend('Location','NorthEastOutside');
    axis('square');
    axis('equal');
    fig_export('Z:\ADCS\figures\torqueCalTst.eps');
    figure(2);
    clf
    %sample number
    sn=1:length(meas(1,:));
    %calculate error magnitude
    err=[meas(1,:);meas(2,:)]-Bs(1:2,:);
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
    fig_export('Z:\ADCS\figures\torqueCalTst-err.eps');
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
    fig_export(fullfile('.','figures',[basename,'-err-flips.eps']));
end