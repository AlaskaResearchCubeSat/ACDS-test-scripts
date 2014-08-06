function offsetplot(cor,boards)
    %name of axes for plots and printouts    
    axes_names={'X','Y','Z'};   
    %name of SPB boards
    board_names={'X+','X-','Y+','Y-','Z+','Z-'};
    %tell which main axis each sensor axis corosponds to
    board_axes=[2,-3;  -2,-3;  -1,-3;  1,-3; 2,1; -1,2]; 
    clf;
    fprintf('\n==========================[Correction Data Offsets]==========================\n');
    for k=1:3
        %subplot for each axis
        subplot(3,1,k);
        hold on;
        cm=lines(5);
        cm_idx=1;
        plots=false(size(board_names));
        %print out axis maximum swing
        fprintf('%s-axis:\n',axes_names{k});
        for kk=1:length(boards)
            %get logical index of which board is in use
            idx=strcmp(board_names,boards{kk});
            %get board axes infor for that board
            ax=board_axes(idx,:);
            for jj=1:2
                if(abs(ax(jj))==k)
                    offset=cor{kk}(4:end,jj);
                    offset=offset+cor{kk}(3,jj);
                    %plot error
                    plot(offset,'Color',cm(cm_idx,:));
                    %get max and min
                    mx=max(offset)*1e3;
                    mn=min(offset)*1e3;
                    %print max and min
                    fprintf('\t%s SPB\n\t\tMax = %.2f mGauss\n\t\tMin =%.2f mGauss\n\t\tDeveation = %.2f mGauss\n',board_names{idx},mx,mn,mx-mn);
                    cm_idx=cm_idx+1;
                    plots=plots | idx;
                end
            end
        end
        hold off;
        legend(board_names{plots});
        xlabel('index');
    end
    fprintf('=============================================================================\n');
end
