function costTable = analyze_costs(summaryTable, healthExposureTable)
% ANALYZE_COSTS Compute cost-effectiveness metrics with bounds for interventions
%   Incorporates an improved AQI-hours avoided metric that weights partial
%   improvements and prevents zero-valued bounds when reductions occur.

% Get unique configurations WITHOUT leakage in grouping
uniqueConfigs = unique(summaryTable(~strcmp(summaryTable.mode,'baseline'), ...
    {'location','filterType','mode'}));

costTable = table();

for i = 1:height(uniqueConfigs)
    loc = uniqueConfigs.location{i};
    filt = uniqueConfigs.filterType{i};
    mode = uniqueConfigs.mode{i};

    % Get BOTH tight and leaky intervention rows
    intRowTight = summaryTable(strcmp(summaryTable.location,loc) & ...
        strcmp(summaryTable.leakage,'tight') & ...
        strcmp(summaryTable.filterType,filt) & ...
        strcmp(summaryTable.mode,mode), :);
    intRowLeaky = summaryTable(strcmp(summaryTable.location,loc) & ...
        strcmp(summaryTable.leakage,'leaky') & ...
        strcmp(summaryTable.filterType,filt) & ...
        strcmp(summaryTable.mode,mode), :);

    % Get baseline rows for both envelope conditions
    baseRowTight = summaryTable(strcmp(summaryTable.location,loc) & ...
        strcmp(summaryTable.leakage,'tight') & ...
        strcmp(summaryTable.mode,'baseline'), :);
    baseRowLeaky = summaryTable(strcmp(summaryTable.location,loc) & ...
        strcmp(summaryTable.leakage,'leaky') & ...
        strcmp(summaryTable.mode,'baseline'), :);

    if isempty(intRowTight) || isempty(intRowLeaky) || ...
       isempty(baseRowTight) || isempty(baseRowLeaky)
        continue; 
    end

    % Get health exposure data for bounds
    baseExpTight = healthExposureTable(strcmp(healthExposureTable.location,loc) & ...
        strcmp(healthExposureTable.leakage,'tight') & ...
        strcmp(healthExposureTable.filterType,filt) & ...
        strcmp(healthExposureTable.scenario,'baseline'), :);
    baseExpLeaky = healthExposureTable(strcmp(healthExposureTable.location,loc) & ...
        strcmp(healthExposureTable.leakage,'leaky') & ...
        strcmp(healthExposureTable.filterType,filt) & ...
        strcmp(healthExposureTable.scenario,'baseline'), :);
    intExpTight = healthExposureTable(strcmp(healthExposureTable.location,loc) & ...
        strcmp(healthExposureTable.leakage,'tight') & ...
        strcmp(healthExposureTable.filterType,filt) & ...
        strcmp(healthExposureTable.scenario,mode), :);
    intExpLeaky = healthExposureTable(strcmp(healthExposureTable.location,loc) & ...
        strcmp(healthExposureTable.leakage,'leaky') & ...
        strcmp(healthExposureTable.filterType,filt) & ...
        strcmp(healthExposureTable.scenario,mode), :);

    if isempty(baseExpTight) || isempty(baseExpLeaky) || ...
       isempty(intExpTight) || isempty(intExpLeaky)
        continue; 
    end

    % Calculate bounds for total cost
    total_cost_lower = min(intRowTight.total_cost, intRowLeaky.total_cost);
    total_cost_upper = max(intRowTight.total_cost, intRowLeaky.total_cost);
    total_cost_mean = (intRowTight.total_cost + intRowLeaky.total_cost) / 2;

    % Calculate bounds for PM2.5 reduction
    pm25_reduction_tight = baseRowTight.avg_indoor_PM25 - intRowTight.avg_indoor_PM25;
    pm25_reduction_leaky = baseRowLeaky.avg_indoor_PM25 - intRowLeaky.avg_indoor_PM25;
    pm25_reduction_lower = min(pm25_reduction_tight, pm25_reduction_leaky);
    pm25_reduction_upper = max(pm25_reduction_tight, pm25_reduction_leaky);
    pm25_reduction_mean = (pm25_reduction_tight + pm25_reduction_leaky) / 2;
    
    percent_PM25_reduction_tight = 100 * pm25_reduction_tight / baseRowTight.avg_indoor_PM25;
    percent_PM25_reduction_leaky = 100 * pm25_reduction_leaky / baseRowLeaky.avg_indoor_PM25;
    percent_PM25_reduction_lower = min(percent_PM25_reduction_tight, percent_PM25_reduction_leaky);
    percent_PM25_reduction_upper = max(percent_PM25_reduction_tight, percent_PM25_reduction_leaky);
    percent_PM25_reduction_mean = (percent_PM25_reduction_tight + percent_PM25_reduction_leaky) / 2;

    % Calculate bounds for PM10 reduction
    pm10_reduction_tight = baseRowTight.avg_indoor_PM10 - intRowTight.avg_indoor_PM10;
    pm10_reduction_leaky = baseRowLeaky.avg_indoor_PM10 - intRowLeaky.avg_indoor_PM10;
    pm10_reduction_lower = min(pm10_reduction_tight, pm10_reduction_leaky);
    pm10_reduction_upper = max(pm10_reduction_tight, pm10_reduction_leaky);
    pm10_reduction_mean = (pm10_reduction_tight + pm10_reduction_leaky) / 2;
    
    percent_PM10_reduction_tight = 100 * pm10_reduction_tight / baseRowTight.avg_indoor_PM10;
    percent_PM10_reduction_leaky = 100 * pm10_reduction_leaky / baseRowLeaky.avg_indoor_PM10;
    percent_PM10_reduction_lower = min(percent_PM10_reduction_tight, percent_PM10_reduction_leaky);
    percent_PM10_reduction_upper = max(percent_PM10_reduction_tight, percent_PM10_reduction_leaky);
    percent_PM10_reduction_mean = (percent_PM10_reduction_tight + percent_PM10_reduction_leaky) / 2;

    % Calculate bounds for AQI hours avoided using improved metric
    if ~isempty(baseRowTight) && ~isempty(intRowTight) && ...
       ~isempty(baseRowLeaky) && ~isempty(intRowLeaky)

        AQI_hours_avoided_tight = calculate_improved_aqi_metric(...
            baseRowTight.indoor_PM25{1}, baseRowTight.indoor_PM10{1}, ...
            intRowTight.indoor_PM25{1},  intRowTight.indoor_PM10{1});

        AQI_hours_avoided_leaky = calculate_improved_aqi_metric(...
            baseRowLeaky.indoor_PM25{1}, baseRowLeaky.indoor_PM10{1}, ...
            intRowLeaky.indoor_PM25{1},  intRowLeaky.indoor_PM10{1});
    else
        warning('analyze_costs:missingAQI', ...
            'Missing AQI data for %s / %s / %s. Setting AQI hours avoided to NaN.', ...
            loc, filt, mode);
        AQI_hours_avoided_tight = NaN;
        AQI_hours_avoided_leaky = NaN;
    end
    
    AQI_hours_avoided_lower = min(AQI_hours_avoided_tight, AQI_hours_avoided_leaky);
    AQI_hours_avoided_upper = max(AQI_hours_avoided_tight, AQI_hours_avoided_leaky);
    AQI_hours_avoided_mean = (AQI_hours_avoided_tight + AQI_hours_avoided_leaky) / 2;

    % Calculate bounds for cost effectiveness metrics
    % Note: For cost per unit reduced, lower reduction means higher cost/unit
    if pm25_reduction_tight > 0
        cost_per_ug_pm25_tight = intRowTight.total_cost / pm25_reduction_tight;
    else
        cost_per_ug_pm25_tight = Inf;
    end
    if pm25_reduction_leaky > 0
        cost_per_ug_pm25_leaky = intRowLeaky.total_cost / pm25_reduction_leaky;
    else
        cost_per_ug_pm25_leaky = Inf;
    end
    cost_per_ug_pm25_removed_lower = min(cost_per_ug_pm25_tight, cost_per_ug_pm25_leaky);
    cost_per_ug_pm25_removed_upper = max(cost_per_ug_pm25_tight, cost_per_ug_pm25_leaky);
    cost_per_ug_pm25_removed_mean = (cost_per_ug_pm25_tight + cost_per_ug_pm25_leaky) / 2;
    
    if pm10_reduction_tight > 0
        cost_per_ug_pm10_tight = intRowTight.total_cost / pm10_reduction_tight;
    else
        cost_per_ug_pm10_tight = Inf;
    end
    if pm10_reduction_leaky > 0
        cost_per_ug_pm10_leaky = intRowLeaky.total_cost / pm10_reduction_leaky;
    else
        cost_per_ug_pm10_leaky = Inf;
    end
    cost_per_ug_pm10_removed_lower = min(cost_per_ug_pm10_tight, cost_per_ug_pm10_leaky);
    cost_per_ug_pm10_removed_upper = max(cost_per_ug_pm10_tight, cost_per_ug_pm10_leaky);
    cost_per_ug_pm10_removed_mean = (cost_per_ug_pm10_tight + cost_per_ug_pm10_leaky) / 2;
    
    if AQI_hours_avoided_tight > 0.1
        cost_per_AQI_tight = intRowTight.total_cost / AQI_hours_avoided_tight;
    else
        cost_per_AQI_tight = Inf;
    end
    if AQI_hours_avoided_leaky > 0.1
        cost_per_AQI_leaky = intRowLeaky.total_cost / AQI_hours_avoided_leaky;
    else
        cost_per_AQI_leaky = Inf;
    end
    cost_per_AQI_hour_avoided_lower = min(cost_per_AQI_tight, cost_per_AQI_leaky);
    cost_per_AQI_hour_avoided_upper = max(cost_per_AQI_tight, cost_per_AQI_leaky);
    cost_per_AQI_hour_avoided_mean = (cost_per_AQI_tight + cost_per_AQI_leaky) / 2;

    % Build row with bounds information
    % We now store mean values as the primary metrics, with bounds as additional columns
    row = table({loc}, {filt}, {mode}, ...
        total_cost_mean, total_cost_lower, total_cost_upper, ...
        pm25_reduction_mean, pm25_reduction_lower, pm25_reduction_upper, ...
        percent_PM25_reduction_mean, percent_PM25_reduction_lower, percent_PM25_reduction_upper, ...
        pm10_reduction_mean, pm10_reduction_lower, pm10_reduction_upper, ...
        percent_PM10_reduction_mean, percent_PM10_reduction_lower, percent_PM10_reduction_upper, ...
        AQI_hours_avoided_mean, AQI_hours_avoided_lower, AQI_hours_avoided_upper, ...
        cost_per_ug_pm25_removed_mean, cost_per_ug_pm25_removed_lower, cost_per_ug_pm25_removed_upper, ...
        cost_per_ug_pm10_removed_mean, cost_per_ug_pm10_removed_lower, cost_per_ug_pm10_removed_upper, ...
        cost_per_AQI_hour_avoided_mean, cost_per_AQI_hour_avoided_lower, cost_per_AQI_hour_avoided_upper, ...
        'VariableNames', {'location','filterType','mode', ...
        'total_cost','total_cost_lower','total_cost_upper', ...
        'pm25_reduction','pm25_reduction_lower','pm25_reduction_upper', ...
        'percent_PM25_reduction','percent_PM25_reduction_lower','percent_PM25_reduction_upper', ...
        'pm10_reduction','pm10_reduction_lower','pm10_reduction_upper', ...
        'percent_PM10_reduction','percent_PM10_reduction_lower','percent_PM10_reduction_upper', ...
        'AQI_hours_avoided','AQI_hours_avoided_lower','AQI_hours_avoided_upper', ...
        'cost_per_ug_pm25_removed','cost_per_ug_pm25_removed_lower','cost_per_ug_pm25_removed_upper', ...
        'cost_per_ug_pm10_removed','cost_per_ug_pm10_removed_lower','cost_per_ug_pm10_removed_upper', ...
        'cost_per_AQI_hour_avoided','cost_per_AQI_hour_avoided_lower','cost_per_AQI_hour_avoided_upper'});

    costTable = [costTable; row];
end

fprintf('\n=== AQI Hours Avoided Summary (Improved Metric) ===\n');
aqiMean = mean(costTable.AQI_hours_avoided, 'omitnan');
aqiLower = min(costTable.AQI_hours_avoided_lower, [], 'omitnan');
aqiUpper = max(costTable.AQI_hours_avoided_upper, [], 'omitnan');
fprintf('Mean AQI hours avoided: %s\n', ...
    format_bounds(aqiMean, aqiLower, aqiUpper, ...
    'MeanFormat', '%.1f h', 'BoundFormat', '%.1f h', 'Style', 'both'));
fprintf('Scenarios with zero lower bound: %d of %d\n', ...
    sum(costTable.AQI_hours_avoided_lower == 0), height(costTable));
nz = costTable.AQI_hours_avoided_lower(costTable.AQI_hours_avoided_lower > 0);
if ~isempty(nz)
    fprintf('Minimum non-zero lower bound: %.1f h (tight case)\n', min(nz));
else
    fprintf('Minimum non-zero lower bound: N/A\n');
end
end