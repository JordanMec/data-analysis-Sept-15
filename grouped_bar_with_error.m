function grouped_bar_with_error(categories, filters, values, errLow, errHigh, colors, yLabel, titleStr, savePath)
%GROUPED_BAR_WITH_ERROR Create a grouped bar plot with error bars.
% categories - cell array of scenario names (groups along x-axis)
% filters    - cell array of filter names (series within each group)
% values     - matrix of mean values (nScenarios x nFilters)
% errLow/errHigh - matrices of lower and upper error bars (same size as values)
% colors     - nFilters x 3 matrix of RGB colors. If empty, lines(nFilters).
% yLabel     - y-axis label string
% titleStr   - plot title string
% savePath   - optional path to save the figure

if nargin < 6 || isempty(colors)
    colors = lines(numel(filters));
end
fig = create_hidden_figure();
ax  = nexttile;

ngroups = size(values,1);
nbars   = size(values,2);

% Manually position bars to avoid issues when only one group exists
groupWidth = min(0.8, nbars/(nbars + 1.5));
barWidth   = groupWidth / nbars;
centers    = 1:ngroups;

hold(ax, 'on');
b = gobjects(1, nbars);
for i = 1:nbars
    x = centers - groupWidth/2 + (i-0.5)*barWidth;
    b(i) = bar(ax, x, values(:,i), 'BarWidth', barWidth, 'FaceColor', colors(i,:));
    errorbar(ax, x, values(:,i), errLow(:,i), errHigh(:,i), 'k', 'LineStyle','none');
end

ax.XTick = centers;
ax.XTickLabel = categories;
ylabel(ax, yLabel);
legend(ax, filters, 'Location','best');
title(ax, titleStr);
xtickangle(ax,45);
ax.YGrid = 'on';

add_figure_caption(fig, sprintf(['The grouped bar chart titled "%s" compares %s for each scenario, with color-coded series for every filter and error bars showing the provided bounds.' newline ...
    'Category labels on the x-axis and the legend tie each cluster to its scenario so differences in both magnitude and uncertainty stand out.'], titleStr, yLabel));
if nargin >= 9 && ~isempty(savePath)
    saveas(fig, savePath);
end
close(fig);
end
