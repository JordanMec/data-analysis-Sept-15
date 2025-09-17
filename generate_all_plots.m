function generate_all_plots(summaryTable, rangeTable, filterComparisonTable, healthExposureTable, avoidedExposureTable, costTable, tradeoffTable, figuresDir)
if ~exist(figuresDir, 'dir')
    mkdir(figuresDir);
end

% Create category folders
cats.pm        = fullfile(figuresDir, 'pm');
cats.cost      = fullfile(figuresDir, 'cost');
cats.exposure  = fullfile(figuresDir, 'exposure');
cats.tradeoffs = fullfile(figuresDir, 'tradeoffs');
cats.bounds    = fullfile(figuresDir, 'bounds');
cats.ranges    = fullfile(figuresDir, 'ranges');
cats.summary   = fullfile(figuresDir, 'summary');
catDirs = struct2cell(cats);
for i = 1:numel(catDirs)
    if ~exist(catDirs{i}, 'dir')
        mkdir(catDirs{i});
    end
end

% Advanced active mode visualizations are generated separately in
% `active_mode_analysis` by analyze_active_mode_advanced

% === Core Visualizations ===
plot_pm25_envelope(summaryTable, cats.pm);
plot_pm10_envelope(summaryTable, cats.pm);  % Fixed: removed extra arguments

plot_aqi_stacked_bars(healthExposureTable, cats.exposure);
plot_aqi_time_avoided(avoidedExposureTable, cats.exposure);
plot_cumulative_exposure(summaryTable, cats.exposure);
plot_cumulative_exposure_pm10(summaryTable, cats.exposure);

plot_cost_vs_aqi_avoided(costTable, cats.cost);
plot_efficiency_cost_quadrant(costTable, cats.cost);
plot_efficiency_cost_quadrant_pm10(costTable, cats.cost);
plot_cost_per_aqi_hour(costTable, cats.cost);

plot_airflow_penalty(tradeoffTable, cats.tradeoffs);
plot_filter_replacement(tradeoffTable, cats.tradeoffs);
plot_filter_life_envelope(summaryTable, cats.tradeoffs);

% === Enhanced Bounds Visualizations ===
plot_comprehensive_bounds(costTable, cats.bounds);
plot_statistical_summary(summaryTable, rangeTable, cats.bounds);
plot_deterministic_bounds(summaryTable, costTable, cats.bounds);
plot_envelope_sensitivity(summaryTable, costTable, cats.bounds);

% Plot tight vs leaky ranges for key metrics
rangeMetrics = {'avg_indoor_PM25','avg_indoor_PM10','total_cost','filter_replaced'};
% Determine global category order and color palette for consistency
allCats = strcat(strrep(rangeTable.location,'_','-'), "-", ...
                 strrep(rangeTable.filterType,'_','-'), "-", ...
                 strrep(rangeTable.mode,'_','-'));
uniqueCats = unique(allCats, 'stable');
rangeColors = get_color_palette(numel(uniqueCats));
for i = 1:numel(rangeMetrics)
    plot_scalar_ranges(rangeTable, rangeMetrics{i}, cats.ranges, uniqueCats, rangeColors, summaryTable);
end

% --- Summary visualizations ---
plot_intervention_matrix(costTable, 'PM25', cats.summary);
plot_executive_summary(costTable, cats.summary);

% Additional uncertainty-aware figures
disp("Generating enhanced uncertainty-aware visualizations...");
plot_configuration_overlap(costTable, cats.bounds);
% Additional PM10-focused summary visualizations
plot_intervention_matrix(costTable, 'PM10', cats.summary);

end