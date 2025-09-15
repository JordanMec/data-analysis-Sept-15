function investigate_aqi_bounds(summaryTable, costTable, healthExposureTable)
% INVESTIGATE_AQI_BOUNDS Debug AQI hours avoided lower bounds
%   Provides console output explaining scenarios where the AQI hours
%   avoided lower bound is zero and why.

fprintf('\n=== INVESTIGATING AQI HOURS AVOIDED BOUNDS ===\n\n');

pm25_good = 9.0;
pm10_good = 54.0;

fprintf('AQI "Good" Thresholds:\n');
fprintf('  PM2.5: %.1f \xB5g/m\xB3\n', pm25_good);
fprintf('  PM10: %.1f \xB5g/m\xB3\n\n', pm10_good);

uniqueConfigs = unique(costTable(:, {'location','filterType','mode'}));
problematicConfigs = {};
for i = 1:height(uniqueConfigs)
    loc  = uniqueConfigs.location{i};
    filt = uniqueConfigs.filterType{i};
    mode = uniqueConfigs.mode{i};

    if strcmp(mode, 'baseline'), continue; end

    fprintf('Configuration: %s-%s-%s\n', loc, filt, mode);
    costRow = costTable(strcmp(costTable.location, loc) & ...
                       strcmp(costTable.filterType, filt) & ...
                       strcmp(costTable.mode, mode), :);
    if isempty(costRow)
        fprintf('  WARNING: No cost data found\n\n');
        continue;
    end

    fprintf('  AQI Hours Avoided:\n');
    fprintf('    Mean: %.1f hours\n', costRow.AQI_hours_avoided);
    fprintf('    Lower bound: %.1f hours\n', costRow.AQI_hours_avoided_lower);
    fprintf('    Upper bound: %.1f hours\n', costRow.AQI_hours_avoided_upper);

    if costRow.AQI_hours_avoided_lower == 0
        problematicConfigs{end+1} = sprintf('%s-%s-%s', loc, filt, mode); %#ok<AGROW>
        fprintf('  *** ISSUE: Lower bound is ZERO ***\n');
        for envelope = {'tight','leaky'}
            fprintf('\n  Analyzing %s envelope:\n', envelope{1});
            baseRow = summaryTable(strcmp(summaryTable.location, loc) & ...
                                  strcmp(summaryTable.leakage, envelope{1}) & ...
                                  strcmp(summaryTable.filterType, filt) & ...
                                  strcmp(summaryTable.mode, 'baseline'), :);
            intRow  = summaryTable(strcmp(summaryTable.location, loc) & ...
                                  strcmp(summaryTable.leakage, envelope{1}) & ...
                                  strcmp(summaryTable.filterType, filt) & ...
                                  strcmp(summaryTable.mode, mode), :);
            if ~isempty(baseRow) && ~isempty(intRow)
                basePM25 = baseRow.indoor_PM25{1};
                basePM10 = baseRow.indoor_PM10{1};
                intPM25  = intRow.indoor_PM25{1};
                intPM10  = intRow.indoor_PM10{1};
                badHours = sum((basePM25 > pm25_good) | (basePM10 > pm10_good));
                improved = sum(((basePM25 > pm25_good) | (basePM10 > pm10_good)) & ...
                               ((intPM25 <= pm25_good) & (intPM10 <= pm10_good)));
                fprintf('    Baseline hours above threshold: %d\n', badHours);
                fprintf('    Hours improved by intervention: %d\n', improved);
                meanImprovement = mean(basePM25) - mean(intPM25);
                fprintf('    PM2.5 reduction: %.2f \xB5g/m\xB3\n', meanImprovement);
            else
                fprintf('    ERROR: Missing data for this envelope\n');
            end
        end
    end
    fprintf('\n');
end

fprintf('\n=== SUMMARY ===\n');
fprintf('Configurations with zero lower bound: %d\n', numel(problematicConfigs));
if ~isempty(problematicConfigs)
    fprintf('Problematic configurations:\n');
    for i = 1:numel(problematicConfigs)
        fprintf('  - %s\n', problematicConfigs{i});
    end
end
end