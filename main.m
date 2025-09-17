% main_updated.m - Enhanced master script with composite efficacy scoring
% This preserves ALL original functionality while adding the new efficacy analysis

close all; clear all; clc;

% Ensure helper functions are accessible when the script is run from elsewhere
[thisDir, ~, ~] = fileparts(mfilename('fullpath'));
addpath(thisDir);

%%  1. Setup (unchanged from original)
disp("Starting enhanced air quality simulation pipeline...");

% Determine location of simulation result files
dataDir = 'C:\Users\jorda\MATLAB Drive\twinSAPPHIRES\twinRESULTS\simulation_data_only_9_16';
if isempty(dataDir)
    dataDir = fullfile(pwd, 'data');
end
if ~exist(dataDir, 'dir')
    error('Data directory not found: %s', dataDir);
end

% Create timestamped results directory
timestamp = datestr(now, 'mmmm_dd_HH_MM_SS');
baseResultsDir = fullfile(pwd, 'results');
if ~exist(baseResultsDir, 'dir')
    mkdir(baseResultsDir);
end
resultsDir = fullfile(baseResultsDir, ['run_' timestamp]);
mkdir(resultsDir);
disp(['Created timestamped results folder: ', resultsDir]);

%% 2. Load raw simulation data (unchanged)
disp("Loading .mat simulation files...");
simData = collect_simulation_data(dataDir);
validate_simulation_data(simData);

%% 3. Preprocess and structure data (unchanged)
disp("Preprocessing and summarizing...");
summaryTable = preprocess_structure_data(simData);
provenance = create_data_provenance_table(summaryTable);
% Verify envelope bounds and consistency of time series
verify_envelope_completeness(summaryTable);

% Check data completeness only for numeric columns that should have values
numericCols = {'avg_indoor_PM25', 'avg_indoor_PM10', 'avg_outdoor_PM25', 'avg_outdoor_PM10', 'total_cost'};
% If all filter replacement intervals are NaN (e.g., short simulation period)
% exclude that column from the completeness check to avoid false negatives
if ~all(isnan(summaryTable.filter_replaced))
    numericCols{end+1} = 'filter_replaced';
else
    warning('Filter replacement data unavailable; ignoring in completeness check.');
end
summaryTable.data_complete = ~any(isnan(summaryTable{:, numericCols}), 2);

summaryTable.cost_includes_filter = false(height(summaryTable), 1);
summaryTable.physical_validity = summaryTable.avg_indoor_PM25 <= summaryTable.avg_outdoor_PM25;
save(fullfile(resultsDir, 'summaryTable.mat'), 'summaryTable', 'provenance');

%% 4. Build tight vs. leaky ranges (unchanged)
disp("Building range table for tight vs. leaky analysis...");
metrics = {'avg_indoor_PM25', 'avg_indoor_PM10', ...
           'avg_outdoor_PM25', 'avg_outdoor_PM10', ...
           'total_cost', 'filter_replaced'};
rangeTable = build_range_table(summaryTable, metrics);
save(fullfile(resultsDir,'rangeTable.mat'),'rangeTable');

%% 5. Filter comparison (HEPA vs. MERV) (unchanged)
disp("Running HEPA vs. MERV filter performance analysis...");
filterComparisonTable = analyze_filter_performance(summaryTable);
save(fullfile(resultsDir, 'filterComparisonTable.mat'), 'filterComparisonTable');

%% 6. Baseline vs. Active intervention analysis (unchanged)
disp("Analyzing efficacy of intervention (baseline vs. active)...");
efficacyTable = analyze_efficacy_vs_baseline(summaryTable);
save(fullfile(resultsDir, 'efficacyTable.mat'), 'efficacyTable');

%% 7. AQI health exposure analysis (unchanged)
disp("Analyzing AQI exposure and hours avoided...");
healthExposureTable = analyze_health_exposure(summaryTable);
save(fullfile(resultsDir, 'healthExposureTable.mat'), 'healthExposureTable');

% New: calculate avoided exposure relative to outdoor air
disp("Calculating avoided AQI exposure by category...");
avoidedExposureTable = analyze_avoided_exposure(summaryTable);
save(fullfile(resultsDir, 'avoidedExposureTable.mat'), 'avoidedExposureTable');

%% 8. Cost-benefit analysis (unchanged)
disp("Running cost-benefit calculations...");
costTable = analyze_costs(summaryTable, healthExposureTable);
save(fullfile(resultsDir, 'costTable.mat'), 'costTable');

%% 9. Physical tradeoffs (maintenance, airflow) (unchanged)
disp("Analyzing physical filter tradeoffs...");
tradeoffTable = analyze_physical_tradeoffs(summaryTable);
save(fullfile(resultsDir, 'tradeoffTable.mat'), 'tradeoffTable');

%% 10. NEW: Calculate Composite Efficacy Scores
disp("Computing composite efficacy scores (NEW ANALYSIS)...");
efficacyScoreTable = table(); % Initialize empty in case of error

try
    % Calculate the composite efficacy scores
    efficacyScoreTable = calculate_efficacy_scores(summaryTable, costTable, healthExposureTable);
    save(fullfile(resultsDir, 'efficacyScoreTable.mat'), 'efficacyScoreTable');
    
    % Display key results immediately
    fprintf('\n=== COMPOSITE EFFICACY SCORE RESULTS ===\n');
    fprintf('Successfully calculated efficacy scores for %d configurations\n', height(efficacyScoreTable));
    
    % Show top 5 configurations
    fprintf('\nTOP 5 CONFIGURATIONS BY COMPOSITE EFFICACY:\n');
    topConfigs = efficacyScoreTable(1:min(5, height(efficacyScoreTable)), :);
    for i = 1:height(topConfigs)
        fprintf('%d. %s-%s-%s: Score %.1f (±%.1f)\n', ...
            topConfigs.rank(i), topConfigs.location{i}, ...
            topConfigs.filterType{i}, topConfigs.mode{i}, ...
            topConfigs.mean_efficacy_score(i), topConfigs.score_range_half(i));
    end
    
    % Identify best overall configuration
    bestConfig = efficacyScoreTable(1,:);
    fprintf('\n🏆 BEST OVERALL: %s-%s-%s (Score: %.1f ± %.1f)\n', ...
        bestConfig.location{1}, bestConfig.filterType{1}, bestConfig.mode{1}, ...
        bestConfig.mean_efficacy_score, bestConfig.score_range_half);
    
    % Check for configurations with high uncertainty
    highUncertainty = efficacyScoreTable(efficacyScoreTable.score_range > 10, :);
    if ~isempty(highUncertainty)
        fprintf('\n⚠️  CONFIGURATIONS WITH HIGH UNCERTAINTY (>10 point range):\n');
        for i = 1:min(3, height(highUncertainty))
            fprintf('   %s-%s-%s (range: %.1f points)\n', ...
                highUncertainty.location{i}, highUncertainty.filterType{i}, ...
                highUncertainty.mode{i}, highUncertainty.score_range(i));
        end
    end
    fprintf('\n');
    
catch ME
    warning('Failed to calculate efficacy scores: %s', ME.message);
    fprintf('Continuing with traditional analysis only...\n');
end

%% 11. Advanced Active Mode Aerosol Analysis (NEW)
disp("Running advanced aerosol analysis for active mode...");
activeAnalysisResults = analyze_active_mode_advanced(summaryTable, resultsDir);
save(fullfile(resultsDir, 'activeAnalysisResults.mat'), 'activeAnalysisResults');

% Display key active mode insights
fprintf('\n=== ACTIVE MODE AEROSOL ANALYSIS HIGHLIGHTS ===\n');

% Show average I/O ratios
configs = fieldnames(activeAnalysisResults.ioRatios);
fprintf('\nAverage Indoor/Outdoor Ratios (Active Mode):\n');
for i = 1:length(configs)
    config = configs{i};
    ioData = activeAnalysisResults.ioRatios.(config);
    pm25Bounds = ioData.stats.pm25_range;
    pm10Bounds = ioData.stats.pm10_range;
    pm25Str = format_bounds(ioData.stats.pm25_mean, ...
        min(pm25Bounds), max(pm25Bounds), 'MeanFormat', '%.3f', ...
        'BoundFormat', '%.3f', 'Style', 'both');
    pm10Str = format_bounds(ioData.stats.pm10_mean, ...
        min(pm10Bounds), max(pm10Bounds), 'MeanFormat', '%.3f', ...
        'BoundFormat', '%.3f', 'Style', 'both');
    fprintf('  %s: PM2.5=%s, PM10=%s\n', strrep(config, '_', '-'), pm25Str, pm10Str);
end

% Show trigger response metrics
if isfield(activeAnalysisResults, 'triggerResponse')
    fprintf('\nTrigger Response Performance:\n');
    triggerConfigs = fieldnames(activeAnalysisResults.triggerResponse);
    for i = 1:length(triggerConfigs)
        config = triggerConfigs{i};
        if isfield(activeAnalysisResults.triggerResponse.(config), 'metrics')
            metrics = activeAnalysisResults.triggerResponse.(config).metrics;
            if isfield(metrics, 'avg_response_time') && ~isnan(metrics.avg_response_time)
                respStr = format_bounds(metrics.avg_response_time, ...
                    metrics.avg_response_time_bounds(1), ...
                    metrics.avg_response_time_bounds(2), ...
                    'MeanFormat', '%.1f h', 'BoundFormat', '%.1f h', ...
                    'Style', 'both');
                activeStr = format_bounds(metrics.active_percentage, ...
                    metrics.active_percentage_bounds(1), ...
                    metrics.active_percentage_bounds(2), ...
                    'MeanFormat', '%.0f%%', 'BoundFormat', '%.0f%%', ...
                    'Style', 'both');
                fprintf('  %s: Response Time=%s, Active=%s of time\n', ...
                    strrep(config, '_', '-'), respStr, activeStr);
            end
        end
    end
end

% Show filter comparison
if isfield(activeAnalysisResults, 'filterComparison')
    fprintf('\nHEPA vs MERV Performance (Active Mode):\n');
    locations = fieldnames(activeAnalysisResults.filterComparison);
    for i = 1:length(locations)
        location = locations{i};
        comparison = activeAnalysisResults.filterComparison.(location);
        if isfield(comparison, 'hepa') && isfield(comparison, 'merv')
            fprintf('  %s:\n', location);
            hepaIO = format_bounds(comparison.hepa.avg_io_ratio_pm25, ...
                comparison.hepa.avg_io_ratio_pm25_lower, comparison.hepa.avg_io_ratio_pm25_upper, ...
                'MeanFormat', '%.3f', 'BoundFormat', '%.3f', 'Style', 'both');
            hepaPeak = format_bounds(comparison.hepa.peak_reduction, ...
                comparison.hepa.peak_reduction_lower, comparison.hepa.peak_reduction_upper, ...
                'MeanFormat', '%.1f%%', 'BoundFormat', '%.1f%%', 'Style', 'both');
            mervIO = format_bounds(comparison.merv.avg_io_ratio_pm25, ...
                comparison.merv.avg_io_ratio_pm25_lower, comparison.merv.avg_io_ratio_pm25_upper, ...
                'MeanFormat', '%.3f', 'BoundFormat', '%.3f', 'Style', 'both');
            mervPeak = format_bounds(comparison.merv.peak_reduction, ...
                comparison.merv.peak_reduction_lower, comparison.merv.peak_reduction_upper, ...
                'MeanFormat', '%.1f%%', 'BoundFormat', '%.1f%%', 'Style', 'both');
            fprintf('    HEPA: I/O PM2.5=%s, Peak Reduction=%s\n', hepaIO, hepaPeak);
            fprintf('    MERV: I/O PM2.5=%s, Peak Reduction=%s\n', mervIO, mervPeak);
        end
    end
end

fprintf('\n✓ Active mode analysis complete - see %s for detailed results\n', ...
    fullfile(resultsDir, 'active_mode_analysis'));

%% 12. Generate ALL plots (original + new efficacy plots)
disp("Generating comprehensive visualizations...");

% ORIGINAL PLOTS - All preserved exactly as before
generate_all_plots(summaryTable, rangeTable, filterComparisonTable, ...
    healthExposureTable, avoidedExposureTable, costTable, tradeoffTable, resultsDir);

% NEW EFFICACY PLOTS - Only if efficacy scores were calculated successfully
if ~isempty(efficacyScoreTable) && height(efficacyScoreTable) > 0
    try
        disp("Generating NEW efficacy score visualizations...");
        plot_efficacy_scores(efficacyScoreTable, resultsDir);
        disp("✓ Efficacy score plots generated successfully");
    catch ME
        warning('Failed to generate efficacy score plots: %s', ME.message);
        disp('Original plots remain available');
    end
else
    disp("Skipping efficacy score plots (no valid efficacy data)");
end

%% 13. Generate summary report
disp("Generating summary report...");
generate_summary_report(summaryTable, rangeTable, costTable, efficacyScoreTable, resultsDir, activeAnalysisResults);
disp("✓ Summary report generated with efficacy analysis");

% Validate that all saved outputs include tight/leaky bound pairs
validate_bound_pairing(resultsDir);

%% 14. Final completion message with comprehensive results
disp("✅ ENHANCED ANALYSIS COMPLETE!");
disp("==========================================");
disp(['📁 All results saved to: ', resultsDir]);
disp("");

% Summary of what was generated
fprintf('📊 GENERATED ANALYSES:\n');
fprintf('  ✓ Original air quality simulation analysis\n');
fprintf('  ✓ PM2.5/PM10 concentration envelopes\n');
fprintf('  ✓ Cost-effectiveness analysis\n');
fprintf('  ✓ Health exposure (AQI) analysis\n');
fprintf('  ✓ Filter performance comparisons\n');
fprintf('  ✓ Physical tradeoff analysis\n');
fprintf('  ✓ Building envelope sensitivity analysis\n');

if ~isempty(efficacyScoreTable) && height(efficacyScoreTable) > 0
    fprintf('  ✓ NEW: Composite efficacy scoring\n');
    fprintf('  ✓ NEW: Multi-criteria performance ranking\n');
    fprintf('  ✓ NEW: Enhanced uncertainty quantification\n');
    
    % Final summary of best configuration
    bestConfig = efficacyScoreTable(1,:);
    fprintf('\n🎯 RECOMMENDED CONFIGURATION:\n');
    fprintf('   Configuration: %s-%s-%s\n', bestConfig.location{1}, bestConfig.filterType{1}, bestConfig.mode{1});
    fprintf('   Composite Score: %.1f ± %.1f (out of 100)\n', bestConfig.mean_efficacy_score, bestConfig.score_range_half);
    fprintf('   Ranking: #1 out of %d configurations\n', height(efficacyScoreTable));
    fprintf('   Best Envelope: %s building envelope\n', bestConfig.best_scenario{1});
    
    % Performance breakdown
    fprintf('\n📈 PERFORMANCE BREAKDOWN:\n');
    fprintf('   PM2.5 Component: %.1f/40 points\n', bestConfig.avg_pm25_component);
    fprintf('   PM10 Component: %.1f/20 points\n', bestConfig.avg_pm10_component);
    fprintf('   Cost Component: %.1f/20 points\n', bestConfig.avg_cost_component);
    fprintf('   AQI Component: %.1f/20 points\n', bestConfig.avg_aqi_component);
else
    fprintf('  ⚠️  Efficacy scoring skipped due to data issues\n');
end

fprintf('\n📄 REPORTS GENERATED:\n');
fprintf('  • analysis_summary.md\n');

fprintf('\n🔍 KEY FILES TO REVIEW:\n');
fprintf('  • %s (all summary tables)\n', fullfile(resultsDir, '*.mat'));
fprintf('  • %s (visualization figures)\n', fullfile(resultsDir, '*.png'));
if ~isempty(efficacyScoreTable) && height(efficacyScoreTable) > 0
    fprintf('  • efficacy_scores_comprehensive.png (NEW - multi-criteria analysis)\n');
    fprintf('  • efficacy_ranking_table.png (NEW - performance rankings)\n');
end


disp("==========================================");
