%% Network Visualizer
%  Visualize Substrate Network and Network Slices
% * |b_undirect|: if this argument is set to |true|, draw the network as undirected graph.
function plot(this, b_undirect)
if nargin < 2
    b_undirect = false;
end
num_figure = this.NumberSlices+1;
plot_col = ceil(sqrt(num_figure));
plot_row = ceil(num_figure/plot_col);
h1 = subplot(plot_row,plot_col, 1);
if b_undirect
    g = graph(this.Topology.adjacency+this.Topology.adjacency');
    g.plot('XData',this.Topology.Nodes.Location(:,1), ...
        'YData', this.Topology.Nodes.Location(:,2), ...
        'NodeLabel', 1:this.NumberNodes, ...
        'MarkerSize', 5,...
        'LineWidth', 1.5, ...
        'NodeColor', PhysicalNetwork.NodeColor(1,:), ...
        'EdgeColor', PhysicalNetwork.EdgeColor(1,:));
else
    this.Topology.plot('XData',this.Topology.Nodes.Location(:,1), ...
        'YData', this.Topology.Nodes.Location(:,2), ...
        'EdgeLabel', this.Topology.Edges.Index, ...
        'NodeLabel', 1:this.NumberNodes, ...
        'MarkerSize', 5,...
        'LineWidth', 1.5, ...
        'NodeColor', PhysicalNetwork.NodeColor(1,:), ...
        'EdgeColor', PhysicalNetwork.EdgeColor(1,:));
end
title('Substrate Network');
for i = 2:num_figure
    h = subplot(plot_row,plot_col, i);
    node_label = cell(this.slices{i-1}.NumberVirtualNodes,1);
    for j = 1:this.slices{i-1}.NumberVirtualNodes
        node_label{j} = sprintf('%d(%d)', ...
            j, this.slices{i-1}.VirtualNodes.PhysicalNode(j));
    end
    if b_undirect
        g = graph(this.slices{i-1}.Topology.Adjacent+...
            this.slices{i-1}.Topology.Adjacent');
        g.plot(...
            'XData', ...
            this.Topology.Nodes.Location(this.slices{i-1}.VirtualNodes.PhysicalNode,1),...
            'Ydata', ...
            this.Topology.Nodes.Location(this.slices{i-1}.VirtualNodes.PhysicalNode,2),...
            'NodeLabel', node_label,...
            'MarkerSize', 5,...
            'LineWidth', 1.5, ...
            'EdgeColor', ...
            PhysicalNetwork.EdgeColor(mod(i-1,length(PhysicalNetwork.EdgeColor))+1,:), ...
            'NodeColor', ...
            PhysicalNetwork.NodeColor(mod(i-1,length(PhysicalNetwork.NodeColor))+1,:));
    else
        dg = digraph(this.slices{i-1}.Topology.Adjacent);
        [s,t] = dg.findedge;
        idx = this.slices{i-1}.Topology.IndexEdge(s,t);
        edge_label = cell(this.slices{i-1}.NumberVirtualLinks,1);
        for j = 1:this.slices{i-1}.NumberVirtualLinks
            eid = idx(j);
            edge_label{j} = sprintf('%d(%d)',...
                eid, this.slices{i-1}.VirtualLinks.PhysicalLink(eid));
        end
        dg.plot(...
            'XData', ...
            this.Topology.Nodes.Location(this.slices{i-1}.VirtualNodes.PhysicalNode,1),...
            'Ydata', ...
            this.Topology.Nodes.Location(this.slices{i-1}.VirtualNodes.PhysicalNode,2),...
            'EdgeLabel', edge_label,...
            'NodeLabel', node_label,...
            'MarkerSize', 5,...
            'LineWidth', 1.5, ...
            'EdgeColor', ...
            PhysicalNetwork.EdgeColor(mod(i-1,length(PhysicalNetwork.EdgeColor))+1,:), ...
            'NodeColor', ...
            PhysicalNetwork.NodeColor(mod(i-1,length(PhysicalNetwork.NodeColor))+1,:));
    end
    title(sprintf('Network slice (%d)',i-1));
    h.XLim = h1.XLim;
    h.YLim = h1.YLim;
end