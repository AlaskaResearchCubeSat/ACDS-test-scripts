
ax_names={'X','Y','Z'};

board_names={'X+','X-','Y+','Y-'};
gain={[1,64],[1,64],[1,64],[1,64]};

a={vrrotvec2mat([0 1 0 pi/2]),vrrotvec2mat([0 1 0 -pi/2]),vrrotvec2mat([1 0 0 pi/2]),vrrotvec2mat([1 0 0 -pi/2])};

%AM or PM strings for time display
ampm={'AM','PM'};

cstart=fix(clock);
fprintf('Starting Test at %i:%02i:%02i\nSimulation Running Please Wait\n',cstart(4:6));

%get start time to calculate elapsed time
Tstart=tic();

num=2*length(ax_names);

for k=1:length(board_names)
    for tq=1:2
        for ax=1:length(ax_names)
            %skip some tests
            %if(tq==1 && ax<=2)
            %    num=num-1;
            %    continue;
            %end
            %array to set wich torquer to flip
            torquer=zeros(1,3);
            %set toruer
            torquer(ax)=tq;
            %[p,m]=offset_test('X-','COM6',9600,torquer,95.3,1);
            [p,m]=offset_test('X-','COM3',57600,torquer,gain{k}(1),gain{k}(2),a{k});
            %save figure
            saveas(gcf(),['Z:\ADCS\figures\' board_names{k} ax_names{ax} int2str(tq) '-flip-fig'],'fig');
            %save data
            save(['Z:\ADCS\figures\' board_names{k} ax_names{ax} int2str(tq) '-flip-pm'],'p','m')
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
end

%plot data
run('Z:\ADCS\figures\tqOffsetPlot');


        
