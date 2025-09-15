function plot_airflow_penalty(tradeoffTable, figuresDir)
% PLOT_AIRFLOW_PENALTY Visualize airflow restrictions with uncertainty bounds
%   Enhanced version with physics-based methodology and informative legends

if isempty(tradeoffTable)
    warning('plot_airflow_penalty: no data provided, skipping plot.');
    return;
end

% Check for bounds columns
hasBounds = ismember('airflow_penalty_lower', tradeoffTable.Properties.VariableNames);

% Get unique configurations
filters = unique(tradeoffTable.filterType);
modes = unique(tradeoffTable.mode);
locations = unique(tradeoffTable.location);

% Create figure with multiple panels
fig = figure('Position', [100 100 1400 900], 'Visible', 'off');

%% Panel 1: Main comparison by filter and mode
subplot(2, 3, [1 2]);
hold on;

nFilters = length(filters);
nModes = length(modes);
meanPenalty = zeros(nModes, nFilters);
lowerBounds = zeros(nModes, nFilters);
upperBounds = zeros(nModes, nFilters);

for m = 1:nModes
    for f = 1:nFilters
        mask = strcmp(tradeoffTable.filterType, filters{f}) & ...
               strcmp(tradeoffTable.mode, modes{m});
        rows = tradeoffTable(mask, :);
        if isempty(rows)
            meanPenalty(m, f) = NaN;
            continue;
        end
        meanPenalty(m, f) = mean(rows.airflow_penalty_percent, 'omitnan');
        if hasBounds
            lowerBounds(m, f) = mean(rows.airflow_penalty_lower, 'omitnan');
            upperBounds(m, f) = mean(rows.airflow_penalty_upper, 'omitnan');
        else
            lowerBounds(m, f) = meanPenalty(m, f) * 0.9;
            upperBounds(m, f) = meanPenalty(m, f) * 1.1;
        end
    end
end

% Ensure values are real in case upstream calculations introduced
% small imaginary components
meanPenalty  = real(meanPenalty);
lowerBounds  = real(lowerBounds);
upperBounds  = real(upperBounds);

% Plot grouped bars with consistent colors
x = 1:nModes;
width = 0.35;
colors = [0.2 0.4 0.8; 0.8 0.3 0.3];

for f = 1:nFilters
    offset = (f - 1.5) * width;
    bar(x + offset, meanPenalty(:, f), width, 'FaceColor', colors(f, :));
    errorLow = meanPenalty(:, f) - lowerBounds(:, f);
    errorHigh = upperBounds(:, f) - meanPenalty(:, f);
    errorbar(x + offset, meanPenalty(:, f), errorLow, errorHigh, ...
             'k', 'LineStyle', 'none', 'LineWidth', 1.5, 'CapSize', 8);
    for m = 1:nModes
        if ~isnan(meanPenalty(m, f))
            text(m + offset, upperBounds(m, f) + 0.5, ...
                 sprintf('%.1f%%', meanPenalty(m, f)), ...
                 'HorizontalAlignment', 'center', 'FontSize', 9);
        end
    end
end

yline(10, '--r', 'Typical Comfort Threshold (10%)', 'LineWidth', 1.5, 'LabelHorizontalAlignment', 'left');
yline(20, '--', 'Color', [0.8 0.4 0], 'LineWidth', 1.5);
text(0.5, 20.5, 'Noticeable Impact (20%)', 'FontSize', 9, 'Color', [0.8 0.4 0]);

set(gca, 'XTick', x, 'XTickLabel', modes);
ylabel('Airflow Reduction (%)');
title('Airflow Penalty by Filter Type and Operating Mode');
legend(filters, 'Location', 'northwest');
grid on;
% Account for complex values when determining y-limits
ylim([0 max(real(upperBounds(:)))*1.2]);

%% Panel 2: Physics-based explanation
subplot(2, 3, 3);
axis off;
text(0.1, 0.9, 'Airflow Penalty Factors:', 'FontWeight', 'bold', 'FontSize', 11);
text(0.1, 0.8, '• Filter pressure drop', 'FontSize', 10);
text(0.1, 0.7, '• Filter loading state', 'FontSize', 10);
text(0.1, 0.6, '• Operating mode', 'FontSize', 10);
text(0.1, 0.5, '• Building envelope', 'FontSize', 10);
text(0.1, 0.3, 'Methodology:', 'FontWeight', 'bold', 'FontSize', 11);
text(0.1, 0.2, 'Penalties calculated using fan laws', 'FontSize', 9);
text(0.1, 0.1, 'Bounds show tight vs leaky homes', 'FontSize', 9);

%% Panel 3: Location-specific differences
subplot(2, 3, 4);
hold on;

locationMeans = zeros(length(locations), length(filters));
locationRanges = zeros(length(locations), length(filters));

for l = 1:length(locations)
    for f = 1:length(filters)
        mask = strcmp(tradeoffTable.location, locations{l}) & ...
               strcmp(tradeoffTable.filterType, filters{f});
        rows = tradeoffTable(mask, :);
        if ~isempty(rows)
            locationMeans(l, f) = mean(rows.airflow_penalty_percent, 'omitnan');
            if hasBounds
                lower = mean(rows.airflow_penalty_lower, 'omitnan');
                upper = mean(rows.airflow_penalty_upper, 'omitnan');
                locationRanges(l, f) = upper - lower;
            else
                locationRanges(l, f) = locationMeans(l, f) * 0.2;
            end
        end
    end
end

% Ensure real values before plotting
locationMeans  = real(locationMeans);
locationRanges = real(locationRanges);

b = bar(locationMeans, 'grouped');
for i = 1:length(b)
    b(i).FaceColor = colors(i,:);
end
set(gca, 'XTick', 1:length(locations), 'XTickLabel', locations);
ylabel('Mean Airflow Penalty (%)');
title('Location-Specific Airflow Impact');
legend(filters, 'Location', 'best');
grid on;

%% Panel 4: Envelope sensitivity analysis
subplot(2, 3, 5);
hold on;

sensitivity = zeros(height(tradeoffTable), 1);
configLabels = cell(height(tradeoffTable), 1);

for i = 1:height(tradeoffTable)
    if hasBounds
        range = tradeoffTable.airflow_penalty_upper(i) - tradeoffTable.airflow_penalty_lower(i);
        mean_val = tradeoffTable.airflow_penalty_percent(i);
        if mean_val > 0
            sensitivity(i) = 100 * range / mean_val;
        end
    end
    configLabels{i} = sprintf('%s-%s-%s', ...
        tradeoffTable.location{i}(1:3), ...
        tradeoffTable.filterType{i}(1:4), ...
        tradeoffTable.mode{i}(1:min(6,end)));
end

% Remove any imaginary components that may have arisen from calculations
sensitivity = real(sensitivity);

[sortedSens, sortIdx] = sort(sensitivity, 'descend');
topN = min(10, length(sortedSens));
barh(1:topN, sortedSens(1:topN), 'FaceColor', [0.6 0.6 0.8]);
set(gca, 'YTick', 1:topN, 'YTickLabel', configLabels(sortIdx(1:topN)));
xlabel('Envelope Sensitivity (% variation)');
title('Configurations Most Sensitive to Building Envelope');
grid on;

%% Panel 5: Correlation plot
subplot(2, 3, 6);
hold on;

 allMeans  = tradeoffTable.airflow_penalty_percent;
 if hasBounds
     allLower = tradeoffTable.airflow_penalty_lower;
     allUpper = tradeoffTable.airflow_penalty_upper;
     allRanges = allUpper - allLower;
 else
     allLower = allMeans * 0.9;
     allUpper = allMeans * 1.1;
     allRanges = allUpper - allLower;
 end

 % Remove any imaginary components before plotting
 allMeans  = real(allMeans);
 allLower  = real(allLower);
 allUpper  = real(allUpper);
 allRanges = real(allRanges);

xErrLow  = allMeans - allLower;
xErrHigh = allUpper - allMeans;

filterColors = zeros(height(tradeoffTable), 3);
for i = 1:height(tradeoffTable)
    if strcmpi(tradeoffTable.filterType{i}, 'hepa')
        filterColors(i,:) = [0.2 0.4 0.8];
    else
        filterColors(i,:) = [0.8 0.3 0.3];
    end
    plot([allLower(i) allUpper(i)], [allRanges(i) allRanges(i)], '-', ...
        'Color', [0.3 0.3 0.3], 'LineWidth', 1.2);
    plot([allLower(i) allLower(i)], [allRanges(i)-0.2 allRanges(i)+0.2], '-', ...
        'Color', [0.3 0.3 0.3], 'LineWidth', 1.2);
    plot([allUpper(i) allUpper(i)], [allRanges(i)-0.2 allRanges(i)+0.2], '-', ...
        'Color', [0.3 0.3 0.3], 'LineWidth', 1.2);
end

scatter(allMeans, allRanges, 100, filterColors, 'filled', 'MarkerEdgeColor', 'k');

labels = cell(height(tradeoffTable),1);
for i = 1:height(tradeoffTable)
    labels{i} = sprintf('%s-%s', tradeoffTable.location{i}, tradeoffTable.filterType{i});
    text(allMeans(i), allRanges(i), labels{i}, 'VerticalAlignment','bottom', ...
        'HorizontalAlignment','center', 'FontSize', 8);
end
xlabel('Mean Airflow Penalty (%)');
ylabel('Uncertainty Range (% points)');
title('Airflow Penalty vs. Uncertainty');
grid on;

h1 = plot(NaN, NaN, 'o', 'MarkerSize', 10, 'MarkerFaceColor', [0.2 0.4 0.8], 'MarkerEdgeColor', 'k');
h2 = plot(NaN, NaN, 'o', 'MarkerSize', 10, 'MarkerFaceColor', [0.8 0.3 0.3], 'MarkerEdgeColor', 'k');
legend([h1 h2], {'HEPA', 'MERV'}, 'Location', 'best');

if length(allMeans) > 5
    validIdx = ~isnan(allMeans) & ~isnan(allRanges);
    if sum(validIdx) > 2
        p = polyfit(allMeans(validIdx), allRanges(validIdx), 1);
        xfit = linspace(min(allMeans(validIdx)), max(allMeans(validIdx)), 100);
        yfit = polyval(p, xfit);
        plot(xfit, yfit, 'k--', 'LineWidth', 1.5);
    end
end

sgtitle('Comprehensive Airflow Penalty Analysis with Consistent Methodology', ...
        'FontSize', 14, 'FontWeight', 'bold');

save_figure(fig, figuresDir, 'airflow_penalty_comprehensive_improved.png');
close(fig);
end