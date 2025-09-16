function generate_summary_report(summaryTable, rangeTable, costTable, efficacyScoreTable, resultsDir, activeAnalysisResults)
% GENERATE_SUMMARY_REPORT Generate comprehensive text/markdown report with efficacy scores
% 
% Inputs:
%   summaryTable      - Main summary data
%   rangeTable       - Tight vs leaky range analysis  
%   costTable        - Cost-effectiveness analysis
%   efficacyScoreTable - Composite efficacy scores (can be empty)
%   resultsDir       - Output directory
%   activeAnalysisResults - (optional) Advanced active mode results

if nargin < 6
    activeAnalysisResults = [];
end

fid = fopen(fullfile(resultsDir, 'analysis_summary.md'), 'w');

fmtRange = @(meanVal, lowVal, upVal, meanFmt, boundFmt) ...
    format_bounds(meanVal, lowVal, upVal, 'MeanFormat', meanFmt, ...
    'BoundFormat', boundFmt, 'Style', 'both');

% Header with timestamp
fprintf(fid, '# Air Quality Simulation Analysis Summary\n');
fprintf(fid, 'Generated: %s\n\n', datestr(now));

% Executive Summary
fprintf(fid, '## Executive Summary\n\n');

% Count scenarios analyzed
nScenarios = height(unique(summaryTable(:,{'location','leakage','filterType','mode'})));
nLocations = numel(unique(summaryTable.location));
fprintf(fid, '- Analyzed %d total scenarios across %d locations\n', nScenarios, nLocations);
fprintf(fid, '- Compared HEPA vs MERV filters in tight vs leaky building envelopes\n');
fprintf(fid, '- Evaluated baseline, active, and always-on operating modes\n');

if ~isempty(efficacyScoreTable)
    fprintf(fid, '- **NEW**: Calculated composite efficacy scores for %d intervention configurations\n', height(efficacyScoreTable));
end
fprintf(fid, '\n');

%% Composite Efficacy Analysis (NEW SECTION)
if ~isempty(efficacyScoreTable)
    fprintf(fid, '## 🏆 Composite Efficacy Analysis\n\n');
    fprintf(fid, 'A weighted composite score combining:\n');
    fprintf(fid, '- PM2.5 reduction (40%% weight)\n');
    fprintf(fid, '- PM10 reduction (20%% weight)\n');
    fprintf(fid, '- Cost effectiveness (20%% weight)\n');
    fprintf(fid, '- AQI hours avoided (20%% weight)\n\n');
    
    % Top performers
    fprintf(fid, '### Top 5 Performing Configurations\n\n');
    topN = min(5, height(efficacyScoreTable));
    fprintf(fid, '| Rank | Configuration | Score | Half Range | Best Envelope | PM2.5 Component | Cost Component |\n');
    fprintf(fid, '|------|---------------|-------|-----|---------------|-----------------|----------------|\n');
    
    for i = 1:topN
        row = efficacyScoreTable(i,:);
        scoreStr = fmtRange(row.mean_efficacy_score, ...
            row.tight_efficacy_score, row.leaky_efficacy_score, '%.1f', '%.1f');
        fprintf(fid, '| #%d | %s-%s-%s | %s | %.1f | %s | %.1f | %.1f |\n', ...
            row.rank, row.location{1}, row.filterType{1}, row.mode{1}, ...
            scoreStr, row.score_range_half, ...
            row.best_scenario{1}, row.avg_pm25_component, row.avg_cost_component);
    end
    fprintf(fid, '\n');
    
    % Performance insights
    bestConfig = efficacyScoreTable(1,:);
    fprintf(fid, '### Key Insights\n\n');
    bestScoreStr = fmtRange(bestConfig.mean_efficacy_score, ...
        bestConfig.tight_efficacy_score, bestConfig.leaky_efficacy_score, ...
        '%.1f', '%.1f');
    fprintf(fid, '- **Best Overall Configuration**: %s-%s-%s (Score: %s)\n', ...
        bestConfig.location{1}, bestConfig.filterType{1}, bestConfig.mode{1}, ...
        bestScoreStr);
    
    % Calculate filter type performance
    hepaConfigs = efficacyScoreTable(strcmpi(efficacyScoreTable.filterType, 'hepa'), :);
    mervConfigs = efficacyScoreTable(strcmpi(efficacyScoreTable.filterType, 'merv'), :);
    
    if ~isempty(hepaConfigs) && ~isempty(mervConfigs)
        hepaAvg = mean(hepaConfigs.mean_efficacy_score);
        mervAvg = mean(mervConfigs.mean_efficacy_score);
        if hepaAvg > mervAvg
            fprintf(fid, '- **Filter Performance**: HEPA filters show %.1f%% higher average efficacy than MERV\n', ...
                ((hepaAvg - mervAvg) / mervAvg * 100));
        else
            fprintf(fid, '- **Filter Performance**: MERV filters show %.1f%% higher average efficacy than HEPA\n', ...
                ((mervAvg - hepaAvg) / hepaAvg * 100));
        end
    end
    
    % Envelope sensitivity
    tightBetter = sum(strcmp(efficacyScoreTable.best_scenario, 'tight'));
    leakyBetter = sum(strcmp(efficacyScoreTable.best_scenario, 'leaky'));
    fprintf(fid, '- **Envelope Sensitivity**: Tight envelopes perform better in %d/%d configurations (%.0f%%)\n', ...
        tightBetter, height(efficacyScoreTable), (tightBetter/height(efficacyScoreTable)*100));
    
    % High uncertainty configurations
    highUncertainty = efficacyScoreTable(efficacyScoreTable.score_range > 10, :);
    if ~isempty(highUncertainty)
        fprintf(fid, '- **High Uncertainty**: %d configurations show >10 point efficacy range between tight/leaky\n', ...
            height(highUncertainty));
    end
    fprintf(fid, '\n');
end

if exist('activeAnalysisResults', 'var') && ~isempty(activeAnalysisResults)
    fprintf(fid, '\n## Advanced Active Mode Analysis\n\n');
    fprintf(fid, 'Comprehensive aerosol dynamics analysis for active interventions.\n\n');

    % I/O Ratio Summary
    fprintf(fid, '### Indoor/Outdoor Ratio Performance\n\n');
    fprintf(fid, '| Configuration | PM2.5 I/O | PM10 I/O | Envelope Range |\n');
    fprintf(fid, '|---------------|-----------|----------|----------------|\n');

    if isfield(activeAnalysisResults, 'ioRatios')
        ioConfigs = fieldnames(activeAnalysisResults.ioRatios);
        for i = 1:length(ioConfigs)
            config = ioConfigs{i};
            ioData = activeAnalysisResults.ioRatios.(config);
            pm25Bounds = ioData.stats.pm25_range;
            pm10Bounds = ioData.stats.pm10_range;
            pm25Str = fmtRange(ioData.stats.pm25_mean, ...
                min(pm25Bounds), max(pm25Bounds), '%.3f', '%.3f');
            pm10Str = fmtRange(ioData.stats.pm10_mean, ...
                min(pm10Bounds), max(pm10Bounds), '%.3f', '%.3f');
            pm25RangePct = 100 * abs(diff(pm25Bounds)) / (2 * ioData.stats.pm25_mean);
            fprintf(fid, '| %s | %s | %s | Range %.1f%% |\n', ...
                strrep(config, '_', '-'), pm25Str, pm10Str, pm25RangePct);
        end
    end

    % Trigger Response Summary
    fprintf(fid, '\n### Trigger Response Characteristics\n\n');

    if isfield(activeAnalysisResults, 'triggerResponse')
        fprintf(fid, '| Configuration | Avg Response Time | Active Time | Peak Reduction |\n');
        fprintf(fid, '|---------------|-------------------|-------------|----------------|\n');

        triggerConfigs = fieldnames(activeAnalysisResults.triggerResponse);
        for i = 1:length(triggerConfigs)
            config = triggerConfigs{i};
            triggerData = activeAnalysisResults.triggerResponse.(config);

            if isfield(triggerData, 'metrics') && isfield(triggerData, 'pm25_response')
                respTimeStr = fmtRange(triggerData.metrics.avg_response_time, ...
                    triggerData.metrics.avg_response_time_bounds(1), ...
                    triggerData.metrics.avg_response_time_bounds(2), '%.1f h', '%.1f h');
                activeStr = fmtRange(triggerData.metrics.active_percentage, ...
                    triggerData.metrics.active_percentage_bounds(1), ...
                    triggerData.metrics.active_percentage_bounds(2), '%.0f%%', '%.0f%%');
                peakStr = fmtRange(triggerData.pm25_response.avg_peak_reduction, ...
                    triggerData.pm25_response.avg_peak_reduction_bounds(1), ...
                    triggerData.pm25_response.avg_peak_reduction_bounds(2), '%.1f%%', '%.1f%%');
                fprintf(fid, '| %s | %s | %s | %s |\n', ...
                    strrep(config, '_', '-'), respTimeStr, activeStr, peakStr);
            end
        end
    end

    % Key Findings
    fprintf(fid, '\n### Key Active Mode Findings\n\n');

    % Find best performing configuration
    bestIO = Inf;
    bestConfig = '';
    if isfield(activeAnalysisResults, 'ioRatios')
        ioConfigs = fieldnames(activeAnalysisResults.ioRatios);
        for i = 1:length(ioConfigs)
            config = ioConfigs{i};
            ioValue = activeAnalysisResults.ioRatios.(config).stats.pm25_mean;
            if ioValue < bestIO
                bestIO = ioValue;
                bestConfig = config;
            end
        end
        bestBounds = activeAnalysisResults.ioRatios.(bestConfig).stats.pm25_range;
        bestIOStr = fmtRange(bestIO, min(bestBounds), max(bestBounds), '%.3f', '%.3f');
        fprintf(fid, '- **Best I/O Ratio**: %s (%s)\n', strrep(bestConfig, '_', '-'), bestIOStr);
    end

    % Building envelope impact
    if isfield(activeAnalysisResults, 'uncertainty')
        uncertConfigs = fieldnames(activeAnalysisResults.uncertainty);
        avgUncertainty = 0;
        for i = 1:length(uncertConfigs)
            config = uncertConfigs{i};
            avgUncertainty = avgUncertainty + ...
                activeAnalysisResults.uncertainty.(config).pm25_range_percent;
        end
        avgUncertainty = avgUncertainty / length(uncertConfigs);
        fprintf(fid, '- **Average Envelope Uncertainty (half range)**: %.1f%%\n', avgUncertainty/2);
    end

    fprintf(fid, '- **Analysis Focus**: Triggered intervention dynamics only\n');
    fprintf(fid, '- **Envelope Treatment**: Tight/leaky as uncertainty bounds\n');

    fprintf(fid, '\nDetailed active mode analysis available in `active_mode_analysis/` subdirectory.\n');
end

%%% Traditional Performance Metrics (preserved from original)
fprintf(fid, '## Traditional Performance Metrics\n\n');

% Best performing configurations (traditional metrics)
fprintf(fid, '### Best PM2.5 Reduction\n');
[~, bestIdx] = max(costTable.percent_PM25_reduction);
if ~isempty(bestIdx)
    bestConfig = costTable(bestIdx,:);
    hasLeakCol = ismember('leakage', costTable.Properties.VariableNames);
    if hasLeakCol
        fprintf(fid, '- Configuration: %s-%s-%s-%s\n', bestConfig.location{1}, ...
            bestConfig.leakage{1}, bestConfig.filterType{1}, bestConfig.mode{1});
    else
        fprintf(fid, '- Configuration: %s-%s-%s (tight/leaky bounds)\n', ...
            bestConfig.location{1}, bestConfig.filterType{1}, bestConfig.mode{1});
    end
    % Report mean value with explicit uncertainty bounds
    if ismember('percent_PM25_reduction_lower', costTable.Properties.VariableNames)
        fprintf(fid, '- PM2.5 Reduction: %.1f%% (Bounds: %.1f%% - %.1f%%)\n', ...
            bestConfig.percent_PM25_reduction, ...
            bestConfig.percent_PM25_reduction_lower, bestConfig.percent_PM25_reduction_upper);
    else
        fprintf(fid, '- PM2.5 Reduction: %.1f%%\n', bestConfig.percent_PM25_reduction);
    end
    if ismember('total_cost_lower', costTable.Properties.VariableNames)
        fprintf(fid, '- Annual Cost: $%.2f (Bounds: $%.2f - $%.2f)\n\n', ...
            bestConfig.total_cost, bestConfig.total_cost_lower, bestConfig.total_cost_upper);
    else
        fprintf(fid, '- Annual Cost: $%.2f\n\n', bestConfig.total_cost);
    end
end

% Most cost-effective
fprintf(fid, '### Most Cost-Effective ($/AQI hour avoided)\n');
validCost = costTable(costTable.cost_per_AQI_hour_avoided > 0, :);
[~, bestCostIdx] = min(validCost.cost_per_AQI_hour_avoided);
if ~isempty(bestCostIdx)
    bestCostConfig = validCost(bestCostIdx,:);
    hasLeakCol = ismember('leakage', validCost.Properties.VariableNames);
    if hasLeakCol
        fprintf(fid, '- Configuration: %s-%s-%s-%s\n', bestCostConfig.location{1}, ...
            bestCostConfig.leakage{1}, bestCostConfig.filterType{1}, bestCostConfig.mode{1});
    else
        fprintf(fid, '- Configuration: %s-%s-%s (tight/leaky bounds)\n', ...
            bestCostConfig.location{1}, bestCostConfig.filterType{1}, bestCostConfig.mode{1});
    end
    % Include uncertainty bounds when available
    if ismember('cost_per_AQI_hour_avoided_lower', validCost.Properties.VariableNames)
        fprintf(fid, '- Cost per AQI hour avoided: $%.2f (Bounds: $%.2f - $%.2f)\n', ...
            bestCostConfig.cost_per_AQI_hour_avoided, ...
            bestCostConfig.cost_per_AQI_hour_avoided_lower, bestCostConfig.cost_per_AQI_hour_avoided_upper);
    else
        fprintf(fid, '- Cost per AQI hour avoided: $%.2f\n', bestCostConfig.cost_per_AQI_hour_avoided);
    end
    if ismember('percent_PM25_reduction_lower', validCost.Properties.VariableNames)
        fprintf(fid, '- PM2.5 Reduction: %.1f%% (Bounds: %.1f%% - %.1f%%)\n\n', ...
            bestCostConfig.percent_PM25_reduction, ...
            bestCostConfig.percent_PM25_reduction_lower, bestCostConfig.percent_PM25_reduction_upper);
    else
        fprintf(fid, '- PM2.5 Reduction: %.1f%%\n\n', bestCostConfig.percent_PM25_reduction);
    end
end

% Uncertainty Analysis
fprintf(fid, '## Uncertainty Analysis\n\n');

% Report highest uncertainty metrics
fprintf(fid, '### Metrics with Highest Building Envelope Sensitivity\n');
highUnc = rangeTable(rangeTable.range_percent > 20, :);
if ~isempty(highUnc)
    sortedHighUnc = sortrows(highUnc, 'range_percent', 'descend');
    maxShow = min(5, height(sortedHighUnc));
    for i = 1:maxShow
        fprintf(fid, '- %s: %.1f%% variation between tight and leaky\n', ...
            sortedHighUnc.metric{i}, sortedHighUnc.range_percent(i));
    end
else
    fprintf(fid, '- All metrics show <20%% variation\n');
end
fprintf(fid, '\n');

% Filter Comparison
fprintf(fid, '## Filter Type Comparison\n\n');

% Average performance by filter type
hepaRows = costTable(strcmpi(costTable.filterType, 'hepa'), :);
mervRows = costTable(strcmpi(costTable.filterType, 'merv'), :);

if ~isempty(hepaRows) && ~isempty(mervRows)
    fprintf(fid, '### Average Performance\n');
    hepaPM25Min = min(hepaRows.percent_PM25_reduction);
    hepaPM25Max = max(hepaRows.percent_PM25_reduction);
    mervPM25Min = min(mervRows.percent_PM25_reduction);
    mervPM25Max = max(mervRows.percent_PM25_reduction);
    hepaCostMin = min(hepaRows.total_cost);
    hepaCostMax = max(hepaRows.total_cost);
    mervCostMin = min(mervRows.total_cost);
    mervCostMax = max(mervRows.total_cost);
    fprintf(fid, '- HEPA PM2.5 Reduction: %.1f%% (range %.1f%% - %.1f%%)\n', ...
        mean(hepaRows.percent_PM25_reduction), hepaPM25Min, hepaPM25Max);
    fprintf(fid, '- MERV PM2.5 Reduction: %.1f%% (range %.1f%% - %.1f%%)\n', ...
        mean(mervRows.percent_PM25_reduction), mervPM25Min, mervPM25Max);
    fprintf(fid, '- HEPA Annual Cost: $%.2f (range $%.2f - $%.2f)\n', ...
        mean(hepaRows.total_cost), hepaCostMin, hepaCostMax);
    fprintf(fid, '- MERV Annual Cost: $%.2f (range $%.2f - $%.2f)\n\n', ...
        mean(mervRows.total_cost), mervCostMin, mervCostMax);
end

% Operating Mode Analysis
fprintf(fid, '## Operating Mode Analysis\n\n');
modes = unique(costTable.mode(~strcmp(costTable.mode, 'baseline')));
for m = 1:numel(modes)
    modeRows = costTable(strcmp(costTable.mode, modes{m}), :);
    if ~isempty(modeRows)
        fprintf(fid, '### %s Mode\n', modes{m});
        pm25Str = fmtRange(mean(modeRows.percent_PM25_reduction, 'omitnan'), ...
            min(modeRows.percent_PM25_reduction_lower, [], 'omitnan'), ...
            max(modeRows.percent_PM25_reduction_upper, [], 'omitnan'), '%.1f%%', '%.1f%%');
        costStr = fmtRange(mean(modeRows.total_cost, 'omitnan'), ...
            min(modeRows.total_cost_lower, [], 'omitnan'), ...
            max(modeRows.total_cost_upper, [], 'omitnan'), '$%.2f', '$%.2f');
        aqiStr = fmtRange(mean(modeRows.AQI_hours_avoided, 'omitnan'), ...
            min(modeRows.AQI_hours_avoided_lower, [], 'omitnan'), ...
            max(modeRows.AQI_hours_avoided_upper, [], 'omitnan'), '%.0f h', '%.0f h');
        fprintf(fid, '- Average PM2.5 Reduction: %s\n', pm25Str);
        fprintf(fid, '- Average Annual Cost: %s\n', costStr);
        fprintf(fid, '- Average AQI Hours Avoided: %s\n\n', aqiStr);
    end
end

% Location-specific findings
fprintf(fid, '## Location Analysis\n\n');
locations = unique(summaryTable.location);
for l = 1:numel(locations)
    locRows = costTable(strcmp(costTable.location, locations{l}), :);
    if ~isempty(locRows)
        fprintf(fid, '### %s\n', locations{l});
        [~, bestLocIdx] = max(locRows.percent_PM25_reduction);
        hasLeakCol = ismember('leakage', locRows.Properties.VariableNames);
        if hasLeakCol
            fprintf(fid, '- Best configuration: %s-%s-%s', ...
                locRows.leakage{bestLocIdx}, locRows.filterType{bestLocIdx}, locRows.mode{bestLocIdx});
        else
            fprintf(fid, '- Best configuration: %s-%s', ...
                locRows.filterType{bestLocIdx}, locRows.mode{bestLocIdx});
        end
        if ismember('percent_PM25_reduction_lower', locRows.Properties.VariableNames)
            fprintf(fid, ' (%.1f%% PM2.5 reduction, bounds %.1f%% - %.1f%%)\n', ...
                locRows.percent_PM25_reduction(bestLocIdx), ...
                locRows.percent_PM25_reduction_lower(bestLocIdx), ...
                locRows.percent_PM25_reduction_upper(bestLocIdx));
        else
            fprintf(fid, ' (%.1f%% PM2.5 reduction)\n', ...
                locRows.percent_PM25_reduction(bestLocIdx));
        end
        if ismember('total_cost_lower', locRows.Properties.VariableNames)
            fprintf(fid, '- Cost range: $%.2f - $%.2f (Best Cost: $%.2f, bounds $%.2f - $%.2f)\n\n', ...
                min(locRows.total_cost), max(locRows.total_cost), ...
                locRows.total_cost(bestLocIdx), locRows.total_cost_lower(bestLocIdx), locRows.total_cost_upper(bestLocIdx));
        else
            fprintf(fid, '- Cost range: $%.2f - $%.2f\n\n', ...
            min(locRows.total_cost), max(locRows.total_cost));
        end
    end
end

% Data Quality Notes
fprintf(fid, '## Data Quality Notes\n\n');
completeData = sum(summaryTable.data_complete);
totalRows = height(summaryTable);
fprintf(fid, '- Data completeness: %d/%d rows (%.1f%%)\n', ...
    completeData, totalRows, 100*completeData/totalRows);
fprintf(fid, '- Physical validity check passed: %d/%d rows\n', ...
    sum(summaryTable.physical_validity), totalRows);

% Files generated
fprintf(fid, '\n## Output Files\n\n');
fprintf(fid, '### Data Tables\n');
fprintf(fid, '- `summaryTable.mat` - Main processed simulation data\n');
fprintf(fid, '- `rangeTable.mat` - Tight vs leaky uncertainty analysis\n');
fprintf(fid, '- `costTable.mat` - Cost-effectiveness metrics\n');
fprintf(fid, '- `filterComparisonTable.mat` - HEPA vs MERV performance\n');
fprintf(fid, '- `efficacyTable.mat` - Baseline vs intervention analysis\n');
fprintf(fid, '- `healthExposureTable.mat` - AQI exposure analysis\n');
fprintf(fid, '- `tradeoffTable.mat` - Physical filter tradeoffs\n');

if ~isempty(efficacyScoreTable)
    fprintf(fid, '- `efficacyScoreTable.mat` - **NEW**: Composite efficacy scores\n');
end

fprintf(fid, '\n### Visualizations\n');
fprintf(fid, '- PM concentration envelope plots\n');
fprintf(fid, '- Cost-effectiveness quadrant maps\n');
fprintf(fid, '- Health exposure comparison charts\n');
fprintf(fid, '- Filter performance analysis plots\n');
fprintf(fid, '- Building envelope sensitivity analysis\n');

if ~isempty(efficacyScoreTable)
    fprintf(fid, '- **NEW**: Composite efficacy score rankings\n');
    fprintf(fid, '- **NEW**: Multi-criteria performance heatmaps\n');
    fprintf(fid, '- **NEW**: Component score breakdowns\n');
end

fprintf(fid, '\n### Reports\n');
fprintf(fid, '- `analysis_summary.md` - This report with efficacy analysis\n');

fclose(fid);

fprintf('✓ Summary report saved to: %s\n', fullfile(resultsDir, 'analysis_summary.md'));