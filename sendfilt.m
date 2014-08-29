function sendfilt(sobj,b,a)
%sendfilt Send filter coefficents to microcontroller
%   Detailed explanation goes here

%if a not given assume FIR
if(nargin<3)
    a=[1];
end

if ~isvector(b)
    error('b must be a vector');
end
b=reshape(b,1,[]);

%make sure a is a vector
if ~isvector(a)
    error('a must be a vector');
end
a=reshape(a,1,[]);

%check that the first element of a is 1
if(a(1)~=1)
    error('first element of a must be 1 but %i found',a(1));
end

%get filter orders
na=length(a);
nb=length(b);

%tell microcontroller we are sending a filter
command(sobj,'filter new');
%get line from file
line=fgetl(sobj);
%strip line endings
line=deblank(line);
%parse line
[n,nr,e]=sscanf(line,'Ready for filter upload na=%i nb=%i');
%check if there was an error
if(~isempty(e))
    error('could not parse line "%s", "%s" returned',line,e);
end

if(nr~=2)
    fprintf(sobj,'abort');
    error('Failed to parse string "%s"',line);
end

%get sizes for a and b
asize=n(1);
bsize=n(2);

%calculate number of zeros to add to a and b
a_zeros=asize-(length(a)-1);
b_zeros=bsize-length(b);

if(a_zeros<0)
    fprintf(sobj,'abort');
    error('maximum size for a is %i',asize+1);
end

if(b_zeros<0)
    fprintf(sobj,'abort');
    error('maximum size for b is %i',bsize);
end

%print a values
str=sprintf('%.20G, ',[a(2:end),zeros(1,a_zeros)]);
str=str(1:(end-2));         %remove trailing comma
fprintf(sobj,'%s\n',str);
fprintf('%s\n',str);
%print b
str=sprintf('%.20G, ',[b,zeros(1,b_zeros)]);
str=str(1:(end-2));         %remove trailing comma
fprintf(sobj,'%s\n',str);
fprintf('%s\n',str);

str=sprintf('na = %i nb = %i\n',length(a)-1,length(b));
%print filter orders
fprintf(sobj,'%s',str);
fprintf('%s',str);

%get line with error or success
line=fgetl(sobj);
%strip line endings
line=deblank(line);
%prefix in case of an error
errorprefix='Error : ';
%check for error prefix
if(strncmp(line,errorprefix,length(errorprefix)))
    error(line);
end
fprintf('%s\n',line);


end

