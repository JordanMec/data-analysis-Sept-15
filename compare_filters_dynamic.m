function filterComparison = compare_filters_dynamic(activeData)
% COMPARE_FILTERS_DYNAMIC Compare HEPA vs MERV performance under dynamic conditions
%
% This function compares the performance of HEPA and MERV filters under
% active mode operation, analyzing various performance metrics.
%
% Input:
%   activeData - Structure containing active mode data from analyze_active_mode_advanced
%
% Output:
%   filterComparison - Structure containing filter comparison results by location

filterComparison = struct();
locations = unique(cellfun(@(x) activeData.(x).location, fieldnames(activeData), 'UniformOutput', false));

for loc_idx = 1:length(locations)
    location = locations{loc_idx};
    filterComparison.(location) = struct();
    
    % Find HEPA and MERV configs
    configs = fieldnames(activeData);
    hepa_config = [];
    merv_config = [];
    
    for i = 1:length(configs)
        if strcmp(activeData.(configs{i}).location, location)
            if strcmpi(activeData.(configs{i}).filterType, 'hepa')
                hepa_config = configs{i};
            elseif strcmpi(activeData.(configs{i}).filterType, 'merv')
                merv_config = configs{i};
            end
        end
    end
    
    if ~isempty(hepa_config) && ~isempty(merv_config)
        hepa_data = activeData.(hepa_config);
        merv_data = activeData.(merv_config);
        
        % Initialize structures
        filterComparison.(location).hepa = struct();
        filterComparison.(location).merv = struct();
        
        %% PM2.5 performance - calculate bounds properly
        hepa_io_pm25_tight = hepa_data.indoor_PM25_tight ./ hepa_data.outdoor_PM25;
        hepa_io_pm25_leaky = hepa_data.indoor_PM25_leaky ./ hepa_data.outdoor_PM25;
        merv_io_pm25_tight = merv_data.indoor_PM25_tight ./ merv_data.outdoor_PM25;
        merv_io_pm25_leaky = merv_data.indoor_PM25_leaky ./ merv_data.outdoor_PM25;
        
        % Remove infinities
        hepa_io_pm25_tight(~isfinite(hepa_io_pm25_tight)) = NaN;
        hepa_io_pm25_leaky(~isfinite(hepa_io_pm25_leaky)) = NaN;
        merv_io_pm25_tight(~isfinite(merv_io_pm25_tight)) = NaN;
        merv_io_pm25_leaky(~isfinite(merv_io_pm25_leaky)) = NaN;
        
        % Store PM2.5 bounds and means for HEPA
        filterComparison.(location).hepa.avg_io_ratio_pm25_tight = nanmean(hepa_io_pm25_tight);
        filterComparison.(location).hepa.avg_io_ratio_pm25_leaky = nanmean(hepa_io_pm25_leaky);
        filterComparison.(location).hepa.avg_io_ratio_pm25_lower = min(...
            filterComparison.(location).hepa.avg_io_ratio_pm25_tight, ...
            filterComparison.(location).hepa.avg_io_ratio_pm25_leaky);
        filterComparison.(location).hepa.avg_io_ratio_pm25_upper = max(...
            filterComparison.(location).hepa.avg_io_ratio_pm25_tight, ...
            filterComparison.(location).hepa.avg_io_ratio_pm25_leaky);
        filterComparison.(location).hepa.avg_io_ratio_pm25 = ...
            (filterComparison.(location).hepa.avg_io_ratio_pm25_tight + ...
             filterComparison.(location).hepa.avg_io_ratio_pm25_leaky) / 2;
        
        % Store PM2.5 bounds and means for MERV
        filterComparison.(location).merv.avg_io_ratio_pm25_tight = nanmean(merv_io_pm25_tight);
        filterComparison.(location).merv.avg_io_ratio_pm25_leaky = nanmean(merv_io_pm25_leaky);
        filterComparison.(location).merv.avg_io_ratio_pm25_lower = min(...
            filterComparison.(location).merv.avg_io_ratio_pm25_tight, ...
            filterComparison.(location).merv.avg_io_ratio_pm25_leaky);
        filterComparison.(location).merv.avg_io_ratio_pm25_upper = max(...
            filterComparison.(location).merv.avg_io_ratio_pm25_tight, ...
            filterComparison.(location).merv.avg_io_ratio_pm25_leaky);
        filterComparison.(location).merv.avg_io_ratio_pm25 = ...
            (filterComparison.(location).merv.avg_io_ratio_pm25_tight + ...
             filterComparison.(location).merv.avg_io_ratio_pm25_leaky) / 2;
        
        %% PM10 performance - calculate bounds properly
        hepa_io_pm10_tight = hepa_data.indoor_PM10_tight ./ hepa_data.outdoor_PM10;
        hepa_io_pm10_leaky = hepa_data.indoor_PM10_leaky ./ hepa_data.outdoor_PM10;
        merv_io_pm10_tight = merv_data.indoor_PM10_tight ./ merv_data.outdoor_PM10;
        merv_io_pm10_leaky = merv_data.indoor_PM10_leaky ./ merv_data.outdoor_PM10;
        
        % Remove infinities
        hepa_io_pm10_tight(~isfinite(hepa_io_pm10_tight)) = NaN;
        hepa_io_pm10_leaky(~isfinite(hepa_io_pm10_leaky)) = NaN;
        merv_io_pm10_tight(~isfinite(merv_io_pm10_tight)) = NaN;
        merv_io_pm10_leaky(~isfinite(merv_io_pm10_leaky)) = NaN;
        
        % Store PM10 bounds and means for HEPA
        filterComparison.(location).hepa.avg_io_ratio_pm10_tight = nanmean(hepa_io_pm10_tight);
        filterComparison.(location).hepa.avg_io_ratio_pm10_leaky = nanmean(hepa_io_pm10_leaky);
        filterComparison.(location).hepa.avg_io_ratio_pm10_lower = min(...
            filterComparison.(location).hepa.avg_io_ratio_pm10_tight, ...
            filterComparison.(location).hepa.avg_io_ratio_pm10_leaky);
        filterComparison.(location).hepa.avg_io_ratio_pm10_upper = max(...
            filterComparison.(location).hepa.avg_io_ratio_pm10_tight, ...
            filterComparison.(location).hepa.avg_io_ratio_pm10_leaky);
        filterComparison.(location).hepa.avg_io_ratio_pm10 = ...
            (filterComparison.(location).hepa.avg_io_ratio_pm10_tight + ...
             filterComparison.(location).hepa.avg_io_ratio_pm10_leaky) / 2;
        
        % Store PM10 bounds and means for MERV
        filterComparison.(location).merv.avg_io_ratio_pm10_tight = nanmean(merv_io_pm10_tight);
        filterComparison.(location).merv.avg_io_ratio_pm10_leaky = nanmean(merv_io_pm10_leaky);
        filterComparison.(location).merv.avg_io_ratio_pm10_lower = min(...
            filterComparison.(location).merv.avg_io_ratio_pm10_tight, ...
            filterComparison.(location).merv.avg_io_ratio_pm10_leaky);
        filterComparison.(location).merv.avg_io_ratio_pm10_upper = max(...
            filterComparison.(location).merv.avg_io_ratio_pm10_tight, ...
            filterComparison.(location).merv.avg_io_ratio_pm10_leaky);
        filterComparison.(location).merv.avg_io_ratio_pm10 = ...
            (filterComparison.(location).merv.avg_io_ratio_pm10_tight + ...
             filterComparison.(location).merv.avg_io_ratio_pm10_leaky) / 2;
        
        %% Response time with bounds for HEPA
        filterComparison.(location).hepa.response_time_tight = calculate_avg_response_time(hepa_data, 'tight');
        filterComparison.(location).hepa.response_time_leaky = calculate_avg_response_time(hepa_data, 'leaky');
        filterComparison.(location).hepa.response_time_lower = nanmin([...
            filterComparison.(location).hepa.response_time_tight, ...
            filterComparison.(location).hepa.response_time_leaky]);
        filterComparison.(location).hepa.response_time_upper = nanmax([...
            filterComparison.(location).hepa.response_time_tight, ...
            filterComparison.(location).hepa.response_time_leaky]);
        filterComparison.(location).hepa.response_time = ...
            nanmean([filterComparison.(location).hepa.response_time_tight, ...
                     filterComparison.(location).hepa.response_time_leaky]);
        
        %% Response time with bounds for MERV
        filterComparison.(location).merv.response_time_tight = calculate_avg_response_time(merv_data, 'tight');
        filterComparison.(location).merv.response_time_leaky = calculate_avg_response_time(merv_data, 'leaky');
        filterComparison.(location).merv.response_time_lower = nanmin([...
            filterComparison.(location).merv.response_time_tight, ...
            filterComparison.(location).merv.response_time_leaky]);
        filterComparison.(location).merv.response_time_upper = nanmax([...
            filterComparison.(location).merv.response_time_tight, ...
            filterComparison.(location).merv.response_time_leaky]);
        filterComparison.(location).merv.response_time = ...
            nanmean([filterComparison.(location).merv.response_time_tight, ...
                     filterComparison.(location).merv.response_time_leaky]);
        
        %% Peak reduction capability with bounds for HEPA
        filterComparison.(location).hepa.peak_reduction_tight = calculate_peak_reduction_capability(hepa_data, 'tight');
        filterComparison.(location).hepa.peak_reduction_leaky = calculate_peak_reduction_capability(hepa_data, 'leaky');
        filterComparison.(location).hepa.peak_reduction_lower = min(...
            filterComparison.(location).hepa.peak_reduction_tight, ...
            filterComparison.(location).hepa.peak_reduction_leaky);
        filterComparison.(location).hepa.peak_reduction_upper = max(...
            filterComparison.(location).hepa.peak_reduction_tight, ...
            filterComparison.(location).hepa.peak_reduction_leaky);
        filterComparison.(location).hepa.peak_reduction = ...
            (filterComparison.(location).hepa.peak_reduction_tight + ...
             filterComparison.(location).hepa.peak_reduction_leaky) / 2;
        
        %% Peak reduction capability with bounds for MERV
        filterComparison.(location).merv.peak_reduction_tight = calculate_peak_reduction_capability(merv_data, 'tight');
        filterComparison.(location).merv.peak_reduction_leaky = calculate_peak_reduction_capability(merv_data, 'leaky');
        filterComparison.(location).merv.peak_reduction_lower = min(...
            filterComparison.(location).merv.peak_reduction_tight, ...
            filterComparison.(location).merv.peak_reduction_leaky);
        filterComparison.(location).merv.peak_reduction_upper = max(...
            filterComparison.(location).merv.peak_reduction_tight, ...
            filterComparison.(location).merv.peak_reduction_leaky);
        filterComparison.(location).merv.peak_reduction = ...
            (filterComparison.(location).merv.peak_reduction_tight + ...
             filterComparison.(location).merv.peak_reduction_leaky) / 2;
        
        %% Stability score with bounds for HEPA
        filterComparison.(location).hepa.stability_score_tight = calculate_stability_score(hepa_io_pm25_tight);
        filterComparison.(location).hepa.stability_score_leaky = calculate_stability_score(hepa_io_pm25_leaky);
        filterComparison.(location).hepa.stability_score_lower = min(...
            filterComparison.(location).hepa.stability_score_tight, ...
            filterComparison.(location).hepa.stability_score_leaky);
        filterComparison.(location).hepa.stability_score_upper = max(...
            filterComparison.(location).hepa.stability_score_tight, ...
            filterComparison.(location).hepa.stability_score_leaky);
        filterComparison.(location).hepa.stability_score = ...
            (filterComparison.(location).hepa.stability_score_tight + ...
             filterComparison.(location).hepa.stability_score_leaky) / 2;
        
        %% Stability score with bounds for MERV
        filterComparison.(location).merv.stability_score_tight = calculate_stability_score(merv_io_pm25_tight);
        filterComparison.(location).merv.stability_score_leaky = calculate_stability_score(merv_io_pm25_leaky);
        filterComparison.(location).merv.stability_score_lower = min(...
            filterComparison.(location).merv.stability_score_tight, ...
            filterComparison.(location).merv.stability_score_leaky);
        filterComparison.(location).merv.stability_score_upper = max(...
            filterComparison.(location).merv.stability_score_tight, ...
            filterComparison.(location).merv.stability_score_leaky);
        filterComparison.(location).merv.stability_score = ...
            (filterComparison.(location).merv.stability_score_tight + ...
             filterComparison.(location).merv.stability_score_leaky) / 2;
        
        %% Size selectivity
        filterComparison.(location).hepa.size_selectivity = ...
            filterComparison.(location).hepa.avg_io_ratio_pm10 / ...
            filterComparison.(location).hepa.avg_io_ratio_pm25;
        filterComparison.(location).merv.size_selectivity = ...
            filterComparison.(location).merv.avg_io_ratio_pm10 / ...
            filterComparison.(location).merv.avg_io_ratio_pm25;
    end
end

end

%% Helper: Calculate average response time
function avg_response_time = calculate_avg_response_time(data, envelope)
% Calculate average system response time to concentration changes
% Modified to handle specific envelope

if nargin < 2
    indoor_data = data.indoor_PM25_mean;
    outdoor_data = data.outdoor_PM25;
else
    outdoor_data = data.outdoor_PM25;
    if strcmp(envelope, 'tight')
        indoor_data = data.indoor_PM25_tight;
    else
        indoor_data = data.indoor_PM25_leaky;
    end
end

outdoor_increases = find(diff(outdoor_data) > 5);
response_times = [];

for idx = outdoor_increases'
    if idx + 12 <= length(indoor_data)
        % Look for 50% reduction in increase
        outdoor_increase = outdoor_data(idx) - outdoor_data(idx-1);
        indoor_baseline = indoor_data(idx-1);
        
        for t = 1:12
            indoor_current = indoor_data(idx + t);
            indoor_increase = indoor_current - indoor_baseline;
            
            if indoor_increase < 0.5 * outdoor_increase
                response_times(end+1) = t;
                break;
            end
        end
    end
end

if ~isempty(response_times)
    avg_response_time = mean(response_times);
else
    avg_response_time = NaN;
end

end

%% Helper: Calculate peak reduction capability
function peak_reduction = calculate_peak_reduction_capability(data, envelope)
% Calculate average peak reduction during high pollution events

if nargin < 2
    indoor_data = data.indoor_PM25_mean;
else
    if strcmp(envelope, 'tight')
        indoor_data = data.indoor_PM25_tight;
    else
        indoor_data = data.indoor_PM25_leaky;
    end
end

threshold = prctile(data.outdoor_PM25, 90);
high_pollution = data.outdoor_PM25 > threshold;

if any(high_pollution)
    outdoor_high = data.outdoor_PM25(high_pollution);
    indoor_high = indoor_data(high_pollution);
    
    % Expected indoor if no filtration (1:1 ratio)
    expected_indoor = outdoor_high;
    
    % Actual reduction
    reductions = 100 * (expected_indoor - indoor_high) ./ expected_indoor;
    peak_reduction = nanmean(reductions);
else
    peak_reduction = NaN;
end

end

%% Helper: Calculate stability score
function stability = calculate_stability_score(io_ratio)
% Calculate performance stability metric

% Remove NaN values
valid_data = io_ratio(~isnan(io_ratio));

if length(valid_data) > 24
    % Calculate rolling standard deviation
    window = 24; % 24-hour window
    rolling_std = movstd(valid_data, window);
    rolling_mean = movmean(valid_data, window);
    
    % Coefficient of variation
    cv = rolling_std ./ rolling_mean;
    
    % Stability score (inverse of average CV)
    stability = 1 / (1 + nanmean(cv));
else
    stability = NaN;
end

end