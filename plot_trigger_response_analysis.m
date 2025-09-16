function plot_trigger_response_analysis(triggerAnalysis, saveDir, activeData, params)
%PLOT_TRIGGER_RESPONSE_ANALYSIS Visualize trigger response metrics
%   PLOT_TRIGGER_RESPONSE_ANALYSIS(TRIGGERANALYSIS, SAVEDIR, ACTIVEDATA, PARAMS)
%   creates summary figures. ACTIVEDATA and PARAMS required
%   for the event timeline subplot.
if nargin < 3
    activeData = struct();
end
if nargin < 4
    params = struct();
end
%% Visualization Function 2: Trigger Response Analysis
if isempty(fieldnames(triggerAnalysis))
    warning('plot_trigger_response_analysis: no data provided, skipping plot.');
    return;
end

fig = figure('Visible', 'off');
set_figure_fullscreen(fig);

configs = fieldnames(triggerAnalysis);
nConfigs = length(configs);

% Summary metrics comparison
subplot(2, 3, 1);
hold on;

lag_times = [];
peak_reductions = [];
labels = {};

for i = 1:nConfigs
    config = configs{i};
    if isfield(triggerAnalysis.(config), 'pm25_response')
        response = triggerAnalysis.(config).pm25_response;
        lag_times(end+1) = response.avg_lag_time;
        peak_reductions(end+1) = response.avg_peak_reduction;
        labels{end+1} = strrep(config, '_', '-');
    end
end

if ~isempty(lag_times)
    scatter(lag_times, peak_reductions, 100, 'filled');
    for i = 1:length(labels)
        text(lag_times(i)+0.1, peak_reductions(i), labels{i}, 'FontSize', 8);
    end
    xlabel('Average Lag Time (hours)');
    ylabel('Average Peak Reduction (%)');
    title('Trigger Response Performance');
    grid on;
end

% Response time distribution
subplot(2, 3, 2);
hold on;
colors = lines(nConfigs);

for i = 1:nConfigs
    config = configs{i};
    if isfield(triggerAnalysis.(config), 'metrics')
        metrics = triggerAnalysis.(config).metrics;
        if isfield(metrics, 'avg_response_time') && ~isnan(metrics.avg_response_time)
            bar(i, metrics.avg_response_time, 'FaceColor', colors(i,:));
            if isfield(metrics, 'avg_response_time_bounds')
                lb = metrics.avg_response_time_bounds(1);
                ub = metrics.avg_response_time_bounds(2);
                errLow = metrics.avg_response_time - lb;
                errHigh = ub - metrics.avg_response_time;
                errorbar(i, metrics.avg_response_time, errLow, errHigh, 'k');
            elseif isfield(metrics, 'response_time_std')
                errorbar(i, metrics.avg_response_time, metrics.response_time_std, 'k');
            end
        end
    end
end

set(gca, 'XTick', 1:nConfigs, 'XTickLabel', labels);
ylabel('Response Time (hours)');
title('Average System Response Time');
xtickangle(45);
grid on;

% Active vs Inactive efficiency
subplot(2, 3, 3);
active_ratios = [];
inactive_ratios = [];

for i = 1:nConfigs
    config = configs{i};
    if isfield(triggerAnalysis.(config), 'metrics')
        metrics = triggerAnalysis.(config).metrics;
        if isfield(metrics, 'active_io_ratio')
            active_ratios(i) = metrics.active_io_ratio;
            inactive_ratios(i) = metrics.inactive_io_ratio;
        else
            active_ratios(i) = NaN;
            inactive_ratios(i) = NaN;
        end
    end
end

x = 1:nConfigs;
width = 0.35;
hActive = bar(x - width/2, active_ratios, width, 'FaceColor', [0.2 0.6 0.2]);
hold on;
hInactive = bar(x + width/2, inactive_ratios, width, 'FaceColor', [0.8 0.2 0.2]);
set(gca, 'XTick', x, 'XTickLabel', labels);
ylabel('I/O Ratio');
legend([hActive hInactive], {'Active', 'Inactive'}, 'Location', 'best');
title('Active vs Inactive Performance');
xtickangle(45);
grid on;

% Event timeline example (first config)
subplot(2, 3, [4 6]);
config = configs{1};
data = triggerAnalysis.(config);

eventTbl = table();
if nargin >= 3 && ~isempty(activeData) && isfield(activeData, config)
    series = activeData.(config);
    if nargin < 4 || isempty(params)
        params = get_analysis_params();
    end
    tvec = (1:numel(series.outdoor_PM25))';
    events = [];
    if isfield(series, 'intervention_on')
        events = detect_intervention_events(series.intervention_on, ...
            series.outdoor_PM25, tvec, params);
    elseif isfield(series, 'fan_status')
        events = detect_intervention_events(series.fan_status, ...
            series.outdoor_PM25, tvec, params);
    else
        events = detect_outdoor_events(series.outdoor_PM25, tvec, 'PM2.5', params);
    end

    if ~isempty(events)
        eventTbl = compute_event_metrics_table(string(config), "PM2.5", events, ...
            series.outdoor_PM25(:), series.indoor_PM25_mean(:), params, tvec);
    end
end

if ~isempty(eventTbl)
    plot_event_timeline(eventTbl, config);
else
    plot_event_timeline_example(data, config);
end

sgtitle('Trigger Response Analysis - Active Mode', 'FontSize', 14, 'FontWeight', 'bold');
save_figure(fig, saveDir, 'trigger_response_analysis.png');
close(fig);
end

%% Visualization Function 3: Penetration Analysis
function plot_penetration_analysis(penetrationAnalysis, saveDir)
fig = figure('Visible', 'off');
set_figure_fullscreen(fig);

configs = fieldnames(penetrationAnalysis);
nConfigs = length(configs);

% Penetration factors comparison
subplot(2, 2, 1);
hold on;

pm25_factors = [];
pm10_factors = [];
pm25_bounds = [];
pm10_bounds = [];
labels = {};

for i = 1:nConfigs
    config = configs{i};
    data = penetrationAnalysis.(config);
    
    pm25_factors(i) = data.pm25_penetration_mean;
    pm10_factors(i) = data.pm10_penetration_mean;
    pm25_bounds(i,:) = data.pm25_penetration_bounds;
    pm10_bounds(i,:) = data.pm10_penetration_bounds;
    labels{i} = sprintf('%s\n%s Filter', strrep(data.location, '_', ' '), upper(data.filterType));
end

x = 1:nConfigs;
width = 0.35;

% Plot with error bars
bar(x - width/2, pm25_factors, width, 'FaceColor', [0.2 0.4 0.8]);
bar(x + width/2, pm10_factors, width, 'FaceColor', [0.8 0.3 0.3]);

% Add error bars for bounds
errorbar(x - width/2, pm25_factors, ...
    pm25_factors - pm25_bounds(:,1)', pm25_bounds(:,2)' - pm25_factors, ...
    'k', 'LineStyle', 'none');
errorbar(x + width/2, pm10_factors, ...
    pm10_factors - pm10_bounds(:,1)', pm10_bounds(:,2)' - pm10_factors, ...
    'k', 'LineStyle', 'none');

set(gca, 'XTick', x, 'XTickLabel', labels);
ylabel('Penetration Factor');
legend({'PM2.5', 'PM10'}, 'Location', 'best');
title('Particle Penetration Factors');
grid on;
ylim([0 1]);

% Removal efficiency
subplot(2, 2, 2);
pm25_removal = (1 - pm25_factors) * 100;
pm10_removal = (1 - pm10_factors) * 100;
% Bounds come as [tightMean, leakyMean]; ensure lower bound first
pm25_pen_sorted = sort(pm25_bounds, 2);  % ascending penetration
pm10_pen_sorted = sort(pm10_bounds, 2);
pm25_removal_bounds = (1 - fliplr(pm25_pen_sorted)) * 100;
pm10_removal_bounds = (1 - fliplr(pm10_pen_sorted)) * 100;

bar(x - width/2, pm25_removal, width, 'FaceColor', [0.2 0.4 0.8]);
hold on;
bar(x + width/2, pm10_removal, width, 'FaceColor', [0.8 0.3 0.3]);

errorbar(x - width/2, pm25_removal, ...
    pm25_removal - pm25_removal_bounds(:,1)', pm25_removal_bounds(:,2)' - pm25_removal, ...
    'k', 'LineStyle', 'none', 'HandleVisibility', 'off');
errorbar(x + width/2, pm10_removal, ...
    pm10_removal - pm10_removal_bounds(:,1)', pm10_removal_bounds(:,2)' - pm10_removal, ...
    'k', 'LineStyle', 'none', 'HandleVisibility', 'off');

set(gca, 'XTick', x, 'XTickLabel', labels);
ylabel('Removal Efficiency (%)');
legend({'PM2.5', 'PM10'}, 'Location', 'best');
title('Particle Removal Efficiency');
grid on;

% Size-dependent efficiency ratio
subplot(2, 2, 3);
size_ratio = pm10_factors ./ pm25_factors;
ratio_bounds(:,1) = pm10_bounds(:,1) ./ pm25_bounds(:,2);
ratio_bounds(:,2) = pm10_bounds(:,2) ./ pm25_bounds(:,1);

bar(size_ratio, 'FaceColor', [0.6 0.6 0.6]);
hold on;
errorbar(x, size_ratio, ...
    size_ratio - ratio_bounds(:,1)', ratio_bounds(:,2)' - size_ratio, ...
    'k', 'LineStyle', 'none', 'HandleVisibility', 'off');

set(gca, 'XTick', x, 'XTickLabel', labels);
ylabel('PM10/PM2.5 Penetration Ratio');
title('Size-Dependent Penetration');
yline(1, '--k', 'Equal Penetration');
grid on;

% Dynamic penetration over time (example)
subplot(2, 2, 4);
% Show how penetration varies over time for first config
config = configs{1};
data = penetrationAnalysis.(config);
if isfield(data, 'hourly_penetration_pm25')
    t = 1:min(168, length(data.hourly_penetration_pm25)); % First week
    plot(t, data.hourly_penetration_pm25(t), 'b-', 'LineWidth', 1.5);
    hold on;
    plot(t, data.hourly_penetration_pm10(t), 'r-', 'LineWidth', 1.5);
    xlabel('Hour');
    ylabel('Penetration Factor');
    title(sprintf('Temporal Variation - %s', config));
    legend({'PM2.5', 'PM10'}, 'Location', 'best');
    grid on;
end

sgtitle('Particle Penetration Analysis - Active Mode', 'FontSize', 14, 'FontWeight', 'bold');
save_figure(fig, saveDir, 'penetration_analysis.png');
close(fig);
end

%% Visualization Function 4: Event Response Analysis
function plot_event_response_analysis(eventAnalysis, saveDir)
fig = figure('Visible', 'off');
set_figure_fullscreen(fig);

configs = fieldnames(eventAnalysis);
colors = get_color_palette(length(configs));

% Event statistics summary
subplot(2, 3, 1);
event_counts = [];
avg_durations = [];
count_bounds = [];
duration_bounds = [];
labels = {};

for i = 1:length(configs)
    config = configs{i};
    data = eventAnalysis.(config);
    event_counts(i) = data.total_events;
    avg_durations(i) = data.avg_event_duration;
    if isfield(data, 'total_events_bounds')
        count_bounds(i,:) = data.total_events_bounds;
    else
        count_bounds(i,:) = [NaN NaN];
    end
    if isfield(data, 'avg_event_duration_bounds')
        duration_bounds(i,:) = data.avg_event_duration_bounds;
    else
        duration_bounds(i,:) = [NaN NaN];
    end
    labels{i} = strrep(config, '_', ' ');
end

positions = 1:length(configs);
offset = 0.2;

yyaxis left;
b1 = bar(positions - offset, event_counts, 0.4, 'FaceColor','flat');
b1.CData = colors;
hold on;
errorbar(positions - offset, event_counts, event_counts - count_bounds(:,1)', count_bounds(:,2)' - event_counts, 'k', 'LineStyle','none');
ylabel('Number of Events');

yyaxis right;
b2 = bar(positions + offset, avg_durations, 0.4, 'FaceColor','flat');
b2.CData = colors;
hold on;
errorbar(positions + offset, avg_durations, avg_durations - duration_bounds(:,1)', duration_bounds(:,2)' - avg_durations, 'k', 'LineStyle','none');
ylabel('Avg Duration (hours)');

text(0.02,0.98,'Error bars show tight/leaky bounds', 'Units','normalized', ...
    'VerticalAlignment','top','FontSize',8,'FontAngle','italic');

set(gca, 'XTick', 1:length(configs), 'XTickLabel', labels);
xtickangle(45);
title('Pollution Event Statistics');
grid on;

% Response effectiveness scatter
subplot(2, 3, 2);
peak_reductions = [];
integrated_reductions = [];

for i = 1:length(configs)
    config = configs{i};
    data = eventAnalysis.(config);
    if isfield(data, 'pm25_response')
        peak_reductions(i) = data.pm25_response.avg_peak_reduction;
        integrated_reductions(i) = data.pm25_response.avg_integrated_reduction;
    else
        peak_reductions(i) = NaN;
        integrated_reductions(i) = NaN;
    end
end

scatter(peak_reductions, integrated_reductions, 100, 1:length(configs), 'filled');
xlabel('Peak Reduction (%)');
ylabel('Integrated Reduction (%)');
title('Event Response Effectiveness');
colormap(lines(length(configs)));
grid on;

% Add diagonal reference line
lims = [0 100];
plot(lims, lims, 'k--', 'LineWidth', 0.5);

% Event severity distribution
subplot(2, 3, 3);
hold on;
colors = lines(2); % 1=tight, 2=leaky
offset = 0.2;

for i = 1:length(configs)
    config = configs{i};
    data = eventAnalysis.(config);
    if isfield(data, 'event_severities_tight') && ~isempty(data.event_severities_tight)
        boxchart(ones(numel(data.event_severities_tight),1)*(i-offset), ...
            data.event_severities_tight(:), 'BoxWidth',0.3, ...
            'BoxFaceColor', colors(1,:), 'MarkerStyle','.');
    end
    if isfield(data, 'event_severities_leaky') && ~isempty(data.event_severities_leaky)
        boxchart(ones(numel(data.event_severities_leaky),1)*(i+offset), ...
            data.event_severities_leaky(:), 'BoxWidth',0.3, ...
            'BoxFaceColor', colors(2,:), 'MarkerStyle','.');
    end
end

xlim([0 length(configs)+1]);
set(gca, 'XTick', 1:length(configs), 'XTickLabel', labels);
xtickangle(45);
ylabel('Peak/Baseline Ratio');
title('Distribution of Event Severities');
legend({'Tight','Leaky'}, 'Location', 'best');
grid on;

% Example event response curves
subplot(2, 3, [4 6]);
% Plot example responses for most severe events
plot_example_event_responses(eventAnalysis);

sgtitle('Pollution Event Response Analysis - Active Mode', 'FontSize', 14, 'FontWeight', 'bold');
save_figure(fig, saveDir, 'event_response_analysis.png');
close(fig);
end

%% Visualization Function 5: Temporal Patterns
function plot_temporal_patterns(temporalAnalysis, saveDir)
fig = figure('Visible', 'off');
set_figure_fullscreen(fig);

configs = fieldnames(temporalAnalysis);

% Diurnal patterns
subplot(2, 2, 1);
hold on;
colors = lines(length(configs));

for i = 1:length(configs)
    config = configs{i};
    data = temporalAnalysis.(config);
    if isfield(data, 'diurnal_io_ratio')
        plot(0:23, data.diurnal_io_ratio, 'o-', 'Color', colors(i,:), ...
            'LineWidth', 2, 'MarkerSize', 6);
    end
end

xlabel('Hour of Day');
ylabel('Average I/O Ratio');
title('Diurnal Pattern of Filtration Performance');
legend(strrep(configs, '_', ' '), 'Location', 'best');
grid on;
xlim([-0.5 23.5]);

% Temporal stability
subplot(2, 2, 2);
stability_scores = [];
labels = {};

for i = 1:length(configs)
    config = configs{i};
    data = temporalAnalysis.(config);
    if isfield(data, 'stability_score')
        stability_scores(i) = data.stability_score;
        % Use single-line labels to clearly show both location and filter
        % type, preventing duplicated tick marks on some backends.
        labels{i} = sprintf('%s - %s Filter', ...
            strrep(data.location, '_', ' '), upper(data.filterType));
    end
end

bar(stability_scores, 'FaceColor', [0.4 0.6 0.8]);
set(gca, 'XTick', 1:length(labels), 'XTickLabel', labels);
ylabel('Stability Score');
title('Temporal Performance Stability');
grid on;

% Performance degradation over time
subplot(2, 2, [3 4]);
hold on;

for i = 1:length(configs)
    config = configs{i};
    data = temporalAnalysis.(config);
    if isfield(data, 'performance_trend')
        days = 1:length(data.performance_trend);
        plot(days, data.performance_trend, 'o-', 'Color', colors(i,:), ...
            'LineWidth', 1.5, 'MarkerSize', 4);
    end
end

xlabel('Day');
ylabel('Daily Average I/O Ratio');
title('Performance Trend Over Time');
legend(strrep(configs, '_', ' '), 'Location', 'best');
grid on;

sgtitle('Temporal Patterns in Active Mode Performance', 'FontSize', 14, 'FontWeight', 'bold');
save_figure(fig, saveDir, 'temporal_patterns.png');
close(fig);
end

%% Visualization Function 6: Cross-Correlation Analysis
function plot_correlation_analysis(correlationAnalysis, saveDir)
fig = figure('Visible', 'off');
set_figure_fullscreen(fig);

configs = fieldnames(correlationAnalysis);

% Lag correlation plots
nConfigs = length(configs);
nCols = min(3, nConfigs);
nRows = ceil(nConfigs / nCols);

for i = 1:nConfigs
    subplot(nRows, nCols, i);
    
    config = configs{i};
    data = correlationAnalysis.(config);
    
    if isfield(data, 'pm25_correlation')
        plot(data.lags, data.pm25_correlation, 'b-', 'LineWidth', 2);
        hold on;
        plot(data.lags, data.pm10_correlation, 'r-', 'LineWidth', 2);
        
        % Mark peak correlation
        [max_corr_pm25, max_idx_pm25] = max(data.pm25_correlation);
        [max_corr_pm10, max_idx_pm10] = max(data.pm10_correlation);
        
        plot(data.lags(max_idx_pm25), max_corr_pm25, 'bo', 'MarkerSize', 8, 'LineWidth', 2);
        plot(data.lags(max_idx_pm10), max_corr_pm10, 'ro', 'MarkerSize', 8, 'LineWidth', 2);
        
        xlabel('Lag (hours)');
        ylabel('Cross-Correlation');
        title(sprintf('%s\nOptimal Lag: PM2.5=%dh, PM10=%dh', ...
            strrep(config, '_', ' '), ...
            data.lags(max_idx_pm25), data.lags(max_idx_pm10)));
        legend({'PM2.5', 'PM10'}, 'Location', 'best');
        grid on;
        xlim([-12 12]);
    end
end

sgtitle('Cross-Correlation Analysis: Indoor vs Outdoor', 'FontSize', 14, 'FontWeight', 'bold');
save_figure(fig, saveDir, 'correlation_analysis.png');
close(fig);
end

%% Visualization Function 7: Dynamic Filter Comparison
function plot_dynamic_filter_comparison(filterComparison, saveDir)
fig = figure('Visible', 'off');
set_figure_fullscreen(fig);

locations = fieldnames(filterComparison);

for loc_idx = 1:length(locations)
    location = locations{loc_idx};
    data = filterComparison.(location);
    
    % Performance metrics comparison
    subplot(2, 2, loc_idx);
    
    metrics = {'avg_io_ratio_pm25', 'avg_io_ratio_pm10', ...
               'response_time', 'peak_reduction', 'stability_score'};
    metric_labels = {'I/O PM2.5', 'I/O PM10', 'Response (h)', ...
                    'Peak Red. (%)', 'Stability'};
    
    hepa_values = [];
    merv_values = [];
    
    for m = 1:length(metrics)
        if isfield(data.hepa, metrics{m})
            hepa_values(m) = data.hepa.(metrics{m});
            merv_values(m) = data.merv.(metrics{m});
        else
            hepa_values(m) = NaN;
            merv_values(m) = NaN;
        end
    end
    
    % Normalize to compare on same scale
    hepa_norm = (hepa_values - nanmin([hepa_values, merv_values])) ./ ...
                (nanmax([hepa_values, merv_values]) - nanmin([hepa_values, merv_values]));
    merv_norm = (merv_values - nanmin([hepa_values, merv_values])) ./ ...
                (nanmax([hepa_values, merv_values]) - nanmin([hepa_values, merv_values]));
    
    x = 1:length(metrics);
    width = 0.35;
    
    bar(x - width/2, hepa_norm, width, 'FaceColor', [0.2 0.4 0.8]);
    bar(x + width/2, merv_norm, width, 'FaceColor', [0.8 0.3 0.3]);
    
    set(gca, 'XTick', x, 'XTickLabel', metric_labels);
    xtickangle(45);
    ylabel('Normalized Score');
    title(sprintf('%s - Filter Comparison', location));
    legend({'HEPA', 'MERV'}, 'Location', 'best');
    grid on;
end

% Overall comparison radar chart
subplot(2, 2, [3 4]);
plot_filter_radar_comparison(filterComparison);

sgtitle('Dynamic Filter Performance Comparison - Active Mode', 'FontSize', 14, 'FontWeight', 'bold');
save_figure(fig, saveDir, 'filter_comparison_dynamic.png');
close(fig);
end

%% Visualization Function 8: Uncertainty Analysis
function plot_uncertainty_analysis(uncertaintyAnalysis, saveDir)
fig = figure('Visible', 'off');
set_figure_fullscreen(fig);

configs = fieldnames(uncertaintyAnalysis);

% Uncertainty ranges
subplot(2, 2, 1);
pm25_ranges = [];
pm10_ranges = [];
labels = {};

for i = 1:length(configs)
    config = configs{i};
    data = uncertaintyAnalysis.(config);
    pm25_ranges(i) = data.pm25_range_percent;
    pm10_ranges(i) = data.pm10_range_percent;
    labels{i} = strrep(config, '_', '-');
end

x = 1:length(configs);
width = 0.35;
bar(x - width/2, pm25_ranges, width, 'FaceColor', [0.2 0.4 0.8]);
bar(x + width/2, pm10_ranges, width, 'FaceColor', [0.8 0.3 0.3]);

set(gca, 'XTick', x, 'XTickLabel', labels);
xtickangle(45);
ylabel('Uncertainty Range (%)');
legend({'PM2.5', 'PM10'}, 'Location', 'best');
title('Building Envelope Uncertainty');
grid on;

% Confidence intervals over time
subplot(2, 2, 2);
config = configs{1}; % Example
data = uncertaintyAnalysis.(config);

if isfield(data, 'hourly_ci_pm25')
    t = 1:min(168, size(data.hourly_ci_pm25, 2));
    
    % Plot confidence bands
    fill([t fliplr(t)], ...
         [data.hourly_ci_pm25(1,t) fliplr(data.hourly_ci_pm25(2,t))], ...
         [0.2 0.4 0.8], 'FaceAlpha', 0.3, 'EdgeColor', 'none');
    hold on;
    plot(t, data.hourly_mean_pm25(t), 'b-', 'LineWidth', 2);
    
    xlabel('Hour');
    ylabel('Indoor PM2.5 (μg/m³)');
    title(sprintf('Confidence Intervals - %s', config));
    legend({'Envelope Bounds', 'Mean'}, 'Location', 'best');
    grid on;
end

% Uncertainty contribution
subplot(2, 2, 3);
contribution_data = [];
contribution_labels = {'Building Envelope', 'Outdoor Variability', ...
                      'System Response', 'Measurement'};

for i = 1:length(configs)
    config = configs{i};
    data = uncertaintyAnalysis.(config);
    if isfield(data, 'uncertainty_contributions')
        contribution_data(:,i) = data.uncertainty_contributions;
    end
end

if ~isempty(contribution_data)
    bar(contribution_data', 'stacked');
    set(gca, 'XTick', 1:length(configs), 'XTickLabel', labels);
    xtickangle(45);
    ylabel('Contribution to Total Uncertainty (%)');
    legend(contribution_labels, 'Location', 'best');
    title('Uncertainty Source Analysis');
    grid on;
end

% Sensitivity analysis
subplot(2, 2, 4);
plot_sensitivity_tornado(uncertaintyAnalysis);

sgtitle('Uncertainty Quantification - Active Mode', 'FontSize', 14, 'FontWeight', 'bold');
save_figure(fig, saveDir, 'uncertainty_analysis.png');
close(fig);
end

%% Helper visualization functions
function plot_event_timeline_example(triggerData, configName)
%PLOT_EVENT_TIMELINE_EXAMPLE Visualize lag and recovery times for each event

resp = triggerData.pm25_response;
if isempty(resp) || resp.num_events == 0
    title(sprintf('Event Timeline Example - %s', strrep(configName,'_',' ')));
    text(0.5,0.5,'No events','HorizontalAlignment','center');
    return;
end

n = resp.num_events;
hold on;
for i = 1:n
    % Lag time segment
    line([0 resp.lag_times(i)], [i i], 'Color', [0.2 0.4 0.8], 'LineWidth', 2);
    % Recovery time segment
    if ~isnan(resp.recovery_times(i))
        line([resp.lag_times(i) resp.lag_times(i)+resp.recovery_times(i)], ...
             [i i], 'Color', [0.8 0.3 0.3], 'LineWidth', 2);
    end
end

xlabel('Hours Relative to Event Peak');
ylabel('Event Index');
title(sprintf('Event Timeline Example - %s', strrep(configName,'_',' ')));
legend({'Lag Time','Recovery'}, 'Location','best');
grid on;
end

function plot_event_timeline(eventTable, configName)
%PLOT_EVENT_TIMELINE Draw lag, rise and recovery segments using event metrics

if isempty(eventTable)
    title(sprintf('Event Timeline - %s', strrep(configName,'_',' ')));
    text(0.5,0.5,'No events','HorizontalAlignment','center');
    return;
end

n = height(eventTable);
hold on;
colors = struct('rise',[0.6 0.6 0.6],'lag',[0.2 0.4 0.8],'rec',[0.8 0.3 0.3]);

for i = 1:n
    startRel = eventTable.start_idx(i) - eventTable.peak_out_idx(i);
    peakRel = eventTable.peak_in_idx(i) - eventTable.peak_out_idx(i);
    endRel = eventTable.end_idx(i) - eventTable.peak_out_idx(i);
    rtbRel = eventTable.rtb_idx(i) - eventTable.peak_out_idx(i);

    line([startRel 0], [i i], 'Color', colors.rise, 'LineWidth', 2);
    line([0 peakRel], [i i], 'Color', colors.lag, 'LineWidth', 2);
    if ~isnan(rtbRel)
        line([endRel rtbRel], [i i], 'Color', colors.rec, 'LineWidth', 2);
    else
        line([endRel endRel+1], [i i], 'Color', colors.rec, 'LineStyle','--', 'LineWidth', 2);
        text(endRel+1, i, 'no RTB', 'VerticalAlignment','middle','FontSize',8,'Color',colors.rec);
    end

    plot(startRel, i, '^', 'MarkerFaceColor', colors.rise, 'MarkerEdgeColor', 'k');
    plot(0, i, 'v', 'MarkerFaceColor', 'k', 'MarkerEdgeColor', 'k');
    plot(peakRel, i, 'o', 'MarkerFaceColor', colors.lag, 'MarkerEdgeColor', 'k');
    plot(endRel, i, 's', 'MarkerFaceColor', colors.rec, 'MarkerEdgeColor', 'k');
    if ~isnan(rtbRel)
        plot(rtbRel, i, 'd', 'MarkerFaceColor', 'w', 'MarkerEdgeColor', colors.rec);
    end
end

    xlabel('Hours Relative to Outdoor Peak');
    ylabel('Event Number');
    yticks(1:n);
    ylim([0 n+1]);
    title(sprintf('Event Timeline - %s', strrep(configName,'_',' ')));
legend({'Rise','Lag','Recovery'}, 'Location','best');
grid on;
end

function plot_example_event_responses(eventAnalysis)
%PLOT_EXAMPLE_EVENT_RESPONSES Visualize scatter of individual event metrics

configs = fieldnames(eventAnalysis);
nConfigs = numel(configs);
colors = lines(nConfigs);
hold on;

legendHandles = gobjects(nConfigs,1);

offsets = linspace(-0.3, 0.3, nConfigs);
maxEvents = 0;

for i = 1:nConfigs
    config = configs{i};
    if ~isfield(eventAnalysis.(config), 'pm25_response')
        continue;
    end
    resp = eventAnalysis.(config).pm25_response;

    if isfield(resp, 'peak_reductions_tight') && isfield(resp, 'peak_reductions_leaky')
        nEv = min(numel(resp.peak_reductions_tight), numel(resp.peak_reductions_leaky));
    elseif isfield(resp, 'peak_reductions')
        nEv = numel(resp.peak_reductions);
    else
        nEv = 0;
    end

    maxEvents = max(maxEvents, nEv);

    xSeries = NaN(1,nEv);
    ySeries = NaN(1,nEv);
    for j = 1:nEv
        x = j + offsets(i);
        if isfield(resp, 'peak_reductions_tight') && isfield(resp, 'peak_reductions_leaky')
            yVals = sort([resp.peak_reductions_tight(j), resp.peak_reductions_leaky(j)]);
            plot([x x], yVals, '-', 'Color', colors(i,:), 'LineWidth', 1.5);
            scatter([x x], yVals, 20, 'filled', 'MarkerFaceColor', colors(i,:), 'MarkerEdgeColor', 'k');
            ySeries(j) = mean(yVals);
        else
            yVal = resp.peak_reductions(j);
            scatter(x, yVal, 30, 'filled', 'MarkerFaceColor', colors(i,:), 'MarkerEdgeColor', 'k');
            ySeries(j) = yVal;
        end
        xSeries(j) = x;
    end
    plot(xSeries, ySeries, '-', 'Color', colors(i,:), 'LineWidth', 1, 'HandleVisibility', 'off');
    legendHandles(i) = scatter(NaN, NaN, 30, 'filled', 'MarkerFaceColor', colors(i,:), 'MarkerEdgeColor', 'k');
end

xlabel('Event Index');
ylabel('Peak Reduction (%)');
title('Event Response Metrics by Event');
% Filter out invalid handles before creating the legend
valid = isgraphics(legendHandles);
if any(valid)
    legend(legendHandles(valid), strrep(configs(valid),'_',' '), 'Location','best');
end
grid on;
xlim([0 maxEvents + 1]);
end

function plot_filter_radar_comparison(filterComparison)
%PLOT_FILTER_RADAR_COMPARISON Radar chart comparing HEPA and MERV

ax = gca;
pos = get(ax,'Position');
delete(ax);
ax = polaraxes('Position', pos);
hold(ax,'on');

metrics = {'avg_io_ratio_pm25','avg_io_ratio_pm10','response_time', ...
           'peak_reduction','stability_score'};
metric_labels = {'I/O PM2.5','I/O PM10','Response','Peak Red.','Stability'};

locs = fieldnames(filterComparison);
nMetrics = numel(metrics);

hepa_vals = NaN(numel(locs), nMetrics);
merv_vals = NaN(numel(locs), nMetrics);
for i = 1:numel(locs)
    loc = locs{i};
    for m = 1:nMetrics
        if isfield(filterComparison.(loc).hepa, metrics{m})
            hepa_vals(i,m) = filterComparison.(loc).hepa.(metrics{m});
        end
        if isfield(filterComparison.(loc).merv, metrics{m})
            merv_vals(i,m) = filterComparison.(loc).merv.(metrics{m});
        end
    end
end

hepa_avg = nanmean(hepa_vals,1);
merv_avg = nanmean(merv_vals,1);
maxVals = nanmax([hepa_avg; merv_avg], [], 1);
maxVals(maxVals==0) = 1;
hepa_norm = hepa_avg ./ maxVals;
merv_norm = merv_avg ./ maxVals;

theta = linspace(0,2*pi,nMetrics+1);
polarplot(ax, theta, [hepa_norm hepa_norm(1)], 'LineWidth',2,'Color',[0.2 0.4 0.8]);
polarplot(ax, theta, [merv_norm merv_norm(1)], 'LineWidth',2,'Color',[0.8 0.3 0.3]);
polarscatter(ax, theta, [hepa_norm hepa_norm(1)], 50, [0.2 0.4 0.8],'filled');
polarscatter(ax, theta, [merv_norm merv_norm(1)], 50, [0.8 0.3 0.3],'filled');

ax.ThetaTick = rad2deg(theta(1:end-1));
ax.ThetaTickLabel = metric_labels;
ax.RLim = [0 1];
legend(ax, {'HEPA','MERV'}, 'Location','southoutside');
title(ax,'Multi-Criteria Filter Comparison');
end

function plot_sensitivity_tornado(uncertaintyAnalysis)
%PLOT_SENSITIVITY_TORNADO Horizontal bar chart of uncertainty contributions

configs = fieldnames(uncertaintyAnalysis);
contrib = [];
for i = 1:numel(configs)
    data = uncertaintyAnalysis.(configs{i});
    if isfield(data,'uncertainty_contributions')
        contrib(:,end+1) = data.uncertainty_contributions(:);
    end
end

if isempty(contrib)
    title('Sensitivity Analysis');
    text(0.5,0.5,'No uncertainty data','HorizontalAlignment','center');
    return;
end

avgContrib = mean(contrib,2,'omitnan');
[sortedVals,order] = sort(avgContrib,'descend');
labels = {'Building Envelope','Outdoor Variability','System Response','Measurement'};

barh(sortedVals,'FaceColor',[0.4 0.6 0.8]);
set(gca,'YTick',1:numel(order),'YTickLabel',labels(order));
xlabel('Contribution (%)');
title('Sensitivity Analysis');
grid on;
end