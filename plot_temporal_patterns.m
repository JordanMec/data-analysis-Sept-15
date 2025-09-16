function plot_temporal_patterns(temporalAnalysis, saveDir)
%PLOT_TEMPORAL_PATTERNS Visualize diurnal and longer-term trends in I/O ratios
%   plot_temporal_patterns(temporalAnalysis, saveDir) creates several figures
%   describing temporal behavior of filtration performance in active mode.

if isempty(fieldnames(temporalAnalysis))
    warning('plot_temporal_patterns: no data provided, skipping plot.');
    return;
end

fig = figure('Visible', 'off');
set_figure_fullscreen(fig);

configs = fieldnames(temporalAnalysis);

% Diurnal patterns
subplot(2, 2, 1);
hold on;
colors = lines(length(configs));
diurnalHandles = [];
diurnalLabels = {};

for i = 1:length(configs)
    config = configs{i};
    data = temporalAnalysis.(config);
    if isfield(data, 'diurnal_io_ratio')
        if isfield(data, 'diurnal_io_ratio_lower')
            fill([0:23 fliplr(0:23)], ...
                 [data.diurnal_io_ratio_lower' fliplr(data.diurnal_io_ratio_upper')], ...
                 colors(i,:), 'FaceAlpha',0.2,'EdgeColor','none');
        end
        h = plot(0:23, data.diurnal_io_ratio, 'o-', 'Color', colors(i,:), ...
            'LineWidth', 2, 'MarkerSize', 6);
        diurnalHandles(end+1) = h; %#ok<AGROW>
        diurnalLabels{end+1} = strrep(config, '_', ' '); %#ok<AGROW>
    end
end

xlabel('Hour of Day');
ylabel('Average I/O Ratio');
title('Diurnal Variation in Filtration Performance');
if ~isempty(diurnalHandles)
    legend(diurnalHandles, diurnalLabels, 'Location', 'best');
else
    legend(strrep(configs, '_', ' '), 'Location', 'best');
end
grid on;
xlim([-0.5 23.5]);

% Temporal stability
subplot(2, 2, 2);
stability_scores = [];
stab_lower = [];
stab_upper = [];
labels = {};

for i = 1:length(configs)
    config = configs{i};
    data = temporalAnalysis.(config);
    if isfield(data, 'stability_score')
        stability_scores(i) = data.stability_score;
        if isfield(data, 'stability_score_lower')
            stab_lower(i) = data.stability_score_lower;
            stab_upper(i) = data.stability_score_upper;
        else
            stab_lower(i) = NaN; stab_upper(i) = NaN;
        end
        % Use single-line labels combining location and filter type
        % to avoid issues where newline characters create separate
        % tick marks on some rendering backends.
        labels{i} = sprintf('%s - %s Filter', ...
            strrep(data.location, '_', ' '), upper(data.filterType));
    end
end

bar(stability_scores, 'FaceColor', [0.4 0.6 0.8]);
hold on;
if any(~isnan(stab_lower))
    errorbar(1:length(stability_scores), stability_scores, ...
        stability_scores - stab_lower, stab_upper - stability_scores, 'k.', 'LineStyle','none');
end
set(gca, 'XTick', 1:length(labels), 'XTickLabel', labels);
ylabel('Stability Score');
title('Filtration Performance Stability Over Time');
grid on;

% Performance degradation over time
subplot(2, 2, [3 4]);
hold on;

lineHandles = [];
legendLabels = {};
for i = 1:length(configs)
    config = configs{i};
    data = temporalAnalysis.(config);
    if isfield(data, 'performance_trend') && ~isempty(data.performance_trend)
        days = 1:length(data.performance_trend);
        if isfield(data, 'performance_trend_lower')
            fill([days fliplr(days)], ...
                 [data.performance_trend_lower fliplr(data.performance_trend_upper)], ...
                 colors(i,:), 'FaceAlpha',0.2,'EdgeColor','none');
        elseif isfield(data, 'performance_trend_tight')
            lowerVals = min(data.performance_trend_tight, data.performance_trend_leaky);
            upperVals = max(data.performance_trend_tight, data.performance_trend_leaky);
            fill([days fliplr(days)], [lowerVals fliplr(upperVals)], ...
                 colors(i,:), 'FaceAlpha',0.2,'EdgeColor','none');
        end
        h = plot(days, data.performance_trend, 'o-', 'Color', colors(i,:), ...
                 'LineWidth', 1.5, 'MarkerSize', 4);
        lineHandles(end+1) = h; %#ok<AGROW>
        legendLabels{end+1} = strrep(config, '_', ' '); %#ok<AGROW>
    end
end

xlabel('Day');
ylabel('Daily Average I/O Ratio');
title('Filtration Performance Trend Over Time');
if ~isempty(lineHandles)
    legend(lineHandles, legendLabels, 'Location', 'best');
else
    legend(strrep(configs, '_', ' '), 'Location', 'best');
end
grid on;

sgtitle('Temporal Patterns in Active Mode Filtration Performance', 'FontSize', 14, 'FontWeight', 'bold');
save_figure(fig, saveDir, 'temporal_patterns.png');
close(fig);
end