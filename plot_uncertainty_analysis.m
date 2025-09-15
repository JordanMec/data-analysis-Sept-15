function plot_uncertainty_analysis(uncertaintyAnalysis, saveDir)
%PLOT_UNCERTAINTY_ANALYSIS Visualize sources of uncertainty in active mode
%   plot_uncertainty_analysis(uncertaintyAnalysis, saveDir) summarizes building
%   envelope and system uncertainties with stacked bars and confidence intervals.

if isempty(fieldnames(uncertaintyAnalysis))
    warning('plot_uncertainty_analysis: no data provided, skipping plot.');
    return;
end

figure('Position', [100 100 1400 900], 'Visible', 'off');

configs = fieldnames(uncertaintyAnalysis);

% Scenario ranges
subplot(2, 2, 1);
pm25_ranges = [];
pm10_ranges = [];
labels = {};

for i = 1:length(configs)
    config = configs{i};
    data = uncertaintyAnalysis.(config);
    pm25_ranges(i) = data.pm25_range_percent;
    pm10_ranges(i) = data.pm10_range_percent;
    labels{i} = strrep(config, '_', '-');
end

x = 1:length(configs);
width = 0.35;
h25 = bar(x - width/2, pm25_ranges, width, 'FaceColor', [0.2 0.4 0.8]);
hold on;
h10 = bar(x + width/2, pm10_ranges, width, 'FaceColor', [0.8 0.3 0.3]);

set(gca, 'XTick', x, 'XTickLabel', labels);
xtickangle(45);
ylabel('Scenario Range (%)');
legend([h25 h10], {'PM2.5', 'PM10'}, 'Location', 'best');
title('Building Envelope Scenario Bounds');
grid on;

% Confidence intervals over time
subplot(2, 2, 2);
config = configs{1}; % Example
data = uncertaintyAnalysis.(config);

if isfield(data, 'hourly_ci_pm25')
    t = 1:min(168, size(data.hourly_ci_pm25, 2));

    % Plot confidence bands
    fill([t fliplr(t)], ...
         [data.hourly_ci_pm25(1,t) fliplr(data.hourly_ci_pm25(2,t))], ...
         [0.2 0.4 0.8], 'FaceAlpha', 0.3, 'EdgeColor', 'none');
    hold on;
    plot(t, data.hourly_mean_pm25(t), 'b-', 'LineWidth', 2);

    xlabel('Hour');
    % Use TeX interpreter for micro symbol and superscript
    ylabel('Indoor PM2.5 (\mu g/m^3)', 'Interpreter', 'tex');
    title(sprintf('Confidence Intervals - %s', config));
    legend({'Envelope Bounds', 'Mean'}, 'Location', 'best');
    grid on;
end

% Range contribution
subplot(2, 2, 3);
contribution_data = [];
contribution_labels = {'Building Envelope', 'Outdoor Variability', ...
                      'System Response', 'Measurement'};

for i = 1:length(configs)
    config = configs{i};
    data = uncertaintyAnalysis.(config);
    if isfield(data, 'uncertainty_contributions')
        contribution_data(:,i) = data.uncertainty_contributions;
    end
end

if ~isempty(contribution_data)
    % Sort so bars with the smallest contribution are plotted first (on top)
    avgContrib = mean(contribution_data, 2, 'omitnan');
    [~, order] = sort(avgContrib, 'ascend');
    contribution_data = contribution_data(order, :);
    contribution_labels = contribution_labels(order);

    colors = get_color_palette(numel(contribution_labels));
    b = bar(contribution_data', 'stacked', 'BarWidth', 0.9);
    for n = 1:numel(b)
        b(n).FaceColor = colors(n, :);
    end

    set(gca, 'XTick', 1:length(configs), 'XTickLabel', labels);
    xtickangle(45);
    ylabel('Contribution to Total Range (%)');
    legend(contribution_labels, 'Location', 'best');
    title('Scenario Bounds Source Analysis');
    grid on;
end

% Sensitivity analysis
subplot(2, 2, 4);
plot_sensitivity_tornado(uncertaintyAnalysis);

sgtitle('Scenario Bounds Quantification - Active Mode', 'FontSize', 14, 'FontWeight', 'bold');
save_figure(gcf, saveDir, 'uncertainty_analysis.png');
close(gcf);
end

function plot_sensitivity_tornado(uncertaintyAnalysis)
%PLOT_SENSITIVITY_TORNADO Display average uncertainty contributions
%   Creates a horizontal bar chart sorted by contribution magnitude.

configs = fieldnames(uncertaintyAnalysis);
contrib = [];
for i = 1:numel(configs)
    data = uncertaintyAnalysis.(configs{i});
    if isfield(data, 'uncertainty_contributions')
        contrib(:,end+1) = data.uncertainty_contributions(:);
    end
end

if isempty(contrib)
    title('Sensitivity Analysis');
    text(0.5,0.5,'No scenario bounds data','HorizontalAlignment','center');
    return;
end

avgContrib = mean(contrib,2,'omitnan');
[sortedVals, order] = sort(avgContrib,'descend');
labels = {'Building Envelope','Outdoor Variability','System Response','Measurement'};

barh(sortedVals, 'FaceColor', [0.4 0.6 0.8]);
set(gca,'YTick',1:numel(order),'YTickLabel',labels(order));
set(gca,'YDir','reverse');
xlabel('Contribution (%)');
title('Sensitivity Analysis');
grid on;
end