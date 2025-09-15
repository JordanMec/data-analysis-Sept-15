function efficacyTable = analyze_efficacy_vs_baseline(summaryTable)
% ANALYZE_EFFICACY_VS_BASELINE Evaluate intervention efficacy with bounds
% Returns one row per configuration with mean values and bounds

% Get unique configurations WITHOUT leakage
uniqueConfigs = unique(summaryTable(~strcmp(summaryTable.mode,'baseline'), ...
    {'location','filterType','mode'}));

efficacyTable = table();

for i = 1:height(uniqueConfigs)
    loc = uniqueConfigs.location{i};
    filt = uniqueConfigs.filterType{i};
    modeName = uniqueConfigs.mode{i};
    
    % Get intervention data for both envelopes
    intTight = summaryTable(strcmp(summaryTable.location,loc) & ...
        strcmp(summaryTable.leakage,'tight') & ...
        strcmp(summaryTable.filterType,filt) & ...
        strcmp(summaryTable.mode,modeName), :);
    intLeaky = summaryTable(strcmp(summaryTable.location,loc) & ...
        strcmp(summaryTable.leakage,'leaky') & ...
        strcmp(summaryTable.filterType,filt) & ...
        strcmp(summaryTable.mode,modeName), :);
    
    % Get baseline data for both envelopes
    baseTight = summaryTable(strcmp(summaryTable.location,loc) & ...
        strcmp(summaryTable.leakage,'tight') & ...
        strcmp(summaryTable.mode,'baseline'), :);
    baseLeaky = summaryTable(strcmp(summaryTable.location,loc) & ...
        strcmp(summaryTable.leakage,'leaky') & ...
        strcmp(summaryTable.mode,'baseline'), :);
    
    if isempty(intTight) || isempty(intLeaky) || ...
       isempty(baseTight) || isempty(baseLeaky)
        warning('Missing data for %s-%s-%s', loc, filt, modeName);
        continue;
    end
    
    % Calculate bounds for each metric
    
    % PM2.5 metrics
    pm25_base_tight = baseTight.avg_indoor_PM25;
    pm25_base_leaky = baseLeaky.avg_indoor_PM25;
    pm25_int_tight = intTight.avg_indoor_PM25;
    pm25_int_leaky = intLeaky.avg_indoor_PM25;
    
    pm25_reduction_tight = pm25_base_tight - pm25_int_tight;
    pm25_reduction_leaky = pm25_base_leaky - pm25_int_leaky;
    pm25_pct_reduction_tight = 100 * pm25_reduction_tight / pm25_base_tight;
    pm25_pct_reduction_leaky = 100 * pm25_reduction_leaky / pm25_base_leaky;
    
    % PM10 metrics
    pm10_base_tight = baseTight.avg_indoor_PM10;
    pm10_base_leaky = baseLeaky.avg_indoor_PM10;
    pm10_int_tight = intTight.avg_indoor_PM10;
    pm10_int_leaky = intLeaky.avg_indoor_PM10;
    
    pm10_reduction_tight = pm10_base_tight - pm10_int_tight;
    pm10_reduction_leaky = pm10_base_leaky - pm10_int_leaky;
    pm10_pct_reduction_tight = 100 * pm10_reduction_tight / pm10_base_tight;
    pm10_pct_reduction_leaky = 100 * pm10_reduction_leaky / pm10_base_leaky;
    
    % Calculate bounds (min/max) and means
    pm25_reduction = (pm25_reduction_tight + pm25_reduction_leaky) / 2;
    pm25_reduction_lower = min(pm25_reduction_tight, pm25_reduction_leaky);
    pm25_reduction_upper = max(pm25_reduction_tight, pm25_reduction_leaky);
    
    pm25_pct_reduction = (pm25_pct_reduction_tight + pm25_pct_reduction_leaky) / 2;
    pm25_pct_reduction_lower = min(pm25_pct_reduction_tight, pm25_pct_reduction_leaky);
    pm25_pct_reduction_upper = max(pm25_pct_reduction_tight, pm25_pct_reduction_leaky);
    
    pm10_reduction = (pm10_reduction_tight + pm10_reduction_leaky) / 2;
    pm10_reduction_lower = min(pm10_reduction_tight, pm10_reduction_leaky);
    pm10_reduction_upper = max(pm10_reduction_tight, pm10_reduction_leaky);
    
    pm10_pct_reduction = (pm10_pct_reduction_tight + pm10_pct_reduction_leaky) / 2;
    pm10_pct_reduction_lower = min(pm10_pct_reduction_tight, pm10_pct_reduction_leaky);
    pm10_pct_reduction_upper = max(pm10_pct_reduction_tight, pm10_pct_reduction_leaky);
    
    % Build single row with bounds
    row = table({loc}, {filt}, {modeName}, ...
        pm25_reduction, pm25_reduction_lower, pm25_reduction_upper, ...
        pm25_pct_reduction, pm25_pct_reduction_lower, pm25_pct_reduction_upper, ...
        pm10_reduction, pm10_reduction_lower, pm10_reduction_upper, ...
        pm10_pct_reduction, pm10_pct_reduction_lower, pm10_pct_reduction_upper, ...
        'VariableNames', {
        'location', 'filterType', 'mode', ...
        'PM25_reduction', 'PM25_reduction_lower', 'PM25_reduction_upper', ...
        'PM25_percent_reduction', 'PM25_percent_reduction_lower', 'PM25_percent_reduction_upper', ...
        'PM10_reduction', 'PM10_reduction_lower', 'PM10_reduction_upper', ...
        'PM10_percent_reduction', 'PM10_percent_reduction_lower', 'PM10_percent_reduction_upper'
        });
    
    efficacyTable = [efficacyTable; row];
end

% Sort by PM2.5 percent reduction (descending)
efficacyTable = sortrows(efficacyTable, 'PM25_percent_reduction', 'descend');

end