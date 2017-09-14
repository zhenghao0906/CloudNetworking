%% Optimization in Single Slice 
% Optimize the resource allocation in a single slice.
%   All service flows are placed in one slice.
%   The VNFs in a slice are treated as one function.
%
% * *NOTE*: with the same optimal objective value, the two methods may result in different
% solutions.
% * *TODO*: to remove the unused VNFs from the single slice, check if b_vnf functions
% right with |I_path_function| and the output.
% * *TODO*: the solution of |'single-function'| is infeasible.
% 
%%
function [output, runtime] = singleSliceOptimization( this, options )
if nargin <= 1
    options.Display = 'final';
    options.Method = 'normal';
else
    if ~isfield(options, 'Display')
        options.Display = 'final';
    end
    if ~isfield(options, 'Method')
        options.Method = 'normal';
    elseif ~strcmpi(options.Method, 'normal') && ~strcmpi(options.Method, 'single-function') 
        error('error: invalid method (%s)', options.Method);
    end
end
% this.clearStates;

%% Merge slices into one single big slice
NL = this.NumberLinks;
NN = this.NumberNodes;
NS = this.NumberSlices;
NP = this.NumberPaths;
slice_data.adjacent = this.graph.Adjacent;
slice_data.link_map_S2P = (1:NL)';
slice_data.link_map_P2S = (1:NL)';
slice_data.link_capacity = this.getLinkField('Capacity');
slice_data.node_map_S2P = (1:NN)';
slice_data.node_map_P2S = (1:NN)';
slice_data.node_capacity = this.getDataCenterField('Capacity');
slice_data.flow_table = table([],[],[],[],[],[],[],'VariableNames',...
    {this.slices{1}.FlowTable.Properties.VariableNames{:,:},'Weight'});
NF = this.NumberFlows;
flow_owner = zeros(NF, 1);
nf = 0;
% b_vnf = false(this.NumberVNFs, 1);
if strcmp(options.Method, 'single-function')
    slice_data.alpha_f = zeros(NS, 1);
end
slice_data.ConstantProfit = 0;
for s = 1:NS
    sl = this.slices{s};
    new_table = sl.FlowTable;
    % Map the virtual nodes to physical nodes.
    new_table.Source = sl.VirtualNodes{new_table.Source, {'PhysicalNode'}};
    new_table.Target = sl.VirtualNodes{new_table.Target, {'PhysicalNode'}};
    for f = 1:height(sl.FlowTable)
        % path_list is handle object, is should be copyed to the new table.
        path_list = PathList(sl.FlowTable{f,'Paths'});
        for p = 1:path_list.Width
            path = path_list.paths{p};
            path.node_list = sl.VirtualNodes{path.node_list,{'PhysicalNode'}};
        end
        new_table{f,'Paths'} = path_list;
    end
    new_table.Weight = sl.weight*ones(height(new_table),1);
    slice_data.flow_table = [slice_data.flow_table; new_table];
    flow_owner(nf+(1:sl.NumberFlows)) = s;
    nf = nf + sl.NumberFlows;
    if strcmp(options.Method, 'normal')
%         b_vnf(this.slices{s}.VNFList) = true;
    elseif strcmp(options.Method, 'single-function')
        slice_data.alpha_f(s) = sum(this.VNFTable{sl.VNFList,{'ProcessEfficiency'}});
    end
    slice_data.ConstantProfit = slice_data.ConstantProfit; % + sl.constant_profit; 
end
if strcmp(options.Method, 'normal')
    slice_data.VNFList = 1:this.NumberVNFs;
%     slice_data.VNFList = find(b_vnf);
else    % single-function
    slice_data.VNFList = 1;
end
slice_data.parent = this;
% NV might not be the true number of VNFs when the method is 'single-function'
NV = length(slice_data.VNFList);        
% the flow id and path id has been allocated in each slice already, no need to reallocate.
ss = Slice(slice_data);
I_flow_function = zeros(NF, this.NumberVNFs);
for f = 1:NF
    I_flow_function(f, this.slices{flow_owner(f)}.VNFList) = 1;
end
ss.I_path_function = ss.I_flow_path'*I_flow_function;

if nargout == 2
    tic;
end
net_profit = ss.optimalFlowRate(options);
if nargout == 2
    runtime.Serial = toc;
    runtime.Parallel = runtime.Serial;
end
output.welfare_approx_optimal = net_profit;
output.welfare_accurate_optimal = sum(ss.FlowTable.Weight.*fcnUtility(ss.FlowTable.Rate)) ...
    - this.getNetworkCost(ss.VirtualDataCenters.Load, ss.VirtualLinks.Load, 'Accurate');
    %     + ss.constant_profit; => move toCLoudNetworkEx;
% if ~isempty(this.eta)
%     embed_profit_approx = this.eta * ...
%         this.getNetworkCost(ss.VirtualNodes.Load, ss.VirtualLinks.Load, 'Approximiate');
%     embed_profit_accurate = this.eta * ...
%         this.getNetworkCost(ss.VirtualNodes.Load, ss.VirtualLinks.Load, 'Accurate');
% else
%     embed_profit_approx = 0;
%     embed_profit_accurate = 0;   
% end
% output.welfare_approx_optimal = output.welfare_approx_optimal + embed_profit_approx;
% output.welfare_accurate_optimal = output.welfare_accurate_optimal + embed_profit_accurate;
if ~strcmp(options.Display, 'off') && ~strcmp(options.Display, 'none')
    fprintf('\tThe optimal net social welfare of the network: %G.\n', ...
        output.welfare_approx_optimal);
end

%% Partition the network resources according to the global optimization
pid_offset = 0;
NC = this.NumberDataCenters;
if strcmp(options.Method, 'single-function')    % TODO
    z_npf = reshape(full(ss.Variables.z), NC, NP, this.NumberVNFs);
elseif strcmp(options.Method, 'normal')
    z_npf = reshape(full(ss.Variables.z), NC, NP, NV);
end
options.Tolerance = 10^-2;
% node_load = zeros(this.NumberNodes, 1);
% link_load = zeros(this.NumberLinks, 1);
for s = 1:NS
    sl = this.slices{s};
    pid = 1:sl.NumberPaths;
    sl.x_path = ss.Variables.x(pid_offset+pid);
    nid = sl.getDCPI;       % here is the DC index, not the node index.
    vid = sl.VNFList;
    sl.z_npf = ...
        reshape(z_npf(nid,pid+pid_offset,vid),sl.num_vars-sl.NumberPaths, 1);
    pid_offset = pid_offset + sl.NumberPaths;
    if ~sl.checkFeasible([sl.x_path; sl.z_npf], options)
        error('error: infeasible solution.');
    end
    sl.VirtualDataCenters.Capacity = sl.getNodeLoad(sl.z_npf);
    sl.VirtualLinks.Capacity = sl.getLinkLoad(sl.x_path);
    % DEBUG
%     eid = sl.VirtualLinks.PhysicalLink;
%     node_load(nid) = node_load(nid) + sl.VirtualNodes.Capacity;
%     link_load(eid) = link_load(eid) + sl.VirtualLinks.Capacity;
end
% disp(max(node_load-this.getNodeField('Capacity')));
% disp(max(link_load-this.getLinkField('Capacity')));

%% Compute the real resource demand with given prices
options.Method = 'slice-price';
if nargout == 2
    [node_price, link_price, rt] = pricingFactorAdjustment(this, options);
    runtime.Serial = runtime.Serial + rt.Serial;
    runtime.Parallel = runtime.Parallel + rt.Parallel;
else
    [node_price, link_price] = pricingFactorAdjustment(this, options);
end
% Finalize substrate network
this.finalize(node_price, link_price);

%% Calculate the output
% the profit type with |Percent| has been deprecated.
if cellstrfind(options.ProfitType, 'Percent')
    warning('the profit type with Percent has been deprecated.');
end
output = this.calculateOutput(output, options);
output.SingleSlice = ss;
end