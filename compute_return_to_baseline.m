function rtb_times = compute_return_to_baseline(events, indoor, baseline, params)
%COMPUTE_RETURN_TO_BASELINE Estimate time to return to baseline after events.
%  RTB_TIMES = COMPUTE_RETURN_TO_BASELINE(EVENTS, INDOOR, BASELINE, PARAMS)
%  returns the number of samples after each event end until indoor
%  concentrations re-enter a tolerance band around the pre-event baseline and
%  remain there for a hold period.

n = numel(events);
rtb_times = NaN(n,1);
for k = 1:n
    ev = events(k);
    if numel(indoor) - ev.end < params.rtb.min_data_hours
        continue
    end
    base = baseline(ev.start);
    bandLow = base*(1 - params.rtb.tolerance_fraction);
    bandHigh = base*(1 + params.rtb.tolerance_fraction);
    hold = params.rtb.hold_time_hours;
    searchEnd = min(numel(indoor), ev.end + params.response.lookahead_hours);
    for t = ev.end:searchEnd-hold+1
        seg = indoor(t:t+hold-1);
        if all(seg >= bandLow & seg <= bandHigh)
            rtb_times(k) = t - ev.end;
            break
        end
    end
end
end