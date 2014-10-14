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
    %set to landscape
    %set(h,'PaperOrientation','landscape');
    %rotate page size so it looks correct
    set(h,'PaperSize',fliplr(get(h,'PaperSize')));
    %set to normalized units
    set(h,'PaperUnits','normalized');
    %set to fill page
    set(h,'PaperPosition', [0 0 1 1]);
    %generate print
    print(h,'-painters','-dpdf','-r600',file);
end