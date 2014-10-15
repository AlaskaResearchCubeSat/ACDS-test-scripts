function tqOffsetPlot(SPB,folder)

    %set a to quiet down Matlab
    a=eye(3);
    %load data
    load(fullfile(folder,'dat.mat'));
    %get base filename
    basename=regexp(fullfile(folder), ['[^\' filesep ']+(?=\' filesep '?$)'], 'match');
    %make basename not a cell array
    basename=basename{:};
    %make figures directory
    quiet_mkdir(fullfile('.','figures'));

    
    %number of torquers in each axis
    tq_axes=4;
    %axis names
    ax_names={'X' 'Y' 'Z'};
    %file names for flip data
    files=cell(length(ax_names)*tq_axes,1);
    %lables for flip data
    names=cell(length(ax_names)*tq_axes,1);
    for k=1:length(ax_names)
        for kk=1:tq_axes
            idx=(k-1)*tq_axes+kk;
            files{idx}=sprintf('%s%s%i-flip-pm.mat',SPB,ax_names{k},kk);
            names{idx}=sprintf('%s%i',ax_names{k},kk);
        end
    end
    
    %get SPB board index
    board_idx=strcmp(spb_names,'Y+');
    
    %get vector for which axis was measured
    ax1=abs(a{board_idx}*[1;0;0])==1;
    ax2=abs(a{board_idx}*[0;1;0])==1;
    %get name of the measured axis
    ax1_name=ax_names{ax1};
    ax2_name=ax_names{ax2};
    
    %cell arrays for flip data
    p=cell(size(files));
    m=cell(size(files));
    
    v=zeros(length(files),2);
    namesp=cell(size(files));
    namesm=cell(size(files));

    for k=1:length(files)
        s=load(fullfile(folder,files{k}));
        p{k}=s.p-ones(20,1)*median(s.p);
        m{k}=s.m-ones(20,1)*median(s.m);
        v(k,:)=abs(median(s.p(:,[3 6]))-median(s.m(:,[3 6])));
        pdif=(max(s.p(:,[3 6]))-min(s.p(:,[3 6])))*1e3;
        mdif=(max(s.m(:,[3 6]))-min(s.m(:,[3 6])))*1e3;
        fprintf('%s error:\n\tX sensor : p = %f mGauss m = %f mGauss\n\tY sensor : p = %f mGauss m = %f mGauss\n',names{k},pdif(1),mdif(1),pdif(2),mdif(2));
        namesp{k}=strcat(names{k},'+');
        namesm{k}=strcat(names{k},'-');
    end

    %concatinate arrays
    dat=vertcat(p{:},m{:});
    %extract offsets
    dat=dat(:,[3 6]);

    idx=reshape(ones(length(dat)/length(names)/2,1)*(1:length(names)),[],1);
    sn=sort([namesp namesm]);

    %options for boxplot
    boxoptions={'datalim',20e-3*[-1,1],'extrememode','compress'};

    figure(1);
    clf;

    boxplot(dat(:,1),{namesp{idx},namesm{idx}},'grouporder',sn,boxoptions{:});
    title(sprintf('%s SPB %s-axis',SPB,ax1_name));
    ylabel('Field offset variation [Gauss]');

    %save plot
    fig_export(fullfile('.','figures',[basename,SPB,'-' ax1_name '.pdf']));

    figure(2);
    clf;
    boxplot(dat(:,2),{namesp{idx},namesm{idx}},'grouporder',sn,boxoptions{:});
    title(sprintf('%s SPB %s-axis',SPB,ax2_name));
    ylabel('Field offset variation [Gauss]');


    %save plot
    fig_export(fullfile('.','figures',[basename,SPB,'-' ax2_name '.pdf']));

    figure(3);
    clf;
    bar(v)
    set(gca,'XtickLabel',names);
    ylabel('Torquer Flip Offset [Gauss]');
    %save plot
    fig_export(fullfile('.','figures',[basename,SPB,'-values.pdf']));

end