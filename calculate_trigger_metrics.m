function metrics = calculate_trigger_metrics(data, params)
% Calculate overall trigger performance metrics. In addition to the mean
% response time based on the average indoor series, compute separate
% response times for the tight and leaky envelopes so that plots can show
% the uncertainty range between the two scenarios.

metrics = struct();

% --- Response time using mean indoor series ---
    outdoor_increases = find(diff(data.outdoor_PM25) > params.response.diff_threshold);
response_times = NaN(numel(outdoor_increases),1);
rtIdx = 0;

for idx = outdoor_increases'
    if idx + params.response.lookahead_hours <= numel(data.indoor_PM25_mean)
        indoor_response = data.indoor_PM25_mean(idx:idx+params.response.lookahead_hours);
        baseline = data.indoor_PM25_mean(idx);
        target = baseline * params.response.target_fraction;

        response_idx = find(indoor_response < target, 1);
        if ~isempty(response_idx)
            rtIdx = rtIdx + 1;
            response_times(rtIdx) = response_idx;
        end
    end
end

response_times = response_times(1:rtIdx);

metrics.avg_response_time = nanmean(response_times);
metrics.response_time_std = nanstd(response_times);

% --- Response times for tight and leaky envelopes ---
[rt_tight, rt_tight_std] = compute_avg_response_time(data.indoor_PM25_tight, data.outdoor_PM25, params);
[rt_leaky, rt_leaky_std] = compute_avg_response_time(data.indoor_PM25_leaky, data.outdoor_PM25, params);
% Ensure bounds follow the [min, max] convention
metrics.avg_response_time_bounds = [min(rt_tight, rt_leaky), max(rt_tight, rt_leaky)];
metrics.response_time_std = nanmean([rt_tight_std, rt_leaky_std]);

% Filtration efficiency during active periods
% Estimate when system is actively filtering (low I/O ratios)
io_ratio = data.indoor_PM25_mean ./ data.outdoor_PM25;
io_ratio(~isfinite(io_ratio)) = NaN;
    active_threshold = nanmedian(io_ratio) * params.active_mode.threshold_factor;
active_periods = io_ratio < active_threshold;

metrics.active_hours = sum(active_periods);
metrics.active_percentage = 100 * sum(active_periods) / numel(active_periods);

% Efficiency during active periods
if any(active_periods)
    metrics.active_io_ratio = nanmean(io_ratio(active_periods));
    metrics.inactive_io_ratio = nanmean(io_ratio(~active_periods));
    metrics.efficiency_gain = 100 * (metrics.inactive_io_ratio - metrics.active_io_ratio) / ...
        metrics.inactive_io_ratio;
end

end