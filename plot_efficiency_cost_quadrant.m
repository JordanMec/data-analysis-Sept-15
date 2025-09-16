function plot_efficiency_cost_quadrant(costTable, figuresDir)
if isempty(costTable)
    warning('plot_efficiency_cost_quadrant: no data provided, skipping plot.');
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
    
    % Extract bounds for PM2.5 reduction and cost
    xMean = row.percent_PM25_reduction;
    xLower = row.percent_PM25_reduction_lower;
    xUpper = row.percent_PM25_reduction_upper;
    
    yMean = row.total_cost;
    yLower = row.total_cost_lower;
    yUpper = row.total_cost_upper;
    
    % Calculate error bars
    xErr = [xMean - xLower, xUpper - xMean];
    yErr = [yMean - yLower, yUpper - yMean];
    
    marker = markers{mod(i-1,length(markers))+1};
    
    % Plot uncertainty region as a shaded rectangle
    patch([xLower xUpper xUpper xLower], ...
          [yLower yLower yUpper yUpper], ...
          colors(i,:), 'FaceAlpha', 0.2, 'EdgeColor', colors(i,:), ...
          'EdgeAlpha', 0.5, 'LineStyle', ':', ...
          'DisplayName', sprintf('%s-%s-%s Uncertainty', loc, filt, mode));
    
    % Plot mean point with error bars
    h = scatter_with_errorbars(xMean, yMean, xErr, yErr, colors(i,:), marker);
    set(h, 'DisplayName', sprintf('%s-%s-%s Bound', loc, filt, mode));
end

% Add median lines
x_median = median(costTable.percent_PM25_reduction, 'omitnan');
y_median = median(costTable.total_cost, 'omitnan');
hX = xline(x_median, '--k', 'Median Reduction', 'LineWidth', 1.5);
set(hX, 'DisplayName', 'Median Reduction');
hY = yline(y_median, '--k', 'Median Cost', 'LineWidth', 1.5);
set(hY, 'DisplayName', 'Median Cost');

% Add quadrant labels with better positioning
text(x_median*0.5, y_median*0.5, 'Low Cost, Low Reduction', ...
     'HorizontalAlignment', 'center', 'FontWeight', 'bold', 'Color', [0.5 0.5 0.5]);
text(x_median*1.5, y_median*0.5, 'Low Cost, High Reduction', ...
     'HorizontalAlignment', 'center', 'FontWeight', 'bold', 'Color', [0 0.5 0]);
text(x_median*0.5, y_median*1.5, 'High Cost, Low Reduction', ...
     'HorizontalAlignment', 'center', 'FontWeight', 'bold', 'Color', [0.8 0 0]);
text(x_median*1.5, y_median*1.5, 'High Cost, High Reduction', ...
     'HorizontalAlignment', 'center', 'FontWeight', 'bold', 'Color', [0.5 0.5 0]);

xlabel('% Indoor PM2.5 Reduction from Baseline');
ylabel('Total Operational Cost ($)');
title('Cost Versus Indoor Fine Particulate Matter Reduction with Uncertainty Regions');
grid on;
legend('Location', 'eastoutside');

% Add note about visualization
    text(0.02, 0.02, 'Shaded regions show full uncertainty from tight/leaky bounds', ...
         'Units', 'normalized', 'FontSize', 8, 'FontAngle', 'italic');

save_figure(fig, figuresDir, 'efficiency_cost_quadrant.png');
close(fig);
end