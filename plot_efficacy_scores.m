function plot_efficacy_scores(efficacyScoreTable, figuresDir)
% PLOT_EFFICACY_SCORES Create comprehensive visualizations of composite efficacy scores
%
% Inputs:
%   efficacyScoreTable - Table from calculate_efficacy_scores
%   figuresDir        - Directory to save figures

if isempty(efficacyScoreTable)
    warning('plot_efficacy_scores: no data provided, skipping plot.');
    return;
end

% Create comprehensive efficacy visualization
fig = figure('Visible','off');
set_figure_fullscreen(fig);
tiledlayout(2,3,'TileSpacing','compact','Padding','compact');

% Sort by rank for consistent ordering
efficacyScoreTable = sortrows(efficacyScoreTable, 'rank');
nConfigs = height(efficacyScoreTable);

% Create scenario labels
scenarioLabels = cell(nConfigs, 1);
for i = 1:nConfigs
    scenarioLabels{i} = sprintf('%s-%s-%s', ...
        efficacyScoreTable.location{i}(1:min(4,end)), ...
        efficacyScoreTable.filterType{i}(1:4), ...
        efficacyScoreTable.mode{i}(1:min(6,end)));
end

colors = lines(nConfigs);
cmap = get_color_map();

%% Panel 1: Overall Efficacy Score Ranking with Confidence Intervals
nexttile;
hold on;

% Plot bars with error bars
for i = 1:nConfigs
    bar(i, efficacyScoreTable.mean_efficacy_score(i), ...
        'FaceColor', colors(i,:), 'EdgeColor', 'k', 'LineWidth', 0.5);
end

% Add half of the score range as error bars
errorbar(1:nConfigs, efficacyScoreTable.mean_efficacy_score, ...
    efficacyScoreTable.score_range_half, 'k', 'LineStyle', 'none', ...
    'LineWidth', 1.5, 'CapSize', 8);

% Formatting
set(gca, 'XTick', 1:nConfigs, 'XTickLabel', scenarioLabels);
xtickangle(45);
ylabel('Composite Efficacy Score (0-100)');
title('Overall Efficacy Ranking');
grid on;
ylim([0 100]);

% Add ranking numbers on bars
for i = 1:nConfigs
    text(i, efficacyScoreTable.mean_efficacy_score(i) + 2, ...
        sprintf('#%d', efficacyScoreTable.rank(i)), ...
        'HorizontalAlignment', 'center', 'FontWeight', 'bold', 'FontSize', 8);
end

%% Panel 2: Component Score Breakdown (Stacked Bar)
nexttile;
componentData = [efficacyScoreTable.avg_pm25_component, ...
                efficacyScoreTable.avg_pm10_component, ...
                efficacyScoreTable.avg_cost_component, ...
                efficacyScoreTable.avg_aqi_component];

bar(componentData, 'stacked');
set(gca, 'XTick', 1:nConfigs, 'XTickLabel', scenarioLabels);
xtickangle(45);
ylabel('Component Score Contribution');
title('Efficacy Component Breakdown');
legend({'PM2.5 (40%)', 'PM10 (20%)', 'Cost Eff. (20%)', 'AQI Hours (20%)'}, ...
    'Location', 'eastoutside');
grid on;

%% Panel 3: Tight vs Leaky Performance Comparison
nexttile;
hold on;

% Plot tight vs leaky scores as overlaid bars
bar(1:nConfigs, efficacyScoreTable.tight_efficacy_score, ...
    'FaceColor', cmap.tight, 'EdgeColor', 'none', 'FaceAlpha', 0.8, ...
    'BarWidth', 0.8, 'DisplayName', 'Tight Envelope');
bar(1:nConfigs, efficacyScoreTable.leaky_efficacy_score, ...
    'FaceColor', cmap.leaky, 'EdgeColor', 'k', 'FaceAlpha', 0.6, ...
    'BarWidth', 0.5, 'DisplayName', 'Leaky Envelope');

set(gca, 'XTick', 1:nConfigs, 'XTickLabel', scenarioLabels);
xtickangle(45);
ylabel('Efficacy Score');
title('Building Envelope Comparison');
legend('Location', 'eastoutside');
grid on;

%% Panel 4: Score Range (Uncertainty) Analysis
nexttile;
bar(efficacyScoreTable.score_range, 'FaceColor', cmap.gray, 'EdgeColor', 'k');
set(gca, 'XTick', 1:nConfigs, 'XTickLabel', scenarioLabels);
xtickangle(45);
ylabel('Score Range (Tight - Leaky)');
title('Performance Uncertainty');
grid on;

% Add threshold line for "high uncertainty"
yline(10, '--r', 'High Uncertainty Threshold', 'LineWidth', 1);

%% Panel 5: Cost-Effectiveness vs PM2.5 Efficacy Scatter
nexttile;
scatter(efficacyScoreTable.avg_pm25_component, efficacyScoreTable.avg_cost_component, ...
    100, efficacyScoreTable.mean_efficacy_score, 'filled');
colormap(parula);
cb = colorbar;
ylabel(cb, 'Overall Efficacy Score');

xlabel('PM2.5 Component Score');
ylabel('Cost Effectiveness Component Score');
title('PM2.5 vs Cost Trade-off');
grid on;

% Add scenario labels
for i = 1:nConfigs
    text(efficacyScoreTable.avg_pm25_component(i) + 0.5, ...
        efficacyScoreTable.avg_cost_component(i), ...
        sprintf('#%d', efficacyScoreTable.rank(i)), ...
        'FontSize', 8, 'FontWeight', 'bold');
end

%% Panel 6: Performance Matrix Heatmap
nexttile;
% Create matrix of component scores for heatmap
heatmapData = [efficacyScoreTable.avg_pm25_component, ...
              efficacyScoreTable.avg_pm10_component, ...
              efficacyScoreTable.avg_cost_component, ...
              efficacyScoreTable.avg_aqi_component]';

imagesc(heatmapData);
colormap(hot);
cb = colorbar;
ylabel(cb, 'Component Score');

set(gca, 'XTick', 1:nConfigs, 'XTickLabel', scenarioLabels);
set(gca, 'YTick', 1:4, 'YTickLabel', {'PM2.5', 'PM10', 'Cost', 'AQI'});
xtickangle(45);
title('Performance Heatmap');

% Add text annotations
for i = 1:size(heatmapData,1)
    for j = 1:size(heatmapData,2)
        text(j, i, sprintf('%.1f', heatmapData(i,j)), ...
            'HorizontalAlignment', 'center', 'Color', 'w', 'FontSize', 8);
    end
end

% Overall title
sgtitle('Composite Efficacy Score Analysis: Multi-Criteria Performance Evaluation', ...
    'FontSize', 14, 'FontWeight', 'bold');

% Save
save_figure(fig, figuresDir, 'efficacy_scores_comprehensive.png');
close(fig);

%% Create summary ranking table visualization
create_efficacy_ranking_table(efficacyScoreTable, figuresDir);

end

function create_efficacy_ranking_table(efficacyScoreTable, figuresDir)
% Create a clean table visualization of the ranking without UI components

fig = figure('Visible','off');
set_figure_fullscreen(fig);
ax = axes('Parent', fig, 'Position',[0.05 0.18 0.9 0.74]);

% Hide axis visuals without disabling visibility (exportgraphics ignores
% children of invisible axes when saving figures)
set(ax, 'XTick', [], 'YTick', [], 'Box', 'off', 'Color', 'none');
if isprop(ax, 'XAxis') % Guard for Octave compatibility
    ax.XAxis.Visible = 'off';
    ax.YAxis.Visible = 'off';
end

% Prepare table data
nRows = min(10, height(efficacyScoreTable)); % Show top 10
tableData = cell(nRows+1, 7); % +1 for header

% Header
tableData(1,:) = {'Rank', 'Configuration', 'Score', '±Half', 'PM2.5', 'Cost', 'AQI'};

% Data rows
for i = 1:nRows
    row = efficacyScoreTable(i,:);
    tableData{i+1,1} = sprintf('#%d', row.rank);
    tableData{i+1,2} = sprintf('%s-%s-%s', row.location{1}, row.filterType{1}, row.mode{1});
    tableData{i+1,3} = sprintf('%.1f', row.mean_efficacy_score);
    tableData{i+1,4} = sprintf('±%.1f', row.score_range_half);
    tableData{i+1,5} = sprintf('%.1f', row.avg_pm25_component);
    tableData{i+1,6} = sprintf('%.1f', row.avg_cost_component);
    tableData{i+1,7} = sprintf('%.1f', row.avg_aqi_component);
end

% Layout settings
colWidths = [0.08 0.28 0.12 0.12 0.12 0.12 0.16];
colPositions = [0, cumsum(colWidths)];
rowHeight = 1;
nDisplayRows = size(tableData, 1);

% Configure axes for manual table rendering
set(ax, 'XLim', [0 1], 'YLim', [0 nDisplayRows], 'YDir', 'reverse');
hold(ax, 'on');

headerColor = [0.2 0.4 0.6];
headerTextColor = [1 1 1];
rowColors = [1 1 1; 0.95 0.95 0.95];
textAlignments = {'center','left','center','center','center','center','center'};

for rowIdx = 1:nDisplayRows
    isHeader = (rowIdx == 1);
    if isHeader
        bgColor = headerColor;
        fontWeight = 'bold';
        fontColor = headerTextColor;
    else
        bgColor = rowColors(mod(rowIdx-2, size(rowColors,1)) + 1, :);
        fontWeight = 'normal';
        fontColor = [0 0 0];
    end

    yPos = (rowIdx-1) * rowHeight;

    for colIdx = 1:numel(colWidths)
        xPos = colPositions(colIdx);
        rectangle('Parent', ax, 'Position', [xPos, yPos, colWidths(colIdx), rowHeight], ...
            'FaceColor', bgColor, 'EdgeColor', [0.8 0.8 0.8]);

        if strcmp(textAlignments{colIdx}, 'left')
            textX = xPos + 0.01;
        else
            textX = xPos + colWidths(colIdx)/2;
        end
        text(ax, textX, yPos + rowHeight/2, tableData{rowIdx, colIdx}, ...
            'HorizontalAlignment', textAlignments{colIdx}, ...
            'VerticalAlignment', 'middle', ...
            'FontWeight', fontWeight, ...
            'FontSize', 11, ...
            'Color', fontColor, ...
            'Interpreter', 'none');
    end
end

title(ax, 'Efficacy Score Rankings: Top Performing Configurations', ...
    'FontSize', 14, 'FontWeight', 'bold');

hold(ax, 'off');

% Save
save_figure(fig, figuresDir, 'efficacy_ranking_table.png');
close(fig);
end
