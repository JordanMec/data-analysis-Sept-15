function ioAnalysis = analyze_io_ratios(activeData)
% Comprehensive Indoor/Outdoor ratio analysis

ioAnalysis = struct();
configs = fieldnames(activeData);

for i = 1:numel(configs)
    config = configs{i};
    data = activeData.(config);
    
    % Calculate I/O ratios for PM2.5
    io_pm25_tight = data.indoor_PM25_tight ./ data.outdoor_PM25;
    io_pm25_leaky = data.indoor_PM25_leaky ./ data.outdoor_PM25;
    io_pm25_mean = data.indoor_PM25_mean ./ data.outdoor_PM25;
    
    % Calculate I/O ratios for PM10
    io_pm10_tight = data.indoor_PM10_tight ./ data.outdoor_PM10;
    io_pm10_leaky = data.indoor_PM10_leaky ./ data.outdoor_PM10;
    io_pm10_mean = data.indoor_PM10_mean ./ data.outdoor_PM10;
    
    % Handle infinities and NaNs
    io_pm25_tight(~isfinite(io_pm25_tight)) = NaN;
    io_pm25_leaky(~isfinite(io_pm25_leaky)) = NaN;
    io_pm25_mean(~isfinite(io_pm25_mean)) = NaN;
    io_pm10_tight(~isfinite(io_pm10_tight)) = NaN;
    io_pm10_leaky(~isfinite(io_pm10_leaky)) = NaN;
    io_pm10_mean(~isfinite(io_pm10_mean)) = NaN;
    
    % Store results
    ioAnalysis.(config) = struct();
    ioAnalysis.(config).location = data.location;
    ioAnalysis.(config).filterType = data.filterType;
    
    % Time series
    ioAnalysis.(config).io_pm25_tight = io_pm25_tight;
    ioAnalysis.(config).io_pm25_leaky = io_pm25_leaky;
    ioAnalysis.(config).io_pm25_mean = io_pm25_mean;
    ioAnalysis.(config).io_pm10_tight = io_pm10_tight;
    ioAnalysis.(config).io_pm10_leaky = io_pm10_leaky;
    ioAnalysis.(config).io_pm10_mean = io_pm10_mean;
    
    % Statistics
    ioAnalysis.(config).stats = struct();
    ioAnalysis.(config).stats.pm25_mean = nanmean(io_pm25_mean);
    ioAnalysis.(config).stats.pm25_std = nanstd(io_pm25_mean);
    ioAnalysis.(config).stats.pm25_median = nanmedian(io_pm25_mean);
    ioAnalysis.(config).stats.pm25_range = [nanmean(io_pm25_tight), nanmean(io_pm25_leaky)];
    
    ioAnalysis.(config).stats.pm10_mean = nanmean(io_pm10_mean);
    ioAnalysis.(config).stats.pm10_std = nanstd(io_pm10_mean);
    ioAnalysis.(config).stats.pm10_median = nanmedian(io_pm10_mean);
    ioAnalysis.(config).stats.pm10_range = [nanmean(io_pm10_tight), nanmean(io_pm10_leaky)];
    
    % Dynamic range analysis
    ioAnalysis.(config).dynamics = struct();
    ioAnalysis.(config).dynamics.pm25_variability = nanstd(io_pm25_mean) / nanmean(io_pm25_mean);
    ioAnalysis.(config).dynamics.pm10_variability = nanstd(io_pm10_mean) / nanmean(io_pm10_mean);
end

end