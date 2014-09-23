function A=make_spb_rot(bx,by)
    %function A=make_spb_rot(bx,by)
    %   generates a rotation matrix to transform measurements that are
    %   measured in the axes bx and by into the x and y axes, respectively

    %check if input arguments are vectors
    if(~isvector(bx) || ~isvector(by))
        error('''bx'' and ''by'' must be vectors');
    end
    %make column unit vectors
    bx=bx(:)/norm(bx);
    by=by(:)/norm(by);
    %check for orthoganal vectors
    if(dot(bx,by))
        error('''bx'' and ''by'' must be orthoganal')
    end
    %calculate rotation matrix 
    A=[bx,by,cross(bx,by)];
    %calculate the inverse transform (A'=A^-1 for a rotation matrix)
    A=A';
end
