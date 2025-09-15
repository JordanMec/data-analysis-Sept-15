function correlationAnalysis = analyze_cross_correlations(activeData)
% ANALYZE_CROSS_CORRELATIONS Analyze cross-correlations between outdoor and indoor concentrations
%
% This function analyzes the lag correlations between outdoor and indoor PM
% concentrations to understand system response characteristics.
%
% Input:
%   activeData - Structure containing active mode data from analyze_active_mode_advanced
%
% Output:
%   correlationAnalysis - Structure containing cross-correlation analysis results

correlationAnalysis = struct();
configs = fieldnames(activeData);

for i = 1:length(configs)
    config = configs{i};
    data = activeData.(config);
    
    correlationAnalysis.(config) = struct();
    
    % Cross-correlation for PM2.5 (mean and bounds)
    [corr_pm25, lags_pm25] = xcorr(data.outdoor_PM25, data.indoor_PM25_mean, 24, 'normalized');
    corr_pm25_tight = xcorr(data.outdoor_PM25, data.indoor_PM25_tight, 24, 'normalized');
    corr_pm25_leaky = xcorr(data.outdoor_PM25, data.indoor_PM25_leaky, 24, 'normalized');

    % Cross-correlation for PM10 (mean and bounds)
    [corr_pm10, lags_pm10] = xcorr(data.outdoor_PM10, data.indoor_PM10_mean, 24, 'normalized');
    corr_pm10_tight = xcorr(data.outdoor_PM10, data.indoor_PM10_tight, 24, 'normalized');
    corr_pm10_leaky = xcorr(data.outdoor_PM10, data.indoor_PM10_leaky, 24, 'normalized');
    
    % Store results
    % Ensure row orientation for compatibility with plotting routines
    correlationAnalysis.(config).pm25_correlation = corr_pm25(:)';
    correlationAnalysis.(config).pm10_correlation = corr_pm10(:)';

    % Store tight and leaky envelope correlations as a 2xN matrix
    correlationAnalysis.(config).pm25_correlation_bounds = [corr_pm25_tight(:)'; corr_pm25_leaky(:)'];
    correlationAnalysis.(config).pm10_correlation_bounds = [corr_pm10_tight(:)'; corr_pm10_leaky(:)'];

    % Lags are the same for PM2.5 and PM10 so just store once
    correlationAnalysis.(config).lags = lags_pm25(:)';
    
    % Find optimal lag (maximum correlation)
    [max_corr_pm25, max_idx_pm25] = max(corr_pm25);
    [max_corr_pm10, max_idx_pm10] = max(corr_pm10);
    
    correlationAnalysis.(config).optimal_lag_pm25 = lags_pm25(max_idx_pm25);
    correlationAnalysis.(config).optimal_lag_pm10 = lags_pm10(max_idx_pm10);
    correlationAnalysis.(config).max_correlation_pm25 = max_corr_pm25;
    correlationAnalysis.(config).max_correlation_pm10 = max_corr_pm10;
    
    % Frequency domain analysis
    if length(data.indoor_PM25_mean) > 48
        try
            % Try to use pwelch if Signal Processing Toolbox is available
            [psd_out, f] = pwelch(data.outdoor_PM25, [], [], [], 1); % 1 sample/hour
            [psd_in, ~] = pwelch(data.indoor_PM25_mean, [], [], [], 1);
            
            correlationAnalysis.(config).transfer_function = psd_in ./ psd_out;
            correlationAnalysis.(config).frequencies = f;
            
            % Find cutoff frequency (where transfer function drops to 0.5)
            tf_normalized = correlationAnalysis.(config).transfer_function / ...
                           correlationAnalysis.(config).transfer_function(1);
            cutoff_idx = find(tf_normalized < 0.5, 1);
            if ~isempty(cutoff_idx)
                correlationAnalysis.(config).cutoff_frequency = f(cutoff_idx);
            else
                correlationAnalysis.(config).cutoff_frequency = NaN;
            end
        catch ME
            if contains(ME.message, 'pwelch') || contains(ME.message, 'Signal Processing')
                % Signal Processing Toolbox not available - skip frequency analysis
                fprintf('Note: Signal Processing Toolbox not available. Skipping frequency domain analysis.\n');
                correlationAnalysis.(config).transfer_function = [];
                correlationAnalysis.(config).frequencies = [];
                correlationAnalysis.(config).cutoff_frequency = NaN;
            else
                % Other error - rethrow
                rethrow(ME);
            end
        end
    else
        % Not enough data for frequency analysis
        correlationAnalysis.(config).transfer_function = [];
        correlationAnalysis.(config).frequencies = [];
        correlationAnalysis.(config).cutoff_frequency = NaN;
    end
end

end