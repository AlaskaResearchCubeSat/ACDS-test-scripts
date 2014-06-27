function parm=mag_parm(cor,gain)
    %convert magnetomitor calibration values into datasheet values by using
    %the total gain (ADC and amplifier)
    s=size(cor);
    if(s(2)~=6)
        error('cor must have 6 columns');
    end
    %print cor
    %fmt=reshape(('% 12E ')'*ones(1,6),1,[]);
    %fmt(end:end+1)='\n';
    %for k=1:s(1)
    %    fprintf(char(fmt),cor(k,:));
    %end
    %calcualte values
    parm(:,1)=1e3*cor(:,5)./(cor(:,1).*cor(:,5)-cor(:,4).*cor(:,2))/gain/(2*2^16-1);
    parm(:,2)=-100*cor(:,2)./cor(:,5);
    parm(:,3)=1e3*(cor(:,2).*cor(:,6)-cor(:,5).*cor(:,3))./(cor(:,1).*cor(:,5)-cor(:,4).*cor(:,2))/gain/(2*2^16-1);
    
    parm(:,4)=1e3*cor(:,1)./(cor(:,1).*cor(:,5)-cor(:,4).*cor(:,2))/gain/(2*2^16-1);
    parm(:,5)=-100*cor(:,4)./cor(:,1);
    parm(:,6)=1e3*(cor(:,3).*cor(:,4)-cor(:,1).*cor(:,6))./(cor(:,1).*cor(:,5)-cor(:,4).*cor(:,2))/gain/(2*2^16-1);
    %check output arguments
    if(nargout==0)
        %print results
        for k=1:s(1)
                %print results
                fprintf(['Value  X\t\tY\t\t\tUnits\n',...
                         'Ss   %f\t%f\tmV/V/Gauss\n',...
                         'Ds   %f%%\t%f%%\n',...
                         'Vos  %f\t%f\t\tmV/V\n'],parm(k,1),parm(k,4),parm(k,2),parm(k,5),parm(k,3),parm(k,6));
        end
    end
end