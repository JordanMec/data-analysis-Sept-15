function triggerAnalysis = analyze_trigger_response(activeData, params)
% Analyze how quickly and effectively the system responds to triggers

triggerAnalysis = struct();
configs = fieldnames(activeData);

for i = 1:numel(configs)
    config = configs{i};
    data = activeData.(config);
    
    triggerAnalysis.(config) = struct();
    
    % Detect trigger events (significant increases in outdoor PM)
    tvec = (1:numel(data.outdoor_PM25))';
    pm25_events = detect_outdoor_events(data.outdoor_PM25, tvec, 'PM2.5', params);
    pm10_events = detect_outdoor_events(data.outdoor_PM10, tvec, 'PM10', params);
    
    % Analyze response to PM2.5 events
    if ~isempty(pm25_events)
        pm25_response = analyze_event_response(pm25_events, ...
            data.outdoor_PM25, data.indoor_PM25_mean, ...
            data.indoor_PM25_tight, data.indoor_PM25_leaky, params);
        triggerAnalysis.(config).pm25_response = pm25_response;
    end
    
    % Analyze response to PM10 events
    if ~isempty(pm10_events)
        pm10_response = analyze_event_response(pm10_events, ...
            data.outdoor_PM10, data.indoor_PM10_mean, ...
            data.indoor_PM10_tight, data.indoor_PM10_leaky, params);
        triggerAnalysis.(config).pm10_response = pm10_response;
    end
    
    % Overall trigger metrics
    triggerAnalysis.(config).metrics = calculate_trigger_metrics(data, params);
end

end