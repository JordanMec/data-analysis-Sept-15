function plot_statistical_summary(summaryTable, rangeTable, figuresDir)
% PLOT_STATISTICAL_SUMMARY Create executive summary of bounds and ranges
if isempty(summaryTable) || isempty(rangeTable)
    warning('plot_statistical_summary: no data provided, skipping plot.');
    return;
end
fig = figure('Visible','off');
set_figure_fullscreen(fig);

%% Calculate summary statistics
configs = unique(summaryTable(:,{'location','filterType','mode'}));
configs = configs(~strcmp(configs.mode,'baseline'),:); % Exclude baseline

nConfigs = height(configs);
summaryStats = zeros(nConfigs, 6); % 6 metrics
configLabels = cell(nConfigs,1);

for i = 1:nConfigs
    loc = configs.location{i};
    filt = configs.filterType{i};
    mode = configs.mode{i};
    
    % Get tight and leaky rows
    tightRow = summaryTable(strcmp(summaryTable.location,loc) & ...
        strcmp(summaryTable.filterType,filt) & ...
        strcmp(summaryTable.mode,mode) & ...
        strcmp(summaryTable.leakage,'tight'), :);
    leakyRow = summaryTable(strcmp(summaryTable.location,loc) & ...
        strcmp(summaryTable.filterType,filt) & ...
        strcmp(summaryTable.mode,mode) & ...
        strcmp(summaryTable.leakage,'leaky'), :);
    
    if ~isempty(tightRow) && ~isempty(leakyRow)
        % Calculate scenario ranges (as percentage)
        summaryStats(i,1) = 100 * abs(tightRow.avg_indoor_PM25 - leakyRow.avg_indoor_PM25) / ...
            mean([tightRow.avg_indoor_PM25, leakyRow.avg_indoor_PM25]);
        summaryStats(i,2) = 100 * abs(tightRow.avg_indoor_PM10 - leakyRow.avg_indoor_PM10) / ...
            mean([tightRow.avg_indoor_PM10, leakyRow.avg_indoor_PM10]);
        summaryStats(i,3) = 100 * abs(tightRow.total_cost - leakyRow.total_cost) / ...
            mean([tightRow.total_cost, leakyRow.total_cost]);
        
        % Filter replacement range
        if ~isnan(tightRow.filter_replaced) && ~isnan(leakyRow.filter_replaced)
            summaryStats(i,4) = 100 * abs(tightRow.filter_replaced - leakyRow.filter_replaced) / ...
                mean([tightRow.filter_replaced, leakyRow.filter_replaced]);
        end
        
        % Performance metrics (absolute values)
        summaryStats(i,5) = mean([tightRow.avg_indoor_PM25, leakyRow.avg_indoor_PM25]);
        summaryStats(i,6) = mean([tightRow.total_cost, leakyRow.total_cost]);
    end
    
    configLabels{i} = sprintf('%s-%s-%s', loc, filt, mode);
end

%% Create subplots
% 1. Radar chart of uncertainties - create as a separate axes
ax1 = subplot(2,3,[1 2]);
delete(ax1); % Remove the regular axes
ax1 = polaraxes('Position', [0.05 0.55 0.4 0.4]); % Create polar axes
hold(ax1, 'on');

theta = linspace(0, 2*pi, 5); % 4 metrics + close the polygon
r_labels = {'PM2.5','PM10','Cost','Filter Life','PM2.5'};

% Normalize to 0-1 scale for radar plot
maxVals = max(summaryStats(:,1:4), [], 1);
maxVals(maxVals == 0) = 1; % Avoid division by zero
normStats = summaryStats(:,1:4) ./ maxVals;

colors = lines(nConfigs);
for i = 1:nConfigs
    if any(normStats(i,:) > 0)
        r = [normStats(i,:), normStats(i,1)]; % Close the polygon
        polarplot(ax1, theta, r, 'LineWidth', 2, 'Color', colors(i,:));
        polarscatter(ax1, theta, r, 50, colors(i,:), 'filled');
    end
end

ax1.ThetaTickLabel = r_labels(1:end-1);
ax1.RLim = [0 1];
title(ax1, 'Normalized Scenario Ranges (Tight vs Leaky)');

% Create legend separately
legendAx = axes('Position', [0.45 0.65 0.1 0.25], 'Visible', 'off');
hold(legendAx, 'on');
for i = 1:nConfigs
    plot(legendAx, NaN, NaN, 'Color', colors(i,:), 'LineWidth', 2, 'DisplayName', configLabels{i});
end
legend(legendAx, 'Location','eastoutside');

% 2. Performance vs range scatter
subplot(2,3,3);
avgRange = mean(summaryStats(:,1:4), 2, 'omitnan');
avgPerformance = 100 - summaryStats(:,5); % Convert to reduction

scatter(avgRange, avgPerformance, 100, 1:nConfigs, 'filled');
xlabel('Average Range (%)');
ylabel('PM2.5 Reduction Performance');
title('Performance vs. Range Trade-off');
colormap(lines(nConfigs));
grid on;

% Add diagonal lines for equal trade-off
hold on;
xlims = xlim; ylims = ylim;
plot([0 100], [100 0], 'k--', 'LineWidth', 0.5);

% 3. Cost range breakdown
subplot(2,3,4);
[sortedCost, sortIdx] = sort(summaryStats(:,3), 'descend');
validIdx = sortIdx(sortedCost > 0);
if ~isempty(validIdx)
    barh(1:length(validIdx), sortedCost(sortedCost > 0));
    set(gca, 'YTick', 1:length(validIdx), 'YTickLabel', configLabels(validIdx));
    xlabel('Cost Range (%)');
    title('Cost Variability Ranking');
    grid on;
end

% 4. Comprehensive range heatmap
subplot(2,3,[5 6]);
metricLabels = {'PM2.5 Rng.', 'PM10 Rng.', 'Cost Rng.', 'Filter Rng.'};
heatmapData = summaryStats(:,1:4)';

imagesc(heatmapData);
colormap(flipud(hot));
cb = colorbar;
ylabel(cb, 'Range (%)');

set(gca, 'XTick', 1:nConfigs, 'XTickLabel', configLabels);
set(gca, 'YTick', 1:4, 'YTickLabel', metricLabels);
xtickangle(45);
title('Range Heatmap Across All Scenarios');

% Add text annotations
for i = 1:size(heatmapData,1)
    for j = 1:size(heatmapData,2)
        if ~isnan(heatmapData(i,j))
            text(j, i, sprintf('%.1f', heatmapData(i,j)), ...
                'HorizontalAlignment', 'center', 'Color', 'w');
        end
    end
end

% Overall title
sgtitle('Statistical Summary: Building Envelope Range Analysis', ...
    'FontSize', 16, 'FontWeight', 'bold');

% Save
save_figure(fig, figuresDir, 'statistical_summary_bounds.png');
close(fig);
end