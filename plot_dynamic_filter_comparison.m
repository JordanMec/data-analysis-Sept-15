function plot_dynamic_filter_comparison(filterComparison, saveDir)
%PLOT_DYNAMIC_FILTER_COMPARISON Compare HEPA vs MERV filter performance dynamically
%   plot_dynamic_filter_comparison(filterComparison, saveDir) creates a set of
%   plots illustrating how different filter types perform under active mode.

if isempty(fieldnames(filterComparison))
    warning('plot_dynamic_filter_comparison: no data provided, skipping plot.');
    return;
end

fig = figure('Visible', 'off');
set_figure_fullscreen(fig);

locations = fieldnames(filterComparison);

for loc_idx = 1:length(locations)
    location = locations{loc_idx};
    data = filterComparison.(location);

    % Performance metrics comparison
    subplot(2, 2, loc_idx);

    metrics = {'avg_io_ratio_pm25', 'avg_io_ratio_pm10', ...
               'response_time', 'peak_reduction', 'stability_score'};
    metric_labels = {'I/O PM2.5', 'I/O PM10', 'Response (h)', ...
                    'Peak Red. (%)', 'Stability'};

    hepa_values = [];
    merv_values = [];
    hepa_low = [];
    hepa_up = [];
    merv_low = [];
    merv_up = [];

    for m = 1:length(metrics)
        if isfield(data.hepa, metrics{m})
            hepa_values(m) = data.hepa.(metrics{m});
            merv_values(m) = data.merv.(metrics{m});
            lowField = [metrics{m} '_lower'];
            upField  = [metrics{m} '_upper'];
            if isfield(data.hepa, lowField)
                hepa_low(m) = data.hepa.(lowField);
                hepa_up(m)  = data.hepa.(upField);
                merv_low(m) = data.merv.(lowField);
                merv_up(m)  = data.merv.(upField);
            else
                hepa_low(m) = NaN; hepa_up(m) = NaN;
                merv_low(m) = NaN; merv_up(m) = NaN;
            end
        else
            hepa_values(m) = NaN;
            merv_values(m) = NaN;
            hepa_low(m) = NaN; hepa_up(m) = NaN;
            merv_low(m) = NaN; merv_up(m) = NaN;
        end
    end

    % Normalize to compare on same scale
    hepa_norm = (hepa_values - nanmin([hepa_values, merv_values])) ./ ...
                (nanmax([hepa_values, merv_values]) - nanmin([hepa_values, merv_values]));
    merv_norm = (merv_values - nanmin([hepa_values, merv_values])) ./ ...
                (nanmax([hepa_values, merv_values]) - nanmin([hepa_values, merv_values]));

    x = 1:length(metrics);
    width = 0.35;

    hHepa = bar(x - width/2, hepa_norm, width, 'FaceColor', [0.2 0.4 0.8]);
    hold on;
    hMerv = bar(x + width/2, merv_norm, width, 'FaceColor', [0.8 0.3 0.3]);
    if any(~isnan(hepa_low))
        
        errorbar(x - width/2, hepa_norm, hepa_norm - ((hepa_low - nanmin([hepa_values, ...
            merv_values])) ./ (nanmax([hepa_values, merv_values]) - nanmin([hepa_values, merv_values]))),...
            ((hepa_up - nanmin([hepa_values, merv_values])) ./ (nanmax([hepa_values, merv_values]) ...
            - nanmin([hepa_values, merv_values]))) - hepa_norm, 'k.', 'LineStyle','none');

        errorbar(x + width/2, merv_norm, merv_norm - ((merv_low - nanmin([hepa_values, merv_values])) ...
            ./ (nanmax([hepa_values, merv_values]) - nanmin([hepa_values, merv_values]))),...
            ((merv_up - nanmin([hepa_values, merv_values])) ./ (nanmax([hepa_values, merv_values]) ...
            - nanmin([hepa_values, merv_values]))) - merv_norm, 'k.', 'LineStyle','none');
    end

    set(gca, 'XTick', x, 'XTickLabel', metric_labels);
    xtickangle(45);
    ylabel('Normalized Score');
    title(sprintf('Filter Comparison for %s', strrep(location, '_', ' ')));
    legend([hHepa hMerv], {'HEPA', 'MERV'}, 'Location', 'best');
    grid on;
end

% Overall comparison radar chart
subplot(2, 2, [3 4]);
plot_filter_radar_comparison(filterComparison);

sgtitle('Dynamic Filter Performance Comparison During Active Mode', 'FontSize', 14, 'FontWeight', 'bold');
add_figure_caption(fig, sprintf(['Bar charts across the top compare normalized HEPA and MERV performance metrics for each location, and the radar chart aggregates those differences across all sites.' newline ...
    'Error bars appear when uncertainty bounds are available so you can see how envelope assumptions might change the story.' newline ...
    'Together the visuals reveal whether one filter consistently leads or if strengths trade places depending on metric and location.']));
save_figure(fig, saveDir, 'filter_comparison_dynamic.png');
close(fig);
end

function plot_filter_radar_comparison(filterComparison)
%PLOT_FILTER_RADAR_COMPARISON Create a simple radar chart comparing HEPA and MERV
%   Averages metrics across all locations and normalizes them for display.

cartAx = gca;
pos = get(cartAx, 'Position');
delete(cartAx);        % replace subplot axes with custom radar axes
ax = axes('Position', pos);
hold(ax, 'on');
axis(ax, 'equal');
ax.XLim = [-1.1 1.1];
ax.YLim = [-1.1 1.1];
ax.XTick = [];
ax.YTick = [];
box(ax, 'off');

metrics = {'avg_io_ratio_pm25', 'avg_io_ratio_pm10', ...
           'response_time', 'peak_reduction', 'stability_score'};
metric_labels = {'I/O PM2.5', 'I/O PM10', 'Response', ...
                 'Peak Red.', 'Stability'};

locations = fieldnames(filterComparison);
nMetrics = numel(metrics);

% Draw radar grid
thetaFine = linspace(0, 2*pi, 360);
gridRadii = linspace(0.25, 1, 4);
for r = gridRadii
    [xCircle, yCircle] = pol2cart(thetaFine, r * ones(size(thetaFine)));
    plot(ax, xCircle, yCircle, 'Color', [0.85 0.85 0.85], 'LineStyle', '-', ...
        'HandleVisibility', 'off');
    [radialLabelX, radialLabelY] = pol2cart(pi/2, r);
    text(ax, radialLabelX, radialLabelY, sprintf('%.2f', r), ...
        'Color', [0.6 0.6 0.6], 'HorizontalAlignment', 'center', ...
        'VerticalAlignment', 'bottom', 'FontSize', 8, 'HandleVisibility', 'off');
end

thetaSpokes = linspace(0, 2*pi, nMetrics + 1);
thetaSpokes = thetaSpokes(1:end-1);
for m = 1:nMetrics
    [xSpoke, ySpoke] = pol2cart([thetaSpokes(m) thetaSpokes(m)], [0 1]);
    plot(ax, xSpoke, ySpoke, 'Color', [0.85 0.85 0.85], 'LineStyle', '-', ...
        'HandleVisibility', 'off');
    [labelX, labelY] = pol2cart(thetaSpokes(m), 1.12);
    hAlign = 'center';
    if cos(thetaSpokes(m)) > 0.1
        hAlign = 'left';
    elseif cos(thetaSpokes(m)) < -0.1
        hAlign = 'right';
    end
    vAlign = 'middle';
    if sin(thetaSpokes(m)) > 0.1
        vAlign = 'bottom';
    elseif sin(thetaSpokes(m)) < -0.1
        vAlign = 'top';
    end
    text(ax, labelX, labelY, metric_labels{m}, 'HorizontalAlignment', hAlign, ...
        'VerticalAlignment', vAlign, 'FontWeight', 'bold');
end

axis(ax, 'off');

hepa_vals = NaN(numel(locations), nMetrics);
merv_vals = NaN(numel(locations), nMetrics);
hepa_lower_vals = NaN(numel(locations), nMetrics);
hepa_upper_vals = NaN(numel(locations), nMetrics);
merv_lower_vals = NaN(numel(locations), nMetrics);
merv_upper_vals = NaN(numel(locations), nMetrics);
for i = 1:numel(locations)
    loc = locations{i};
    for m = 1:nMetrics
        if isfield(filterComparison.(loc).hepa, metrics{m})
            hepa_vals(i,m) = filterComparison.(loc).hepa.(metrics{m});
        end
        if isfield(filterComparison.(loc).merv, metrics{m})
            merv_vals(i,m) = filterComparison.(loc).merv.(metrics{m});
        end
        lowField = [metrics{m} '_lower'];
        upField  = [metrics{m} '_upper'];
        if isfield(filterComparison.(loc).hepa, lowField)
            hepa_lower_vals(i,m) = filterComparison.(loc).hepa.(lowField);
            hepa_upper_vals(i,m) = filterComparison.(loc).hepa.(upField);
        end
        if isfield(filterComparison.(loc).merv, lowField)
            merv_lower_vals(i,m) = filterComparison.(loc).merv.(lowField);
            merv_upper_vals(i,m) = filterComparison.(loc).merv.(upField);
        end
    end
end

hepa_avg = nanmean(hepa_vals,1);
merv_avg = nanmean(merv_vals,1);
hepa_lower_avg = nanmean(hepa_lower_vals,1);
hepa_upper_avg = nanmean(hepa_upper_vals,1);
merv_lower_avg = nanmean(merv_lower_vals,1);
merv_upper_avg = nanmean(merv_upper_vals,1);

maxVals = nanmax([hepa_upper_avg; merv_upper_avg; hepa_avg; merv_avg], [], 1);
maxVals(maxVals == 0) = 1;
hepa_norm = hepa_avg ./ maxVals;
merv_norm = merv_avg ./ maxVals;
hepa_lower_norm = hepa_lower_avg ./ maxVals;
hepa_upper_norm = hepa_upper_avg ./ maxVals;
merv_lower_norm = merv_lower_avg ./ maxVals;
merv_upper_norm = merv_upper_avg ./ maxVals;

theta = linspace(0, 2*pi, nMetrics + 1);
hepa_r = [hepa_norm hepa_norm(1)];
merv_r = [merv_norm merv_norm(1)];
hepa_lower_poly = [hepa_lower_norm hepa_lower_norm(1)];
hepa_upper_poly = [hepa_upper_norm hepa_upper_norm(1)];
merv_lower_poly = [merv_lower_norm merv_lower_norm(1)];
merv_upper_poly = [merv_upper_norm merv_upper_norm(1)];

if all(isfinite(hepa_lower_poly)) && all(isfinite(hepa_upper_poly))
    [hepaLowerX, hepaLowerY] = pol2cart(theta, hepa_lower_poly);
    [hepaUpperX, hepaUpperY] = pol2cart(theta, hepa_upper_poly);
    patch(ax, [hepaLowerX fliplr(hepaUpperX)], [hepaLowerY fliplr(hepaUpperY)], ...
        [0.2 0.4 0.8], 'FaceAlpha', 0.1, 'EdgeColor', 'none', 'HandleVisibility', 'off');
end
if all(isfinite(merv_lower_poly)) && all(isfinite(merv_upper_poly))
    [mervLowerX, mervLowerY] = pol2cart(theta, merv_lower_poly);
    [mervUpperX, mervUpperY] = pol2cart(theta, merv_upper_poly);
    patch(ax, [mervLowerX fliplr(mervUpperX)], [mervLowerY fliplr(mervUpperY)], ...
        [0.8 0.3 0.3], 'FaceAlpha', 0.1, 'EdgeColor', 'none', 'HandleVisibility', 'off');
end

[hepaX, hepaY] = pol2cart(theta, hepa_r);
[mervX, mervY] = pol2cart(theta, merv_r);
hPolarHepa = plot(ax, hepaX, hepaY, 'LineWidth', 2, 'Color', [0.2 0.4 0.8]);
hPolarMerv = plot(ax, mervX, mervY, 'LineWidth', 2, 'Color', [0.8 0.3 0.3]);

[hepaPointX, hepaPointY] = pol2cart(theta(1:end-1), hepa_r(1:end-1));
[mervPointX, mervPointY] = pol2cart(theta(1:end-1), merv_r(1:end-1));
scatter(ax, hepaPointX, hepaPointY, 50, [0.2 0.4 0.8], 'filled', 'HandleVisibility', 'off');
scatter(ax, mervPointX, mervPointY, 50, [0.8 0.3 0.3], 'filled', 'HandleVisibility', 'off');

hRangeHepa = patch(ax, NaN, NaN, [0.2 0.4 0.8], 'FaceAlpha', 0.1, 'EdgeColor', 'none');
hRangeMerv = patch(ax, NaN, NaN, [0.8 0.3 0.3], 'FaceAlpha', 0.1, 'EdgeColor', 'none');
legend(ax, [hPolarHepa hPolarMerv hRangeHepa hRangeMerv], ...
    {'HEPA mean', 'MERV mean', 'HEPA tight–leaky', 'MERV tight–leaky'}, ...
    'Location', 'southoutside');
title(ax, 'Filter Comparison Across Multiple Criteria');
end
