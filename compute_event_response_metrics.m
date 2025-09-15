function out = compute_event_response_metrics(events, outdoor, indoor_series, params)
% Helper for envelope-specific event response metrics

out = struct('avg_lag_time', NaN, 'avg_peak_reduction', NaN, ...
             'avg_integrated_reduction', NaN, 'avg_recovery_time', NaN, ...
             'lag_times', [], 'peak_reductions', [], ...
             'integrated_reductions', [], 'recovery_times', []);

if isempty(events)
    return;
end

lag_times = NaN(numel(events),1);
peak_red  = NaN(numel(events),1);
int_red   = NaN(numel(events),1);
recovery_times = NaN(numel(events),1);

for j = 1:numel(events)
    ev = events(j);
    pre = max(1, ev.start - 6):ev.start-1;
    win = ev.start:min(length(outdoor), ev.end + 12);

    base = nanmean(indoor_series(pre));
    [ind_peak, idx] = max(indoor_series(win));
    lag_times(j) = win(idx) - ev.peak_time;

    expected = base + (ev.peak_value - ev.baseline);
    peak_red(j) = 100 * (expected - ind_peak) / expected;

    outdoor_excess = outdoor(win) - ev.baseline;
    indoor_excess  = indoor_series(win) - base;
    int_red(j) = 100 * (1 - sum(indoor_excess) / sum(outdoor_excess));

    if ev.end < length(indoor_series) - params.response.lookahead_hours
        post = ev.end:min(length(indoor_series), ev.end + params.response.lookahead_hours);
        thresh = base * params.response.recovery_factor;
        r = find(indoor_series(post) < thresh, 1);
        if ~isempty(r)
            recovery_times(j) = r;
        end
    end
end

out.lag_times = lag_times;
out.peak_reductions = peak_red;
out.integrated_reductions = int_red;
out.recovery_times = recovery_times;

out.avg_lag_time = nanmean(lag_times);
out.avg_peak_reduction = nanmean(peak_red);
out.avg_integrated_reduction = nanmean(int_red);
out.avg_recovery_time = nanmean(recovery_times);
end