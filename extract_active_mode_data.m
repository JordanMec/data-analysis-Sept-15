function activeData = extract_active_mode_data(summaryTable)
% Extract only active/triggered mode data with tight/leaky bounds

% Filter for active mode only
activeMask = strcmp(summaryTable.mode, 'active') | strcmp(summaryTable.mode, 'triggered');
activeRows = summaryTable(activeMask, :);

% Get unique configurations
configs = unique(activeRows(:, {'location', 'filterType'}));
activeData = struct();

for i = 1:height(configs)
    loc = configs.location{i};
    filt = configs.filterType{i};
    
    % Get tight and leaky data
    tightData = activeRows(strcmp(activeRows.location, loc) & ...
                          strcmp(activeRows.filterType, filt) & ...
                          strcmp(activeRows.leakage, 'tight'), :);
    leakyData = activeRows(strcmp(activeRows.location, loc) & ...
                          strcmp(activeRows.filterType, filt) & ...
                          strcmp(activeRows.leakage, 'leaky'), :);
    
    if isempty(tightData) || isempty(leakyData)
        continue;
    end
    
    % Store configuration data with bounds
    configKey = sprintf('%s_%s', loc, filt);
    activeData.(configKey) = struct();
    activeData.(configKey).location = loc;
    activeData.(configKey).filterType = filt;
    
    % Store time series data
    activeData.(configKey).indoor_PM25_tight = tightData.indoor_PM25{1};
    activeData.(configKey).indoor_PM25_leaky = leakyData.indoor_PM25{1};
    activeData.(configKey).indoor_PM10_tight = tightData.indoor_PM10{1};
    activeData.(configKey).indoor_PM10_leaky = leakyData.indoor_PM10{1};
    
    activeData.(configKey).outdoor_PM25 = tightData.outdoor_PM25{1}; % Same for both
    activeData.(configKey).outdoor_PM10 = tightData.outdoor_PM10{1};
    
    % Calculate mean and bounds
    activeData.(configKey).indoor_PM25_mean = (tightData.indoor_PM25{1} + leakyData.indoor_PM25{1}) / 2;
    activeData.(configKey).indoor_PM10_mean = (tightData.indoor_PM10{1} + leakyData.indoor_PM10{1}) / 2;
    
    % Store summary statistics
    activeData.(configKey).avg_indoor_PM25 = [tightData.avg_indoor_PM25, leakyData.avg_indoor_PM25];
    activeData.(configKey).avg_indoor_PM10 = [tightData.avg_indoor_PM10, leakyData.avg_indoor_PM10];
end

end