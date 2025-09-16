function plot_executive_summary(costTable, figuresDir)
% PLOT_EXECUTIVE_SUMMARY Create executive dashboard with uncertainty awareness

% Remove baseline rows
costTable = costTable(~strcmp(costTable.mode, 'baseline'), :);

if isempty(costTable)
    warning('plot_executive_summary: no data provided, skipping plot.');
    return;
end


% Check for bounds columns
hasBounds = ismember('percent_PM25_reduction_lower', costTable.Properties.VariableNames);

% Pre-compute configuration list and consistent colors for all plots
configs = unique(costTable(:, {'location', 'filterType', 'mode'}));
colors = lines(height(configs));

fig = figure('Visible', 'off');
set_figure_fullscreen(fig);

%% Panel 1: Active metrics for Bakersfield
subplot(2, 3, 1);

% Accept both "bakersfield" and shortened "baker" location strings
locMask  = contains(lower(costTable.location), 'bakersfield') | ...
    contains(lower(costTable.location), 'baker');
% Treat "triggered" as active
modeMask = strcmpi(costTable.mode, 'active') | strcmpi(costTable.mode, 'triggered');
bfActive = costTable(locMask & modeMask, :);

if isempty(bfActive)
    text(0.5, 0.5, 'No active data for Bakersfield', 'HorizontalAlignment', 'center');
    set(gca,'visible','off');
else
    % Aggregate across any filter types
    pm25Mean = mean(bfActive.percent_PM25_reduction);
    pm10Mean = mean(bfActive.percent_PM10_reduction);
    costMean = mean(bfActive.total_cost);
    aqiMean  = mean(bfActive.AQI_hours_avoided);

    if hasBounds
        pm25Low = mean(bfActive.percent_PM25_reduction_lower);
        pm25High = mean(bfActive.percent_PM25_reduction_upper);
        pm10Low = mean(bfActive.percent_PM10_reduction_lower);
        pm10High = mean(bfActive.percent_PM10_reduction_upper);
        costLow = mean(bfActive.total_cost_lower);
        costHigh = mean(bfActive.total_cost_upper);
        aqiLow = mean(bfActive.AQI_hours_avoided_lower);
        aqiHigh = mean(bfActive.AQI_hours_avoided_upper);
    else
        pm25Low = pm25Mean * 0.9;  pm25High = pm25Mean * 1.1;
        pm10Low = pm10Mean * 0.9;  pm10High = pm10Mean * 1.1;
        costLow = costMean * 0.9;  costHigh = costMean * 1.1;
        aqiLow  = aqiMean  * 0.9;  aqiHigh  = aqiMean  * 1.1;
    end

    categories = {'PM2.5 Reduction (%)', 'PM10 Reduction (%)', ...
        'AQI Hours Avoided', 'Cost ($)'};
    means = [pm25Mean, pm10Mean, aqiMean, costMean];
    lowerVals = [pm25Low, pm10Low, aqiLow, costLow];
    upperVals = [pm25High, pm10High, aqiHigh, costHigh];
    errLow = means - lowerVals;
    errHigh = upperVals - means;
    valueFormats = {'%.1f%%','%.1f%%','%.0f h','$%.0f'};

    b = bar(categorical(categories), means, 'FaceColor', 'flat');
    b.CData = lines(numel(means));
    hold on;

    % Get bar center positions for accurate errorbar placement
    xCenters = b.XEndPoints;
    yCenters = b.YEndPoints;  % should match the bar heights

    % Plot errorbars at those exact x–y locations
    errorbar(xCenters, yCenters, errLow, errHigh, 'k', ...
        'LineStyle','none','LineWidth',1.5);

    % Numeric value labels on bars at the same centers
    for i = 1:numel(means)
        if isfinite(lowerVals(i)) && isfinite(upperVals(i))
            label = format_bounds(means(i), lowerVals(i), upperVals(i), ...
                'MeanFormat', valueFormats{i}, 'BoundFormat', valueFormats{i}, ...
                'Style', 'both', 'IncludeNewline', true);
            offset = 0.05 * max(abs(upperVals(i)), 1);
            text(xCenters(i), upperVals(i) + offset, label, ...
                'HorizontalAlignment','center', 'VerticalAlignment','bottom', ...
                'FontSize', 8);
        end
    end

    ylabel('Metric Value (Varies by Category)');
    title('Active Intervention Results for Bakersfield');
    grid on;
end

%% Panel 2: Cost-Effectiveness Quadrants with Uncertainty
subplot(2, 3, [2 3]);
hold on;
% Use precomputed configs and colors for consistent scheme
legendEntries = cell(height(configs),1);

for i = 1:height(configs)
    row = costTable(strcmp(costTable.location, configs.location{i}) & ...
        strcmp(costTable.filterType, configs.filterType{i}) & ...
        strcmp(costTable.mode, configs.mode{i}), :);
    if isempty(row), continue; end
    xMean = row.percent_PM25_reduction;
    yMean = row.total_cost;
    if hasBounds
        xLower = row.percent_PM25_reduction_lower;
        xUpper = row.percent_PM25_reduction_upper;
        yLower = row.total_cost_lower;
        yUpper = row.total_cost_upper;
    else
        xLower = xMean * 0.9; xUpper = xMean * 1.1;
        yLower = yMean * 0.9; yUpper = yMean * 1.1;
    end
    % Use a patch object instead of rectangle so the legend works in both
    % MATLAB and Octave. The patch supports the ``DisplayName`` property
    % which ``rectangle`` does not in some environments.
    rectX = [xLower, xUpper, xUpper, xLower];
    rectY = [yLower, yLower, yUpper, yUpper];
    hRect = patch(rectX, rectY, colors(i,:), ...
        'EdgeColor', colors(i,:), 'LineWidth', 1, ...
        'FaceAlpha', 0.2, ...
        'DisplayName', sprintf('%s-%s-%s', configs.location{i}, configs.filterType{i}, configs.mode{i}));
    hPoint = plot(xMean, yMean, 'o', 'MarkerSize', 8, ...
        'MarkerFaceColor', colors(i,:), 'MarkerEdgeColor', 'k', ...
        'DisplayName', 'Mean');
    legendEntries{i} = hRect.DisplayName;
end

% Add quadrant lines
xMed = median(costTable.percent_PM25_reduction);
yMed = median(costTable.total_cost);
xline(xMed, '--k', 'Median Reduction');
yline(yMed, '--k', 'Median Cost');

xlabel('Particulate Matter 2.5 Reduction (Percent)');
ylabel('Annual Cost (Dollars)');
title('Cost and Effectiveness Outcomes with Uncertainty Ranges');
grid on;
legend('Location', 'eastoutside');

%% Panel 3: Performance Distribution
subplot(2, 3, 4);
hold on;
filterTypes = unique(costTable.filterType);
positions = 1:length(filterTypes);
for f = 1:length(filterTypes)
    rows = costTable(strcmp(costTable.filterType, filterTypes{f}), :);
    vals = rows.percent_PM25_reduction;
    if hasBounds
        allVals = [vals; rows.percent_PM25_reduction_lower; rows.percent_PM25_reduction_upper];
    else
        allVals = vals;
    end
    q25 = prctile(vals, 25);
    q50 = prctile(vals, 50);
    q75 = prctile(vals, 75);
    boxWidth = 0.3;
    % Patch object to represent the interquartile range so that legends work
    % consistently in environments where ``rectangle`` lacks a ``DisplayName``
    % property.
    bxX = [positions(f)-boxWidth/2, positions(f)+boxWidth/2, ...
        positions(f)+boxWidth/2, positions(f)-boxWidth/2];
    bxY = [q25, q25, q75, q75];
    patch(bxX, bxY, [0.7 0.7 0.7], 'EdgeColor', 'k', ...
        'DisplayName', 'IQR');
    plot([positions(f)-boxWidth/2, positions(f)+boxWidth/2], [q50 q50], 'k-', 'LineWidth', 2, 'DisplayName', 'Median');
    jitter = (rand(size(vals))-0.5) * 0.2;
    scatter(positions(f) + jitter, vals, 50, 'filled', 'MarkerFaceAlpha', 0.6, 'DisplayName', filterTypes{f});
    plot([positions(f) positions(f)], [min(allVals) max(allVals)], 'k-', 'LineWidth', 1, 'DisplayName', 'Range');
end
set(gca, 'XTick', positions, 'XTickLabel', filterTypes);
xlabel('Filter Type');
ylabel('Particulate Matter 2.5 Reduction (Percent)');
title('Performance Distribution Across Filter Types');
grid on;
legend(unique(get(gca,'Children')),'Location','bestoutside');

%% Panel 4: Uncertainty Analysis
subplot(2, 3, 5);
hold on;
performance = []; uncertainty = []; colorList = [];
for i = 1:height(configs)
    row = costTable(strcmp(costTable.location, configs.location{i}) & ...
        strcmp(costTable.filterType, configs.filterType{i}) & ...
        strcmp(costTable.mode, configs.mode{i}), :);
    if ~isempty(row)
        performance(end+1) = row.percent_PM25_reduction; %#ok<*AGROW>
        if hasBounds
            uncRange = row.percent_PM25_reduction_upper - row.percent_PM25_reduction_lower;
        else
            uncRange = row.percent_PM25_reduction * 0.2;
        end
        uncertainty(end+1) = uncRange;
        colorList(end+1,:) = colors(i,:);
    end
end
hScatter = scatter(performance, uncertainty, 100, colorList, 'filled', ...
    'DisplayName', 'Configs');
% Add trend line
if length(performance) > 2
    p = polyfit(performance, uncertainty, 1);
    xfit = linspace(min(performance), max(performance), 100);
    yfit = polyval(p, xfit);
    hLine = plot(xfit, yfit, 'r--', 'LineWidth', 1.5, 'DisplayName', 'Trend Line');
end
xlabel('Mean Particulate Matter 2.5 Reduction (Percent)');
ylabel('Uncertainty Range (Percentage Points)');
title('Performance Versus Uncertainty Range');
grid on;

%% Panel 5: Top Interventions Table
subplot(2, 3, 6);
axis off;

% Rank interventions by a composite score
configs = unique(costTable(:, {'location', 'filterType', 'mode'}));
nConfigs = height(configs);
scores = zeros(nConfigs, 1);
summaryData = cell(nConfigs, 5);
maxCostTotal = max(costTable.total_cost);
maxReduction = max(costTable.percent_PM25_reduction);
if ~isfinite(maxCostTotal) || maxCostTotal == 0
    maxCostTotal = 1;
end
if ~isfinite(maxReduction) || maxReduction == 0
    maxReduction = 1;
end

for i = 1:nConfigs
    row = costTable(strcmp(costTable.location, configs.location{i}) & ...
        strcmp(costTable.filterType, configs.filterType{i}) & ...
        strcmp(costTable.mode, configs.mode{i}), :);

    if ~isempty(row)
        % Composite score: high PM2.5 reduction, low cost, low uncertainty
        pm25Score = row.percent_PM25_reduction / 100;
        costScore = 1 - (row.total_cost / max(costTable.total_cost));

        if hasBounds
            uncRange = row.percent_PM25_reduction_upper - row.percent_PM25_reduction_lower;
            certScore = 1 - (uncRange / max(costTable.percent_PM25_reduction));
        else
            certScore = 0.8; % Default certainty
        end

        scores(i) = 0.5*pm25Score + 0.3*costScore + 0.2*certScore;

        summaryData{i,1} = sprintf('%s-%s-%s', configs.location{i}(1:3), ...
            configs.filterType{i}(1:4), configs.mode{i}(1:min(6,end)));

        if hasBounds
            summaryData{i,2} = format_bounds(row.percent_PM25_reduction, ...
                row.percent_PM25_reduction_lower, row.percent_PM25_reduction_upper, ...
                'MeanFormat', '%.1f%%', 'BoundFormat', '%.1f%%', ...
                'Style', 'both', 'IncludeNewline', true);
            summaryData{i,3} = format_bounds(row.total_cost, ...
                row.total_cost_lower, row.total_cost_upper, ...
                'MeanFormat', '$%.0f', 'BoundFormat', '$%.0f', ...
                'Style', 'both', 'IncludeNewline', true);
            summaryData{i,4} = format_bounds(row.AQI_hours_avoided, ...
                row.AQI_hours_avoided_lower, row.AQI_hours_avoided_upper, ...
                'MeanFormat', '%.0f h', 'BoundFormat', '%.0f h', ...
                'Style', 'both', 'IncludeNewline', true);

            pm25LowerScore = row.percent_PM25_reduction_lower / 100;
            pm25UpperScore = row.percent_PM25_reduction_upper / 100;
            costLowerScore = 1 - (row.total_cost_upper / maxCostTotal);
            costUpperScore = 1 - (row.total_cost_lower / maxCostTotal);
            certScore = 1 - (uncRange / maxReduction);
            scoreLower = 0.5*pm25LowerScore + 0.3*costLowerScore + 0.2*certScore;
            scoreUpper = 0.5*pm25UpperScore + 0.3*costUpperScore + 0.2*certScore;
            summaryData{i,5} = format_bounds(scores(i), scoreLower, scoreUpper, ...
                'MeanFormat', '%.2f', 'BoundFormat', '%.2f', ...
                'Style', 'both', 'IncludeNewline', true);
        else
            summaryData{i,2} = sprintf('%.1f%%', row.percent_PM25_reduction);
            summaryData{i,3} = sprintf('$%.0f', row.total_cost);
            summaryData{i,4} = sprintf('%.0f h', row.AQI_hours_avoided);
            summaryData{i,5} = sprintf('%.2f', scores(i));
        end
    end
end

% Sort by score
[~, sortIdx] = sort(scores, 'descend');
topN = min(5, nConfigs);

% Create table
tableData = [{'Configuration', 'PM2.5↓', 'Cost/yr', 'AQI Hours', 'Score'}; ...
    summaryData(sortIdx(1:topN), :)];

% Display table
text(0.5, 0.9, 'Top 5 Interventions (Composite Score)', ...
    'HorizontalAlignment', 'center', 'FontWeight', 'bold', 'FontSize', 12);


colStart = 0.05;
colSpacing = 0.2;

for r = 1:size(tableData, 1)
    for c = 1:size(tableData, 2)
        x = colStart + (c-1)*colSpacing;
        y = 0.7 - (r-1)*0.12;

        if r == 1
            % Header
            text(x, y, tableData{r,c}, 'FontWeight', 'bold', 'FontSize', 10);
        else
            text(x, y, tableData{r,c}, 'FontSize', 9);
        end
    end
end

% Add scoring explanation
text(0.5, 0.05, 'Score = 0.5×(PM2.5 reduction) + 0.3×(cost efficiency) + 0.2×(certainty)', ...
    'HorizontalAlignment', 'center', 'FontSize', 8, 'FontAngle', 'italic');

% Overall title
sgtitle('Executive Summary of Intervention Performance with Uncertainty Ranges', ...
    'FontSize', 16, 'FontWeight', 'bold');

add_figure_caption(fig, sprintf(['This executive dashboard blends bar charts, scatter plots, and a ranking table to summarize intervention performance under uncertainty.' newline ...
    'The upper panels show Bakersfield active-mode outcomes alongside a cost-versus-effectiveness quadrant map, while the lower plots trace how reductions distribute by filter type and how uncertainty expands with performance.' newline ...
    'A curated table distills the top scoring configurations so decision makers can quickly see which options balance impact, cost, and reliability.']));

save_figure(fig, figuresDir, 'executive_summary_with_bounds.png');
close(fig);
end
