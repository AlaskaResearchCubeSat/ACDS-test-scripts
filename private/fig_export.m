function fig_export(h,file)
    if nargin<2
        %if only one argument given then treat it as the filename
        file=h;
        %set h to current figure
        h=gcf();
    end
    
    %split filename
    [path,basename,ext]=fileparts(file);
    if(~strcmp(ext,'.pdf'))
        ext='.pdf';
        warning('Figure export type changed to PDF')
    end
    %recombine filename
    file=fullfile(path,[basename,ext]);
    %set to points units
    set(h,'PaperUnits','points');
    %get pagesize
    psize=get(h,'PaperSize');
    %put page size in landscape order
    psize=sort(psize,1,'descend');
    %set new size
    set(h,'PaperSize',psize);
    %set to fill page
    set(h,'PaperPosition', [0 0 psize]);
    %generate print
    print(h,'-painters','-dpdf','-r600',file);
end