function plot_penetration_analysis(penetrationAnalysis, saveDir)
%PLOT_PENETRATION_ANALYSIS Visualize particle penetration factors and removal efficiency
%   plot_penetration_analysis(penetrationAnalysis, saveDir) creates plots of
%   penetration factors for PM2.5 and PM10 along with removal efficiency and
%   size-dependent behavior. Results are saved to the specified directory.

if isempty(fieldnames(penetrationAnalysis))
    warning('plot_penetration_analysis: no data provided, skipping plot.');
    return;
end

fig = figure('Visible', 'off');
set_figure_fullscreen(fig);

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
ylabel('Particle Penetration Factor');
legend([hPM25 hPM10], {'PM2.5', 'PM10'}, 'Location', 'best');
title('Particle Penetration Factors by Configuration');
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
ylabel('Removal Efficiency (Percent)');
legend([hR25 hR10], {'PM2.5', 'PM10'}, 'Location', 'best');
title('Particle Removal Efficiency by Configuration');
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
ylabel('Particulate Matter 10 to Particulate Matter 2.5 Penetration Ratio');
title('Size Dependent Penetration Ratio');
yline(1, '--k', 'Equal Penetration');
grid on;

% Dynamic penetration over time (example)
subplot(2, 2, 4);
% Show how penetration varies over time for first config
config = configs{1};
data = penetrationAnalysis.(config);
if isfield(data, 'hourly_penetration_pm25')
    t = 1:min(168, length(data.hourly_penetration_pm25)); % First week
    hold on;
    if isfield(data, 'hourly_penetration_pm25_bounds')
        bounds25 = data.hourly_penetration_pm25_bounds(:, 1:length(data.hourly_penetration_pm25));
        tight25 = bounds25(1, t);
        leaky25 = bounds25(2, t);
        valid25 = isfinite(tight25) & isfinite(leaky25);
        fill([t(valid25) fliplr(t(valid25))], [tight25(valid25) fliplr(leaky25(valid25))], ...
            [0.2 0.4 0.8], 'FaceAlpha', 0.2, 'EdgeColor', 'none');
    end
    if isfield(data, 'hourly_penetration_pm10_bounds')
        bounds10 = data.hourly_penetration_pm10_bounds(:, 1:length(data.hourly_penetration_pm10));
        tight10 = bounds10(1, t);
        leaky10 = bounds10(2, t);
        valid10 = isfinite(tight10) & isfinite(leaky10);
        fill([t(valid10) fliplr(t(valid10))], [tight10(valid10) fliplr(leaky10(valid10))], ...
            [0.8 0.3 0.3], 'FaceAlpha', 0.2, 'EdgeColor', 'none');
    end
    plot(t, data.hourly_penetration_pm25(t), 'b-', 'LineWidth', 1.5);
    plot(t, data.hourly_penetration_pm10(t), 'r-', 'LineWidth', 1.5);
    xlabel('Time in Hours');
    ylabel('Particle Penetration Factor');
    title(sprintf('Penetration Temporal Variation for %s', strrep(config, '_', ' ')));
    legend({'PM2.5 Bounds', 'PM10 Bounds', 'PM2.5 Mean', 'PM10 Mean'}, 'Location', 'best');
    grid on;
end

sgtitle('Particle Penetration Analysis During Active Mode', 'FontSize', 14, 'FontWeight', 'bold');
add_figure_caption(fig, sprintf(['Panels in this figure contrast penetration behavior for PM2.5 and PM10 so the impact of envelope tightness is easy to see.' newline ...
    'Bars with error ranges summarize average factors and removal efficiencies, the ratio plot checks whether coarse particles bypass filters more readily, and the time-series panel shows how penetration evolves with envelope bounds shaded in.' newline ...
    'Reading across the layout reveals which configurations keep pollutants out consistently and when leakage risk grows over time.']));
save_figure(fig, saveDir, 'penetration_analysis.png');
close(fig);
end
