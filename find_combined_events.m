function events = find_combined_events(pm25_series, pm10_series, thr_pm25, thr_pm10, min_duration)
%FIND_COMBINED_EVENTS Detect events where PM2.5 and PM10 exceed thresholds.
%   EVENTS = FIND_COMBINED_EVENTS(PM25, PM10, THR_PM25, THR_PM10, MIN_DURATION)
%   returns a structure array of events. An event begins when both PM25 and
%   PM10 concentrations are simultaneously above the specified thresholds and
%   ends once either pollutant drops below its threshold. MIN_DURATION
%   specifies the minimum event length in samples.

    if nargin < 5
        min_duration = 1;
    end

    above = (pm25_series >= thr_pm25) & (pm10_series >= thr_pm10);
    above(isnan(above)) = false;
    starts = find(diff([false; above]) == 1);
    ends   = find(diff([above; false]) == -1);

    events = struct('start', {}, 'end', {}, 'duration', {}, ...
                    'peak_time', {}, 'peak_value', {}, 'peak_pm10', {}, ...
                    'baseline', {}, 'baseline_out', {});

    for k = 1:numel(starts)
        s = starts(k);
        e = ends(k);
        dur = e - s + 1;
        if dur < min_duration
            continue;
        end
        win = s:e;
        [~, idx] = max(pm25_series(win) + pm10_series(win));
        peak_idx = win(idx);
        events(end+1) = struct( ...
            'start', s, ...
            'end', e, ...
            'duration', dur, ...
            'peak_time', peak_idx, ...
            'peak_value', pm25_series(peak_idx), ...
            'peak_pm10', pm10_series(peak_idx), ...
            'baseline', thr_pm25, ...
            'baseline_out', thr_pm25 );
    end
end
