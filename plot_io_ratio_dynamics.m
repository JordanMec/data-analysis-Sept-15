function plot_io_ratio_dynamics(ioAnalysis, saveDir)
figure('Position', [100 100 1400 900], 'Visible', 'off');
configs = fieldnames(ioAnalysis);
nConfigs = numel(configs);

tiledlayout(ceil(nConfigs/2), 2, 'TileSpacing', 'compact');

for i = 1:nConfigs
    config = configs{i};
    data = ioAnalysis.(config);
    
    nexttile;
    hold on;
    
    % Plot time series with bounds
    t = 1:numel(data.io_pm25_mean);
    
    % PM2.5 bounds -- handle NaNs to ensure the shaded area renders correctly
    valid25 = isfinite(data.io_pm25_tight) & isfinite(data.io_pm25_leaky);
    t25 = t(valid25);
    fill([t25 fliplr(t25)], ...
        [data.io_pm25_tight(valid25)' fliplr(data.io_pm25_leaky(valid25)')], ...
        [0.2 0.4 0.8], 'FaceAlpha', 0.3, 'EdgeColor', 'none');
    plot(t, data.io_pm25_mean, 'b-', 'LineWidth', 2);
    
    % PM10 bounds
    valid10 = isfinite(data.io_pm10_tight) & isfinite(data.io_pm10_leaky);
    t10 = t(valid10);
    fill([t10 fliplr(t10)], ...
        [data.io_pm10_tight(valid10)' fliplr(data.io_pm10_leaky(valid10)')], ...
        [0.8 0.3 0.3], 'FaceAlpha', 0.3, 'EdgeColor', 'none');
    plot(t, data.io_pm10_mean, 'r-', 'LineWidth', 2);
    
    % Add reference lines
    yline(1, '--k', 'No Filtration');
    yline(data.stats.pm25_median, ':b', sprintf('Median: %.2f', data.stats.pm25_median));
    
    xlabel('Hour');
    ylabel('Indoor/Outdoor Ratio');
    title(sprintf('%s - %s Filter', data.location, data.filterType));
    legend({'PM2.5 Bounds', 'PM2.5 Mean', 'PM10 Bounds', 'PM10 Mean'}, 'Location', 'best');
    grid on;
    ylim([0 1.5]);
end

sgtitle('Indoor/Outdoor Ratio Dynamics - Active Mode', 'FontSize', 14, 'FontWeight', 'bold');
save_figure(gcf, saveDir, 'io_ratio_dynamics.png');
close(gcf);
end