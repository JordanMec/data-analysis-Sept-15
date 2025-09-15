function [avg_rt, rt_std] = compute_avg_response_time(indoor_series, outdoor_series, params)
%COMPUTE_AVG_RESPONSE_TIME Helper used by calculate_trigger_metrics to
%determine the response time of a given indoor concentration series.

increases = find(diff(outdoor_series) > params.response.diff_threshold);
response_times = NaN(numel(increases),1);
idx = 0;

for k = increases'
    if k + params.response.lookahead_hours <= numel(indoor_series)
        window = indoor_series(k:k+params.response.lookahead_hours);
        baseline = indoor_series(k);
        target = baseline * params.response.target_fraction;
        r = find(window < target, 1);
        if ~isempty(r)
            idx = idx + 1;
            response_times(idx) = r;
        end
    end
end

response_times = response_times(1:idx);
avg_rt = nanmean(response_times);
rt_std = nanstd(response_times);
end