function temporalAnalysis = analyze_temporal_patterns(activeData)
% ANALYZE_TEMPORAL_PATTERNS Analyze temporal patterns in filtration performance
% Properly treats tight/leaky as bounds on possible home configurations

temporalAnalysis = struct();
configs = fieldnames(activeData);

for i = 1:length(configs)
    config = configs{i};
    data = activeData.(config);
    
    temporalAnalysis.(config) = struct();
    temporalAnalysis.(config).location = data.location;
    temporalAnalysis.(config).filterType = data.filterType;
    
    % Calculate I/O ratios for BOTH bounds
    io_ratio_pm25_tight = data.indoor_PM25_tight ./ data.outdoor_PM25;
    io_ratio_pm25_leaky = data.indoor_PM25_leaky ./ data.outdoor_PM25;
    io_ratio_pm25_tight(~isfinite(io_ratio_pm25_tight)) = NaN;
    io_ratio_pm25_leaky(~isfinite(io_ratio_pm25_leaky)) = NaN;
    
    % Diurnal pattern - calculate for both bounds
    hours_of_day = mod(0:length(io_ratio_pm25_tight)-1, 24);
    diurnal_io_tight = zeros(24, 1);
    diurnal_io_leaky = zeros(24, 1);
    diurnal_io_lower = zeros(24, 1);
    diurnal_io_upper = zeros(24, 1);
    diurnal_counts = zeros(24, 1);
    
    for h = 0:23
        hour_mask = hours_of_day == h;
        hour_data_tight = io_ratio_pm25_tight(hour_mask);
        hour_data_leaky = io_ratio_pm25_leaky(hour_mask);
        
        diurnal_io_tight(h+1) = nanmean(hour_data_tight);
        diurnal_io_leaky(h+1) = nanmean(hour_data_leaky);
        
        % True bounds (min/max at each hour)
        diurnal_io_lower(h+1) = min(diurnal_io_tight(h+1), diurnal_io_leaky(h+1));
        diurnal_io_upper(h+1) = max(diurnal_io_tight(h+1), diurnal_io_leaky(h+1));
        
        diurnal_counts(h+1) = sum(~isnan(hour_data_tight));
    end
    
    temporalAnalysis.(config).diurnal_io_ratio_tight = diurnal_io_tight;
    temporalAnalysis.(config).diurnal_io_ratio_leaky = diurnal_io_leaky;
    temporalAnalysis.(config).diurnal_io_ratio_lower = diurnal_io_lower;
    temporalAnalysis.(config).diurnal_io_ratio_upper = diurnal_io_upper;
    temporalAnalysis.(config).diurnal_io_ratio = (diurnal_io_tight + diurnal_io_leaky) / 2; % For compatibility
    temporalAnalysis.(config).diurnal_counts = diurnal_counts;
    
    % Weekly pattern - with bounds
    days = floor((0:length(io_ratio_pm25_tight)-1) / 24);
    day_of_week = mod(days, 7) + 1;
    
    weekday_mask = day_of_week >= 1 & day_of_week <= 5;
    weekend_mask = day_of_week >= 6;
    
    temporalAnalysis.(config).weekly_pattern = struct();
    temporalAnalysis.(config).weekly_pattern.weekday_avg_tight = nanmean(io_ratio_pm25_tight(weekday_mask));
    temporalAnalysis.(config).weekly_pattern.weekday_avg_leaky = nanmean(io_ratio_pm25_leaky(weekday_mask));
    temporalAnalysis.(config).weekly_pattern.weekend_avg_tight = nanmean(io_ratio_pm25_tight(weekend_mask));
    temporalAnalysis.(config).weekly_pattern.weekend_avg_leaky = nanmean(io_ratio_pm25_leaky(weekend_mask));
    
    % Bounds
    temporalAnalysis.(config).weekly_pattern.weekday_avg_lower = min(...
        temporalAnalysis.(config).weekly_pattern.weekday_avg_tight, ...
        temporalAnalysis.(config).weekly_pattern.weekday_avg_leaky);
    temporalAnalysis.(config).weekly_pattern.weekday_avg_upper = max(...
        temporalAnalysis.(config).weekly_pattern.weekday_avg_tight, ...
        temporalAnalysis.(config).weekly_pattern.weekday_avg_leaky);
    
    % For compatibility
    temporalAnalysis.(config).weekly_pattern.weekday_avg = ...
        (temporalAnalysis.(config).weekly_pattern.weekday_avg_tight + ...
         temporalAnalysis.(config).weekly_pattern.weekday_avg_leaky) / 2;
    temporalAnalysis.(config).weekly_pattern.weekend_avg = ...
        (temporalAnalysis.(config).weekly_pattern.weekend_avg_tight + ...
         temporalAnalysis.(config).weekly_pattern.weekend_avg_leaky) / 2;
    
    % Performance stability - calculate bounds
    daily_averages_tight = [];
    daily_averages_leaky = [];
    for d = 0:max(days)
        day_mask = days == d;
        if sum(day_mask) > 12
            daily_averages_tight(end+1) = nanmean(io_ratio_pm25_tight(day_mask));
            daily_averages_leaky(end+1) = nanmean(io_ratio_pm25_leaky(day_mask));
        end
    end
    
    if length(daily_averages_tight) > 1
        stability_tight = 1 - (std(daily_averages_tight) / mean(daily_averages_tight));
        stability_leaky = 1 - (std(daily_averages_leaky) / mean(daily_averages_leaky));
        
        temporalAnalysis.(config).stability_score_tight = stability_tight;
        temporalAnalysis.(config).stability_score_leaky = stability_leaky;
        temporalAnalysis.(config).stability_score_lower = min(stability_tight, stability_leaky);
        temporalAnalysis.(config).stability_score_upper = max(stability_tight, stability_leaky);
        temporalAnalysis.(config).stability_score = (stability_tight + stability_leaky) / 2;
        
        temporalAnalysis.(config).performance_trend_tight = daily_averages_tight;
        temporalAnalysis.(config).performance_trend_leaky = daily_averages_leaky;
        % Explicitly store lower and upper bounds for clarity
        temporalAnalysis.(config).performance_trend_lower = min(daily_averages_tight, daily_averages_leaky);
        temporalAnalysis.(config).performance_trend_upper = max(daily_averages_tight, daily_averages_leaky);

        temporalAnalysis.(config).performance_trend = (daily_averages_tight + daily_averages_leaky) / 2;
    else
        temporalAnalysis.(config).stability_score = NaN;
        temporalAnalysis.(config).stability_score_lower = NaN;
        temporalAnalysis.(config).stability_score_upper = NaN;
        temporalAnalysis.(config).performance_trend = [];
    end
    
    % Temporal autocorrelation with bounds
    valid_data_tight = io_ratio_pm25_tight(~isnan(io_ratio_pm25_tight));
    valid_data_leaky = io_ratio_pm25_leaky(~isnan(io_ratio_pm25_leaky));
    
    if length(valid_data_tight) > 48 && length(valid_data_leaky) > 48
        try
            % Try to use autocorr if Econometrics Toolbox is available
            [acf_tight, lags] = autocorr(valid_data_tight, 'NumLags', 24);
            [acf_leaky, ~] = autocorr(valid_data_leaky, 'NumLags', 24);
            
        catch ME
            % Manual calculation if autocorr not available
            fprintf('Note: autocorr function not available. Using simple autocorrelation.\n');
            
            maxLag = 24;
            lags = 0:maxLag;
            
            % Manual ACF calculation for tight
            acf_tight = zeros(maxLag+1, 1);
            acf_tight(1) = 1; % Lag 0 is always 1
            mean_tight = mean(valid_data_tight);
            var_tight = var(valid_data_tight);
            
            for lag = 1:maxLag
                if lag < length(valid_data_tight)
                    cov_lag = mean((valid_data_tight(1:end-lag) - mean_tight) .* ...
                                  (valid_data_tight(lag+1:end) - mean_tight));
                    acf_tight(lag+1) = cov_lag / var_tight;
                end
            end
            
            % Manual ACF calculation for leaky
            acf_leaky = zeros(maxLag+1, 1);
            acf_leaky(1) = 1;
            mean_leaky = mean(valid_data_leaky);
            var_leaky = var(valid_data_leaky);
            
            for lag = 1:maxLag
                if lag < length(valid_data_leaky)
                    cov_lag = mean((valid_data_leaky(1:end-lag) - mean_leaky) .* ...
                                  (valid_data_leaky(lag+1:end) - mean_leaky));
                    acf_leaky(lag+1) = cov_lag / var_leaky;
                end
            end
        end
        
        % Store bounds
        temporalAnalysis.(config).autocorrelation_tight = acf_tight;
        temporalAnalysis.(config).autocorrelation_leaky = acf_leaky;
        
        % Calculate bounds at each lag
        acf_lower = min([acf_tight, acf_leaky], [], 2);
        acf_upper = max([acf_tight, acf_leaky], [], 2);
        
        temporalAnalysis.(config).autocorrelation_lower = acf_lower;
        temporalAnalysis.(config).autocorrelation_upper = acf_upper;
        temporalAnalysis.(config).autocorrelation = (acf_tight + acf_leaky) / 2;
        temporalAnalysis.(config).acf_lags = lags;
        
        % Find decorrelation time for both bounds
        decorr_idx_tight = find(abs(acf_tight) < 0.2, 1);
        decorr_idx_leaky = find(abs(acf_leaky) < 0.2, 1);
        
        if ~isempty(decorr_idx_tight)
            decorr_time_tight = lags(decorr_idx_tight);
        else
            decorr_time_tight = NaN;
        end
        
        if ~isempty(decorr_idx_leaky)
            decorr_time_leaky = lags(decorr_idx_leaky);
        else
            decorr_time_leaky = NaN;
        end
        
        temporalAnalysis.(config).decorrelation_time_tight = decorr_time_tight;
        temporalAnalysis.(config).decorrelation_time_leaky = decorr_time_leaky;
        temporalAnalysis.(config).decorrelation_time_lower = nanmin([decorr_time_tight, decorr_time_leaky]);
        temporalAnalysis.(config).decorrelation_time_upper = nanmax([decorr_time_tight, decorr_time_leaky]);
        temporalAnalysis.(config).decorrelation_time = nanmean([decorr_time_tight, decorr_time_leaky]);
        
    else
        % Not enough data
        temporalAnalysis.(config).autocorrelation = [];
        temporalAnalysis.(config).autocorrelation_lower = [];
        temporalAnalysis.(config).autocorrelation_upper = [];
        temporalAnalysis.(config).acf_lags = [];
        temporalAnalysis.(config).decorrelation_time = NaN;
        temporalAnalysis.(config).decorrelation_time_lower = NaN;
        temporalAnalysis.(config).decorrelation_time_upper = NaN;
    end
end

end