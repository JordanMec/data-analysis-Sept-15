function events = find_pollution_events(outdoor_series, threshold, min_duration, thresh_mult)
% Find periods where outdoor concentration exceeds threshold

above_threshold = outdoor_series > threshold;
starts = find(diff([0; above_threshold]) == 1);
ends = find(diff([above_threshold; 0]) == -1);

events = [];
for j = 1:length(starts)
    duration = ends(j) - starts(j) + 1;
    if duration >= min_duration
        event = struct();

        event.start = starts(j);
        event.end = ends(j);
        event.duration = duration;

        event_data = outdoor_series(starts(j):ends(j));
        [event.peak_value, peak_idx] = max(event_data);
        event.peak_time = starts(j) + peak_idx - 1;
        event.baseline = threshold / thresh_mult; % Reverse calculation

        events = [events; event];

    end
end

end