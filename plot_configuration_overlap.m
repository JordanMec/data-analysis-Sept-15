function plot_configuration_overlap(costTable, figuresDir)
% PLOT_CONFIGURATION_OVERLAP Visualize overlap between configuration bounds
% Shows when different interventions have overlapping performance ranges

if isempty(costTable)
    warning('plot_configuration_overlap: no data provided, skipping plot.');
    return;
end

fig = figure('Visible', 'off');
set_figure_fullscreen(fig);

% Get configurations
configs = unique(costTable(:, {'location', 'filterType', 'mode'}));
nConfigs = height(configs);

% Create configuration labels
labels = cell(nConfigs, 1);
for i = 1:nConfigs
    labels{i} = sprintf('%s-%s-%s', ...
        configs.location{i}(1:3), ...
        configs.filterType{i}(1:4), ...
        configs.mode{i}(1:min(6,end)));
end

%% Panel 1: PM2.5 Reduction Overlap
subplot(2,2,1);
hold on;

% Extract PM2.5 reduction bounds
pm25_means = zeros(nConfigs, 1);
pm25_lower = zeros(nConfigs, 1);
pm25_upper = zeros(nConfigs, 1);

for i = 1:nConfigs
    row = costTable(strcmp(costTable.location, configs.location{i}) & ...
        strcmp(costTable.filterType, configs.filterType{i}) & ...
        strcmp(costTable.mode, configs.mode{i}), :);

    if ~isempty(row)
        pm25_means(i) = row.percent_PM25_reduction;
        if ismember('percent_PM25_reduction_lower', row.Properties.VariableNames)
            pm25_lower(i) = row.percent_PM25_reduction_lower;
            pm25_upper(i) = row.percent_PM25_reduction_upper;
        else
            % Fallback if bounds columns don't exist
            pm25_lower(i) = pm25_means(i) * 0.9;
            pm25_upper(i) = pm25_means(i) * 1.1;
        end
    end
end

% Sort by mean value
[~, sortIdx] = sort(pm25_means, 'descend');

% Plot ranges as horizontal bars
y = 1:nConfigs;
for i = 1:nConfigs
    idx = sortIdx(i);
    % Color based on filter type
    if contains(configs.filterType{idx}, 'hepa', 'IgnoreCase', true)
        color = [0.2 0.4 0.8];
    else
        color = [0.8 0.3 0.3];
    end

    % Plot range
    plot([pm25_lower(idx), pm25_upper(idx)], [i, i], ...
        'Color', color, 'LineWidth', 6);

    % Plot mean
    plot(pm25_means(idx), i, 'ko', 'MarkerSize', 8, 'MarkerFaceColor', 'w');
end

set(gca, 'YTick', y, 'YTickLabel', labels(sortIdx));
xlabel('Particulate Matter 2.5 Reduction (Percent)');
title('Fine Particulate Matter Reduction with Envelope Bounds');
grid on;

% Add legend for filter types without obscuring data
uniqFilters = unique(configs.filterType, 'stable');
legHandles = gobjects(numel(uniqFilters),1);
for f = 1:numel(uniqFilters)
    if contains(uniqFilters{f}, 'hepa', 'IgnoreCase', true)
        c = [0.2 0.4 0.8];
    else
        c = [0.8 0.3 0.3];
    end
    legHandles(f) = plot(NaN, NaN, '-', 'Color', c, 'LineWidth', 6);
end
% Use more descriptive names in the legend
displayNames = cell(size(uniqFilters));
for f = 1:numel(uniqFilters)
    switch lower(strrep(uniqFilters{f}, '_', ' '))
        case {'hepa', 'hepa filter'}
            displayNames{f} = 'HEPA Filter';
        case {'merv', 'merv filter'}
            displayNames{f} = 'MERV Filter';
        case 'baseline'
            displayNames{f} = 'Baseline';
        otherwise
            displayNames{f} = strrep(uniqFilters{f}, '_', ' ');
    end
end
legend(legHandles, displayNames, 'Location', 'best');

% Highlight overlapping regions
for i = 1:nConfigs-1
    for j = i+1:nConfigs
        idx1 = sortIdx(i);
        idx2 = sortIdx(j);
        overlap_start = max(pm25_lower(idx1), pm25_lower(idx2));
        overlap_end = min(pm25_upper(idx1), pm25_upper(idx2));
        if overlap_start < overlap_end
            % There's overlap
            patch([overlap_start overlap_end overlap_end overlap_start], ...
                [i-0.3 i-0.3 j+0.3 j+0.3], [0.5 0.5 0.5], ...
                'FaceAlpha', 0.2, 'EdgeColor', 'none');
        end
    end
end

%% Panel 2: Cost Overlap
subplot(2,2,2);
hold on;

% Extract cost bounds
cost_means = zeros(nConfigs, 1);
cost_lower = zeros(nConfigs, 1);
cost_upper = zeros(nConfigs, 1);

for i = 1:nConfigs
    row = costTable(strcmp(costTable.location, configs.location{i}) & ...
        strcmp(costTable.filterType, configs.filterType{i}) & ...
        strcmp(costTable.mode, configs.mode{i}), :);

    if ~isempty(row)
        cost_means(i) = row.total_cost;
        if ismember('total_cost_lower', row.Properties.VariableNames)
            cost_lower(i) = row.total_cost_lower;
            cost_upper(i) = row.total_cost_upper;
        else
            cost_lower(i) = cost_means(i) * 0.9;
            cost_upper(i) = cost_means(i) * 1.1;
        end
    end
end

% Sort by mean cost
[~, sortIdx] = sort(cost_means);

% Plot cost ranges
for i = 1:nConfigs
    idx = sortIdx(i);
    if contains(configs.filterType{idx}, 'hepa', 'IgnoreCase', true)
        color = [0.2 0.4 0.8];
    else
        color = [0.8 0.3 0.3];
    end

    plot([cost_lower(idx), cost_upper(idx)], [i, i], ...
        'Color', color, 'LineWidth', 6);
    plot(cost_means(idx), i, 'ko', 'MarkerSize', 8, 'MarkerFaceColor', 'w');
end

set(gca, 'YTick', y, 'YTickLabel', labels(sortIdx));
xlabel('Annual Cost (Dollars)');
title('Operating Cost with Envelope Bounds');
grid on;

%% Panel 3: 2D Overlap Regions
subplot(2,2,[3 4]);
hold on;

% Plot 2D scenario bounds regions
for i = 1:nConfigs
    row = costTable(strcmp(costTable.location, configs.location{i}) & ...
        strcmp(costTable.filterType, configs.filterType{i}) & ...
        strcmp(costTable.mode, configs.mode{i}), :);

    if ~isempty(row)
        % Get bounds
        if ismember('percent_PM25_reduction_lower', row.Properties.VariableNames)
            x_lower = row.percent_PM25_reduction_lower;
            x_upper = row.percent_PM25_reduction_upper;
        else
            x_lower = row.percent_PM25_reduction * 0.9;
            x_upper = row.percent_PM25_reduction * 1.1;
        end

        if ismember('total_cost_lower', row.Properties.VariableNames)
            y_lower = row.total_cost_lower;
            y_upper = row.total_cost_upper;
        else
            y_lower = row.total_cost * 0.9;
            y_upper = row.total_cost * 1.1;
        end

        % Color by filter type
        if contains(configs.filterType{i}, 'hepa', 'IgnoreCase', true)
            color = [0.2 0.4 0.8];
        else
            color = [0.8 0.3 0.3];
        end

        % Plot bounds rectangle
        rectangle('Position', [x_lower, y_lower, x_upper-x_lower, y_upper-y_lower], ...
            'EdgeColor', color, 'LineWidth', 2, 'LineStyle', '-', ...
            'FaceColor', color, 'FaceAlpha', 0.2);

        % Plot center point
        plot(row.percent_PM25_reduction, row.total_cost, 'o', ...
            'MarkerSize', 8, 'MarkerFaceColor', color, ...
            'MarkerEdgeColor', 'k', 'LineWidth', 1);

        % Add label slightly offset so the marker does not cover the text
        if ~exist('x_range','var')
            x_range = max(pm25_upper) - min(pm25_lower);
            y_range = max(cost_upper) - min(cost_lower);
        end
        text(row.percent_PM25_reduction + 0.01*x_range, ...
             row.total_cost + 0.01*y_range, sprintf('%d', i), ...
             'FontSize', 8, 'FontWeight', 'bold', 'BackgroundColor','w');
    end
end

xlabel('Particulate Matter 2.5 Reduction (Percent)');
ylabel('Annual Cost (Dollars)');
title('Performance Overlap Across Configurations');
grid on;

% Add diagonal lines for equal value
ax = gca;
xlims = xlim;
ylims = ylim;
% Normalize and plot iso-value lines
x_norm = linspace(0, 1, 100);
for value = [0.2, 0.4, 0.6, 0.8]
    x_actual = xlims(1) + x_norm * (xlims(2) - xlims(1));
    y_actual = ylims(2) - value * (ylims(2) - ylims(1)) ./ x_norm;
    valid = y_actual >= ylims(1) & y_actual <= ylims(2);
    plot(x_actual(valid), y_actual(valid), '--', 'LineWidth', 0.5, ...
        'Color', [0 0 0 0.5]);
end

% Legend for configuration numbers
legendText = cell(nConfigs, 1);
for i = 1:nConfigs
    legendText{i} = sprintf('%d: %s', i, labels{i});
end
text(xlims(2)*0.02, ylims(2)*0.98, strjoin(legendText, '\n'), ...
    'VerticalAlignment', 'top', 'FontSize', 7, ...
    'BackgroundColor', 'w', 'EdgeColor', 'k');

% Overall title
sgtitle('Configuration Performance Overlap Analysis Across Envelopes', ...
    'FontSize', 14, 'FontWeight', 'bold');

% Save
save_figure(fig, figuresDir, 'configuration_overlap_analysis.png');
close(fig);

end