function fig_export(h,file)
    if nargin<2
        %if only one argument given then treat it as the filename
        file=h;
    end
    print('-depsc2','-painters','-r200',file);
end