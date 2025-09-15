function plot_cost_vs_aqi_avoided(costTable, figuresDir)
if isempty(costTable)
    warning('plot_cost_vs_aqi_avoided: no data provided, skipping plot.');
    return;
end
fig = create_hidden_figure();
nexttile;

uniqueConfigs = unique(costTable(:,{'location','filterType','mode'}));
markers = {'o','s','^','d'};
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
    
    % Extract bounds
    xMean = row.AQI_hours_avoided;
    xLower = row.AQI_hours_avoided_lower;
    xUpper = row.AQI_hours_avoided_upper;
    
    yMean = row.total_cost;
    yLower = row.total_cost_lower;
    yUpper = row.total_cost_upper;
    
    % Calculate error bars (distance from mean to bounds)
    xErr = [xMean - xLower, xUpper - xMean];
    yErr = [yMean - yLower, yUpper - yMean];
    
    % Plot with error bars showing bounds
    marker = markers{mod(i-1,length(markers))+1};
    h = scatter_with_errorbars(xMean, yMean, xErr, yErr, colors(i,:), marker);
    set(h, 'DisplayName', sprintf('%s-%s-%s Bound', loc, filt, mode));
    
    % Add shaded region showing full scenario bounds using patch for compatibility
    patch([xLower xUpper xUpper xLower], ...
          [yLower yLower yUpper yUpper], colors(i,:), ...
          'FaceAlpha', 0.1, 'EdgeColor', colors(i,:), ...
          'EdgeAlpha', 0.3, 'LineStyle', '--', ...
          'DisplayName', sprintf('%s-%s-%s Range', loc, filt, mode));
end

% Add median lines based on mean values
xMedian = median(costTable.AQI_hours_avoided, 'omitnan');
yMedian = median(costTable.total_cost, 'omitnan');
hX = xline(xMedian, '--k', 'Median Avoided');
set(hX, 'DisplayName', 'Median AQI Avoided');
hY = yline(yMedian, '--k', 'Median Cost');
set(hY, 'DisplayName', 'Median Cost');

% Add trend line through mean values
xMeans = costTable.AQI_hours_avoided;
yMeans = costTable.total_cost;
validIdx = isfinite(xMeans) & isfinite(yMeans);
if sum(validIdx) >= 2
    p = polyfit(xMeans(validIdx), yMeans(validIdx), 1);
    xFit = linspace(min(xMeans(validIdx)), max(xMeans(validIdx)), 100);
    yFit = polyval(p, xFit);
    plot(xFit, yFit, ':k', 'LineWidth', 1.5, 'DisplayName', 'Trend (means)');
end

xlabel('AQI Hours Avoided');
ylabel('Total Operational Cost ($)');
title('Cost vs. AQI Exposure Avoided (with Scenario Bounds)');
grid on;
legend('Location', 'eastoutside');

% Add note about bounds
    text(0.02, 0.98, 'Error bars and shaded regions show tight/leaky bounds', ...
         'Units', 'normalized', 'VerticalAlignment', 'top', ...
         'FontSize', 8, 'FontAngle', 'italic');

save_figure(fig, figuresDir, 'cost_vs_aqi_avoided.png');
close(fig);
end