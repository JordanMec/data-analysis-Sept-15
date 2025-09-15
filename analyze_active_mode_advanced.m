function activeAnalysisResults = analyze_active_mode_advanced(summaryTable, resultsDir)
% ANALYZE_ACTIVE_MODE_ADVANCED Comprehensive aerosol dynamics analysis for active interventions
%
% This function performs deep analysis on ONLY the active (triggered) mode data,
% treating tight/leaky as uncertainty bounds rather than separate scenarios.
%
% Analyses include:
% 1. Indoor/Outdoor (I/O) ratio dynamics and temporal patterns
% 2. Trigger response characterization (lag time, efficiency curves)
% 3. Particle penetration factor estimation with uncertainty
% 4. Size-dependent removal efficiency (PM2.5 vs PM10)
% 5. Outdoor event detection and intervention efficacy
% 6. Diurnal and temporal patterns in filtration performance
% 7. Cross-correlation analysis between outdoor spikes and indoor response
% 8. Filter-specific performance metrics under dynamic conditions
%
% Input:
%   summaryTable - Main data table with all simulation results
%   resultsDir   - Directory to save analysis outputs
%
% Output:
%   activeAnalysisResults - Comprehensive struct with all analysis results

fprintf('\n=== ADVANCED ACTIVE MODE AEROSOL ANALYSIS ===\n');
fprintf('Analyzing active intervention dynamics...\n\n');

% Create output directory for active mode analysis
activeDir = fullfile(resultsDir, 'active_mode_analysis');
if ~exist(activeDir, 'dir')
    mkdir(activeDir);
end

% Initialize results structure and load parameter registry
activeAnalysisResults = struct();
params = get_analysis_params(resultsDir);
activeAnalysisResults.params = params;

%% 1. Extract Active Mode Data with Bounds
fprintf('1. Extracting active mode data with tight/leaky bounds...\n');
activeData = extract_active_mode_data(summaryTable);
activeAnalysisResults.activeData = activeData;

%% 2. Indoor/Outdoor Ratio Analysis
fprintf('2. Analyzing I/O ratios and dynamics...\n');
ioAnalysis = analyze_io_ratios(activeData);
activeAnalysisResults.ioRatios = ioAnalysis;

% Visualize I/O ratio dynamics
plot_io_ratio_dynamics(ioAnalysis, activeDir);

%% 3. Trigger Response Characterization
fprintf('3. Characterizing trigger response behavior...\n');
triggerAnalysis = analyze_trigger_response(activeData, params);
activeAnalysisResults.triggerResponse = triggerAnalysis;

% Visualize trigger response metrics
plot_trigger_response_analysis(triggerAnalysis, activeDir, activeData, params);

%% 4. Particle Penetration and Removal Efficiency
fprintf('4. Calculating penetration factors and removal efficiency...\n');
penetrationAnalysis = analyze_penetration_efficiency(activeData);
activeAnalysisResults.penetration = penetrationAnalysis;

% Visualize penetration analysis
plot_penetration_analysis(penetrationAnalysis, activeDir);

%% 5. Outdoor Event Detection and Response
fprintf('5. Detecting outdoor pollution events and analyzing response...\n');
eventAnalysis = detect_analyze_pollution_events(activeData, params);
activeAnalysisResults.events = eventAnalysis;

% Visualize event response
plot_event_response_analysis(eventAnalysis, activeDir);

%% 6. Temporal Pattern Analysis
fprintf('6. Analyzing temporal patterns in filtration performance...\n');
temporalAnalysis = analyze_temporal_patterns(activeData);
activeAnalysisResults.temporal = temporalAnalysis;

% Visualize temporal patterns
plot_temporal_patterns(temporalAnalysis, activeDir);

%% 7. Cross-Correlation and Lag Analysis
fprintf('7. Performing cross-correlation analysis...\n');
correlationAnalysis = analyze_cross_correlations(activeData);
activeAnalysisResults.correlations = correlationAnalysis;

% Visualize correlation analysis
plot_correlation_analysis(correlationAnalysis, activeDir);

%% 8. Filter-Specific Performance Under Dynamic Conditions
fprintf('8. Comparing HEPA vs MERV under dynamic conditions...\n');
filterComparison = compare_filters_dynamic(activeData);
activeAnalysisResults.filterComparison = filterComparison;

% Visualize filter comparison
plot_dynamic_filter_comparison(filterComparison, activeDir);

%% 9. Uncertainty Quantification
fprintf('9. Quantifying uncertainty from building envelope...\n');
uncertaintyAnalysis = quantify_envelope_uncertainty(activeData, summaryTable);
activeAnalysisResults.uncertainty = uncertaintyAnalysis;

% Visualize uncertainty
plot_uncertainty_analysis(uncertaintyAnalysis, activeDir);

%% 10. Generate Comprehensive Report
fprintf('10. Generating comprehensive analysis report...\n');
generate_active_mode_report(activeAnalysisResults, activeDir);

fprintf('\n✓ Advanced active mode analysis complete!\n');
fprintf('Results saved to: %s\n', activeDir);

end