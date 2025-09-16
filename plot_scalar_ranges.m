function plot_scalar_ranges(rangeTable, metricName, figuresDir, categories, colorMap, summaryTable)
% PLOT_SCALAR_RANGES  Plot mean values with tight/leaky ranges as error bars.
%   rangeTable   : table produced by build_range_table
%   metricName   : name of metric to visualize
%   figuresDir   : folder to save output PNG
%   categories   : (optional) cell array specifying global category order
%   colorMap     : (optional) Nx3 array of RGB colors matching categories
%   summaryTable : (optional) table with raw scenario data for derived metrics

if nargin < 6
    summaryTable = [];
end

rows = rangeTable(strcmp(rangeTable.metric, metricName), :);
if isempty(rows)
    warning('Metric %s not found in rangeTable.', metricName);
    return;
end

% Create combined category labels for current metric
cats = strcat(strrep(rows.location,'_','-'), "-", ...
             strrep(rows.filterType,'_','-'), "-", ...
             strrep(rows.mode,'_','-'));

% Determine plotting order based on provided global categories
if nargin >= 4 && ~isempty(categories)
    [~, idx] = ismember(cats, categories);
    valid = idx > 0;
    cats = cats(valid);
    rows = rows(valid, :);
    idx = idx(valid);
    [~, sortIdx] = sort(idx);
    rows = rows(sortIdx, :);
    cats = cats(sortIdx);
    idx = idx(sortIdx);
    if nargin < 5 || isempty(colorMap)
        colorMap = get_color_palette(numel(categories));
    end
    colors = colorMap(idx, :);
else
    % Sort rows to maintain consistent order across metrics
    rows = sortrows(rows, {'location','filterType','mode'});
    colors = get_color_palette(height(rows));
end

if nargin < 3 || isempty(figuresDir)
    figuresDir = fullfile(pwd, 'figures');
end
if ~exist(figuresDir, 'dir')
    mkdir(figuresDir);
end

fig = figure('Visible','off');
set_figure_fullscreen(fig);
hold on;

% Determine default plotting values
values = rows.mean;
lowerBounds = rows.lower_bound;
upperBounds = rows.upper_bound;
noteText = '';

switch lower(metricName)
    case 'avg_indoor_pm25'
        yLabelText = 'Average Indoor Particulate Matter 2.5 Concentration (Micrograms per Cubic Meter)';
        titleText = 'Range of Average Indoor Particulate Matter 2.5 Concentration Across Tight and Leaky Envelopes';
    case 'avg_indoor_pm10'
        yLabelText = 'Average Indoor Particulate Matter 10 Concentration (Micrograms per Cubic Meter)';
        titleText = 'Range of Average Indoor Particulate Matter 10 Concentration Across Tight and Leaky Envelopes';
    case 'total_cost'
        yLabelText = 'Total Operational Cost (Dollars)';
        titleText = 'Total Operational Cost Range Across Tight and Leaky Envelopes';
    otherwise
        yLabelText = strrep(metricName, '_', ' ');
        titleText = sprintf('Range for %s Across Tight and Leaky Envelopes', strrep(metricName, '_', ' '));
end

if strcmp(metricName, 'filter_replaced')
    hoursPerYear = 8760; % Consistent assumption used throughout reports
    hasEventData = ~isempty(summaryTable) && ...
        all(ismember({'filter_replacement_events','filter_runtime_hours','leakage'}, ...
        summaryTable.Properties.VariableNames));

    tightRates = nan(height(rows),1);
    leakyRates = nan(height(rows),1);

    for i = 1:height(rows)
        loc = rows.location{i};
        filt = rows.filterType{i};
        mode = rows.mode{i};

        if hasEventData
            tightRow = summaryTable(strcmp(summaryTable.location, loc) & ...
                strcmp(summaryTable.filterType, filt) & ...
                strcmp(summaryTable.mode, mode) & ...
                strcmp(summaryTable.leakage, 'tight'), :);
            leakyRow = summaryTable(strcmp(summaryTable.location, loc) & ...
                strcmp(summaryTable.filterType, filt) & ...
                strcmp(summaryTable.mode, mode) & ...
                strcmp(summaryTable.leakage, 'leaky'), :);
        else
            tightRow = table();
            leakyRow = table();
        end

        tightRates(i) = compute_replacement_rate_from_row(tightRow, ...
            rows.tight_value(i), hoursPerYear);
        leakyRates(i) = compute_replacement_rate_from_row(leakyRow, ...
            rows.leaky_value(i), hoursPerYear);
    end

    rateMatrix = [tightRates, leakyRates];
    values = mean(rateMatrix, 2, 'omitnan');
    lowerBounds = min(rateMatrix, [], 2, 'omitnan');
    upperBounds = max(rateMatrix, [], 2, 'omitnan');

    % Replace remaining NaNs with zeros so every scenario appears in the chart
    missingMask = isnan(values) | isnan(lowerBounds) | isnan(upperBounds);
    values(missingMask) = 0;
    lowerBounds(missingMask) = 0;
    upperBounds(missingMask) = 0;

    yLabelText = 'Filter Replacements per Year';
    titleText = 'Filter Replacement Frequency Range Across Tight and Leaky Envelopes';
    noteText = 'Derived from simulated replacement events; 0 indicates no replacements observed.';
end

% Plot bars representing the derived values
b = bar(1:height(rows), values, 'FaceColor','flat');
b.CData = colors;

% Overlay error bars showing tight/leaky range
errorbar(1:height(rows), values, ...
    values - lowerBounds, upperBounds - values, ...
    'k', 'LineStyle','none', 'LineWidth',1.5, 'CapSize',8);
xticks(1:height(rows));
xticklabels(cats);
xtickangle(45);
ylabel(yLabelText, 'Interpreter','none');
title(titleText, 'Interpreter','none');
grid on;

if strcmp(metricName, 'filter_replaced')
    maxUpper = max(upperBounds, [], 'omitnan');
    if isempty(maxUpper) || isnan(maxUpper) || maxUpper <= 0
        ylim([0 1]);
    else
        ylim([0 maxUpper * 1.1]);
    end

    if ~isempty(noteText)
        annotation('textbox', [0 0 1 0.04], 'String', noteText, ...
            'Units', 'normalized', 'HorizontalAlignment', 'center', ...
            'VerticalAlignment', 'bottom', 'EdgeColor', 'none', ...
            'Interpreter', 'none', 'FontAngle', 'italic');
    end
end

fname = sprintf('%s_range.png', metricName);
add_figure_caption(fig, sprintf(['Bars show the average %s for each location-filter-mode combination, and the whiskers span outcomes between tight and leaky envelopes.' newline ...
    'Color coding keeps scenarios consistent across metrics, and any italic note under the figure explains how zero or derived values were handled.' newline ...
    'The layout makes it easy to compare which setups have the widest envelope-induced spread and which remain tightly clustered.'], strrep(metricName, '_', ' ')));
save_figure(fig, figuresDir, fname);
close(fig);
end

function rate = compute_replacement_rate_from_row(row, fallbackHours, hoursPerYear)
%COMPUTE_REPLACEMENT_RATE_FROM_ROW Convert raw replacement stats to per-year rate.

rate = NaN;

if ~isempty(row)
    events = row.filter_replacement_events;
    runtime = row.filter_runtime_hours;
    if ~isempty(events)
        events = events(1);
    end
    if ~isempty(runtime)
        runtime = runtime(1);
    end

    if ~isnan(events) && ~isnan(runtime) && runtime > 0
        yearsSimulated = runtime / hoursPerYear;
        if yearsSimulated > 0
            rate = events / yearsSimulated;
        end
    end

    if isnan(rate)
        hoursBetween = row.filter_replaced;
        if ~isempty(hoursBetween)
            hoursBetween = hoursBetween(1);
        end
        if ~isnan(hoursBetween) && hoursBetween > 0
            rate = hoursPerYear / hoursBetween;
        end
    end
end

% Fall back to using the values already stored in the range table when the
% summary table lacks the enhanced event data (e.g., legacy results).
if isnan(rate)
    rate = convert_hours_to_rate(fallbackHours, hoursPerYear);
end

% Ensure the rate is non-negative even if numerical noise creeps in
if isnan(rate)
    rate = NaN;
elseif rate < 0
    rate = 0;
end
end

function rate = convert_hours_to_rate(hoursValue, hoursPerYear)
%CONVERT_HOURS_TO_RATE Convert average hours between replacements to rate.

if isnan(hoursValue) || hoursValue <= 0
    rate = NaN;
else
    rate = hoursPerYear / hoursValue;
end
end
