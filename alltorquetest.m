function alltorquetest(test_names)
    ax_names={'X','Y','Z'};
    spb_names={'X+','X-','Y+','Y-','Z+','Z-'};
    
    if (~exist('test_names','var') || isempty(test_names))
        test_names=spb_names;
    end

    %rotation matricies for SPB's
    a={make_spb_rot([0  -1 0],[0 0 -1]),make_spb_rot([0  1 0],[0 0 -1]),...           %X +/-
       make_spb_rot([ 1 0 0],[0 0 -1]),make_spb_rot([-1 0 0],[0 0 -1]),...             %Y +/-
       make_spb_rot([0  1 0],[-1  0 0]),make_spb_rot([-1 0 0],[0 1 0]),...             %Z +/-
       };

    %AM or PM strings for time display
    ampm={'AM','PM'};

    cstart=fix(clock);
    fprintf('Starting Test at %i:%02i:%02i\nSimulation Running Please Wait\n',cstart(4:6));

    %get start time to calculate elapsed time
    Tstart=tic();

    num=2*length(ax_names);
    %create dat directory
    quiet_mkdir(fullfile('.','dat'));
    %generate new folder name for data
    folder=unique_fliename(fullfile('.','dat','alltorque'));
    %create folder
    quiet_mkdir(folder);
    %save SPB names and rotation matrix
    save(fullfile(folder,'dat.mat'),'a','test_names','spb_names');

    for k=1:length(test_names)
        for ax=1:length(ax_names)
            for tq=1:4
                %find SPB in the list of axis names
                idx=strcmp(test_names{k},spb_names);
                %array to set wich torquer to flip
                torquer=zeros(1,3);
                %set toruer
                torquer(ax)=tq;
                [p,m]=offset_test(test_names{k},'COM3',57600,torquer,-95.3,1,a{idx});
                %save figure
                saveas(gcf(),fullfile(folder,[test_names{k},ax_names{ax},int2str(tq),'-flip-fig']),'fig');
                %save data
                save(fullfile(folder,[test_names{k},ax_names{ax},int2str(tq),'-flip-pm']),'p','m');
                %===[estimate completeion time]===
                %calculate iteration number
                num=num+1;
                %calculate done fraction
                df=((tq-1)*length(ax_names)+ax)/num;
                %get elapsed time
                Te=toc(Tstart);%get remaining time
                %calculate remaining time
                Tr=Te*(df^-1-1);
                %calculate completion estimate
                tcomp=clock+[0 0 0 0 0 Tr];
                %normalize completion estimate
                tcomp=fix(datevec(datenum(tcomp)));
                %get AM or PM
                AMPM_idx=(tcomp(4)>12)+1;
                if(AMPM_idx==2)
                    tcomp(4)=tcomp(4)-12;
                end
                %print new completion estimate
                fprintf('Test %i of %i Complete\nCompletion estimate : %i/%i %i:%02i %s\n',(tq-1)*length(ax_names)+ax,2*length(ax_names),tcomp(2:5),ampm{AMPM_idx});
            end
        end
        tqOffsetPlot(test_names{k},folder);
    end

    %TODO: plot data
end



