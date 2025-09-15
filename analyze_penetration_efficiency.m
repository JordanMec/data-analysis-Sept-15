function penetrationAnalysis = analyze_penetration_efficiency(activeData)
%% Analysis Function: Particle Penetration and Removal Efficiency
% Calculate particle penetration factors and removal efficiency

penetrationAnalysis = struct();
configs = fieldnames(activeData);

for i = 1:length(configs)
    config = configs{i};
    data = activeData.(config);
    
    penetrationAnalysis.(config) = struct();
    penetrationAnalysis.(config).location = data.location;
    penetrationAnalysis.(config).filterType = data.filterType;
    
    % Calculate steady-state penetration factors
    % P = Indoor/Outdoor during steady conditions
    
    % Find steady-state periods (low variability)
    window = 6; % 6-hour window
    outdoor_var_pm25 = movvar(data.outdoor_PM25, window);
    outdoor_var_pm10 = movvar(data.outdoor_PM10, window);
    
    % Steady state = low outdoor variability
    steady_threshold_pm25 = prctile(outdoor_var_pm25, 25);
    steady_threshold_pm10 = prctile(outdoor_var_pm10, 25);
    
    steady_periods_pm25 = outdoor_var_pm25 < steady_threshold_pm25;
    steady_periods_pm10 = outdoor_var_pm10 < steady_threshold_pm10;
    
    % Calculate penetration during steady periods
    if any(steady_periods_pm25)
        pen_pm25_tight = data.indoor_PM25_tight(steady_periods_pm25) ./ ...
                         data.outdoor_PM25(steady_periods_pm25);
        pen_pm25_leaky = data.indoor_PM25_leaky(steady_periods_pm25) ./ ...
                         data.outdoor_PM25(steady_periods_pm25);
        
        pen_pm25_tight(~isfinite(pen_pm25_tight)) = [];
        pen_pm25_leaky(~isfinite(pen_pm25_leaky)) = [];
        
        penetrationAnalysis.(config).pm25_penetration_mean = mean([pen_pm25_tight; pen_pm25_leaky]);
        penetrationAnalysis.(config).pm25_penetration_bounds = [mean(pen_pm25_tight), mean(pen_pm25_leaky)];
    else
        penetrationAnalysis.(config).pm25_penetration_mean = NaN;
        penetrationAnalysis.(config).pm25_penetration_bounds = [NaN, NaN];
    end
    
    if any(steady_periods_pm10)
        pen_pm10_tight = data.indoor_PM10_tight(steady_periods_pm10) ./ ...
                         data.outdoor_PM10(steady_periods_pm10);
        pen_pm10_leaky = data.indoor_PM10_leaky(steady_periods_pm10) ./ ...
                         data.outdoor_PM10(steady_periods_pm10);
        
        pen_pm10_tight(~isfinite(pen_pm10_tight)) = [];
        pen_pm10_leaky(~isfinite(pen_pm10_leaky)) = [];
        
        penetrationAnalysis.(config).pm10_penetration_mean = mean([pen_pm10_tight; pen_pm10_leaky]);
        penetrationAnalysis.(config).pm10_penetration_bounds = [mean(pen_pm10_tight), mean(pen_pm10_leaky)];
    else
        penetrationAnalysis.(config).pm10_penetration_mean = NaN;
        penetrationAnalysis.(config).pm10_penetration_bounds = [NaN, NaN];
    end
    
    % Calculate hourly penetration factors for time series
    hourly_pen_pm25 = data.indoor_PM25_mean ./ data.outdoor_PM25;
    hourly_pen_pm10 = data.indoor_PM10_mean ./ data.outdoor_PM10;
    
    hourly_pen_pm25(~isfinite(hourly_pen_pm25)) = NaN;
    hourly_pen_pm10(~isfinite(hourly_pen_pm10)) = NaN;
    
    penetrationAnalysis.(config).hourly_penetration_pm25 = hourly_pen_pm25;
    penetrationAnalysis.(config).hourly_penetration_pm10 = hourly_pen_pm10;
    
    % Size-dependent analysis
    penetrationAnalysis.(config).size_selectivity = ...
        penetrationAnalysis.(config).pm10_penetration_mean / ...
        penetrationAnalysis.(config).pm25_penetration_mean;
end

end

%% Analysis Function: Pollution Event Detection and Response
function eventAnalysis = detect_analyze_pollution_events(activeData)
% Detect and analyze response to outdoor pollution events

eventAnalysis = struct();
configs = fieldnames(activeData);

for i = 1:length(configs)
    config = configs{i};
    data = activeData.(config);
    
    eventAnalysis.(config) = struct();
    eventAnalysis.(config).location = data.location;
    eventAnalysis.(config).filterType = data.filterType;
    
    % Detect PM2.5 events in outdoor data
    pm25_baseline = prctile(data.outdoor_PM25, 50);
    pm25_threshold = pm25_baseline * 1.5; % 50% above median
    pm25_events = find_pollution_events(data.outdoor_PM25, pm25_threshold, 2);

    % Detect PM10 events in outdoor data
    pm10_baseline = prctile(data.outdoor_PM10, 50);
    pm10_threshold = pm10_baseline * 1.5;
    pm10_events = find_pollution_events(data.outdoor_PM10, pm10_threshold, 2);

    % Bounds using tight and leaky indoor data
    pm25_base_tight = prctile(data.indoor_PM25_tight, 50);
    pm25_base_leaky = prctile(data.indoor_PM25_leaky, 50);
    pm25_events_tight = find_pollution_events(data.indoor_PM25_tight, pm25_base_tight * 1.5, 2);
    pm25_events_leaky = find_pollution_events(data.indoor_PM25_leaky, pm25_base_leaky * 1.5, 2);

    pm10_base_tight = prctile(data.indoor_PM10_tight, 50);
    pm10_base_leaky = prctile(data.indoor_PM10_leaky, 50);
    pm10_events_tight = find_pollution_events(data.indoor_PM10_tight, pm10_base_tight * 1.5, 2);
    pm10_events_leaky = find_pollution_events(data.indoor_PM10_leaky, pm10_base_leaky * 1.5, 2);

    total_tight = length(pm25_events_tight) + length(pm10_events_tight);
    total_leaky = length(pm25_events_leaky) + length(pm10_events_leaky);

    eventAnalysis.(config).pm25_events = pm25_events;
    eventAnalysis.(config).pm10_events = pm10_events;
    eventAnalysis.(config).total_events = mean([total_tight, total_leaky]);
    eventAnalysis.(config).total_events_bounds = [min(total_tight, total_leaky), max(total_tight, total_leaky)];

    % Analyze event characteristics using indoor events for duration bounds
    if ~isempty(pm25_events_tight)
        dur_tight = mean([pm25_events_tight.duration]);
    else
        dur_tight = NaN;
    end
    if ~isempty(pm25_events_leaky)
        dur_leaky = mean([pm25_events_leaky.duration]);
    else
        dur_leaky = NaN;
    end

    % Compute event severities for tight and leaky indoor cases
    if ~isempty(pm25_events_tight)
        severities_tight = [pm25_events_tight.peak_value] ./ [pm25_events_tight.baseline];
    else
        severities_tight = [];
    end
    if ~isempty(pm25_events_leaky)
        severities_leaky = [pm25_events_leaky.peak_value] ./ [pm25_events_leaky.baseline];
    else
        severities_leaky = [];
    end

    if ~isempty(pm25_events)
        severities = [pm25_events.peak_value] ./ [pm25_events.baseline];
        eventAnalysis.(config).event_severities = severities;
        eventAnalysis.(config).event_severities_tight = severities_tight;
        eventAnalysis.(config).event_severities_leaky = severities_leaky;

        eventAnalysis.(config).avg_event_duration = mean([dur_tight, dur_leaky], 'omitnan');
        eventAnalysis.(config).avg_event_duration_bounds = [min(dur_tight, dur_leaky), max(dur_tight, dur_leaky)];

        % Analyze response to events
        response_metrics = analyze_event_responses(pm25_events, data);
        eventAnalysis.(config).pm25_response = response_metrics;
    else
        eventAnalysis.(config).avg_event_duration = NaN;
        eventAnalysis.(config).avg_event_duration_bounds = [NaN, NaN];
        eventAnalysis.(config).event_severities = [];
        eventAnalysis.(config).event_severities_tight = severities_tight;
        eventAnalysis.(config).event_severities_leaky = severities_leaky;
    end
end

end

%% Helper: Find pollution events
function events = find_pollution_events(outdoor_series, threshold, min_duration)
% Find periods where outdoor concentration exceeds threshold

above_threshold = outdoor_series > threshold;
starts = find(diff([0; above_threshold]) == 1);
ends = find(diff([above_threshold; 0]) == -1);

events = [];
for j = 1:length(starts)
    duration = ends(j) - starts(j) + 1;
    if duration >= min_duration
        event = struct();
        event.start = starts(j);
        event.end = ends(j);
        event.duration = duration;
        
        event_data = outdoor_series(starts(j):ends(j));
        [event.peak_value, peak_idx] = max(event_data);
        event.peak_time = starts(j) + peak_idx - 1;
        event.baseline = threshold / 1.5; % Reverse calculation
        
        events = [events; event];
    end
end

end

%% Helper: Analyze responses to events
function response_metrics = analyze_event_responses(events, data)
% Analyze indoor response to outdoor events

response_metrics = struct();
response_metrics.num_events = length(events);
response_metrics.lag_times = [];
response_metrics.peak_reductions = [];
response_metrics.integrated_reductions = [];
response_metrics.recovery_times = [];

for j = 1:length(events)
    event = events(j);
    
    % Define analysis windows
    pre_window = max(1, event.start - 6):event.start-1;
    event_window = event.start:min(length(data.outdoor_PM25), event.end + 24);
    
    % Baseline levels
    outdoor_baseline = mean(data.outdoor_PM25(pre_window));
    indoor_baseline_mean = mean(data.indoor_PM25_mean(pre_window));
    
    % Peak analysis
    [outdoor_peak, outdoor_peak_idx] = max(data.outdoor_PM25(event_window));
    outdoor_peak_time = event_window(outdoor_peak_idx);
    
    [indoor_peak, indoor_peak_idx] = max(data.indoor_PM25_mean(event_window));
    indoor_peak_time = event_window(indoor_peak_idx);
    
    % Lag time
    lag_time = indoor_peak_time - outdoor_peak_time;
    response_metrics.lag_times(end+1) = lag_time;
    
    % Peak reduction
    expected_indoor_peak = indoor_baseline_mean + (outdoor_peak - outdoor_baseline);
    actual_indoor_peak = indoor_peak;
    peak_reduction = 100 * (expected_indoor_peak - actual_indoor_peak) / expected_indoor_peak;
    response_metrics.peak_reductions(end+1) = max(0, peak_reduction);
    
    % Integrated reduction
    outdoor_excess = data.outdoor_PM25(event_window) - outdoor_baseline;
    indoor_excess = data.indoor_PM25_mean(event_window) - indoor_baseline_mean;
    
    outdoor_integral = sum(outdoor_excess(outdoor_excess > 0));
    indoor_integral = sum(indoor_excess(indoor_excess > 0));
    
    if outdoor_integral > 0
        integrated_reduction = 100 * (1 - indoor_integral / outdoor_integral);
        response_metrics.integrated_reductions(end+1) = max(0, integrated_reduction);
    else
        response_metrics.integrated_reductions(end+1) = NaN;
    end
    
    % Recovery time (time to return to within 10% of baseline)
    post_event = event.end:min(length(data.indoor_PM25_mean), event.end + 24);
    recovery_threshold = indoor_baseline_mean * 1.1;
    recovery_idx = find(data.indoor_PM25_mean(post_event) < recovery_threshold, 1);
    
    if ~isempty(recovery_idx)
        response_metrics.recovery_times(end+1) = recovery_idx;
    else
        response_metrics.recovery_times(end+1) = NaN;
    end
end

% Summary statistics
response_metrics.avg_lag_time = nanmean(response_metrics.lag_times);
response_metrics.avg_peak_reduction = nanmean(response_metrics.peak_reductions);
response_metrics.avg_integrated_reduction = nanmean(response_metrics.integrated_reductions);
response_metrics.avg_recovery_time = nanmean(response_metrics.recovery_times);

end

%% Analysis Function: Temporal Patterns
function temporalAnalysis = analyze_temporal_patterns(activeData)
% Analyze temporal patterns in filtration performance

temporalAnalysis = struct();
configs = fieldnames(activeData);

for i = 1:length(configs)
    config = configs{i};
    data = activeData.(config);
    
    temporalAnalysis.(config) = struct();
    temporalAnalysis.(config).location = data.location;
    temporalAnalysis.(config).filterType = data.filterType;
    
    % Calculate I/O ratios
    io_ratio_pm25 = data.indoor_PM25_mean ./ data.outdoor_PM25;
    io_ratio_pm25(~isfinite(io_ratio_pm25)) = NaN;
    
    % Diurnal pattern (hourly averages)
    hours_of_day = mod(0:length(io_ratio_pm25)-1, 24);
    diurnal_io = zeros(24, 1);
    diurnal_counts = zeros(24, 1);
    
    for h = 0:23
        hour_mask = hours_of_day == h;
        hour_data = io_ratio_pm25(hour_mask);
        diurnal_io(h+1) = nanmean(hour_data);
        diurnal_counts(h+1) = sum(~isnan(hour_data));
    end
    
    temporalAnalysis.(config).diurnal_io_ratio = diurnal_io;
    temporalAnalysis.(config).diurnal_counts = diurnal_counts;
    
    % Weekly pattern (weekday vs weekend)
    % Assuming simulation starts on a Monday
    days = floor((0:length(io_ratio_pm25)-1) / 24);
    day_of_week = mod(days, 7) + 1; % 1=Mon, 7=Sun
    
    weekday_mask = day_of_week >= 1 & day_of_week <= 5;
    weekend_mask = day_of_week >= 6;
    
    temporalAnalysis.(config).weekly_pattern = struct();
    temporalAnalysis.(config).weekly_pattern.weekday_avg = nanmean(io_ratio_pm25(weekday_mask));
    temporalAnalysis.(config).weekly_pattern.weekend_avg = nanmean(io_ratio_pm25(weekend_mask));
    
    % Performance stability (coefficient of variation)
    daily_averages = [];
    for d = 0:max(days)
        day_mask = days == d;
        if sum(day_mask) > 12 % At least half day of data
            daily_averages(end+1) = nanmean(io_ratio_pm25(day_mask));
        end
    end
    
    if length(daily_averages) > 1
        temporalAnalysis.(config).stability_score = 1 - (std(daily_averages) / mean(daily_averages));
        temporalAnalysis.(config).performance_trend = daily_averages;
    else
        temporalAnalysis.(config).stability_score = NaN;
        temporalAnalysis.(config).performance_trend = [];
    end
    
    % Temporal autocorrelation
    valid_data = io_ratio_pm25(~isnan(io_ratio_pm25));
    if length(valid_data) > 48
        [acf, lags] = autocorr(valid_data, 'NumLags', 24);
        temporalAnalysis.(config).autocorrelation = acf;
        temporalAnalysis.(config).acf_lags = lags;
        
        % Find decorrelation time
        decorr_idx = find(abs(acf) < 0.2, 1);
        if ~isempty(decorr_idx)
            temporalAnalysis.(config).decorrelation_time = lags(decorr_idx);
        else
            temporalAnalysis.(config).decorrelation_time = NaN;
        end
    end
end

end

%% Analysis Function: Cross-Correlation
function correlationAnalysis = analyze_cross_correlations(activeData)
% Analyze cross-correlations between outdoor and indoor concentrations

correlationAnalysis = struct();
configs = fieldnames(activeData);

for i = 1:length(configs)
    config = configs{i};
    data = activeData.(config);
    
    correlationAnalysis.(config) = struct();
    
    % Cross-correlation for PM2.5
    [corr_pm25, lags_pm25] = xcorr(data.outdoor_PM25, data.indoor_PM25_mean, 24, 'normalized');
    
    % Cross-correlation for PM10
    [corr_pm10, lags_pm10] = xcorr(data.outdoor_PM10, data.indoor_PM10_mean, 24, 'normalized');
    
    % Store results
    % Store as row vectors for consistency
    correlationAnalysis.(config).pm25_correlation = corr_pm25(:)';
    correlationAnalysis.(config).pm10_correlation = corr_pm10(:)';
    correlationAnalysis.(config).lags = lags_pm25(:)';
    
    % Find optimal lag (maximum correlation)
    [max_corr_pm25, max_idx_pm25] = max(corr_pm25);
    [max_corr_pm10, max_idx_pm10] = max(corr_pm10);
    
    correlationAnalysis.(config).optimal_lag_pm25 = lags_pm25(max_idx_pm25);
    correlationAnalysis.(config).optimal_lag_pm10 = lags_pm10(max_idx_pm10);
    correlationAnalysis.(config).max_correlation_pm25 = max_corr_pm25;
    correlationAnalysis.(config).max_correlation_pm10 = max_corr_pm10;
    
    % Frequency domain analysis
    if length(data.indoor_PM25_mean) > 48
        [psd_out, f] = pwelch(data.outdoor_PM25, [], [], [], 1); % 1 sample/hour
        [psd_in, ~] = pwelch(data.indoor_PM25_mean, [], [], [], 1);
        
        correlationAnalysis.(config).transfer_function = psd_in ./ psd_out;
        correlationAnalysis.(config).frequencies = f;
        
        % Find cutoff frequency (where transfer function drops to 0.5)
        tf_normalized = correlationAnalysis.(config).transfer_function / ...
                       correlationAnalysis.(config).transfer_function(1);
        cutoff_idx = find(tf_normalized < 0.5, 1);
        if ~isempty(cutoff_idx)
            correlationAnalysis.(config).cutoff_frequency = f(cutoff_idx);
        else
            correlationAnalysis.(config).cutoff_frequency = NaN;
        end
    end
end

end

%% Analysis Function: Dynamic Filter Comparison
function filterComparison = compare_filters_dynamic(activeData)
% Compare HEPA vs MERV performance under dynamic conditions

filterComparison = struct();
locations = unique(cellfun(@(x) activeData.(x).location, fieldnames(activeData), 'UniformOutput', false));

for loc_idx = 1:length(locations)
    location = locations{loc_idx};
    filterComparison.(location) = struct();
    
    % Find HEPA and MERV configs for this location
    configs = fieldnames(activeData);
    hepa_config = [];
    merv_config = [];
    
    for i = 1:length(configs)
        if strcmp(activeData.(configs{i}).location, location)
            if strcmpi(activeData.(configs{i}).filterType, 'hepa')
                hepa_config = configs{i};
            elseif strcmpi(activeData.(configs{i}).filterType, 'merv')
                merv_config = configs{i};
            end
        end
    end
    
    if ~isempty(hepa_config) && ~isempty(merv_config)
        hepa_data = activeData.(hepa_config);
        merv_data = activeData.(merv_config);
        
        % Compare average I/O ratios
        filterComparison.(location).hepa = struct();
        filterComparison.(location).merv = struct();
        
        % PM2.5 performance
        hepa_io_pm25 = hepa_data.indoor_PM25_mean ./ hepa_data.outdoor_PM25;
        merv_io_pm25 = merv_data.indoor_PM25_mean ./ merv_data.outdoor_PM25;
        hepa_io_pm25(~isfinite(hepa_io_pm25)) = NaN;
        merv_io_pm25(~isfinite(merv_io_pm25)) = NaN;
        
        filterComparison.(location).hepa.avg_io_ratio_pm25 = nanmean(hepa_io_pm25);
        filterComparison.(location).merv.avg_io_ratio_pm25 = nanmean(merv_io_pm25);
        
        % PM10 performance
        hepa_io_pm10 = hepa_data.indoor_PM10_mean ./ hepa_data.outdoor_PM10;
        merv_io_pm10 = merv_data.indoor_PM10_mean ./ merv_data.outdoor_PM10;
        hepa_io_pm10(~isfinite(hepa_io_pm10)) = NaN;
        merv_io_pm10(~isfinite(merv_io_pm10)) = NaN;
        
        filterComparison.(location).hepa.avg_io_ratio_pm10 = nanmean(hepa_io_pm10);
        filterComparison.(location).merv.avg_io_ratio_pm10 = nanmean(merv_io_pm10);
        
        % Response time comparison
        filterComparison.(location).hepa.response_time = calculate_avg_response_time(hepa_data);
        filterComparison.(location).merv.response_time = calculate_avg_response_time(merv_data);
        
        % Peak reduction capability
        filterComparison.(location).hepa.peak_reduction = calculate_peak_reduction_capability(hepa_data);
        filterComparison.(location).merv.peak_reduction = calculate_peak_reduction_capability(merv_data);
        
        % Stability score
        filterComparison.(location).hepa.stability_score = calculate_stability_score(hepa_io_pm25);
        filterComparison.(location).merv.stability_score = calculate_stability_score(merv_io_pm25);
        
        % Size selectivity
        filterComparison.(location).hepa.size_selectivity = ...
            filterComparison.(location).hepa.avg_io_ratio_pm10 / ...
            filterComparison.(location).hepa.avg_io_ratio_pm25;
        filterComparison.(location).merv.size_selectivity = ...
            filterComparison.(location).merv.avg_io_ratio_pm10 / ...
            filterComparison.(location).merv.avg_io_ratio_pm25;
    end
end

end

%% Helper: Calculate average response time
function avg_response_time = calculate_avg_response_time(data)
% Calculate average system response time to concentration changes

outdoor_increases = find(diff(data.outdoor_PM25) > 5);
response_times = [];

for idx = outdoor_increases'
    if idx + 12 <= length(data.indoor_PM25_mean)
        % Look for 50% reduction in increase
        outdoor_increase = data.outdoor_PM25(idx) - data.outdoor_PM25(idx-1);
        indoor_baseline = data.indoor_PM25_mean(idx-1);
        
        for t = 1:12
            indoor_current = data.indoor_PM25_mean(idx + t);
            indoor_increase = indoor_current - indoor_baseline;
            
            if indoor_increase < 0.5 * outdoor_increase
                response_times(end+1) = t;
                break;
            end
        end
    end
end

if ~isempty(response_times)
    avg_response_time = mean(response_times);
else
    avg_response_time = NaN;
end

end

%% Helper: Calculate peak reduction capability
function peak_reduction = calculate_peak_reduction_capability(data)
% Calculate average peak reduction during high pollution events

threshold = prctile(data.outdoor_PM25, 90);
high_pollution = data.outdoor_PM25 > threshold;

if any(high_pollution)
    outdoor_high = data.outdoor_PM25(high_pollution);
    indoor_high = data.indoor_PM25_mean(high_pollution);
    
    % Expected indoor if no filtration (1:1 ratio)
    expected_indoor = outdoor_high;
    
    % Actual reduction
    reductions = 100 * (expected_indoor - indoor_high) ./ expected_indoor;
    peak_reduction = nanmean(reductions);
else
    peak_reduction = NaN;
end

end

%% Helper: Calculate stability score
function stability = calculate_stability_score(io_ratio)
% Calculate performance stability metric

% Remove NaN values
valid_data = io_ratio(~isnan(io_ratio));

if length(valid_data) > 24
    % Calculate rolling standard deviation
    window = 24; % 24-hour window
    rolling_std = movstd(valid_data, window);
    rolling_mean = movmean(valid_data, window);
    
    % Coefficient of variation
    cv = rolling_std ./ rolling_mean;
    
    % Stability score (inverse of average CV)
    stability = 1 / (1 + nanmean(cv));
else
    stability = NaN;
end

end

%% Analysis Function: Uncertainty Quantification
function uncertaintyAnalysis = quantify_envelope_uncertainty(activeData)
% Quantify uncertainty from building envelope (tight vs leaky)

uncertaintyAnalysis = struct();
configs = fieldnames(activeData);

for i = 1:length(configs)
    config = configs{i};
    data = activeData.(config);
    
    uncertaintyAnalysis.(config) = struct();
    
    % Mean concentrations and scenario bounds
    pm25_tight_mean = mean(data.indoor_PM25_tight);
    pm25_leaky_mean = mean(data.indoor_PM25_leaky);
    pm10_tight_mean = mean(data.indoor_PM10_tight);
    pm10_leaky_mean = mean(data.indoor_PM10_leaky);

    pm25_bounds = [min(pm25_tight_mean, pm25_leaky_mean), ...
                   max(pm25_tight_mean, pm25_leaky_mean)];
    pm10_bounds = [min(pm10_tight_mean, pm10_leaky_mean), ...
                   max(pm10_tight_mean, pm10_leaky_mean)];

    pm25_range = diff(pm25_bounds);
    pm10_range = diff(pm10_bounds);

    pm25_mean = mean([pm25_tight_mean, pm25_leaky_mean]);
    pm10_mean = mean([pm10_tight_mean, pm10_leaky_mean]);

    uncertaintyAnalysis.(config).pm25_bounds = pm25_bounds;
    uncertaintyAnalysis.(config).pm10_bounds = pm10_bounds;
    uncertaintyAnalysis.(config).pm25_range_percent = 100 * pm25_range / pm25_mean;
    uncertaintyAnalysis.(config).pm10_range_percent = 100 * pm10_range / pm10_mean;

    % Hourly scenario bounds
    uncertaintyAnalysis.(config).hourly_ci_pm25 = [data.indoor_PM25_tight'; data.indoor_PM25_leaky'];
    uncertaintyAnalysis.(config).hourly_ci_pm10 = [data.indoor_PM10_tight'; data.indoor_PM10_leaky'];
    uncertaintyAnalysis.(config).hourly_mean_pm25 = data.indoor_PM25_mean;
    uncertaintyAnalysis.(config).hourly_mean_pm10 = data.indoor_PM10_mean;

    % Contribution estimates removed; scenario bounds define range
end

end