function plot_deterministic_bounds(summaryTable, costTable, figuresDir)
% PLOT_DETERMINISTIC_BOUNDS Visualize physical bounds from building envelope conditions
%
% This visualization treats tight and leaky runs as *bounds* on a single
% scenario. The costTable is expected to contain mean values with
% corresponding _lower/_upper columns derived from both envelope
% simulations. If those bound columns are missing, the function falls back
% to the older behaviour of pulling separate tight and leaky rows.

if isempty(summaryTable) || isempty(costTable)
    warning('plot_deterministic_bounds: no data provided, skipping plot.');
    return;
end
figure('Position',[100 100 1400 900],'Visible','off');
t = tiledlayout(2,3,'TileSpacing','compact','Padding','compact');

% Get unique scenarios
scenarios = unique(summaryTable(~strcmp(summaryTable.mode,'baseline'), ...
    {'location','filterType','mode'}));

%% Tile 1: Parallel coordinates plot showing tight-to-leaky transitions
nexttile([1 2]);
hold on;

% Metrics to display
metrics = {'avg_indoor_PM25', 'total_cost', 'filter_replaced'};
metricLabels = {'PM2.5 (µg/m³)', 'Annual Cost ($)', 'Filter Hours'};

% Normalize data for parallel coordinates
nMetrics = length(metrics);
nScenarios = height(scenarios);
tightData = zeros(nScenarios, nMetrics);
leakyData = zeros(nScenarios, nMetrics);

for i = 1:nScenarios
    for j = 1:nMetrics
        tightRow = summaryTable(strcmp(summaryTable.location, scenarios.location{i}) & ...
            strcmp(summaryTable.filterType, scenarios.filterType{i}) & ...
            strcmp(summaryTable.mode, scenarios.mode{i}) & ...
            strcmp(summaryTable.leakage, 'tight'), :);
        leakyRow = summaryTable(strcmp(summaryTable.location, scenarios.location{i}) & ...
            strcmp(summaryTable.filterType, scenarios.filterType{i}) & ...
            strcmp(summaryTable.mode, scenarios.mode{i}) & ...
            strcmp(summaryTable.leakage, 'leaky'), :);

        if ~isempty(tightRow) && ~isempty(leakyRow)
            tightData(i,j) = tightRow.(metrics{j});
            leakyData(i,j) = leakyRow.(metrics{j});
        end
    end
end

% Normalize to 0-1 for visualization
normTight = zeros(size(tightData));
normLeaky = zeros(size(leakyData));
for j = 1:nMetrics
    minVal = min([tightData(:,j); leakyData(:,j)]);
    maxVal = max([tightData(:,j); leakyData(:,j)]);
    if maxVal > minVal
        normTight(:,j) = (tightData(:,j) - minVal) / (maxVal - minVal);
        normLeaky(:,j) = (leakyData(:,j) - minVal) / (maxVal - minVal);
    end
end

% Plot lines from tight to leaky
colors = lines(nScenarios);
for i = 1:nScenarios
    x = 1:nMetrics;
    % Plot the physical bounds as a ribbon
    fill([x fliplr(x)], [normTight(i,:) fliplr(normLeaky(i,:))], ...
        colors(i,:), 'FaceAlpha', 0.3, 'EdgeColor', 'none');
    % Plot the bounds
    plot(x, normTight(i,:), '-', 'Color', colors(i,:), 'LineWidth', 2);
    plot(x, normLeaky(i,:), '--', 'Color', colors(i,:), 'LineWidth', 2);
    % Connect with gradient
    for j = 1:nMetrics-1
        plot([j j+1], [normTight(i,j) normTight(i,j+1)], '-', ...
            'Color', colors(i,:), 'LineWidth', 1.5);
        plot([j j+1], [normLeaky(i,j) normLeaky(i,j+1)], '--', ...
            'Color', colors(i,:), 'LineWidth', 1.5);
    end
end

set(gca, 'XTick', 1:nMetrics, 'XTickLabel', metricLabels);
ylabel('Normalized Value');
title('Physical Bounds: Tight (solid) vs Leaky (dashed) Building Envelopes');
ylim([0 1]);
grid on;

%% Tile 2: Operating region visualization
nexttile;
hold on;

% Plot feasible operating regions for each scenario
for i = 1:height(scenarios)
    row = costTable(strcmp(costTable.location, scenarios.location{i}) & ...
        strcmp(costTable.filterType, scenarios.filterType{i}) & ...
        strcmp(costTable.mode, scenarios.mode{i}), :);

    hasBoundCols = all(ismember({'percent_PM25_reduction_lower','percent_PM25_reduction_upper',...
        'total_cost_lower','total_cost_upper'}, ...
        costTable.Properties.VariableNames));
    hasLeakCol = ismember('leakage', costTable.Properties.VariableNames);

    if ~isempty(row) && hasBoundCols
        % Define operating envelope using bound columns
        x = [row.percent_PM25_reduction_lower, row.percent_PM25_reduction_upper];
        y = [row.total_cost_lower, row.total_cost_upper];
    elseif hasLeakCol
        % Fallback: look for separate tight/leaky rows if available
        tightCost = costTable(strcmp(costTable.location, scenarios.location{i}) & ...
            strcmp(costTable.filterType, scenarios.filterType{i}) & ...
            strcmp(costTable.mode, scenarios.mode{i}) & ...
            strcmp(costTable.leakage,'tight'), :);
        leakyCost = costTable(strcmp(costTable.location, scenarios.location{i}) & ...
            strcmp(costTable.filterType, scenarios.filterType{i}) & ...
            strcmp(costTable.mode, scenarios.mode{i}) & ...
            strcmp(costTable.leakage,'leaky'), :);
        if isempty(tightCost) || isempty(leakyCost)
            continue;
        end
        % Treat tight and leaky scenarios as lower/upper bounds
        pm25Vals = [tightCost.percent_PM25_reduction, leakyCost.percent_PM25_reduction];
        costVals = [tightCost.total_cost, leakyCost.total_cost];
        x = [min(pm25Vals), max(pm25Vals)];
        y = [min(costVals), max(costVals)];
    else
        % No leakage column or bound columns - skip this scenario
        continue;
    end

    % Plot operating line
    plot(x, y, '-', 'Color', colors(i,:), 'LineWidth', 3);
    plot(x(1), y(1), 'o', 'MarkerSize', 8, 'MarkerFaceColor', colors(i,:), ...
        'MarkerEdgeColor', 'k'); % Tight
    plot(x(2), y(2), 's', 'MarkerSize', 8, 'MarkerFaceColor', colors(i,:), ...
        'MarkerEdgeColor', 'k'); % Leaky

    % Add annotation
    text(mean(x), mean(y), sprintf('%s-%s', scenarios.location{i}, scenarios.filterType{i}), ...
        'FontSize', 8, 'HorizontalAlignment', 'center');
end

xlabel('PM2.5 Reduction (%)');
ylabel('Annual Operating Cost ($)');
title('Feasible Operating Regions');
legend({'Operating Range', 'Tight Envelope', 'Leaky Envelope'}, 'Location','eastoutside');
grid on;

%% Tile 3: Bounds width analysis
nexttile;
boundWidths = zeros(nScenarios, 3);
scenarioLabels = cell(nScenarios, 1);

for i = 1:nScenarios
    loc = scenarios.location{i};
    filt = scenarios.filterType{i};
    mode = scenarios.mode{i};

    scenarioLabels{i} = sprintf('%s-%s-%s', loc(1:3), filt(1:4), mode(1:3));

    % Calculate absolute bounds width for each metric
    % Only compute widths when both rows contain valid numeric data. Using
    % >0 caused the bounds plot to appear empty when values were 0 or NaN.
    if all(isfinite(tightData(i,:))) && all(isfinite(leakyData(i,:)))
        boundWidths(i,1) = abs(tightData(i,1) - leakyData(i,1)); % PM2.5
        boundWidths(i,2) = abs(tightData(i,2) - leakyData(i,2)); % Cost
        boundWidths(i,3) = abs(tightData(i,3) - leakyData(i,3)); % Filter life
    end
end

bar(boundWidths);
set(gca, 'XTick', 1:nScenarios, 'XTickLabel', scenarioLabels);
xtickangle(45);
ylabel('Absolute Bounds Width');
legend({'PM2.5 (µg/m³)', 'Cost ($)', 'Filter Hours'}, 'Location','northwestoutside');
title('Physical Bounds Width by Scenario');
grid on;

%% Tile 4: Time-dependent bounds visualization
nexttile([1 2]);
% Show how bounds evolve over time for one scenario
exampleIdx = find(strcmp(scenarios.location,'adams') & ...
    strcmp(scenarios.filterType,'hepa') & ...
    strcmp(scenarios.mode,'active'), 1);

if ~isempty(exampleIdx)
    tightRow = summaryTable(strcmp(summaryTable.location, scenarios.location{exampleIdx}) & ...
        strcmp(summaryTable.filterType, scenarios.filterType{exampleIdx}) & ...
        strcmp(summaryTable.mode, scenarios.mode{exampleIdx}) & ...
        strcmp(summaryTable.leakage, 'tight'), :);
    leakyRow = summaryTable(strcmp(summaryTable.location, scenarios.location{exampleIdx}) & ...
        strcmp(summaryTable.filterType, scenarios.filterType{exampleIdx}) & ...
        strcmp(summaryTable.mode, scenarios.mode{exampleIdx}) & ...
        strcmp(summaryTable.leakage, 'leaky'), :);

    if ~isempty(tightRow) && ~isempty(leakyRow)
        tightPM = tightRow.indoor_PM25{1};
        leakyPM = leakyRow.indoor_PM25{1};

        % Determine the hours to plot (first week or available data)
        maxHours = min(168, min(length(tightPM), length(leakyPM)));
        hours = 1:maxHours;

        % Extract the data for the hours
        tightPM_subset = tightPM(hours);
        leakyPM_subset = leakyPM(hours);

        % Create envelope plot
        yyaxis left
        fill([hours fliplr(hours)], [tightPM_subset(:)' fliplr(leakyPM_subset(:)')], ...
            [0.2 0.5 0.8], 'FaceAlpha', 0.3, 'EdgeColor', 'none');
        hold on;
        plot(hours, tightPM_subset, 'b-', 'LineWidth', 2);
        plot(hours, leakyPM_subset, 'b--', 'LineWidth', 2);
        ylabel('Indoor PM2.5 (µg/m³)');
        ylim([0 max([tightPM_subset(:); leakyPM_subset(:)])*1.1]);

        yyaxis right
        boundWidth = abs(tightPM_subset - leakyPM_subset);
        plot(hours, boundWidth, 'r-', 'LineWidth', 1.5);
        ylabel('Bounds Width (µg/m³)');

        xlabel('Hour');
        title(sprintf('Physical Bounds Evolution: %s %s %s (First Week)', ...
            scenarios.location{exampleIdx}, scenarios.filterType{exampleIdx}, ...
            scenarios.mode{exampleIdx}));
        legend({'Operating Envelope', 'Tight', 'Leaky', 'Bounds Width'}, ...
            'Location','eastoutside');
        grid on;
    end
end

% Overall title
sgtitle('Deterministic Physical Bounds Analysis: Building Envelope Performance', ...
    'FontSize', 14, 'FontWeight', 'bold');

% Save
save_figure(gcf, figuresDir, 'deterministic_bounds_analysis.png');
close(gcf);
end