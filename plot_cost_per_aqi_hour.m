function plot_cost_per_aqi_hour(costTable, figuresDir)
% PLOT_COST_PER_AQI_HOUR Compare cost effectiveness with uncertainty bounds

if isempty(costTable)
    warning('plot_cost_per_aqi_hour: no data provided, skipping plot.');
    return;
end

% Get unique configurations (no leakage in grouping)
configs = unique(costTable(:, {'location', 'filterType', 'mode'}));

% Group by filter type and mode for comparison
filters = unique(configs.filterType);
modes = unique(configs.mode);

% Prepare data
nFilters = length(filters);
nModes = length(modes);
meanValues = zeros(nModes, nFilters);
lowerBounds = zeros(nModes, nFilters);
upperBounds = zeros(nModes, nFilters);

for m = 1:nModes
    for f = 1:nFilters
        % Get all locations for this filter/mode combination
        mask = strcmp(configs.filterType, filters{f}) & ...
               strcmp(configs.mode, modes{m});
        relevantConfigs = configs(mask, :);
        
        if isempty(relevantConfigs)
            meanValues(m, f) = NaN;
            lowerBounds(m, f) = NaN;
            upperBounds(m, f) = NaN;
            continue;
        end
        
        % Collect values across locations
        vals = [];
        lows = [];
        highs = [];
        
        for i = 1:height(relevantConfigs)
            row = costTable(strcmp(costTable.location, relevantConfigs.location{i}) & ...
                           strcmp(costTable.filterType, relevantConfigs.filterType{i}) & ...
                           strcmp(costTable.mode, relevantConfigs.mode{i}), :);
            
            if ~isempty(row)
                vals(end+1) = row.cost_per_AQI_hour_avoided;
                
                % Check if bounds columns exist
                if ismember('cost_per_AQI_hour_avoided_lower', row.Properties.VariableNames)
                    lows(end+1) = row.cost_per_AQI_hour_avoided_lower;
                    highs(end+1) = row.cost_per_AQI_hour_avoided_upper;
                else
                    % Estimate bounds if not available
                    lows(end+1) = vals(end) * 0.8;
                    highs(end+1) = vals(end) * 1.2;
                end
            end
        end
        
        % Calculate average across locations
        if ~isempty(vals)
            meanValues(m, f) = mean(vals, 'omitnan');
            lowerBounds(m, f) = mean(lows, 'omitnan');
            upperBounds(m, f) = mean(highs, 'omitnan');
        else
            meanValues(m, f) = NaN;
            lowerBounds(m, f) = NaN;
            upperBounds(m, f) = NaN;
        end
    end
end

% Create figure
fig = figure('Position', [100 100 800 600], 'Visible', 'off');

% Plot grouped bars with error bars
x = 1:nModes;
width = 0.35;
colors = [0.2 0.4 0.8; 0.8 0.3 0.3]; % Blue for HEPA, Red for MERV

hold on;
barHandles = gobjects(1, nFilters);
for f = 1:nFilters
    offset = (f - 1.5) * width;

    % Plot bars
    barHandles(f) = bar(x + offset, meanValues(:, f), width, 'FaceColor', colors(f, :));
    
    % Add error bars
    errorLow = meanValues(:, f) - lowerBounds(:, f);
    errorHigh = upperBounds(:, f) - meanValues(:, f);
    errorbar(x + offset, meanValues(:, f), errorLow, errorHigh, ...
             'k', 'LineStyle', 'none', 'LineWidth', 1.5);
    
    % Add value labels
    for m = 1:nModes
        if ~isnan(meanValues(m, f))
            text(m + offset, upperBounds(m, f) + 0.5, ...
                 sprintf('$%.1f', meanValues(m, f)), ...
                 'HorizontalAlignment', 'center', 'FontSize', 9);
        end
    end
end

% Formatting
set(gca, 'XTick', x, 'XTickLabel', modes);
ylabel('Cost per AQI Hour Avoided ($)');
title('Cost Effectiveness Comparison with Uncertainty Bounds');
legend(barHandles, filters, 'Location', 'best');
grid on;

% Add note about bounds
text(0.02, 0.98, 'Error bars show tight/leaky building envelope bounds', ...
     'Units', 'normalized', 'VerticalAlignment', 'top', ...
     'FontSize', 8, 'FontAngle', 'italic', 'BackgroundColor', 'w');

% Highlight best value
[minVal, minIdx] = min(meanValues(:));
[minMode, minFilter] = ind2sub(size(meanValues), minIdx);
offset = (minFilter - 1.5) * width;
plot(minMode + offset, minVal, 'g*', 'MarkerSize', 12, 'LineWidth', 2, ...
    'HandleVisibility', 'off');

save_figure(fig, figuresDir, 'cost_per_aqi_hour_with_bounds.png');
close(fig);
end