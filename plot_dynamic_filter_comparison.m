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
    title(sprintf('%s - Filter Comparison', location));
    legend([hHepa hMerv], {'HEPA', 'MERV'}, 'Location', 'best');
    grid on;
end

% Overall comparison radar chart
subplot(2, 2, [3 4]);
plot_filter_radar_comparison(filterComparison);

sgtitle('Dynamic Filter Performance Comparison - Active Mode', 'FontSize', 14, 'FontWeight', 'bold');
save_figure(fig, saveDir, 'filter_comparison_dynamic.png');
close(fig);
end

function plot_filter_radar_comparison(filterComparison)
%PLOT_FILTER_RADAR_COMPARISON Create a simple radar chart comparing HEPA and MERV
%   Averages metrics across all locations and normalizes them for display.

ax = gca;
pos = get(ax, 'Position');
delete(ax);        % replace subplot axes with polar axes
ax = polaraxes('Position', pos);
hold(ax, 'on');

metrics = {'avg_io_ratio_pm25', 'avg_io_ratio_pm10', ...
           'response_time', 'peak_reduction', 'stability_score'};
metric_labels = {'I/O PM2.5', 'I/O PM10', 'Response', ...
                 'Peak Red.', 'Stability'};

locations = fieldnames(filterComparison);
nMetrics = numel(metrics);

hepa_vals = NaN(numel(locations), nMetrics);
merv_vals = NaN(numel(locations), nMetrics);
for i = 1:numel(locations)
    loc = locations{i};
    for m = 1:nMetrics
        if isfield(filterComparison.(loc).hepa, metrics{m})
            hepa_vals(i,m) = filterComparison.(loc).hepa.(metrics{m});
        end
        if isfield(filterComparison.(loc).merv, metrics{m})
            merv_vals(i,m) = filterComparison.(loc).merv.(metrics{m});
        end
    end
end

hepa_avg = nanmean(hepa_vals,1);
merv_avg = nanmean(merv_vals,1);
maxVals = nanmax([hepa_avg; merv_avg], [], 1);
maxVals(maxVals == 0) = 1;
hepa_norm = hepa_avg ./ maxVals;
merv_norm = merv_avg ./ maxVals;

theta = linspace(0, 2*pi, nMetrics + 1);
hepa_r = [hepa_norm hepa_norm(1)];
merv_r = [merv_norm merv_norm(1)];

  hPolarHepa = polarplot(ax, theta, hepa_r, 'LineWidth', 2, 'Color', [0.2 0.4 0.8]);
  hold(ax, 'on');
  hPolarMerv = polarplot(ax, theta, merv_r, 'LineWidth', 2, 'Color', [0.8 0.3 0.3]);
  polarscatter(ax, theta, hepa_r, 50, [0.2 0.4 0.8], 'filled', 'HandleVisibility', 'off');
  polarscatter(ax, theta, merv_r, 50, [0.8 0.3 0.3], 'filled', 'HandleVisibility', 'off');

ax.ThetaTick = rad2deg(theta(1:end-1));
ax.ThetaTickLabel = metric_labels;
ax.RLim = [0 1];
  legend(ax, [hPolarHepa hPolarMerv], {'HEPA','MERV'}, 'Location', 'southoutside');
title(ax, 'Multi-Criteria Filter Comparison');
end