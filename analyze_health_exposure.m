function healthExposureTable = analyze_health_exposure(summaryTable)

% Takes a summaryTable of indoor PM2.5/PM10 results under different modes
% and returns a table with, for each (location, leakage, filterType, scenario),
% the number of hours spent in each AQI category.
%
% Inputs:
%   • summaryTable           Table with variables:
%       - location (string or char)
%       - leakage  (string or char)
%       - filterType (string or char)
%       - mode     (string or char: 'baseline','active','triggered','always_on')
%       - indoor_PM25 (cell array, each cell a numeric vector)
%       - indoor_PM10 (cell array, each cell a numeric vector)
%
% Output:
%   • healthExposureTable    Table with columns:
%       - location, leakage, filterType, scenario
%       - Good, Moderate, Unhealthy for Sensitive Groups,
%         Unhealthy, Very Unhealthy, Hazardous
%         (each a count of hours in that AQI category)
%
% This function is fail‑fast: if any required scenario or any PM data
% is missing (empty or NaN), it errors out with a clear identifier.

arguments
    summaryTable           table
end

% ---- Fail‑fast input validation ----
requiredCols = { ...
    'location','leakage','filterType','mode', ...
    'indoor_PM25','indoor_PM10'};
missingCols = setdiff(requiredCols, summaryTable.Properties.VariableNames);
if ~isempty(missingCols)
    error('analyze_health_exposure:MissingColumn', ...
        'Required column(s) %s missing from summaryTable.', ...
        strjoin(missingCols, ', '));
end

% ---- Define AQI categories ----
aqiNames  = ["Good", "Moderate", ...
    "Unhealthy for Sensitive Groups", "Unhealthy", ...
    "Very Unhealthy", "Hazardous"];
aqiLabels = cellstr(aqiNames);

% ---- Choose breakpoints ----
disp("Using updated AQI thresholds...");
pm25_edges = [0.0, 9.0, 35.4, 55.4, 125.4, 225.4, 325.4];
pm10_edges = [0.0, 54.0, 154.0, 254.0, 354.0, 424.0, 604.0];

% ---- Prepare scenarios and output table ----
allScenarios = ["baseline","active","always_on"];
combos     = unique(summaryTable(:,["location","leakage","filterType"]), 'rows');
N          = height(combos) * numel(allScenarios);
varTypes   = [repmat("string",1,3),"string", repelem("double",1,numel(aqiNames))];
varNames   = ["location","leakage","filterType","scenario", aqiNames];
healthExposureTable = table('Size',[N, numel(varNames)], ...
    'VariableTypes',varTypes, 'VariableNames',varNames);

% ---- Populate table ----
rowIdx = 1;
for i = 1:height(combos)
    loc  = combos.location(i);
    leak = combos.leakage(i);
    filt = combos.filterType(i);

    % extract baseline row
    isBase = strcmp(summaryTable.location,loc) & ...
             strcmp(summaryTable.leakage,leak) & ...
             strcmp(summaryTable.mode,"baseline");
    baseRow = summaryTable(isBase,:);
    if isempty(baseRow)
        error('analyze_health_exposure:MissingBaseline', ...
            'No baseline entry for %s / %s / %s.', loc, leak, filt);
    end

    if filt == "baseline"
        scenarioList = "baseline";
    else
        scenarioList = allScenarios;
    end

    for s = 1:numel(scenarioList)
        scenarioName = scenarioList(s);
        if scenarioName=="baseline"
            dataRow = baseRow;
        else
            baseMask = strcmp(summaryTable.location,loc) & ...
                       strcmp(summaryTable.leakage,leak) & ...
                       strcmp(summaryTable.filterType,filt);
            if scenarioName=="active"
                mask = baseMask & (strcmp(summaryTable.mode,"active") | ...
                                   strcmp(summaryTable.mode,"triggered"));
            else
                mask = baseMask & strcmp(summaryTable.mode, scenarioName);
            end
            dataRow = summaryTable(mask,:);
        end

        % fail‑fast if this scenario is missing
        if isempty(dataRow)
            error('analyze_health_exposure:MissingScenario', ...
                'No %s scenario data for %s / %s / %s.', ...
                scenarioName, loc, leak, filt);
        end

        % extract the PM vectors
        pm25 = dataRow.indoor_PM25{1};
        pm10 = dataRow.indoor_PM10{1};

        % ---- Fail‑fast for missing or invalid PM data ----
        if isempty(pm25) || isempty(pm10)
            error('analyze_health_exposure:MissingData', ...
                'Empty PM2.5 or PM10 data for %s / %s / %s scenario %s.', ...
                loc, leak, filt, scenarioName);
        end
        if any(isnan(pm25)) || any(isnan(pm10))
            error('analyze_health_exposure:MissingData', ...
                'NaN values detected in PM2.5 or PM10 data for %s / %s / %s scenario %s.', ...
                loc, leak, filt, scenarioName);
        end

        % count by AQI category
        cat25 = discretize(pm25, pm25_edges, 'categorical', aqiLabels);
        cat10 = discretize(pm10, pm10_edges, 'categorical', aqiLabels);
        worst = max(double(cat25), double(cat10));
        cats  = categorical(worst, 1:numel(aqiNames), ...
                  cellstr(aqiNames), 'Ordinal', true);
        counts = countcats(cats)';

        % write row
        healthExposureTable.location(rowIdx)   = loc;
        healthExposureTable.leakage(rowIdx)    = leak;
        healthExposureTable.filterType(rowIdx) = filt;
        healthExposureTable.scenario(rowIdx)   = scenarioName;
        healthExposureTable{rowIdx, aqiNames}  = counts;
        rowIdx = rowIdx + 1;
    end
end

% ---- Trim unused rows ----
healthExposureTable = healthExposureTable(1:rowIdx-1, :);

end
