function plot_comprehensive_bounds(costTable, figuresDir)
% PLOT_COMPREHENSIVE_BOUNDS Visualize scenario bounds for key metrics
%   Creates a 2x2 tiled layout with horizontal bound bars for cost,
%   PM2.5 reduction, PM10 reduction and AQI hours avoided.

if isempty(costTable)
    warning('plot_comprehensive_bounds: no data provided, skipping plot.');
    return;
end

fig = figure('Visible','off');
set_figure_fullscreen(fig);
layout = tiledlayout(2,2,'TileSpacing','compact','Padding','compact');

% Unique configurations (without leakage dimension)
uniqueConfigs = unique(costTable(:, {'location','filterType','mode'}));
nConfigs = height(uniqueConfigs);
colors = lines(nConfigs);
labels = strings(nConfigs,1);

% Precompute metrics
costLower = zeros(nConfigs,1); costUpper = zeros(nConfigs,1); costMean = zeros(nConfigs,1);
pm25Lower = zeros(nConfigs,1); pm25Upper = zeros(nConfigs,1); pm25Mean = zeros(nConfigs,1);
pm10Lower = zeros(nConfigs,1); pm10Upper = zeros(nConfigs,1); pm10Mean = zeros(nConfigs,1);
aqiLower  = zeros(nConfigs,1); aqiUpper  = zeros(nConfigs,1); aqiMean  = zeros(nConfigs,1);

for i = 1:nConfigs
    loc = uniqueConfigs.location{i};
    filt = uniqueConfigs.filterType{i};
    mode = uniqueConfigs.mode{i};
    labels(i) = sprintf('%s-%s-%s', loc, filt, mode);

    row = costTable(strcmp(costTable.location, loc) & ...
                    strcmp(costTable.filterType, filt) & ...
                    strcmp(costTable.mode, mode), :);
    if isempty(row), continue; end

    costLower(i) = row.total_cost_lower;  costUpper(i) = row.total_cost_upper;  costMean(i) = row.total_cost;
    pm25Lower(i) = row.percent_PM25_reduction_lower;  pm25Upper(i) = row.percent_PM25_reduction_upper;  pm25Mean(i) = row.percent_PM25_reduction;
    pm10Lower(i) = row.percent_PM10_reduction_lower;  pm10Upper(i) = row.percent_PM10_reduction_upper;  pm10Mean(i) = row.percent_PM10_reduction;
    aqiLower(i)  = row.AQI_hours_avoided_lower;        aqiUpper(i)  = row.AQI_hours_avoided_upper;        aqiMean(i)  = row.AQI_hours_avoided;
end

%% Subplot 1: Cost bounds
nexttile(layout,1); hold on;
for i = 1:nConfigs
    plot([costLower(i) costUpper(i)], [i i], 'Color',colors(i,:), 'LineWidth',6);
    plot(costMean(i), i, 'o', 'MarkerFaceColor',colors(i,:), 'MarkerEdgeColor','k');
end
set(gca,'YTick',1:nConfigs,'YTickLabel',labels);
ylabel('Scenario');
xlabel('Total Cost ($)');
title('Cost Bounds');
box on; grid on;

%% Subplot 2: PM2.5 reduction bounds
nexttile(layout,2); hold on;
for i = 1:nConfigs
    plot([pm25Lower(i) pm25Upper(i)], [i i], 'Color',colors(i,:), 'LineWidth',6);
    plot(pm25Mean(i), i, 'o', 'MarkerFaceColor',colors(i,:), 'MarkerEdgeColor','k');
end
set(gca,'YTick',1:nConfigs,'YTickLabel',labels);
ylabel('Scenario');
xlabel('PM2.5 Reduction (%)');
title('PM2.5 Reduction Bounds');
box on; grid on;

%% Subplot 3: PM10 reduction bounds
nexttile(layout,3); hold on;
for i = 1:nConfigs
    plot([pm10Lower(i) pm10Upper(i)], [i i], 'Color',colors(i,:), 'LineWidth',6);
    plot(pm10Mean(i), i, 'o', 'MarkerFaceColor',colors(i,:), 'MarkerEdgeColor','k');
end
set(gca,'YTick',1:nConfigs,'YTickLabel',labels);
ylabel('Scenario');
xlabel('PM10 Reduction (%)');
title('PM10 Reduction Bounds');
box on; grid on;

%% Subplot 4: AQI hours avoided bounds with diagnostics
nexttile(layout,4); hold on;
for i = 1:nConfigs
    plot([aqiLower(i) aqiUpper(i)], [i i], 'Color',colors(i,:), 'LineWidth',6);
    plot(aqiMean(i), i, 'o', 'MarkerFaceColor',colors(i,:), 'MarkerEdgeColor','k');
    if aqiLower(i) == 0 && aqiUpper(i) > 0
        text(aqiUpper(i), i, ' \leftarrow zero lower bound', 'Color','r', 'FontSize',8);
    end
end
set(gca,'YTick',1:nConfigs,'YTickLabel',labels);
ylabel('Scenario');
xlabel('AQI Hours Avoided');
title('AQI Hours Avoided Bounds');
box on; grid on;

sgtitle('Comprehensive Scenario Bounds Analysis','FontSize',14,'FontWeight','bold');

save_figure(fig, figuresDir, 'comprehensive_bounds_analysis.png');
close(fig);
end