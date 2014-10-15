function offsetplot(cor,boards)
    %if no arguments given then read from file
    if(nargin==0)
        %generate file name
        fname=fullfile('dat','cor.mat');
        %print filename
        fprintf('no arguments given, reading data from "%s"\n',fname);
        %load file
        s=load(fname,'cor','store_axis');
        %set values
        cor=s.cor;
        boards=s.store_axis;
        %clear unused vars
        clear s fname
    end
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
    
    tablef=fopen('offsetplot-table-dat.tex','wt');
    
    %add vim modeline
    fprintf(tablef,'%% vim: filetype=tex spell\n');
    %print table start
    fprintf(tablef,'\n\\begin{tabular}{|c|c|c|c|}\n');
    %print line and header
    hline(tablef);
    fprintf(tablef,'\t\\acs{SPB}&Max Offset&Min Offset&Deviation\\\\\n');
    
    for k=1:3
        %subplot for each axis
        sp(k)=subplot(3,1,k);
        hold on;
        cm=lines(5);
        cm_idx=1;
        plots={};
        %print out axis maximum swing
        fprintf('%s-axis:\n',axes_names{k});
        %print table header row
        hline(tablef);
        fprintf(tablef,'\t\\multicolumn{4}{|c|}{\\bfseries %s-axis}\\\\\n',axes_names{k});
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
                    mx=max(offset);
                    mn=min(offset);
                    %add table entry
                    hline(tablef);
                    fprintf(tablef,'\t%s&%.2f&%.2f&%.2f\\\\\n',board_names{idx},mx,mn,mx-mn);
                    %convert to mGauss
                    mx=mx*1e3;
                    mn=mn*1e3;
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
        %get plot position
        p=get(sp(k),'Position');
        shift=0.06;
        streach=0.03;
        if(k==3)
            allp=get(sp,'Position');
            p(4)=p(4)+streach;
            p(2)=2*allp{2}(2)-allp{1}(2);
            set(gca,'XTickLabel',lables);
            xlabel('Torquer State');
            %rotate tick lables so they are visable
            %available:
            %http://www.mathworks.com/matlabcentral/fileexchange/45172-rotatexlabels
            rotateXLabels(gca,45);
            rotlables=findall(gca,'Tag','RotatedXTickLabel');
            set(rotlables,'FontName','FixedWidth');
            set(rotlables,'FontSize',10);
        else
            set(gca,'XTickLabel',{});
            p(2)=p(2)+shift/(3-k);
            p(4)=p(4)+streach;
        end
        %set plot position
        set(sp(k),'Position',p);
    end
    %link plot axis
    linkaxes(sp,'xy');
    fprintf('=============================================================================\n');
    
    %add ending hline
    hline(tablef);
    %end talbe
    fprintf(tablef,'\\end{tabular}\n\n');
    %close table file
    fclose(tablef);
    
    %setup figure for printing
    set(gcf,'PaperPositionMode','auto');
    
    %save plot
    fig_export('./figures/board-offsets.pdf');
end

function hline(f)
    fprintf(f,'\t\\hline\n');
end
