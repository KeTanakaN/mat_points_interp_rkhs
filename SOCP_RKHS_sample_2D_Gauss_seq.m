clear all;
close all;
dir_smp = './DataSmpSeq/'; % Directory to save the data of the sampling points

addpath('C:\Program Files\Mosek\8\toolbox\r2014a');

n_arr = [8, 12, 16, 20, 24, 28, 32, 35]; % Array of the number of sampling points (integers)

w_fix_idx = [];
for n_idx = 1:length(n_arr)
    n = n_arr(n_idx);
    l = n; % l = n
    
    display(strcat('Processing the case n=', num2str(n), '.....'));

    %% Region and candidate points
    % Choose a region
    % ([-1,1] * [-1,1])
%     dom = @(x,y)(-1<=x && x<=1 && -1<=y && y<=1); 
%     k = 23; % Number of the division of each axis
%     prefix = 'sqr';
    % (A triangle in [-1,1] * [-1,1])
%     dom = @(x,y)(x+y>=0 && x<=1 && y<=1); 
%     k = 32; % Number of the division of each axis
%     prefix = 'tri';
    % (A circle in [-1,1] * [-1,1])
    dom = @(x,y)(x^2+y^2<=1); 
    k = 27; % Number of the division of each axis
    prefix = 'dsk';

    x = linspace(-1,1,k);
    y = linspace(-1,1,k);
    X = zeros(1,2,k*k);

    p = 0;
    idx = [];
    for i=1:k
        for j=1:k
            p = p+1;
            X(:,:,p) = [x(i), y(j)];
            if(dom(X(1,1,p), X(1,2,p)))
                idx = [idx, p];
            end
        end
    end

    m = length(idx); % Number of candidates

    %% Vectors of the sampled eigenfunctions
    tic;
    % Gaussian kernel
    eps = 1;
    alp = 1;
    n_p = ceil(sqrt(2*n));
    a = [];
    for i=1:m
        ii = idx(i);
        [lam_x, tmp_x] = func_Gauss_eigen(eps, alp, [1:n_p], X(1,1,ii)); 
        [lam_y, tmp_y] = func_Gauss_eigen(eps, alp, [1:n_p], X(1,2,ii)); 
        count = 0;
        tmp = [];
        for s=1:n_p
            for t=1:s
                if(count >= n)
                    break;
                end
                tmp = [tmp, tmp_x(s+1-t)*tmp_y(t)];
                count = count+1;
            end
        end
        a = [a; tmp];
    end
    a = a';
    toc;

    %% Solving D-optimal design by SOCP.
    tic;
%    [V, prob] = func_make_prob_Dopt_by_SOCP_wfix(l, m, n, a, w_fix_idx);
    [V, prob] = func_make_prob_Dopt_by_SOCP_wfix_sparse(l, m, n, a, w_fix_idx);
    toc;
    tic;
    [r, res] = mosekopt('maximize',prob); % MOSEK optimizer
    toc;
    
    % The primal solution and weights.
    p_sol = res.sol.itr.xx';
    w = 2*p_sol(V-m+1:V);

%     display(w);
%     stem3(X(1,1,idx), X(1,2,idx), w, 'filled');
%     title('weight (3D)');
%     xlim([-1,1]);
%     ylim([-1,1]);
% 
%     pause;

    %% Choosing sampling points
    idx_smpl = [];
    for i=1:m
       crd = idx(i);
       if(mod(crd,k)==0)
           idx_neigh = find(idx==crd-1 | idx==crd-k | idx==crd+k);
       elseif(mod(crd,k)==1) 
           idx_neigh = find(idx==crd+1 | idx==crd-k | idx==crd+k);
       else
           idx_neigh = find(idx==crd-1 | idx==crd+1 | idx==crd-k | idx==crd+k);
       end

       if(prod(w(i) > w(idx_neigh)))
            idx_smpl = [idx_smpl, i];   
       end   
    end

    % plot of all the local maxima
%     scatter(X(1,1,idx(idx_smpl)), X(1,2,idx(idx_smpl)), 'filled');
%     xlim([-1,1]);
%     ylim([-1,1]);
% 
%     pause;

    tmp_w_i = [w(idx_smpl)',idx_smpl'];
    tmp_w_i = sortrows(tmp_w_i, 'descend');
    if(length(tmp_w_i)>=n)
        % output and plot of the sampling points
        w_i = tmp_w_i(1:n,:);  % choosing the first n points
        w_fix_idx = w_i(:,2); % storing the indices of the weights that are fixed in the next iteration.
        smpl = X(:,:,idx(w_fix_idx));
        display(smpl);
        scatter(smpl(1,1,:), smpl(1,2,:), 'filled');
        xlim([-1,1]);
        ylim([-1,1]);
        % output to a file
        filename = strcat(dir_smp,'Gauss2D_', prefix ,'_smp_seq','_n_', num2str(n), '.txt');
%         dlmwrite(filename, reshape(smpl, [2,n])');
    else
        display('The number of local maximums is less than n.');
    end

%    pause;
    
end