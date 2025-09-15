function events = detect_intervention_events(control_series, outdoor_series, time_vec, params)
%DETECT_INTERVENTION_EVENTS Identify events based on intervention activation.
% EVENTS = DETECT_INTERVENTION_EVENTS(CONTROL, OUTDOOR, TIME_VEC, PARAMS)
% returns a structure array with the same fields as DETECT_OUTDOOR_EVENTS but
% using the intervention control signal to determine start/end times. OUTDOOR is
% used to locate the peak concentration within each activation period so that
% subsequent metrics are aligned with outdoor peaks.

if nargin < 3 || isempty(time_vec)
    time_vec = (1:numel(control_series))';
end
if nargin < 4
    params = struct();
end

control = logical(control_series(:));
starts = find(diff([0; control]) == 1);
ends = find(diff([control; 0]) == -1);
if numel(ends) < numel(starts)
    ends(end+1) = numel(control);
end

n = numel(starts);
baseline = prctile(outdoor_series, 20);

events = struct('start', {}, 'end', {}, 'duration', {}, ...
                'peak_time', {}, 'peak_value', {}, 'baseline', {}, ...
                'baseline_out', {}, 'start_time', {}, 'end_time', {}, ...
                'peak_timestamp', {}, 'quality', {});

for i = 1:n
    s = starts(i);
    e = ends(i);
    win = s:e;
    [~, idx] = max(outdoor_series(win));
    pk = win(idx);
    events(i).start = s;
    events(i).end = e;
    events(i).duration = e - s + 1;
    events(i).peak_time = pk;
    events(i).peak_value = outdoor_series(pk);
    events(i).baseline = baseline;
    events(i).baseline_out = baseline;
    events(i).start_time = time_vec(s);
    events(i).end_time = time_vec(e);
    events(i).peak_timestamp = time_vec(pk);
    events(i).quality = struct();
end
end
