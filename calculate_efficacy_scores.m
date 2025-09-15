function efficacyScoreTable = calculate_efficacy_scores(summaryTable, costTable, healthExposureTable)
% CALCULATE_EFFICACY_SCORES Compute composite efficacy metric with uncertainty ranges
%
% This function combines multiple performance measures into a single efficacy score:
% - PM2.5 reduction percentage (40% weight)
% - PM10 reduction percentage (20% weight)
% - Cost effectiveness (20% weight)
% - AQI hours avoided (20% weight)
%
% Inputs:
%   summaryTable        - Table from preprocess_structure_data
%   costTable          - Table from analyze_costs
%   healthExposureTable - Table from analyze_health_exposure
%
% Output:
%   efficacyScoreTable - Table with composite scores and half-range estimates

arguments
    summaryTable        table
    costTable          table
    healthExposureTable table
end

% Input validation
% The cost table may not include a leakage column when bounds are pre-computed.
% Only require the core metrics needed for scoring.
requiredCostCols = {'location','filterType','mode',...
    'percent_PM25_reduction','percent_PM10_reduction',...
    'cost_per_AQI_hour_avoided','AQI_hours_avoided'};

% Check for optional bound columns used to estimate uncertainty
boundCols = {'percent_PM25_reduction_lower','percent_PM25_reduction_upper',...
    'percent_PM10_reduction_lower','percent_PM10_reduction_upper',...
    'cost_per_AQI_hour_avoided_lower','cost_per_AQI_hour_avoided_upper',...
    'AQI_hours_avoided_lower','AQI_hours_avoided_upper'};
hasBounds = all(ismember(boundCols, costTable.Properties.VariableNames));
missingCols = setdiff(requiredCostCols, costTable.Properties.VariableNames);
if ~isempty(missingCols)
    error('calculate_efficacy_scores:MissingColumns',...
        'Required columns missing from costTable: %s', strjoin(missingCols, ', '));
end

% Filter to intervention scenarios only (exclude baseline)
interventionRows = costTable(~strcmp(costTable.mode, 'baseline'), :);
if isempty(interventionRows)
    error('calculate_efficacy_scores:NoInterventions',...
        'No intervention scenarios found in costTable');
end

% Define efficacy weights (must sum to 1.0)
weights = struct();
weights.pm25_reduction = 0.40;  % Primary pollutant of concern
weights.pm10_reduction = 0.20;  % Secondary pollutant
weights.cost_effectiveness = 0.20;  % Economic consideration
weights.aqi_hours_avoided = 0.20;   % Health impact

% Validate weights sum to 1.0
totalWeight = weights.pm25_reduction + weights.pm10_reduction + ...
    weights.cost_effectiveness + weights.aqi_hours_avoided;
if abs(totalWeight - 1.0) > 1e-6
    error('calculate_efficacy_scores:InvalidWeights',...
        'Efficacy weights must sum to 1.0, current sum: %.6f', totalWeight);
end

% Get unique configurations for efficacy calculation
uniqueConfigs = unique(interventionRows(:, {'location','filterType','mode'}));
nConfigs = height(uniqueConfigs);

% Initialize output table
efficacyScoreTable = table();

fprintf('Calculating composite efficacy scores for %d configurations...\n', nConfigs);

for i = 1:nConfigs
    loc = uniqueConfigs.location{i};
    filt = uniqueConfigs.filterType{i};
    mode = uniqueConfigs.mode{i};

    % Row for this configuration (bounds already encoded)
    row = interventionRows(strcmp(interventionRows.location, loc) & ...
        strcmp(interventionRows.filterType, filt) & ...
        strcmp(interventionRows.mode, mode), :);
    if isempty(row)
        warning('Missing cost data for %s-%s-%s, skipping...', loc, filt, mode);
        continue;
    end

    % Extract raw metrics for mean and bounds
    metrics_mean  = extract_metrics(row);
    if hasBounds
        metrics_best  = extract_metrics(row, '_upper', '_lower');
        metrics_worst = extract_metrics(row, '_lower', '_upper');
    else
        metrics_best  = metrics_mean;
        metrics_worst = metrics_mean;
    end

    % Calculate efficacy scores for best and worst scenarios
    score_best = calculate_single_efficacy_score(metrics_best, interventionRows, weights);
    score_worst = calculate_single_efficacy_score(metrics_worst, interventionRows, weights);

    % Compute summary statistics
    mean_score = calculate_single_efficacy_score(metrics_mean, interventionRows, weights);
    score_range = abs(score_best - score_worst);
    % Half-range used as a simple uncertainty estimate between best and worst
    score_range_half = score_range / 2;

    % Determine which scenario performs better
    if score_best > score_worst
        best_scenario = 'best';
        best_score = score_best;
        worst_scenario = 'worst';
        worst_score = score_worst;
    else
        best_scenario = 'worst';
        best_score = score_worst;
        worst_scenario = 'best';
        worst_score = score_best;
    end

    % Create detailed breakdown of component scores
    breakdown_best = calculate_component_breakdown(metrics_best, interventionRows, weights);
    breakdown_worst = calculate_component_breakdown(metrics_worst, interventionRows, weights);

    % Average component scores
    avg_pm25_score = (breakdown_best.pm25_score + breakdown_worst.pm25_score) / 2;
    avg_pm10_score = (breakdown_best.pm10_score + breakdown_worst.pm10_score) / 2;
    avg_cost_score = (breakdown_best.cost_score + breakdown_worst.cost_score) / 2;
    avg_aqi_score = (breakdown_best.aqi_score + breakdown_worst.aqi_score) / 2;

    % Build output row
    row = table({loc}, {filt}, {mode}, ...
        mean_score, score_best, score_worst, ...
        best_score, {best_scenario}, worst_score, {worst_scenario}, ...
        score_range, score_range_half, ...
        avg_pm25_score, avg_pm10_score, avg_cost_score, avg_aqi_score, ...
        'VariableNames', {'location','filterType','mode',...
        'mean_efficacy_score','tight_efficacy_score','leaky_efficacy_score',...
        'best_score','best_scenario','worst_score','worst_scenario',...
        'score_range','score_range_half',...
        'avg_pm25_component','avg_pm10_component','avg_cost_component','avg_aqi_component'});

    efficacyScoreTable = [efficacyScoreTable; row];
end

% Sort by mean efficacy score (descending)
efficacyScoreTable = sortrows(efficacyScoreTable, 'mean_efficacy_score', 'descend');

% Add ranking column
efficacyScoreTable.rank = (1:height(efficacyScoreTable))';

% Display summary
fprintf('\n=== COMPOSITE EFFICACY SCORE RESULTS ===\n');
fprintf('Top 3 performing configurations:\n');
topN = min(3, height(efficacyScoreTable));
for i = 1:topN
    row = efficacyScoreTable(i,:);
    fprintf('%d. %s-%s-%s:\n', i, row.location{1}, row.filterType{1}, row.mode{1});
    fprintf('   Mean Score: %.1f (Tight: %.1f, Leaky: %.1f)\n', ...
        row.mean_efficacy_score, row.tight_efficacy_score, ...
        row.leaky_efficacy_score);
    fprintf('   Score Range: %.1f–%.1f  (±%.1f)\n', ...
        row.worst_score, row.best_score, row.score_range_half);
end

fprintf('\nEfficacy component weights used:\n');
fprintf('  PM2.5 reduction: %.0f%%\n', weights.pm25_reduction * 100);
fprintf('  PM10 reduction: %.0f%%\n', weights.pm10_reduction * 100);
fprintf('  Cost effectiveness: %.0f%%\n', weights.cost_effectiveness * 100);
fprintf('  AQI hours avoided: %.0f%%\n', weights.aqi_hours_avoided * 100);

end

function metrics = extract_metrics(row, redAqiSuffix, costSuffix)
% Extract and validate metrics from a cost table row. Optional suffixes allow
% pulling either the mean values or the pre-computed bounds ("_lower" or "_upper").

if nargin < 2, redAqiSuffix = ""; end
if nargin < 3, costSuffix = ""; end

metrics = struct();

pm25Var = ['percent_PM25_reduction' redAqiSuffix];
if ismember(pm25Var, row.Properties.VariableNames)
    metrics.pm25_reduction = row{1, pm25Var};
else
    metrics.pm25_reduction = row.percent_PM25_reduction;
end

pm10Var = ['percent_PM10_reduction' redAqiSuffix];
if ismember(pm10Var, row.Properties.VariableNames)
    metrics.pm10_reduction = row{1, pm10Var};
else
    metrics.pm10_reduction = row.percent_PM10_reduction;
end

costVar = ['cost_per_AQI_hour_avoided' costSuffix];
if ismember(costVar, row.Properties.VariableNames)
    metrics.cost_per_aqi_hour = row{1, costVar};
else
    metrics.cost_per_aqi_hour = row.cost_per_AQI_hour_avoided;
end

aqiVar = ['AQI_hours_avoided' redAqiSuffix];
if ismember(aqiVar, row.Properties.VariableNames)
    metrics.aqi_hours_avoided = row{1, aqiVar};
else
    metrics.aqi_hours_avoided = row.AQI_hours_avoided;
end

% Handle invalid/missing values
if isnan(metrics.cost_per_aqi_hour) || isinf(metrics.cost_per_aqi_hour)
    metrics.cost_per_aqi_hour = 1000; % Penalty for poor cost effectiveness
end
if isnan(metrics.aqi_hours_avoided) || metrics.aqi_hours_avoided < 0
    metrics.aqi_hours_avoided = 0;
end
end

function score = calculate_single_efficacy_score(metrics, allData, weights)
% Calculate efficacy score for a single scenario
% Normalize each metric to 0-100 scale and apply weights

% Get data ranges for normalization
pm25_range = [min(allData.percent_PM25_reduction), max(allData.percent_PM25_reduction)];
pm10_range = [min(allData.percent_PM10_reduction), max(allData.percent_PM10_reduction)];

% For cost effectiveness, lower is better, so invert the scale
valid_costs = allData.cost_per_AQI_hour_avoided(~isnan(allData.cost_per_AQI_hour_avoided) & ...
    ~isinf(allData.cost_per_AQI_hour_avoided) & allData.cost_per_AQI_hour_avoided > 0);
if ~isempty(valid_costs)
    cost_range = [min(valid_costs), max(valid_costs)];
else
    cost_range = [1, 1000];
end

aqi_range = [min(allData.AQI_hours_avoided), max(allData.AQI_hours_avoided)];

% Normalize metrics to 0-100 scale
pm25_norm = normalize_metric(metrics.pm25_reduction, pm25_range, false);
pm10_norm = normalize_metric(metrics.pm10_reduction, pm10_range, false);
cost_norm = normalize_metric(metrics.cost_per_aqi_hour, cost_range, true); % Invert for cost
aqi_norm = normalize_metric(metrics.aqi_hours_avoided, aqi_range, false);

% Calculate weighted composite score
score = weights.pm25_reduction * pm25_norm + ...
    weights.pm10_reduction * pm10_norm + ...
    weights.cost_effectiveness * cost_norm + ...
    weights.aqi_hours_avoided * aqi_norm;
end

function breakdown = calculate_component_breakdown(metrics, allData, weights)
% Calculate individual component scores for detailed analysis
breakdown = struct();

% Get normalization ranges (same as in calculate_single_efficacy_score)
pm25_range = [min(allData.percent_PM25_reduction), max(allData.percent_PM25_reduction)];
pm10_range = [min(allData.percent_PM10_reduction), max(allData.percent_PM10_reduction)];

valid_costs = allData.cost_per_AQI_hour_avoided(~isnan(allData.cost_per_AQI_hour_avoided) & ...
    ~isinf(allData.cost_per_AQI_hour_avoided) & allData.cost_per_AQI_hour_avoided > 0);
if ~isempty(valid_costs)
    cost_range = [min(valid_costs), max(valid_costs)];
else
    cost_range = [1, 1000];
end

aqi_range = [min(allData.AQI_hours_avoided), max(allData.AQI_hours_avoided)];

% Calculate weighted component scores
breakdown.pm25_score = weights.pm25_reduction * normalize_metric(metrics.pm25_reduction, pm25_range, false);
breakdown.pm10_score = weights.pm10_reduction * normalize_metric(metrics.pm10_reduction, pm10_range, false);
breakdown.cost_score = weights.cost_effectiveness * normalize_metric(metrics.cost_per_aqi_hour, cost_range, true);
breakdown.aqi_score = weights.aqi_hours_avoided * normalize_metric(metrics.aqi_hours_avoided, aqi_range, false);
end

function normalized = normalize_metric(value, range, invert)
% Normalize a metric to 0-100 scale
% invert=true for metrics where lower values are better (e.g., cost)

if range(2) == range(1)
    normalized = 50; % Default to middle if no range
    return;
end

% Standard normalization to 0-100
normalized = 100 * (value - range(1)) / (range(2) - range(1));

% Invert if lower values are better
if invert
    normalized = 100 - normalized;
end

% Ensure bounds
normalized = max(0, min(100, normalized));
end