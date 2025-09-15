function events = detect_outdoor_events(outdoor_series, time_vec, pollutant_type, params)
%DETECT_OUTDOOR_EVENTS Detect significant pollution events in outdoor data.
%
% EVENTS = DETECT_OUTDOOR_EVENTS(SERIES, TIME_VEC, POLLUTANT_TYPE, PARAMS)
% identifies periods in SERIES that rise above a baseline level. TIME_VEC is
% a vector of numeric or datetime timestamps aligned with SERIES. The
% detector uses threshold multipliers and other options stored in PARAMS.
%
% Input arguments:
%   SERIES         - numeric vector of outdoor pollutant concentrations.
%   TIME_VEC       - vector of timestamps (same length as SERIES).
%   POLLUTANT_TYPE - 'PM2.5' or 'PM10'; selects threshold parameters.
%   PARAMS         - struct returned by GET_ANALYSIS_PARAMS.
%
% Output structure array fields:
%   start           - index where the event begins.
%   end             - index where the event ends.
%   duration        - length in samples.
%   peak_time       - index of the maximum value within the event.
%   peak_value      - pollutant concentration at the peak.
%   baseline        - baseline concentration used for thresholding.
%   baseline_out    - same as baseline (future-proof name).
%   start_time      - TIME_VEC(start).
%   end_time        - TIME_VEC(end).
%   peak_timestamp  - TIME_VEC(peak_time).
%   quality         - struct with flags (merged, short, nan_gap).
%
% Detection rules:
%   * Baseline is computed using PARAMS.baseline.percentile. Future versions
%     may use moving windows defined by
%     PARAMS.detection.baseline_window_style and
%     PARAMS.detection.baseline_window_hours.
%   * Points exceeding baseline * threshold_multiplier are flagged.
%   * Contiguous regions above threshold separated by fewer than
%     PARAMS.detection.min_separation_hours are merged.
%   * Regions shorter than PARAMS.detection.min_duration_hours are ignored.
%   * NaN values are treated as below threshold; if a NaN occurs within an
%     event it is noted via quality.nan_gap.
%
% NOTE: The current implementation is intentionally simple so that the
% interface is stable for more advanced detectors in the future.

    % Allow legacy calling form without time vector
    if nargin == 3
        params    = pollutant_type;
        pollutant_type = time_vec;
        time_vec = (1:numel(outdoor_series))';
    end

    if isstring(pollutant_type)
        pollutant_type = char(pollutant_type);
    end
    pollutant_type = validatestring(pollutant_type, {'PM2.5','PM10'});

    if strcmp(pollutant_type, 'PM2.5')
        mult = params.detection.threshold_multiplier_pm25;
    else
        mult = params.detection.threshold_multiplier_pm10;
    end
    min_dur = params.detection.min_duration_hours;
    min_sep = params.detection.min_separation_hours;

    baseline = prctile(outdoor_series, params.baseline.percentile);
    threshold = baseline * mult;

    above = outdoor_series > threshold;
    above(isnan(above)) = false;
    starts = find(diff([0; above]) == 1);
    ends   = find(diff([above; 0]) == -1);

    events = struct('start', {}, 'end', {}, 'duration', {}, ...
                    'peak_time', {}, 'peak_value', {}, 'baseline', {}, ...
                    'baseline_out', {}, 'start_time', {}, 'end_time', {}, ...
                    'peak_timestamp', {}, 'quality', {});

    idx = 0;
    j = 1;
    while j <= numel(starts)
        s = starts(j);
        e = ends(j);
        merged = false;
        k = j + 1;
        while k <= numel(starts) && starts(k) - e <= min_sep
            e = ends(k);
            merged = true;
            k = k + 1;
        end
        j = k;
        dur = e - s + 1;
        if dur < min_dur
            continue; % skip short spikes
        end
        idx = idx + 1;
        window = s:e;
        [~, relIdx] = max(outdoor_series(window));
        peak_idx = window(relIdx);
        q = struct('merged', merged, ...
                   'short', false, ...
                   'nan_gap', any(isnan(outdoor_series(window))));
        events(idx,1) = struct( ...
            'start', s, ...
            'end', e, ...
            'duration', dur, ...
            'peak_time', peak_idx, ...
            'peak_value', outdoor_series(peak_idx), ...
            'baseline', baseline, ...
            'baseline_out', baseline, ...
            'start_time', time_vec(s), ...
            'end_time', time_vec(e), ...
            'peak_timestamp', time_vec(peak_idx), ...
            'quality', q );
    end
end