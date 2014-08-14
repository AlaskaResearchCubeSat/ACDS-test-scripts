function bdot_test_plot(savefile)
    %plot data from bdot_test function stored in savefile

    %load data
    load(savefile);
    %get base filename
    [~,basename,~]=fileparts(savefile);
    %make figures directory
    mkdir(fullfile('.','figures'));
    %create figure
    figure;
    clf;

    M_cmd_lim=0.022;
    sn=1:length(torque);
    [x1,y1]=stairs(sn,M_cmd_lim*torque(:,1));
    [x2,y2]=stairs(sn,M_cmd_lim*torque(:,2));
    [x3,y3]=stairs(sn,M_cmd_lim*torque(:,3));

    subplot(4,1,1);
    plot(x1,y1,sn,Mcmd(:,1));
    xlabel('Sample Number');
    ylabel({'X-axis Dipole';'Moment [A m^2]'});
    legend('Drive','M_{cmd}');

    subplot(4,1,2);
    plot(x2,y2,sn,Mcmd(:,2));
    xlabel('Sample Number');
    ylabel({'Y-axis Dipole';'Moment [A m^2]'});
    legend('Drive','M_{cmd}');

    subplot(4,1,3);
    plot(x3,y3,sn,Mcmd(:,3));
    xlabel('Sample Number');
    ylabel({'Z-axis Dipole';'Moment [A m^2]'});
    legend('Drive','M_{cmd}');

    subplot(4,1,4);
    plot(sn,field(:,1),sn,field(:,2),sn,field(:,3));
    xlabel('Sample Number');
    ylabel('Magnetic Field [Gauss]');
    legend('X','Y','Z');

    %save plot
    fig_export(fullfile('.','figures',[basename,'.eps']));
end