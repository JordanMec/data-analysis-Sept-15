function filterComparisonTable = analyze_filter_performance(summaryTable)
% ANALYZE_FILTER_PERFORMANCE Compare HEPA 13 vs MERV 15 with uncertainty bounds
% Now properly treats tight/leaky as bounds on performance

% Filter rows for all intervention modes (exclude baseline)
compRows = summaryTable(~strcmp(summaryTable.mode, 'baseline'), :);

% Group by location and mode ONLY (not leakage)
uniqueConditions = unique(compRows(:, {'location', 'mode'}));

filterComparisonTable = table();

for i = 1:height(uniqueConditions)
    loc = uniqueConditions.location{i};
    mode = uniqueConditions.mode{i};

    % Get HEPA 13 data for both envelope conditions
    hepaTight = compRows(strcmp(compRows.location, loc) & ...
        strcmp(compRows.mode, mode) & ...
        (strcmpi(compRows.filterType, 'hepa') | strcmpi(compRows.filterType, 'hepa 13')) & ...
        strcmp(compRows.leakage, 'tight'), :);
    hepaLeaky = compRows(strcmp(compRows.location, loc) & ...
        strcmp(compRows.mode, mode) & ...
        (strcmpi(compRows.filterType, 'hepa') | strcmpi(compRows.filterType, 'hepa 13')) & ...
        strcmp(compRows.leakage, 'leaky'), :);
    
    % Get MERV 15 data for both envelope conditions
    mervTight = compRows(strcmp(compRows.location, loc) & ...
        strcmp(compRows.mode, mode) & ...
        (strcmpi(compRows.filterType, 'merv') | strcmpi(compRows.filterType, 'merv 15')) & ...
        strcmp(compRows.leakage, 'tight'), :);
    mervLeaky = compRows(strcmp(compRows.location, loc) & ...
        strcmp(compRows.mode, mode) & ...
        (strcmpi(compRows.filterType, 'merv') | strcmpi(compRows.filterType, 'merv 15')) & ...
        strcmp(compRows.leakage, 'leaky'), :);

    if isempty(hepaTight) || isempty(hepaLeaky) || ...
       isempty(mervTight) || isempty(mervLeaky)
        warning('Missing data for %s-%s', loc, mode);
        continue;
    end

    % Calculate bounds for HEPA 13 performance
    hepa_PM25_lower = min(hepaTight.avg_indoor_PM25, hepaLeaky.avg_indoor_PM25);
    hepa_PM25_upper = max(hepaTight.avg_indoor_PM25, hepaLeaky.avg_indoor_PM25);
    hepa_PM25_mean = (hepaTight.avg_indoor_PM25 + hepaLeaky.avg_indoor_PM25) / 2;
    
    hepa_PM10_lower = min(hepaTight.avg_indoor_PM10, hepaLeaky.avg_indoor_PM10);
    hepa_PM10_upper = max(hepaTight.avg_indoor_PM10, hepaLeaky.avg_indoor_PM10);
    hepa_PM10_mean = (hepaTight.avg_indoor_PM10 + hepaLeaky.avg_indoor_PM10) / 2;
    
    hepa_cost_lower = min(hepaTight.total_cost, hepaLeaky.total_cost);
    hepa_cost_upper = max(hepaTight.total_cost, hepaLeaky.total_cost);
    hepa_cost_mean = (hepaTight.total_cost + hepaLeaky.total_cost) / 2;
    
    hepa_filter_lower = min(hepaTight.filter_replaced, hepaLeaky.filter_replaced);
    hepa_filter_upper = max(hepaTight.filter_replaced, hepaLeaky.filter_replaced);
    hepa_filter_mean = (hepaTight.filter_replaced + hepaLeaky.filter_replaced) / 2;

    % Calculate bounds for MERV 15 performance
    merv_PM25_lower = min(mervTight.avg_indoor_PM25, mervLeaky.avg_indoor_PM25);
    merv_PM25_upper = max(mervTight.avg_indoor_PM25, mervLeaky.avg_indoor_PM25);
    merv_PM25_mean = (mervTight.avg_indoor_PM25 + mervLeaky.avg_indoor_PM25) / 2;
    
    merv_PM10_lower = min(mervTight.avg_indoor_PM10, mervLeaky.avg_indoor_PM10);
    merv_PM10_upper = max(mervTight.avg_indoor_PM10, mervLeaky.avg_indoor_PM10);
    merv_PM10_mean = (mervTight.avg_indoor_PM10 + mervLeaky.avg_indoor_PM10) / 2;
    
    merv_cost_lower = min(mervTight.total_cost, mervLeaky.total_cost);
    merv_cost_upper = max(mervTight.total_cost, mervLeaky.total_cost);
    merv_cost_mean = (mervTight.total_cost + mervLeaky.total_cost) / 2;
    
    merv_filter_lower = min(mervTight.filter_replaced, mervLeaky.filter_replaced);
    merv_filter_upper = max(mervTight.filter_replaced, mervLeaky.filter_replaced);
    merv_filter_mean = (mervTight.filter_replaced + mervLeaky.filter_replaced) / 2;

    % Compute difference metrics with bounds
    % For differences, we need to consider all combinations
    delta_PM25_mean = merv_PM25_mean - hepa_PM25_mean;
    % Worst case for delta (most negative) = merv_lower - hepa_upper
    delta_PM25_lower = merv_PM25_lower - hepa_PM25_upper;
    % Best case for delta (most positive) = merv_upper - hepa_lower
    delta_PM25_upper = merv_PM25_upper - hepa_PM25_lower;
    
    delta_PM10_mean = merv_PM10_mean - hepa_PM10_mean;
    delta_PM10_lower = merv_PM10_lower - hepa_PM10_upper;
    delta_PM10_upper = merv_PM10_upper - hepa_PM10_lower;
    
    delta_cost_mean = hepa_cost_mean - merv_cost_mean;
    delta_cost_lower = hepa_cost_lower - merv_cost_upper;
    delta_cost_upper = hepa_cost_upper - merv_cost_lower;
    
    delta_filter_mean = hepa_filter_mean - merv_filter_mean;
    delta_filter_lower = hepa_filter_lower - merv_filter_upper;
    delta_filter_upper = hepa_filter_upper - merv_filter_lower;

    % Calculate overlap metrics (how much do the bounds overlap?)
    pm25_overlap = calculate_overlap(hepa_PM25_lower, hepa_PM25_upper, ...
                                    merv_PM25_lower, merv_PM25_upper);
    pm10_overlap = calculate_overlap(hepa_PM10_lower, hepa_PM10_upper, ...
                                    merv_PM10_lower, merv_PM10_upper);
    cost_overlap = calculate_overlap(hepa_cost_lower, hepa_cost_upper, ...
                                    merv_cost_lower, merv_cost_upper);

    % Create row with comprehensive bounds information
    row = table({loc}, {mode}, ...
        hepa_PM25_mean, hepa_PM25_lower, hepa_PM25_upper, ...
        merv_PM25_mean, merv_PM25_lower, merv_PM25_upper, ...
        delta_PM25_mean, delta_PM25_lower, delta_PM25_upper, ...
        hepa_PM10_mean, hepa_PM10_lower, hepa_PM10_upper, ...
        merv_PM10_mean, merv_PM10_lower, merv_PM10_upper, ...
        delta_PM10_mean, delta_PM10_lower, delta_PM10_upper, ...
        hepa_cost_mean, hepa_cost_lower, hepa_cost_upper, ...
        merv_cost_mean, merv_cost_lower, merv_cost_upper, ...
        delta_cost_mean, delta_cost_lower, delta_cost_upper, ...
        hepa_filter_mean, hepa_filter_lower, hepa_filter_upper, ...
        merv_filter_mean, merv_filter_lower, merv_filter_upper, ...
        delta_filter_mean, delta_filter_lower, delta_filter_upper, ...
        pm25_overlap, pm10_overlap, cost_overlap, ...
        'VariableNames', {
        'location', 'mode', ...
        'hepa_PM25', 'hepa_PM25_lower', 'hepa_PM25_upper', ...
        'merv_PM25', 'merv_PM25_lower', 'merv_PM25_upper', ...
        'delta_PM25', 'delta_PM25_lower', 'delta_PM25_upper', ...
        'hepa_PM10', 'hepa_PM10_lower', 'hepa_PM10_upper', ...
        'merv_PM10', 'merv_PM10_lower', 'merv_PM10_upper', ...
        'delta_PM10', 'delta_PM10_lower', 'delta_PM10_upper', ...
        'hepa_cost', 'hepa_cost_lower', 'hepa_cost_upper', ...
        'merv_cost', 'merv_cost_lower', 'merv_cost_upper', ...
        'delta_cost', 'delta_cost_lower', 'delta_cost_upper', ...
        'hepa_filter_hours', 'hepa_filter_hours_lower', 'hepa_filter_hours_upper', ...
        'merv_filter_hours', 'merv_filter_hours_lower', 'merv_filter_hours_upper', ...
        'delta_filter_hours', 'delta_filter_hours_lower', 'delta_filter_hours_upper', ...
        'pm25_bounds_overlap', 'pm10_bounds_overlap', 'cost_bounds_overlap'
        });

    filterComparisonTable = [filterComparisonTable; row];
end
end

function overlap = calculate_overlap(a_lower, a_upper, b_lower, b_upper)
% Calculate the percentage of overlap between two intervals
overlap_lower = max(a_lower, b_lower);
overlap_upper = min(a_upper, b_upper);

if overlap_upper < overlap_lower
    overlap = 0; % No overlap
else
    % Calculate overlap as percentage of the union
    union_lower = min(a_lower, b_lower);
    union_upper = max(a_upper, b_upper);
    overlap = 100 * (overlap_upper - overlap_lower) / (union_upper - union_lower);
end
end