function eventAnalysis = detect_analyze_pollution_events(activeData, params)
% Detect and analyze response to outdoor pollution events

eventAnalysis = struct();
configs = fieldnames(activeData);

for i = 1:length(configs)

    config = configs{i};
    data = activeData.(config);

    eventAnalysis.(config) = struct();
    eventAnalysis.(config).location = data.location;
    eventAnalysis.(config).filterType = data.filterType;

    % Use fixed detection thresholds so events start/end consistently
    pm25_threshold = 9.1;
    pm10_threshold = 54;

    % Baselines for severity calculations
    pm25_base_out = prctile(data.outdoor_PM25, params.baseline.percentile);
    pm10_base_out = prctile(data.outdoor_PM10, params.baseline.percentile);

    % Detect events where both PM2.5 and PM10 exceed their thresholds
    combined_events = find_combined_events(data.outdoor_PM25, data.outdoor_PM10, ...
        pm25_threshold, pm10_threshold, params.detection.min_duration_hours);

    % Bounds using tight and leaky indoor data
    pm25_base_tight = prctile(data.indoor_PM25_tight, params.baseline.percentile);
    pm10_base_tight = prctile(data.indoor_PM10_tight, params.baseline.percentile);
    pm25_base_leaky = prctile(data.indoor_PM25_leaky, params.baseline.percentile);
    pm10_base_leaky = prctile(data.indoor_PM10_leaky, params.baseline.percentile);

    events_tight = find_combined_events(data.indoor_PM25_tight, data.indoor_PM10_tight, ...
        pm25_threshold, pm10_threshold, params.detection.min_duration_hours);
    events_leaky = find_combined_events(data.indoor_PM25_leaky, data.indoor_PM10_leaky, ...
        pm25_threshold, pm10_threshold, params.detection.min_duration_hours);

    % Override baseline fields with percentile-based values for severity metrics
    for j = 1:numel(combined_events)
        combined_events(j).baseline = pm25_base_out;
        combined_events(j).baseline_out = pm25_base_out;
    end
    for j = 1:numel(events_tight)
        events_tight(j).baseline = pm25_base_tight;
        events_tight(j).baseline_out = pm25_base_tight;
    end
    for j = 1:numel(events_leaky)
        events_leaky(j).baseline = pm25_base_leaky;
        events_leaky(j).baseline_out = pm25_base_leaky;
    end

    total_tight = length(events_tight);
    total_leaky = length(events_leaky);

    eventAnalysis.(config).combined_events = combined_events;
    eventAnalysis.(config).total_events = mean([total_tight, total_leaky]);
    eventAnalysis.(config).total_events_bounds = [min(total_tight, total_leaky), max(total_tight, total_leaky)];

    % Analyze event characteristics using indoor events for duration bounds
    if ~isempty(events_tight)
        dur_tight = mean([events_tight.duration]);
    else
        dur_tight = NaN;
    end
    if ~isempty(events_leaky)
        dur_leaky = mean([events_leaky.duration]);
    else
        dur_leaky = NaN;
    end

    % Compute event severities for tight and leaky indoor cases
    if ~isempty(events_tight)
        severities_tight = [events_tight.peak_value] ./ [events_tight.baseline];
    else
        severities_tight = [];
    end
    if ~isempty(events_leaky)
        severities_leaky = [events_leaky.peak_value] ./ [events_leaky.baseline];
    else
        severities_leaky = [];
    end

    if ~isempty(combined_events)
        severities = [combined_events.peak_value] ./ [combined_events.baseline];
        eventAnalysis.(config).event_severities = severities;
        eventAnalysis.(config).event_severities_tight = severities_tight;
        eventAnalysis.(config).event_severities_leaky = severities_leaky;

        eventAnalysis.(config).avg_event_duration = mean([dur_tight, dur_leaky], 'omitnan');
        eventAnalysis.(config).avg_event_duration_bounds = [min(dur_tight, dur_leaky), max(dur_tight, dur_leaky)];

        % Analyze response to events
        response_metrics = analyze_event_responses(combined_events, data, params);
        eventAnalysis.(config).pm25_response = response_metrics;
    else
        eventAnalysis.(config).avg_event_duration = NaN;
        eventAnalysis.(config).avg_event_duration_bounds = [NaN, NaN];
        eventAnalysis.(config).event_severities = [];
        eventAnalysis.(config).event_severities_tight = severities_tight;
        eventAnalysis.(config).event_severities_leaky = severities_leaky;
    end
end

end