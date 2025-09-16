function plot_filter_replacement(tradeoffTable, figuresDir)
% PLOT_FILTER_REPLACEMENT Show filter replacement frequency with scenario bounds

if isempty(tradeoffTable)
    warning('plot_filter_replacement: no data provided, skipping plot.');
    return;
end

% Check if the tradeoffTable has the expected bounds columns
if ~ismember('replacements_per_year_lower', tradeoffTable.Properties.VariableNames)
    warning('Bounds columns not found in tradeoffTable. Using estimated bounds.');
    useEstimatedBounds = true;
else
    useEstimatedBounds = false;
end

% Get unique filter types and modes
filters = unique(tradeoffTable.filterType);
modes = unique(tradeoffTable.mode);

% Prepare data
nFilters = length(filters);
nModes = length(modes);
meanReplacements = zeros(nModes, nFilters);
lowerBounds = zeros(nModes, nFilters);
upperBounds = zeros(nModes, nFilters);

for m = 1:nModes
    for f = 1:nFilters
        % Get all locations for this filter/mode
        mask = strcmp(tradeoffTable.filterType, filters{f}) & ...
            strcmp(tradeoffTable.mode, modes{m});
        rows = tradeoffTable(mask, :);

        if isempty(rows)
            meanReplacements(m, f) = NaN;
            lowerBounds(m, f) = NaN;
            upperBounds(m, f) = NaN;
            continue;
        end

        % Average across locations
        meanReplacements(m, f) = mean(rows.estimated_replacements_per_year, 'omitnan');

        if useEstimatedBounds
            % Estimate bounds based on typical variation
            lowerBounds(m, f) = meanReplacements(m, f) * 0.8;
            upperBounds(m, f) = meanReplacements(m, f) * 1.2;
        else
            lowerBounds(m, f) = mean(rows.replacements_per_year_lower, 'omitnan');
            upperBounds(m, f) = mean(rows.replacements_per_year_upper, 'omitnan');
        end
    end
end

% Create figure
fig = figure('Visible', 'off');
set_figure_fullscreen(fig);

% Main plot - grouped bars with error bars
subplot(1, 2, 1);
hold on;

x = 1:nModes;
width = 0.35;
colors = [0.2 0.4 0.8; 0.8 0.3 0.3]; % Blue for HEPA, Red for MERV

for f = 1:nFilters
    offset = (f - 1.5) * width;

    % Plot bars
    bar(x + offset, meanReplacements(:, f), width, 'FaceColor', colors(f, :));

    % Add error bars
    errorLow = meanReplacements(:, f) - lowerBounds(:, f);
    errorHigh = upperBounds(:, f) - meanReplacements(:, f);
    errorbar(x + offset, meanReplacements(:, f), errorLow, errorHigh, ...
        'k', 'LineStyle', 'none', 'LineWidth', 1.5);

    % Add value labels
    for m = 1:nModes
        if ~isnan(meanReplacements(m, f))
            text(m + offset, upperBounds(m, f) + 0.05, ...
                sprintf('%.1f', meanReplacements(m, f)), ...
                'HorizontalAlignment', 'center', 'FontSize', 9);
        end
    end
end

set(gca, 'XTick', x, 'XTickLabel', modes);
ylabel('Filter Replacements per Year');
title('Annual Filter Replacement Frequency');
legend(filters, 'Location', 'northwest');
grid on;
% Determine y-axis limits while safely handling missing data
maxUpper = max(upperBounds(:), [], 'omitnan');
if isnan(maxUpper)
    % Fallback to mean values if bounds are completely missing
    maxUpper = max(meanReplacements(:), [], 'omitnan');
end
if isnan(maxUpper) || maxUpper <= 0
    maxUpper = 1; % sensible default to prevent ylim errors
end
ylim([0 maxUpper * 1.1]);

% Side plot - Range comparison
subplot(1, 2, 2);
hold on;

% Calculate relative range
relativeRange = zeros(nModes, nFilters);
for m = 1:nModes
    for f = 1:nFilters
        if meanReplacements(m, f) > 0
            range = upperBounds(m, f) - lowerBounds(m, f);
            relativeRange(m, f) = 100 * range / meanReplacements(m, f);
        end
    end
end

% Plot relative range
bar(relativeRange', 'grouped');
set(gca, 'XTick', 1:nFilters, 'XTickLabel', filters);
ylabel('Relative Range (%)');
title('Replacement Frequency Range');
legend(modes, 'Location', 'best');
grid on;

% Add explanation
text(0.5, -0.15, 'Wider range indicates greater sensitivity to building envelope', ...
    'Units', 'normalized', 'HorizontalAlignment', 'center', ...
    'FontSize', 9, 'FontAngle', 'italic');

% Overall title
sgtitle('Filter Replacement Analysis with Building Envelope Bounds', ...
    'FontSize', 14, 'FontWeight', 'bold');

save_figure(fig, figuresDir, 'filter_replacement_with_bounds.png');
close(fig);
end