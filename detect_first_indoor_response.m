function response_times = detect_first_indoor_response(events, indoor, params)
%DETECT_FIRST_INDOOR_RESPONSE Find first meaningful indoor response to events.
%  RESPONSE_TIMES = DETECT_FIRST_INDOOR_RESPONSE(EVENTS, INDOOR, PARAMS) returns
%  the number of samples after each event start when the indoor concentration
%  first exceeds a dynamic threshold.  The threshold is computed from a baseline
%  window immediately preceding the event and requires both a multiple of the
%  baseline variability and an absolute increment.

n = numel(events);
response_times = NaN(n,1);
for k = 1:n
    ev = events(k);
    baseIdx = max(1, ev.start - params.first_response.baseline_window_hours):ev.start-1;
    if isempty(baseIdx)
        continue
    end
    if params.first_response.baseline_statistic=="median"
        base = median(indoor(baseIdx),'omitnan');
    else
        base = mean(indoor(baseIdx),'omitnan');
    end
    if params.first_response.variability_method=="mad"
        varb = mad(indoor(baseIdx),1,'omitnan');
    else
        varb = std(indoor(baseIdx),'omitnan');
    end
    threshold = base + max(params.first_response.abs_threshold, ...
        params.first_response.departure_multiplier*varb);
    searchIdx = ev.start:min(numel(indoor), ev.start + params.response.lookahead_hours);
    r = find(indoor(searchIdx) > threshold,1);
    if ~isempty(r)
        response_times(k) = r; % duration after start
    end
end
end