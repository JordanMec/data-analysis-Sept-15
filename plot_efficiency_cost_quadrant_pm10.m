function plot_efficiency_cost_quadrant_pm10(costTable, figuresDir)
if isempty(costTable)
    warning('plot_efficiency_cost_quadrant_pm10: no data provided, skipping plot.');
    return;
end
fig = create_hidden_figure();
nexttile;

uniqueConfigs = unique(costTable(:,{'location','filterType','mode'}));
markers = {'o','s','^','d','v','>'};
colors = lines(height(uniqueConfigs));

hold on;
for i = 1:height(uniqueConfigs)
    loc  = uniqueConfigs.location{i};
    filt = uniqueConfigs.filterType{i};
    mode = uniqueConfigs.mode{i};

    % Get the row for this configuration
    row = costTable(strcmp(costTable.location,loc) & ...
        strcmp(costTable.filterType,filt) & ...
        strcmp(costTable.mode,mode), :);
    if isempty(row), continue; end

    % Extract bounds for PM10 reduction and cost
    xMean  = row.percent_PM10_reduction;
    xLower = row.percent_PM10_reduction_lower;
    xUpper = row.percent_PM10_reduction_upper;

    yMean  = row.total_cost;
    yLower = row.total_cost_lower;
    yUpper = row.total_cost_upper;

    % Calculate error bars
    xErr = [xMean - xLower, xUpper - xMean];
    yErr = [yMean - yLower, yUpper - yMean];

    marker = markers{mod(i-1,length(markers))+1};

    % Plot uncertainty region as a shaded rectangle
    patch([xLower xUpper xUpper xLower], ...
        [yLower yLower yUpper yUpper], colors(i,:), 'FaceAlpha', 0.2, ...
        'EdgeColor', colors(i,:), 'EdgeAlpha', 0.5, 'LineStyle', ':', ...
        'DisplayName', sprintf('%s-%s-%s Uncertainty', loc, filt, mode));

    % Plot mean point with error bars
    h = scatter_with_errorbars(xMean, yMean, xErr, yErr, colors(i,:), marker);
    set(h, 'DisplayName', sprintf('%s-%s-%s Bound', loc, filt, mode));
end

% Add median lines based on mean values
x_median = median(costTable.percent_PM10_reduction, 'omitnan');
y_median = median(costTable.total_cost, 'omitnan');
hX = xline(x_median, '--k', 'Median Reduction', 'LineWidth', 1.5);
set(hX, 'DisplayName', 'Median Reduction');
hY = yline(y_median, '--k', 'Median Cost', 'LineWidth', 1.5);
set(hY, 'DisplayName', 'Median Cost');

xlabel('Indoor Particulate Matter 10 Reduction from Baseline (Percent)');
ylabel('Total Operational Cost (Dollars)');
title('Cost Versus Indoor Coarse Particulate Matter Under 10 Micrometers Reduction with Uncertainty Regions');
grid on;
legend('Location', 'eastoutside');

% Add note about visualization
text(0.02, 0.02, 'Shaded regions show full uncertainty from tight/leaky bounds', ...
    'Units', 'normalized', 'FontSize', 8, 'FontAngle', 'italic');

add_figure_caption(fig, sprintf(['This scatter plot mirrors the PM2.5 analysis but focuses on PM10, pairing each configuration''s average cost with its coarse particle reduction.' newline ...
    'Shaded rectangles and error whiskers show the full tight-to-leaky envelope, and median lines divide the space into intuitive cost-effectiveness quadrants.' newline ...
    'Use it to see which interventions cut coarse particles efficiently without driving up operating costs.']));
save_figure(fig, figuresDir, 'efficiency_cost_quadrant_pm10.png');
close(fig);
end
