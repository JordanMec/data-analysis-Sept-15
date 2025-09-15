function plot_penetration_analysis(penetrationAnalysis, saveDir)
%PLOT_PENETRATION_ANALYSIS Visualize particle penetration factors and removal efficiency
%   plot_penetration_analysis(penetrationAnalysis, saveDir) creates plots of
%   penetration factors for PM2.5 and PM10 along with removal efficiency and
%   size-dependent behavior. Results are saved to the specified directory.

if isempty(fieldnames(penetrationAnalysis))
    warning('plot_penetration_analysis: no data provided, skipping plot.');
    return;
end

figure('Position', [100 100 1400 900], 'Visible', 'off');

configs = fieldnames(penetrationAnalysis);
nConfigs = length(configs);
cmap = get_color_map();

% Penetration factors comparison
subplot(2, 2, 1);
hold on;

pm25_factors = [];
pm10_factors = [];
pm25_bounds = [];
pm10_bounds = [];
labels = {};

for i = 1:nConfigs
    config = configs{i};
    data = penetrationAnalysis.(config);

    pm25_factors(i) = data.pm25_penetration_mean;
    pm10_factors(i) = data.pm10_penetration_mean;
    pm25_bounds(i,:) = data.pm25_penetration_bounds;
    pm10_bounds(i,:) = data.pm10_penetration_bounds;
    labels{i} = sprintf('%s\n%s', data.location, data.filterType);
end

x = 1:nConfigs;
width = 0.35;

% Plot with error bars
hPM25 = bar(x - width/2, pm25_factors, width, 'FaceColor', cmap.pm25);
hold on;
hPM10 = bar(x + width/2, pm10_factors, width, 'FaceColor', cmap.pm10);

% Add error bars for bounds
errorbar(x - width/2, pm25_factors, ...
    pm25_factors - pm25_bounds(:,1)', pm25_bounds(:,2)' - pm25_factors, ...
    'k', 'LineStyle', 'none', 'HandleVisibility', 'off');
errorbar(x + width/2, pm10_factors, ...
    pm10_factors - pm10_bounds(:,1)', pm10_bounds(:,2)' - pm10_factors, ...
    'k', 'LineStyle', 'none', 'HandleVisibility', 'off');

set(gca, 'XTick', x, 'XTickLabel', labels);
ylabel('Penetration Factor');
legend([hPM25 hPM10], {'PM2.5', 'PM10'}, 'Location', 'best');
title('Particle Penetration Factors');
grid on;
ylim([0 1]);

% Removal efficiency
subplot(2, 2, 2);
pm25_removal = (1 - pm25_factors) * 100;
pm10_removal = (1 - pm10_factors) * 100;
% Bounds are provided as [tightMean, leakyMean] and may not be ordered.
% Sort penetration bounds so we can derive valid removal efficiency bounds
pm25_pen_sorted = sort(pm25_bounds, 2);  % [lowPen, highPen]
pm10_pen_sorted = sort(pm10_bounds, 2);
pm25_removal_bounds = (1 - fliplr(pm25_pen_sorted)) * 100; % [minRem, maxRem]
pm10_removal_bounds = (1 - fliplr(pm10_pen_sorted)) * 100;

hR25 = bar(x - width/2, pm25_removal, width, 'FaceColor', cmap.pm25);
hold on;
hR10 = bar(x + width/2, pm10_removal, width, 'FaceColor', cmap.pm10);

% Add error bars for bounds
errorbar(x - width/2, pm25_removal, ...
    pm25_removal - pm25_removal_bounds(:,1)', pm25_removal_bounds(:,2)' - pm25_removal, ...
    'k', 'LineStyle', 'none', 'HandleVisibility', 'off');
errorbar(x + width/2, pm10_removal, ...
    pm10_removal - pm10_removal_bounds(:,1)', pm10_removal_bounds(:,2)' - pm10_removal, ...
    'k', 'LineStyle', 'none', 'HandleVisibility', 'off');

set(gca, 'XTick', x, 'XTickLabel', labels);
ylabel('Removal Efficiency (%)');
legend([hR25 hR10], {'PM2.5', 'PM10'}, 'Location', 'best');
title('Particle Removal Efficiency');
grid on;

% Size-dependent efficiency ratio
subplot(2, 2, 3);
size_ratio = pm10_factors ./ pm25_factors;
ratio_bounds(:,1) = pm10_bounds(:,1) ./ pm25_bounds(:,2);
ratio_bounds(:,2) = pm10_bounds(:,2) ./ pm25_bounds(:,1);

hRatio = bar(size_ratio, 'FaceColor', cmap.gray);
hold on;
errorbar(x, size_ratio, ...
    size_ratio - ratio_bounds(:,1)', ratio_bounds(:,2)' - size_ratio, ...
    'k', 'LineStyle', 'none', 'HandleVisibility', 'off');

set(gca, 'XTick', x, 'XTickLabel', labels);
ylabel('PM10/PM2.5 Penetration Ratio');
title('Size-Dependent Penetration');
yline(1, '--k', 'Equal Penetration');
grid on;

% Dynamic penetration over time (example)
subplot(2, 2, 4);
% Show how penetration varies over time for first config
config = configs{1};
data = penetrationAnalysis.(config);
if isfield(data, 'hourly_penetration_pm25')
    t = 1:min(168, length(data.hourly_penetration_pm25)); % First week
    plot(t, data.hourly_penetration_pm25(t), 'b-', 'LineWidth', 1.5);
    hold on;
    plot(t, data.hourly_penetration_pm10(t), 'r-', 'LineWidth', 1.5);
    xlabel('Hour');
    ylabel('Penetration Factor');
    title(sprintf('Temporal Variation - %s', config));
    legend({'PM2.5', 'PM10'}, 'Location', 'best');
    grid on;
end

sgtitle('Particle Penetration Analysis - Active Mode', 'FontSize', 14, 'FontWeight', 'bold');
save_figure(gcf, saveDir, 'penetration_analysis.png');
close(gcf);
end