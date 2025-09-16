function plot_envelope_sensitivity(summaryTable, costTable, figuresDir)
% PLOT_ENVELOPE_SENSITIVITY Analyze sensitivity to building envelope tightness
% Enhanced version with robust zero handling
if isempty(summaryTable) || isempty(costTable)
    warning('plot_envelope_sensitivity: no data provided, skipping plot.');
    return;
end
fig = figure('Visible','off');
set_figure_fullscreen(fig);

%% Calculate sensitivity indices with enhanced zero handling
scenarios = unique(summaryTable(~strcmp(summaryTable.mode,'baseline'), ...
    {'location','filterType','mode'}));

nScenarios = height(scenarios);
sensitivity = table();

% Define epsilon for near-zero detection
epsilon = 1e-6;

for i = 1:nScenarios
    loc = scenarios.location{i};
    filt = scenarios.filterType{i};
    mode = scenarios.mode{i};

    % Get tight and leaky data
    tightSum = summaryTable(strcmp(summaryTable.location,loc) & ...
        strcmp(summaryTable.filterType,filt) & ...
        strcmp(summaryTable.mode,mode) & ...
        strcmp(summaryTable.leakage,'tight'), :);
    leakySum = summaryTable(strcmp(summaryTable.location,loc) & ...
        strcmp(summaryTable.filterType,filt) & ...
        strcmp(summaryTable.mode,mode) & ...
        strcmp(summaryTable.leakage,'leaky'), :);

    if isempty(tightSum) || isempty(leakySum), continue; end

    % Enhanced sensitivity calculations with zero handling
    
    % PM2.5 sensitivity
    if abs(tightSum.avg_indoor_PM25) < epsilon
        % Near-zero baseline: use absolute difference
        pm25_change = leakySum.avg_indoor_PM25 - tightSum.avg_indoor_PM25;
        pm25_method = 'absolute';
    else
        % Use symmetric percentage for more stable results
        avg_pm25 = (tightSum.avg_indoor_PM25 + leakySum.avg_indoor_PM25) / 2;
        if avg_pm25 > epsilon
            pm25_change = 100 * (leakySum.avg_indoor_PM25 - tightSum.avg_indoor_PM25) / avg_pm25;
            pm25_method = 'symmetric_percent';
        else
            pm25_change = 0;
            pm25_method = 'both_zero';
        end
    end
    
    % PM10 sensitivity
    if abs(tightSum.avg_indoor_PM10) < epsilon
        pm10_change = leakySum.avg_indoor_PM10 - tightSum.avg_indoor_PM10;
        pm10_method = 'absolute';
    else
        avg_pm10 = (tightSum.avg_indoor_PM10 + leakySum.avg_indoor_PM10) / 2;
        if avg_pm10 > epsilon
            pm10_change = 100 * (leakySum.avg_indoor_PM10 - tightSum.avg_indoor_PM10) / avg_pm10;
            pm10_method = 'symmetric_percent';
        else
            pm10_change = 0;
            pm10_method = 'both_zero';
        end
    end
    
    % Cost sensitivity (costs should not be zero, but check anyway)
    if abs(tightSum.total_cost) < epsilon
        cost_change = leakySum.total_cost - tightSum.total_cost;
        cost_method = 'absolute';
    else
        % Standard percentage change for cost (usually non-zero)
        cost_change = 100 * (leakySum.total_cost - tightSum.total_cost) / tightSum.total_cost;
        cost_method = 'percent';
    end

    % Filter life change
    if ~isnan(tightSum.filter_replaced) && ~isnan(leakySum.filter_replaced)
        if abs(tightSum.filter_replaced) < epsilon
            filter_change = leakySum.filter_replaced - tightSum.filter_replaced;
            filter_life_method = 'absolute';
        else
            filter_change = 100 * (leakySum.filter_replaced - tightSum.filter_replaced) / tightSum.filter_replaced;
            filter_life_method = 'percent';
        end
    else
        filter_change = NaN;
        filter_life_method = 'missing';
    end

    % Get cost-effectiveness data (keep existing logic)
    hasLeakCol = ismember('leakage', costTable.Properties.VariableNames);
    hasBoundCols = all(ismember({'percent_PM25_reduction_lower','percent_PM25_reduction_upper',...
        'cost_per_AQI_hour_avoided_lower','cost_per_AQI_hour_avoided_upper'}, ...
        costTable.Properties.VariableNames));

    if hasLeakCol
        tightCost = costTable(strcmp(costTable.location,loc) & ...
            strcmp(costTable.filterType,filt) & ...
            strcmp(costTable.mode,mode) & ...
            strcmp(costTable.leakage,'tight'), :);
        leakyCost = costTable(strcmp(costTable.location,loc) & ...
            strcmp(costTable.filterType,filt) & ...
            strcmp(costTable.mode,mode) & ...
            strcmp(costTable.leakage,'leaky'), :);

        if ~isempty(tightCost) && ~isempty(leakyCost)
            effectiveness_change = leakyCost.percent_PM25_reduction - tightCost.percent_PM25_reduction;
            
            % Enhanced cost per AQI calculation
            if abs(tightCost.cost_per_AQI_hour_avoided) < epsilon
                cost_per_aqi_change = leakyCost.cost_per_AQI_hour_avoided - tightCost.cost_per_AQI_hour_avoided;
                cost_per_aqi_method = 'absolute';
            else
                cost_per_aqi_change = 100 * (leakyCost.cost_per_AQI_hour_avoided - ...
                    tightCost.cost_per_AQI_hour_avoided) / tightCost.cost_per_AQI_hour_avoided;
                cost_per_aqi_method = 'percent';
            end
        else
            effectiveness_change = NaN;
            cost_per_aqi_change = NaN;
            cost_per_aqi_method = 'missing';
        end
    elseif hasBoundCols
        rowCost = costTable(strcmp(costTable.location,loc) & ...
            strcmp(costTable.filterType,filt) & ...
            strcmp(costTable.mode,mode), :);
        if ~isempty(rowCost)
            effectiveness_change = rowCost.percent_PM25_reduction_upper - rowCost.percent_PM25_reduction_lower;
            if rowCost.cost_per_AQI_hour_avoided_lower > epsilon
                cost_per_aqi_change = 100 * (rowCost.cost_per_AQI_hour_avoided_upper - ...
                    rowCost.cost_per_AQI_hour_avoided_lower) / rowCost.cost_per_AQI_hour_avoided_lower;
                cost_per_aqi_method = 'percent';
            else
                cost_per_aqi_change = rowCost.cost_per_AQI_hour_avoided_upper - rowCost.cost_per_AQI_hour_avoided_lower;
                cost_per_aqi_method = 'absolute';
            end
        else
            effectiveness_change = NaN;
            cost_per_aqi_change = NaN;
            cost_per_aqi_method = 'missing';
        end
    else
        effectiveness_change = NaN;
        cost_per_aqi_change = NaN;
        cost_per_aqi_method = 'missing';
    end

    % Build sensitivity row with methods
    row = table({loc}, {filt}, {mode}, pm25_change, pm10_change, cost_change, ...
        filter_change, effectiveness_change, cost_per_aqi_change, ...
        {pm25_method}, {pm10_method}, {cost_method}, {filter_life_method}, ...
        'VariableNames', {'location','filterType','mode', ...
        'pm25_sensitivity','pm10_sensitivity','cost_sensitivity', ...
        'filter_life_sensitivity','effectiveness_change','cost_effectiveness_sensitivity', ...
        'pm25_method','pm10_method','cost_method','filter_life_method'});

    sensitivity = [sensitivity; row];
end

%% Enhanced Visualization with method indicators
% 1. Tornado diagram of sensitivities (modified to handle mixed methods)
subplot(2,2,1);
metrics = {'pm25_sensitivity','pm10_sensitivity','cost_sensitivity','filter_life_sensitivity'};
metricLabels = {'PM2.5 Conc.','PM10 Conc.','Operating Cost','Filter Life'};
meanSens = zeros(length(metrics),1);

% Calculate mean absolute sensitivity, normalizing absolute values
for m = 1:length(metrics)
    values = sensitivity.(metrics{m});
    methods = sensitivity.([strrep(metrics{m},'_sensitivity','') '_method']);
    
    % Normalize absolute values to percentage scale for fair comparison
    normalized_values = zeros(size(values));
    for j = 1:length(values)
        if strcmp(methods{j}, 'absolute')
            % For absolute values, normalize by typical scale
            if contains(metrics{m}, 'pm25')
                normalized_values(j) = values(j) / 10 * 100; % Assume 10 μg/m³ typical scale
            elseif contains(metrics{m}, 'pm10')
                normalized_values(j) = values(j) / 20 * 100; % Assume 20 μg/m³ typical scale
            elseif contains(metrics{m}, 'cost')
                normalized_values(j) = values(j) / 100 * 100; % Assume $100 typical scale
            else
                normalized_values(j) = values(j); % Keep as is
            end
        else
            normalized_values(j) = values(j);
        end
    end
    
    meanSens(m) = mean(abs(normalized_values), 'omitnan');
end

[sortedSens, sortIdx] = sort(meanSens, 'descend');
barh(sortedSens);
set(gca, 'YTick', 1:length(metrics), 'YTickLabel', metricLabels(sortIdx));
xlabel('Mean Sensitivity (Normalized Units)');
title('Parameter Sensitivity Ranking');
grid on;

% Add note about mixed methods
text(0.95, 0.05, 'Note: Absolute differences normalized for comparison', ...
    'Units', 'normalized', 'HorizontalAlignment', 'right', ...
    'VerticalAlignment', 'bottom', 'FontSize', 8, 'FontAngle', 'italic');

% 2. Scenario comparison (existing code with minor modification)
subplot(2,2,2);
scenarioLabels = strcat(sensitivity.location, "-", sensitivity.filterType, "-", sensitivity.mode);
x = 1:height(sensitivity);

% Create bar data, using absolute values where needed
barData = [sensitivity.pm25_sensitivity, sensitivity.cost_sensitivity, ...
    sensitivity.filter_life_sensitivity];

% Add markers for absolute value calculations
hold on;
bar(barData, 'grouped');

% Mark absolute value calculations with asterisks
for i = 1:height(sensitivity)
    if strcmp(sensitivity.pm25_method{i}, 'absolute')
        text(i, barData(i,1), '*', 'HorizontalAlignment', 'center', ...
            'VerticalAlignment', 'bottom', 'FontSize', 12, 'FontWeight', 'bold');
    end
    if strcmp(sensitivity.cost_method{i}, 'absolute')
        text(i, barData(i,2), '*', 'HorizontalAlignment', 'center', ...
            'VerticalAlignment', 'bottom', 'FontSize', 12, 'FontWeight', 'bold');
    end
end

xlabel('Scenario Identifier');
ylabel('Sensitivity (Percent Change or Absolute Difference)');
title('Envelope Sensitivity Across Scenarios');
legend({'PM2.5','Cost','Filter Life'}, 'Location','eastoutside');
set(gca, 'XTick', x, 'XTickLabel', scenarioLabels);
xtickangle(45);
grid on;
text(0.02, 0.98, '* Absolute difference (baseline ≈ 0)', ...
    'Units', 'normalized', 'VerticalAlignment', 'top', 'FontSize', 8);

% 3. Effectiveness vs Cost Trade-off Changes (keep existing)
subplot(2,2,3);
validIdx = ~isnan(sensitivity.effectiveness_change) & ~isnan(sensitivity.cost_sensitivity);
scatter(sensitivity.cost_sensitivity(validIdx), ...
    sensitivity.effectiveness_change(validIdx), ...
    100, 1:sum(validIdx), 'filled');

xlabel('Cost Increase (Percent)');
ylabel('Effectiveness Change (Percentage Points)');
title('Cost Impact Versus Effectiveness Change');
colormap(lines(sum(validIdx)));

% Add quadrant lines
xline(0, '--k');
yline(0, '--k');

% Annotate quadrants
text(max(xlim)*0.7, max(ylim)*0.9, 'Higher Cost,', ...
    'HorizontalAlignment', 'center', 'FontSize', 9, 'Color', [0.5 0.5 0.5]);
text(max(xlim)*0.7, max(ylim)*0.8, 'More Effective', ...
    'HorizontalAlignment', 'center', 'FontSize', 9, 'Color', [0.5 0.5 0.5]);
text(min(xlim)*0.3, min(ylim)*0.9, 'Lower Cost,', ...
    'HorizontalAlignment', 'center', 'FontSize', 9, 'Color', [0.5 0.5 0.5]);
text(min(xlim)*0.3, min(ylim)*0.8, 'Less Effective', ...
    'HorizontalAlignment', 'center', 'FontSize', 9, 'Color', [0.5 0.5 0.5]);
grid on;

% 4. Method summary - show which calculations used which approach
subplot(2,2,4);
method_types = {'percent', 'symmetric_percent', 'absolute', 'missing', 'both_zero'};
method_labels = {'Standard %', 'Symmetric %', 'Absolute Δ', 'Missing', 'Both Zero'};
method_counts = zeros(height(sensitivity), numel(method_types));

for i = 1:height(sensitivity)
    methods = {sensitivity.pm25_method{i}, sensitivity.pm10_method{i}, ...
               sensitivity.cost_method{i}, sensitivity.filter_life_method{i}};
    for m = 1:length(methods)
        idx = find(strcmp(methods{m}, method_types));
        if ~isempty(idx)
            method_counts(i, idx) = method_counts(i, idx) + 1;
        end
    end
end

b = bar(method_counts, 'stacked');
colormap(lines(length(method_types)));
set(gca, 'XTick', 1:height(sensitivity));
set(gca, 'XTickLabel', scenarioLabels);
ylabel('Number of Metrics');
legend(method_labels, 'Location', 'best');
title('Distribution of Calculation Methods Across Metrics');
xtickangle(45);
grid on;

% Overall title
sgtitle('Building Envelope Sensitivity Analysis for Leakage Impact on System Performance', ...
    'FontSize', 14, 'FontWeight', 'bold');

% Save
save_figure(fig, figuresDir, 'envelope_sensitivity_analysis.png');
close(fig);
end
