%get a data block from instrament
function dat=get_block(obj,blkType)
    %set defaults
    if nargin<2
        blkType='int8';
        datSize=1;
    end
    %check for numerical block type
    if isa(blkType,'numeric')
        datSize=blkType;
        switch blkType
            case 1
                blkType='int8';
            case 2
                blkType='int16';
            case 4
                blkType='int32';
            case 8
                blkType='int64';
            otherwise
                error('Invalid Data size for Data block');
        end
    else
        %TODO: make this work for real
        datSize=2;
    end
    %get block header
    s=fread(obj,2);
    %check first char, should be '#'
    if s(1)~='#'
        fgetl(obj)
        error('Invalid data block prefix');
    end
    %seccond char is number of bytes to read for block length
    num=s(2)-'0';
    if num<=0 || num>9
        error('Invalid data block length')
    end
    %read block length
    s=fread(obj,num);
    %reshape into a string
    s=reshape(s,1,[]);
    %get block length
    num=str2double(char(s));
    %read data block
    dat=fread(obj,num/datSize,blkType);
    %read terminator
    c=fread(obj,1,'char');
    %check to see that terminator was output
    if all(c=='\r') || all(c=='\n')
        %print error but don't abort
        fprintf(2,'Error : extra data \"%s\" after data block\n',s);
    end
end