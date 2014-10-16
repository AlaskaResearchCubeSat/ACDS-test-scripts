function [erms]=HCtst(a)
    %test the helmholtz cage
    
    if(~exist('a','var') || isempty(a))
        %if no transform is given then use unity
        %coult use identity matrix but 1 is faster and will work
        a=1;
        inva=1;
    else
        if size(a)~=[3 3]
            error('a must be a 3x3 matrix')
        end
        %calculate inverse to correct for measurments
        inva=inv(a);
    end
   
    try
        cc=cage_control();
        cc.loadCal('calibration.cal');
        
        %theta=linspace(0,2*pi,60);
        %Bs=0.5*[sin(theta);cos(theta);0*theta];
        
        theta=linspace(0,8*pi,500);
        Bs=1/30*[theta.*sin(theta);theta.*cos(theta);0*theta];
        
        %allocate for sensor
        meas=zeros(size(Bs));
        %set initial field
        cc.Bs=Bs(:,1);
        %give extra settaling time
        pause(1);
        
        for k=1:length(Bs)
            cc.Bs=a*Bs(:,k);
            %pause to let the supply settle
            %pause(0.1);
            pause(1);
            %make measurment using sensor
            meas(:,k)=inva*cc.Bm';
        end
        %create dat directory
        quiet_mkdir(fullfile('.','dat'));
        %get unique file name
        savename=unique_fliename(fullfile('.','dat','HCtst.mat'));
        %save data
        save(savename,'-regexp','^(?!(cc)$).');
        %generate plots from datafile
        erms=HCtst_plot(savename);
    catch err
        if exist('cc','var')
            delete(cc);
        end
        rethrow(err);
    end
    if exist('cc','var')
        delete(cc);
    end
end
