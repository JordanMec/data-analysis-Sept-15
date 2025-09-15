function plot_scalar_ranges(rangeTable, metricName, figuresDir, categories, colorMap)
% PLOT_SCALAR_RANGES  Plot mean values with tight/leaky ranges as error bars.
%   rangeTable : table produced by build_range_table
%   metricName : name of metric to visualize
%   figuresDir : folder to save output PNG
%   categories : (optional) cell array specifying global category order
%   colorMap   : (optional) Nx3 array of RGB colors matching categories

rows = rangeTable(strcmp(rangeTable.metric, metricName), :);
if isempty(rows)
    warning('Metric %s not found in rangeTable.', metricName);
    return;
end

% Create combined category labels for current metric
cats = strcat(strrep(rows.location,'_','-'), "-", ...
             strrep(rows.filterType,'_','-'), "-", ...
             strrep(rows.mode,'_','-'));

% Determine plotting order based on provided global categories
if nargin >= 4 && ~isempty(categories)
    [~, idx] = ismember(cats, categories);
    valid = idx > 0;
    cats = cats(valid);
    rows = rows(valid, :);
    idx = idx(valid);
    [~, sortIdx] = sort(idx);
    rows = rows(sortIdx, :);
    cats = cats(sortIdx);
    idx = idx(sortIdx);
    if nargin < 5 || isempty(colorMap)
        colorMap = get_color_palette(numel(categories));
    end
    colors = colorMap(idx, :);
else
    % Sort rows to maintain consistent order across metrics
    rows = sortrows(rows, {'location','filterType','mode'});
    colors = get_color_palette(height(rows));
end

if nargin < 3 || isempty(figuresDir)
    figuresDir = fullfile(pwd, 'figures');
end
if ~exist(figuresDir, 'dir')
    mkdir(figuresDir);
end

figure('Visible','off'); hold on;

% Plot bars representing mean values
b = bar(1:height(rows), rows.mean, 'FaceColor','flat');
b.CData = colors;

% Overlay error bars showing tight/leaky range
errorbar(1:height(rows), rows.mean, ...
    rows.mean - rows.lower_bound, rows.upper_bound - rows.mean, ...
    'k', 'LineStyle','none', 'LineWidth',1.5, 'CapSize',8);
xticks(1:height(rows));
xticklabels(cats);
xtickangle(45);
ylabel(metricName, 'Interpreter','none');
title(sprintf('Range: %s (tight vs. leaky)', metricName), 'Interpreter','none');
grid on;

fname = sprintf('%s_range.png', metricName);
save_figure(gcf, figuresDir, fname);
close(gcf);
end