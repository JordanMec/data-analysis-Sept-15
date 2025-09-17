function plot_correlation_analysis(correlationAnalysis, saveDir)
%PLOT_CORRELATION_ANALYSIS Visualize lag correlations between indoor and outdoor PM
%   plot_correlation_analysis(correlationAnalysis, saveDir) plots cross-
%   correlation curves for each configuration and marks optimal lags.

if isempty(fieldnames(correlationAnalysis))
    warning('plot_correlation_analysis: no data provided, skipping plot.');
    return;
end

fig = figure('Visible', 'off');
set_figure_fullscreen(fig);

configs = fieldnames(correlationAnalysis);

% Lag correlation plots
nConfigs = length(configs);
nCols = min(3, nConfigs);
nRows = ceil(nConfigs / nCols);

for i = 1:nConfigs
    subplot(nRows, nCols, i);

    config = configs{i};
    data = correlationAnalysis.(config);

    if isfield(data, 'pm25_correlation')
        hold on;
        if isfield(data, 'pm25_correlation_bounds')
            lags_row = data.lags(:)';
            fill([lags_row fliplr(lags_row)], ...
                 [data.pm25_correlation_bounds(1,:) fliplr(data.pm25_correlation_bounds(2,:))], ...
                 [0.2 0.4 0.8], 'FaceAlpha', 0.2, 'EdgeColor', 'none');
            fill([lags_row fliplr(lags_row)], ...
                 [data.pm10_correlation_bounds(1,:) fliplr(data.pm10_correlation_bounds(2,:))], ...
                 [0.8 0.3 0.3], 'FaceAlpha', 0.2, 'EdgeColor', 'none');
        end
        plot(data.lags, data.pm25_correlation, 'b-', 'LineWidth', 2);
        plot(data.lags, data.pm10_correlation, 'r-', 'LineWidth', 2);

        % Mark peak correlation
        [max_corr_pm25, max_idx_pm25] = max(data.pm25_correlation);
        [max_corr_pm10, max_idx_pm10] = max(data.pm10_correlation);

        plot(data.lags(max_idx_pm25), max_corr_pm25, 'bo', 'MarkerSize', 8, 'LineWidth', 2);
        plot(data.lags(max_idx_pm10), max_corr_pm10, 'ro', 'MarkerSize', 8, 'LineWidth', 2);

        xlabel('Lag Time (Hours)');
        ylabel('Cross Correlation');
        title(sprintf('%s\nOptimal Lag Fine Particulate Matter 2.5 Micrometers = %dh, Coarse Particulate Matter 10 Micrometers = %dh', ...
            format_filter_label(config), ...
            data.lags(max_idx_pm25), data.lags(max_idx_pm10)));
        legend({'PM2.5 Bounds','PM10 Bounds','PM2.5','PM10'}, 'Location', 'best');
        grid on;
        xlim([-12 12]);
    end
end

sgtitle('Cross Correlation Analysis for Indoor Versus Outdoor Trends', 'FontSize', 14, 'FontWeight', 'bold');
add_figure_caption(fig, sprintf(['Each subplot plots indoor versus outdoor cross correlations across lags, with shaded bands when tight and leaky bounds are available.' newline ...
    'Markers indicate the lag where PM2.5 and PM10 correlations peak so you can gauge how quickly indoor air follows outdoor changes.' newline ...
    'Reviewing the grid reveals which configurations respond promptly and which lag behind under different envelope assumptions.']));
save_figure(fig, saveDir, 'correlation_analysis.png');
close(fig);
end
