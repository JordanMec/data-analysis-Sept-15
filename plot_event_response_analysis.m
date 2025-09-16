function plot_event_response_analysis(eventAnalysis, saveDir)
%PLOT_EVENT_RESPONSE_ANALYSIS Visualize statistics of outdoor pollution events
%   plot_event_response_analysis(eventAnalysis, saveDir) generates a series of
%   plots summarizing detected outdoor pollution events and system response.

if isempty(fieldnames(eventAnalysis))
    warning('plot_event_response_analysis: no data provided, skipping plot.');
    return;
end

fig = figure('Visible', 'off');
set_figure_fullscreen(fig);

configs = fieldnames(eventAnalysis);
colors = get_color_palette(length(configs));

% Event statistics summary
subplot(2, 3, 1);
event_counts = [];
avg_durations = [];
count_bounds = [];
duration_bounds = [];
labels = {};

for i = 1:length(configs)
    config = configs{i};
    data = eventAnalysis.(config);
    event_counts(i) = data.total_events;
    avg_durations(i) = data.avg_event_duration;
    if isfield(data, 'total_events_bounds')
        count_bounds(i,:) = data.total_events_bounds;
    else
        count_bounds(i,:) = [NaN NaN];
    end
    if isfield(data, 'avg_event_duration_bounds')
        duration_bounds(i,:) = data.avg_event_duration_bounds;
    else
        duration_bounds(i,:) = [NaN NaN];
    end
    labels{i} = strrep(config, '_', ' ');
end

positions = 1:length(configs);
offset = 0.2;

yyaxis left;
b1 = bar(positions - offset, event_counts, 0.4, 'FaceColor','flat');
b1.CData = colors;
hold on;
errorbar(positions - offset, event_counts, event_counts - count_bounds(:,1)', count_bounds(:,2)' - event_counts, 'k', 'LineStyle','none');
ylabel('Number of Events');

yyaxis right;
b2 = bar(positions + offset, avg_durations, 0.4, 'FaceColor','flat');
b2.CData = colors;
hold on;
errorbar(positions + offset, avg_durations, avg_durations - duration_bounds(:,1)', duration_bounds(:,2)' - avg_durations, 'k', 'LineStyle','none');
ylabel('Avg Duration (hours)');

text(0.02,0.98,'Error bars show tight/leaky bounds', 'Units','normalized', ...
    'VerticalAlignment','top','FontSize',8,'FontAngle','italic');

set(gca, 'XTick', 1:length(configs), 'XTickLabel', labels);
xtickangle(45);
title('Pollution Event Statistics');
grid on;


% Response effectiveness scatter
subplot(2, 3, 2);
colors = lines(length(configs));

hold on;
for i = 1:length(configs)
    config = configs{i};
    data = eventAnalysis.(config);

    % Choose marker by filter type to visually differentiate
    if strcmpi(data.filterType, 'HEPA')
        marker = 'o';
    else
        marker = 's';
    end

    if isfield(data, 'pm25_response')
        resp = data.pm25_response;
        % Combine tight and leaky event metrics
        if isfield(resp, 'peak_reductions_tight') && isfield(resp, 'peak_reductions_leaky') && ...
           isfield(resp, 'integrated_reductions_tight') && isfield(resp, 'integrated_reductions_leaky')
            xVals = [resp.peak_reductions_tight(:); resp.peak_reductions_leaky(:)];
            yVals = [resp.integrated_reductions_tight(:); resp.integrated_reductions_leaky(:)];
        else
            % Fall back to average metrics if per-event data unavailable
            if isfield(resp, 'avg_peak_reduction') && isfield(resp, 'avg_integrated_reduction')
                xVals = resp.avg_peak_reduction;
                yVals = resp.avg_integrated_reduction;
            else
                xVals = [];
                yVals = [];
            end
        end

        mask = isfinite(xVals) & isfinite(yVals);
        if any(mask)
            scatter(xVals(mask), yVals(mask), 60, 'Marker', marker, ...
                'MarkerFaceColor', colors(i,:), 'MarkerEdgeColor', 'k', ...
                'DisplayName', labels{i});
        end
    end
end

xlabel('Peak Reduction (%)');
ylabel('Integrated Reduction (%)');
title('Event Response Effectiveness');
grid on;
legend('Location','best');

% Add diagonal reference line
lims = [0 100];
plot(lims, lims, 'k--', 'LineWidth', 0.5, 'HandleVisibility','off');

% Event severity distribution
subplot(2, 3, 3);
hold on;
colors = lines(2); % 1=tight, 2=leaky
offset = 0.2;

for i = 1:length(configs)
    config = configs{i};
    data = eventAnalysis.(config);
    if isfield(data, 'event_severities_tight') && ~isempty(data.event_severities_tight)
        boxchart(ones(numel(data.event_severities_tight),1)*(i-offset), ...
            data.event_severities_tight(:), 'BoxWidth',0.3, ...
            'BoxFaceColor', colors(1,:), 'MarkerStyle','.');
    end
    if isfield(data, 'event_severities_leaky') && ~isempty(data.event_severities_leaky)
        boxchart(ones(numel(data.event_severities_leaky),1)*(i+offset), ...
            data.event_severities_leaky(:), 'BoxWidth',0.3, ...
            'BoxFaceColor', colors(2,:), 'MarkerStyle','.');
    end
end

xlim([0 length(configs)+1]);
set(gca, 'XTick', 1:length(configs), 'XTickLabel', labels);
xtickangle(45);
ylabel('Peak/Baseline Ratio');
title('Distribution of Event Severities');
legend({'Tight','Leaky'}, 'Location', 'best');
grid on;

% Example event response curves
subplot(2, 3, [4 6]);
% Plot example responses for most severe events
plot_example_event_responses(eventAnalysis);

sgtitle('Pollution Event Response Analysis - Active Mode', 'FontSize', 14, 'FontWeight', 'bold');
save_figure(fig, saveDir, 'event_response_analysis.png');
close(fig);
end

function plot_example_event_responses(eventAnalysis)
%PLOT_EXAMPLE_EVENT_RESPONSES Visualize individual event metrics
%   Displays peak reduction range for each detected event. If tight and
%   leaky values are available both are drawn, otherwise the single series
%   of peak reductions is shown.

configs = fieldnames(eventAnalysis);
nConfigs = numel(configs);
colors = lines(nConfigs);
hold on;

legendHandles = gobjects(nConfigs,1); % track series for legend

offsets = linspace(-0.3, 0.3, nConfigs);
maxEvents = 0;

for i = 1:nConfigs
    config = configs{i};
    if ~isfield(eventAnalysis.(config), 'pm25_response')
        continue;
    end
    resp = eventAnalysis.(config).pm25_response;

    % Determine number of events based on available fields
    if isfield(resp, 'peak_reductions_tight') && isfield(resp, 'peak_reductions_leaky')
        nEv = min(numel(resp.peak_reductions_tight), numel(resp.peak_reductions_leaky));
    elseif isfield(resp, 'peak_reductions')
        nEv = numel(resp.peak_reductions);
    else
        nEv = 0;
    end

    maxEvents = max(maxEvents, nEv);

    xSeries = NaN(1,nEv);
    ySeries = NaN(1,nEv);
    for j = 1:nEv
        x = j + offsets(i);
        if isfield(resp, 'peak_reductions_tight') && isfield(resp, 'peak_reductions_leaky')
            yVals = sort([resp.peak_reductions_tight(j), resp.peak_reductions_leaky(j)]);
            plot([x x], yVals, '-', 'Color', colors(i,:), 'LineWidth', 1.5);
            scatter([x x], yVals, 20, 'filled', 'MarkerFaceColor', colors(i,:), 'MarkerEdgeColor', 'k');
            ySeries(j) = mean(yVals);
        else
            yVal = resp.peak_reductions(j);
            scatter(x, yVal, 30, 'filled', 'MarkerFaceColor', colors(i,:), 'MarkerEdgeColor', 'k');
            ySeries(j) = yVal;
        end
        xSeries(j) = x;
    end
    plot(xSeries, ySeries, '-', 'Color', colors(i,:), 'LineWidth', 1, 'HandleVisibility', 'off');
    legendHandles(i) = scatter(NaN, NaN, 30, 'filled', 'MarkerFaceColor', colors(i,:), 'MarkerEdgeColor', 'k');
end

xlabel('Event Index');
ylabel('Peak Reduction (%)');
title('Event Response Metrics by Event');
% Filter out any invalid handles in case some configs lacked data
valid = isgraphics(legendHandles);
if any(valid)
    legend(legendHandles(valid), strrep(configs(valid),'_',' '), 'Location','best');
end
grid on;
xlim([0 maxEvents + 1]);
end