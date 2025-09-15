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
figure('Position',[100 100 1400 900],'Visible','off');
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

% Plot tight vs leaky scores
plot(1:nConfigs, efficacyScoreTable.tight_efficacy_score, 'o-', ...
    'Color', cmap.tight, 'LineWidth', 2, 'MarkerSize', 6, 'DisplayName', 'Tight Envelope');
plot(1:nConfigs, efficacyScoreTable.leaky_efficacy_score, 's--', ...
    'Color', cmap.leaky, 'LineWidth', 2, 'MarkerSize', 6, 'DisplayName', 'Leaky Envelope');

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
save_figure(gcf, figuresDir, 'efficacy_scores_comprehensive.png');
close(gcf);

%% Create summary ranking table visualization
create_efficacy_ranking_table(efficacyScoreTable, figuresDir);

end

function create_efficacy_ranking_table(efficacyScoreTable, figuresDir)
% Create a clean table visualization of the ranking

figure('Position',[100 100 1000 600],'Visible','off');
ax = axes('Position',[0.1 0.1 0.8 0.8]);
axis off;

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

% Create table
tbl = uitable('Parent', gcf, 'Data', tableData, ...
    'Units', 'normalized', 'Position', [0.05 0.05 0.9 0.9], ...
    'FontSize', 10, 'RowName', []);

% Style header
tbl.BackgroundColor = [ones(1,3); repmat([0.95 0.95 0.95; 1 1 1], ceil(nRows/2), 1)];

title('Efficacy Score Rankings: Top Performing Configurations', ...
    'FontSize', 14, 'FontWeight', 'bold');

% Save
save_figure(gcf, figuresDir, 'efficacy_ranking_table.png');
close(gcf);
end