function plot_filter_life_envelope(summaryTable, figuresDir)
% PLOT_FILTER_LIFE_ENVELOPE Show filter life degradation with envelope bounds

% Get intervention configurations only
data = summaryTable(~strcmp(summaryTable.mode,'baseline'), :);
configs = unique(data(:, {'location','filterType','mode'}));

% Validate we have data
validConfigs = [];
for i = 1:height(configs)
    tightRow = data(strcmp(data.location, configs.location{i}) & ...
        strcmp(data.filterType, configs.filterType{i}) & ...
        strcmp(data.mode, configs.mode{i}) & ...
        strcmp(data.leakage, 'tight'), :);
    leakyRow = data(strcmp(data.location, configs.location{i}) & ...
        strcmp(data.filterType, configs.filterType{i}) & ...
        strcmp(data.mode, configs.mode{i}) & ...
        strcmp(data.leakage, 'leaky'), :);

    if ~isempty(tightRow) && ~isempty(leakyRow) && ...
            ~isempty(tightRow.filter_life_series{1}) && ~isempty(leakyRow.filter_life_series{1})
        validConfigs(end+1) = i;
    end
end

if isempty(validConfigs)
    warning('No valid filter life data found');
    return;
end

configs = configs(validConfigs, :);
nConfigs = height(configs);

% Create figure with appropriate layout
nCols = min(3, nConfigs);
nRows = ceil(nConfigs / nCols);

fig = figure('Visible', 'off');
set_figure_fullscreen(fig);
tiledlayout(nRows, nCols, 'TileSpacing', 'compact', 'Padding', 'compact');

% Process each configuration
for i = 1:nConfigs
    loc = configs.location{i};
    filt = configs.filterType{i};
    mode = configs.mode{i};

    % Get tight and leaky data
    tightRow = data(strcmp(data.location, loc) & ...
        strcmp(data.filterType, filt) & ...
        strcmp(data.mode, mode) & ...
        strcmp(data.leakage, 'tight'), :);
    leakyRow = data(strcmp(data.location, loc) & ...
        strcmp(data.filterType, filt) & ...
        strcmp(data.mode, mode) & ...
        strcmp(data.leakage, 'leaky'), :);

    seriesT = tightRow.filter_life_series{1};
    seriesL = leakyRow.filter_life_series{1};

    % Compute replacement statistics before any padding adjustments
    avgLifeT = compute_replacement_interval_local(seriesT);
    avgLifeL = compute_replacement_interval_local(seriesL);

    % Ensure consistent orientation for vector operations
    seriesT = seriesT(:)';
    seriesL = seriesL(:)';

    % Ensure same length
    maxLen = max(length(seriesT), length(seriesL));
    if length(seriesT) < maxLen
        seriesT(end+1:maxLen) = seriesT(end);
    end
    if length(seriesL) < maxLen
        seriesL(end+1:maxLen) = seriesL(end);
    end

    t = 1:maxLen;

    nexttile;
    hold on;

    % Calculate envelope
    lower = min(seriesT, seriesL);
    upper = max(seriesT, seriesL);

    % Ensure row vectors for area fill operation
    lower = lower(:)';
    upper = upper(:)';
    mean_life = (seriesT + seriesL) / 2;

    % Plot envelope as shaded area
    fill([t fliplr(t)], [lower fliplr(upper)], [0.7 0.7 0.9], ...
        'FaceAlpha', 0.5, 'EdgeColor', 'none');

    % Plot mean line
    plot(t, mean_life, 'b-', 'LineWidth', 2);

    % Plot bounds
    plot(t, lower, 'b--', 'LineWidth', 1);
    plot(t, upper, 'b--', 'LineWidth', 1);

    % Find and mark replacement points
    replaceT = find(diff(seriesT) > 0);
    replaceL = find(diff(seriesL) > 0);

    if ~isempty(replaceT)
        plot(replaceT, ones(size(replaceT))*100, 'r^', 'MarkerSize', 8, 'MarkerFaceColor', 'r');
    end
    if ~isempty(replaceL)
        plot(replaceL, ones(size(replaceL))*100, 'ro', 'MarkerSize', 8, 'MarkerFaceColor', 'r');
    end

    % Calculate key statistics using available replacement data
    avgValues = [avgLifeT, avgLifeL];
    validMask = ~isnan(avgValues);

    if any(validMask)
        avgLife = mean(avgValues(validMask));
        if sum(validMask) == 2
            rangeHalf = abs(avgLifeT - avgLifeL) / 2;
            statsText = sprintf('Avg replacement: %.0f hrs\nRange: ±%.0f hrs', ...
                avgLife, rangeHalf);
        else
            statsText = sprintf('Avg replacement: %.0f hrs\nRange: n/a', avgLife);
        end
    else
        statsText = 'Avg replacement: n/a\nRange: n/a';
    end

    % Formatting
    ylim([0 105]);
    xlabel('Simulation Time (Hours)');
    ylabel('Remaining Filter Life (Percent)');
    title(sprintf('Filter Life Envelope for %s %s %s', ...
        strrep(loc,'_',' '), strrep(filt,'_',' '), strrep(mode,'_',' ')), ...
        'Interpreter', 'none');
    grid on;

    % Add statistics box
    text(0.02, 0.98, statsText, ...
        'Units', 'normalized', 'VerticalAlignment', 'top', ...
        'BackgroundColor', 'w', 'EdgeColor', 'k', 'FontSize', 8);

    % Legend for first plot only
    if i == 1
        legend({'Envelope', 'Mean', 'Bounds', 'Replacements'}, ...
            'Location', 'southwest');
    end
end

% Add overall title
sgtitle('Filter Life Degradation Across Building Envelope Bounds', ...
    'FontSize', 14, 'FontWeight', 'bold');

% Add general note
annotation('textbox', [0.02 0.02 0.96 0.03], ...
    'String', 'Shaded regions show the range of filter life between tight and leaky building envelopes. Triangles/circles indicate filter replacements.', ...
    'FontSize', 9, 'FontAngle', 'italic', 'LineStyle', 'none', ...
    'HorizontalAlignment', 'center');

add_figure_caption(fig, sprintf(['Each panel shows how remaining filter life evolves for tight and leaky envelopes, with shaded bands capturing the full range and symbols marking replacement events.' newline ...
    'The statistics box summarizes the average replacement interval and its variability so maintenance planning is straightforward.' newline ...
    'Comparing panels reveals which locations and modes experience rapid filter depletion versus those that hold steady.']));
save_figure(fig, figuresDir, 'filter_life_envelope_bounds.png');
close(fig);
end

function hours = compute_replacement_interval_local(series)
%COMPUTE_REPLACEMENT_INTERVAL_LOCAL Estimate average hours between filter changes
%   This local helper mirrors the preprocessing logic while tolerating empty
%   or NaN-only series so the statistics box can display informative values.

if isempty(series)
    hours = NaN;
    return;
end

series = series(:);
series = series(isfinite(series));

if isempty(series)
    hours = NaN;
    return;
end

resetIdx = find(diff(series) > 0);
if isempty(resetIdx)
    hours = NaN;
else
    intervalBoundaries = [0; resetIdx(:); numel(series)];
    intervals = diff(intervalBoundaries);
    hours = mean(intervals);
end
end
