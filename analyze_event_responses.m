function response_metrics = analyze_event_responses(events, data, params)
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
    event_window = event.start:min(length(data.outdoor_PM25), event.end + params.response.lookahead_hours);

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
    post_event = event.end:min(length(data.indoor_PM25_mean), event.end + params.response.lookahead_hours);
    recovery_threshold = indoor_baseline_mean * params.response.recovery_factor;
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