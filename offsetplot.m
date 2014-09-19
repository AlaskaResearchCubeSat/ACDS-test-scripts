function offsetplot(cor,boards)
    %name of axes for plots and printouts    
    axes_names={'X','Y','Z'};   
    %name of SPB boards
    board_names={'X+','X-','Y+','Y-','Z+','Z-'};
    %tell which main axis each sensor axis corosponds to
    board_axes=[2,-3;  -2,-3;  -1,-3;  1,-3; 2,1; -1,2]; 
    %index for status generation
    idx=0:15;
    %generate array for states
    states=zeros(16,4);
    %make binary matrix
    for k=1:4
        states(:,k)=~~bitand(idx,2^(k-1));
    end
    %generate char array of strings
    states=char(ones(size(states))*'-'+('+'-'-')*states);
    %index for states
    Tidx=1:(3*16);
    %default state
    dstate='++--';
    %empty cell array for lables
    lables=cell(1,3*16);
    %generate cell array for ticks
    for k=Tidx
        axis=ceil(k/16)-1;
        lables{k}=[dstate,' ',dstate ' ',dstate];
        lables{k}(5*axis+(1:4))=states(mod(k-1,16)+1,:);
    end
    clf;
    fprintf('\n==========================[Correction Data Offsets]==========================\n');
    
    for k=1:3
        %subplot for each axis
        sp(k)=subplot(3,1,k);
        hold on;
        cm=lines(5);
        cm_idx=1;
        plots={};
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
                    plot(Tidx,offset,'Color',cm(cm_idx,:));
                    %get max and min
                    mx=max(offset)*1e3;
                    mn=min(offset)*1e3;
                    %print max and min
                    fprintf('\t%s SPB\n\t\tMax = %.2f mGauss\n\t\tMin =%.2f mGauss\n\t\tDeveation = %.2f mGauss\n',board_names{idx},mx,mn,mx-mn);
                    cm_idx=cm_idx+1;
                    plots={plots{:},board_names{idx}};
                end
            end
        end
        hold off;
        legend(plots);
        %lable Y-axis
        ylabel('Field Offset [Gauss]');
        %set lables
        set(gca,'XTick',Tidx);
        if(k==3)
            set(gca,'XTickLabel',lables);
            xlabel('Torquer State');
            %rotate tick lables so they are visable
            %available:
            %http://www.mathworks.com/matlabcentral/fileexchange/45172-rotatexlabels
            rotateXLabels(gca,45);
        else
            set(gca,'XTickLabel',{});
        end
    end
    %link plot axis
    linkaxes(sp,'xy');
    fprintf('=============================================================================\n');
    
    %setup figure for printing
    set(gcf,'PaperPositionMode','auto');
    
    %save plot
    fig_export('Z:\ADCS\figures\board-offsets.eps');
    
end
