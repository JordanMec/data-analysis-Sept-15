function summaryTable = preprocess_structure_data(simulationData)
n = length(simulationData);

% Preallocate arrays
location = strings(n,1);
leakage = strings(n,1);
filterType = strings(n,1);
mode = strings(n,1);

% Store hourly pollutant series in cell arrays for later health exposure
% calculations
indoor_PM25 = cell(n,1);
indoor_PM10 = cell(n,1);
outdoor_PM25 = cell(n,1);
outdoor_PM10 = cell(n,1);

% Preallocate averages for quick access in other analyses
avg_indoor_PM25 = zeros(n,1);
avg_indoor_PM10 = zeros(n,1);
avg_outdoor_PM25 = zeros(n,1);
avg_outdoor_PM10 = zeros(n,1);
total_cost = zeros(n,1);
filter_replaced = NaN(n,1);  % Hours between filter changes (computed below)
filter_life_series = cell(n,1);
ach_series = cell(n,1);
max_ach = NaN(n,1);

% Future placeholders
pm25_efficiency = NaN(n,1);
pm10_efficiency = NaN(n,1);
aqi_hours_avoided = NaN(n,1);
cost_per_ug_pm25_removed = NaN(n,1);
cost_per_ug_pm10_removed = NaN(n,1);
cost_per_aqi_hour_avoided = NaN(n,1);

% Loop through simulation data
for i = 1:n
    location(i) = simulationData(i).location;
    leakage(i) = simulationData(i).leakage;
    filterType(i) = simulationData(i).filterType;
    mode(i) = simulationData(i).mode;

    % Store hourly pollutant concentrations
    indoor_PM25{i} = simulationData(i).indoor_PM25;
    indoor_PM10{i} = simulationData(i).indoor_PM10;
    outdoor_PM25{i} = simulationData(i).outdoor_PM25;
    outdoor_PM10{i} = simulationData(i).outdoor_PM10;
    filter_life_series{i} = simulationData(i).filter_life_series;

    % Optional ACH time series for ventilation analysis
    if isfield(simulationData(i), 'ach_series') && ~isempty(simulationData(i).ach_series)
        ach_series{i} = simulationData(i).ach_series;
        max_ach(i) = max(simulationData(i).ach_series);
    else
        ach_series{i} = [];
        max_ach(i) = NaN;
    end

    % Basic stats for quick comparisons
    avg_indoor_PM25(i) = mean(simulationData(i).indoor_PM25);
    avg_indoor_PM10(i) = mean(simulationData(i).indoor_PM10);
    avg_outdoor_PM25(i) = mean(simulationData(i).outdoor_PM25);
    avg_outdoor_PM10(i) = mean(simulationData(i).outdoor_PM10);
    total_cost(i) = simulationData(i).total_cost;

    % Compute average hours between filter replacements if life series provided
    filter_replaced(i) = compute_replacement_interval(filter_life_series{i});

end

% Ensure all hourly series have consistent lengths
lengths = cellfun(@numel, indoor_PM25);
if any(lengths ~= lengths(1))
    error(['Inconsistent length of indoor\_PM25 time series across simulations: ', ...
        mat2str(lengths)]);
end

% Create output table. Include hourly pollutant series as cell arrays so
% downstream analyses (e.g., health exposure calculations) have access to
% the full concentration profiles.
summaryTable = table(location, leakage, filterType, mode, ...
    indoor_PM25, indoor_PM10, outdoor_PM25, outdoor_PM10, ...
    filter_life_series, ach_series, ...
    avg_indoor_PM25, avg_indoor_PM10, ...
    avg_outdoor_PM25, avg_outdoor_PM10, max_ach, ...
    total_cost, filter_replaced, ...
    pm25_efficiency, pm10_efficiency, ...
    aqi_hours_avoided, cost_per_ug_pm25_removed, cost_per_ug_pm10_removed, ...
    cost_per_aqi_hour_avoided);
end

function hours = compute_replacement_interval(series)
%COMPUTE_REPLACEMENT_INTERVAL Estimate average hours between filter changes
%   Looks for increases in the filter life series to infer replacement events.
if isempty(series) || all(series == 100)
    hours = NaN;
    return;
end
resetIdx = find(diff(series) > 0);
if isempty(resetIdx)
    hours = NaN;
else
    % Ensure indices are treated as a single column vector before taking
    % differences so concatenation does not fail for column-oriented input
    intervalBoundaries = [0; resetIdx(:); numel(series)];
    intervals = diff(intervalBoundaries);
    hours = mean(intervals);
end
end
