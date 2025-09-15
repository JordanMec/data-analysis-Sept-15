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

fig = figure('Position', [50 50 1400 900], 'Visible', 'off');
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

    % Calculate key statistics
    avgLife = mean([tightRow.filter_replaced, leakyRow.filter_replaced]);
    rangeLife = abs(tightRow.filter_replaced - leakyRow.filter_replaced);

    % Formatting
    ylim([0 105]);
    xlabel('Hour of Simulation');
    ylabel('Filter Life (%)');
    title(sprintf('%s - %s - %s', loc, filt, mode), 'Interpreter', 'none');
    grid on;

    % Add statistics box
    text(0.02, 0.98, sprintf('Avg replacement: %.0f hrs\nRange: ±%.0f hrs', ...
        avgLife, rangeLife/2), ...
        'Units', 'normalized', 'VerticalAlignment', 'top', ...
        'BackgroundColor', 'w', 'EdgeColor', 'k', 'FontSize', 8);

    % Legend for first plot only
    if i == 1
        legend({'Envelope', 'Mean', 'Bounds', 'Replacements'}, ...
            'Location', 'southwest');
    end
end

% Add overall title
sgtitle('Filter Life Degradation: Building Envelope Bounds', ...
    'FontSize', 14, 'FontWeight', 'bold');

% Add general note
annotation('textbox', [0.02 0.02 0.96 0.03], ...
    'String', 'Shaded regions show the range of filter life between tight and leaky building envelopes. Triangles/circles indicate filter replacements.', ...
    'FontSize', 9, 'FontAngle', 'italic', 'LineStyle', 'none', ...
    'HorizontalAlignment', 'center');

save_figure(fig, figuresDir, 'filter_life_envelope_bounds.png');
close(fig);
end