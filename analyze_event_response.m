function response = analyze_event_response(events, outdoor, indoor_mean, indoor_tight, indoor_leaky, params)
% Analyze indoor response to outdoor events

response = struct();
nEvents = numel(events);
response.num_events = nEvents;
response.lag_times = NaN(nEvents,1);
response.peak_reductions = NaN(nEvents,1);
response.integrated_reductions = NaN(nEvents,1);
response.recovery_times = NaN(nEvents,1);

for j = 1:nEvents
    event = events(j);
    
    % Window around event (before, during, after)
    pre_window = max(1, event.start - 6):event.start-1;
    event_window = event.start:min(length(outdoor), event.end + 12);
    
    % Baseline indoor level
    indoor_baseline = nanmean(indoor_mean(pre_window));
    
    % Find indoor peak during/after event
    [indoor_peak, indoor_peak_idx] = max(indoor_mean(event_window));
    indoor_peak_time = event_window(indoor_peak_idx);
    
    % Calculate lag time
    lag_time = indoor_peak_time - event.peak_time;
    response.lag_times(j) = lag_time;
    
    % Peak reduction
    outdoor_peak = event.peak_value;
    expected_indoor = indoor_baseline + (outdoor_peak - event.baseline);
    peak_reduction = 100 * (expected_indoor - indoor_peak) / expected_indoor;
    response.peak_reductions(j) = peak_reduction;
    
    % Integrated reduction over event
    outdoor_excess = outdoor(event_window) - event.baseline;
    indoor_excess = indoor_mean(event_window) - indoor_baseline;
    integrated_reduction = 100 * (1 - sum(indoor_excess) / sum(outdoor_excess));
    response.integrated_reductions(j) = integrated_reduction;

    % Recovery time (time to return to within 10% of baseline)
    if event.end < length(indoor_mean) - params.response.lookahead_hours
        post_event = event.end:min(length(indoor_mean), event.end + params.response.lookahead_hours);
        recovery_threshold = indoor_baseline * params.response.recovery_factor;
        recovery_idx = find(indoor_mean(post_event) < recovery_threshold, 1);

        if ~isempty(recovery_idx)
            response.recovery_times(j) = recovery_idx;
        else
            response.recovery_times(j) = NaN;
        end
    else
        response.recovery_times(j) = NaN;
    end
end

% Summary statistics
response.avg_lag_time = nanmean(response.lag_times);
response.avg_peak_reduction = nanmean(response.peak_reductions);
response.avg_integrated_reduction = nanmean(response.integrated_reductions);
response.avg_recovery_time = nanmean(response.recovery_times);

% Compute bounds and per-event metrics using tight and leaky series
resp_tight = compute_event_response_metrics(events, outdoor, indoor_tight, params);
resp_leaky = compute_event_response_metrics(events, outdoor, indoor_leaky, params);

% Store bounds using [min, max] ordering
response.avg_lag_time_bounds = [min(resp_tight.avg_lag_time, resp_leaky.avg_lag_time), ...
                               max(resp_tight.avg_lag_time, resp_leaky.avg_lag_time)];
response.avg_peak_reduction_bounds = [min(resp_tight.avg_peak_reduction, resp_leaky.avg_peak_reduction), ...
                                     max(resp_tight.avg_peak_reduction, resp_leaky.avg_peak_reduction)];
response.avg_integrated_reduction_bounds = [min(resp_tight.avg_integrated_reduction, resp_leaky.avg_integrated_reduction), ...
                                            max(resp_tight.avg_integrated_reduction, resp_leaky.avg_integrated_reduction)];
response.avg_recovery_time_bounds = [min(resp_tight.avg_recovery_time, resp_leaky.avg_recovery_time), ...
                                     max(resp_tight.avg_recovery_time, resp_leaky.avg_recovery_time)];

response.lag_times_tight = resp_tight.lag_times;
response.lag_times_leaky = resp_leaky.lag_times;
response.peak_reductions_tight = resp_tight.peak_reductions;
response.peak_reductions_leaky = resp_leaky.peak_reductions;
response.integrated_reductions_tight = resp_tight.integrated_reductions;
response.integrated_reductions_leaky = resp_leaky.integrated_reductions;
response.recovery_times_tight = resp_tight.recovery_times;
response.recovery_times_leaky = resp_leaky.recovery_times;
end