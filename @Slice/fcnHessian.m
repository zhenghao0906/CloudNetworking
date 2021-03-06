%% Hessian matrix of the Lagrangian
% Called by _singleSliceOptimization_;
% To accelarate executing the function, no thorough arguments checking will be done. 
% Throw errors, if necessary fields are not provided.
%%
% Since the problem only contains linear constraint, the Hessian matrix of the
% Lagrangian is equal to the second-derivatives of the objective function, and the
% Lagrangian multipliers $\lambda$ takes no effect.
%
% the Hessian matrix contains only $P\times P$ non-zeros elements on the diagonal,
% which is the second derivatives on path variables.
%
% $$\frac{\partial f}{\partial x(p)^2} =
%    \frac{w\cdot q_{i_p,p_0}}
%    {(1+\sum_{p_0\in\mathcal{P}}{q_{i_p,p_0}\cdot x_{p_0}})^2}$$
%% Method declaration
%   hess = fcnHessian(vars, lambda, slice, options)
%
% options:
%   # PricingPolicy:
%   # bCompact: 'true' for compact mode, which reduce the problem scale.
function hs = fcnHessian(vars, lambda, this, options) %#ok<INUSL>
if isfield(options, 'bCompact') && options.bCompact
    full_vars = zeros(options.num_orig_vars,1);
    full_vars(this.I_active_variables) = vars;
    vars = full_vars;
end

if isempty(this.weight)
    weight = this.FlowTable.Weight;    % for single slice;
else
    weight = this.weight*ones(this.NumberFlows, 1);  % for multiple slices
end
NP = this.NumberPaths;
hs = spalloc(length(vars),length(vars), NP^2);
var_path = vars(1:NP);
for p = 1:NP
    i = this.path_owner(p);
    hs(p,1:NP) = weight(i)*...
        this.I_flow_path(i,:)/(1+(this.I_flow_path(i,:)*var_path))^2; %#ok<SPRIX>
end

if nargin >= 4 && isfield(options, 'PricingPolicy')
    switch options.PricingPolicy
        case {'quadratic-price', 'quadratic'}
            %% quadratic-price
            % Second derivatives on the link payment componet:
            %
            % $$ \frac{\partial \rho_L}{\partial x_p \partial x_{\hat{p}}} =
            %        \frac{\partial (\sum_{e\in p}{\rho^{'}_e\cdot g_{e,p}})}{\partial x_{\hat{p}}} =
            %        \sum_{e\in p}{\frac{\partial \rho^{'}_e}{\partial x_{\hat{p}}}\cdot g_{e,p}} =
            %        \sum_{e\in p}{g_{e,p}\frac{\partial \rho^{'}_e}{\partial y_e}
            %        \frac{\partial y_e}{\partial x_{\hat{p}}}} = $$
            % $$\sum_{e\in p}{g_{e,p}\cdot\rho_e^{''}\cdot g_{e,\hat{p}}}$$
            %
            % Then, for all paths, the hessian matrix component can represented by 
            % $G^T D_e\c G$, where matrix $G(e,p) = g_{e,p}$, $D_e$ is the
            % diagnoal matrix for $\rho_e^{''}$.
            [~,~,lph] = this.fcnLinkPricing(this.prices.Link, this.getLinkLoad(var_path)); % equal to <getLinkCapacity>
            h1 = (this.I_edge_path') * diag(lph) * this.I_edge_path;
            hs(1:NP, 1:NP) = hs(1:NP, 1:NP) + h1;
            var_node = vars((NP+1):this.num_vars);
            [~,~,nph] = this.fcnNodePricing(this.prices.Node, this.getNodeLoad(var_node));
            NC = this.NumberDataCenters;
            %%%
            % Second derivatives on the node payment componet:
            % 
            % $$ \frac{\partial \rho_V}{\partial z_{npf} \partial z_{\hat{n}\hat{p}\hat{f}}} =
            %    h_{p,n}\cdot\rho_n^{''}\cdot h_{\hat{p},\hat{n}},~~n=\hat{n}
            % $$
            % 
            % Since, only when $n\ne\hat{n}$, we have the derivatives equal 0. The NC*NC
            % block of the hessian matrix of the |z| part is a diagnoal. The hessian
            % matrix of z part the following form,
            %
            %          n1p1f1 n2p1f1 ... nNp1f1, n1p2f1 n2p2f1 ... nNp2f1, ...
            %   n1p1f1    *
            %   n2p1f1          *
            %   ...                   .
            %   nNp1f1                     *
            %   n1p2f1                            *
            %   n2p2f1                                    *
            %   ...                                            ...
            %   nNp2f1                                                *   ...
            h2 = spalloc(NP*NC, NP*NC, NP*NP*NC);
            z_index1 = 1:NC;
            for p1 = 1:NP
                z_index2 = 1:NC;
                for p2 = 1:p1           
                    % we only calculate the lower triangle, and use the symetric property
                    % to fill the upper triangle.
                    h2(z_index1,z_index2) = ...
                        diag(this.I_node_path(:,p1) .* nph .* this.I_node_path(:,p2)); %#ok<SPRIX>
                    z_index2 = z_index2 + NC;
                end
                z_index1 = z_index1 + NC;
            end
            h2 = h2 + (tril(h2,-1))';   % fill the upper triangle since the
            h2 = repmat(h2, this.NumberVNFs, this.NumberVNFs);
            hs((NP+1):this.num_vars, (NP+1):this.num_vars) = h2;
        case 'linear'
        otherwise
            error('%s: invalid pricing policy', calledby);
    end
end
if isfield(options, 'bCompact') && options.bCompact
    hs = hs(this.I_active_variables, this.I_active_variables);
end
end
