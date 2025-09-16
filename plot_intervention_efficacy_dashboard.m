function plot_intervention_efficacy_dashboard(summaryTable, costTable, healthExposureTable, figuresDir)
% PLOT_INTERVENTION_EFFICACY_DASHBOARD Create comprehensive dashboard showing intervention effectiveness
%
% This function creates a single figure with multiple panels that clearly show:
% - How effective each intervention is compared to baseline
% - The scenario bounds (tight vs leaky homes)
% - Cost-effectiveness relationships
% - Health benefits achieved
% - Building-specific recommendations

if isempty(summaryTable) || isempty(costTable) || isempty(healthExposureTable)
    warning('plot_intervention_efficacy_dashboard: no data provided, skipping plot.');
    return;
end

%% Setup
fig = figure('Visible','off', 'Color','white');
set_figure_fullscreen(fig);

% Define consistent color scheme
colorBaseline = [0.5 0.5 0.5];
colorHEPA = [0.2 0.4 0.8];
colorMERV = [0.8 0.3 0.3];
colorTriggered = [0.9 0.6 0.2];
colorAlwaysOn = [0.3 0.7 0.3];

% Super title
sgtitle('Air Quality Intervention Efficacy Dashboard Overview', 'FontSize', 18, 'FontWeight', 'bold');

%% Panel 1: PM2.5 Reduction Efficacy by Intervention
subplot(2,3,1)
plotReductionEfficacy(costTable, 'PM2.5');

%% Panel 2: Scenario Bounds Visualization
subplot(2,3,2)
plotScenarioBounds(costTable, summaryTable);

%% Panel 3: Cost-Effectiveness Bubble Chart
subplot(2,3,3)
plotCostEffectivenessBubble(costTable);

%% Panel 4: Cumulative Benefit Over Time
subplot(2,3,4)
plotCumulativeBenefit(summaryTable);

%% Panel 5: Building Envelope Sensitivity
subplot(2,3,5)
plotBuildingEnvelopeSensitivity(costTable);

%% Panel 6: Intervention Efficacy Scorecard
subplot(2,3,6)
plotEfficacyScorecard(costTable, healthExposureTable);

% Save the dashboard
if ~exist(figuresDir, 'dir')
    mkdir(figuresDir);
end
add_figure_caption(fig, sprintf(['Six coordinated panels summarize intervention performance: pollutant reduction, envelope bounds, cost-effectiveness, cumulative benefits, envelope sensitivity, and a scorecard.' newline ...
    'Consistent colors link scenarios across charts so you can trace how each strategy balances air quality gains, operating cost, and reliability.' newline ...
    'Use the dashboard to quickly identify which combinations deliver strong health benefits without triggering unacceptable costs.']));
save_figure(fig, figuresDir, 'intervention_efficacy_dashboard.png');
save_figure(fig, figuresDir, 'intervention_efficacy_dashboard_hires.png');
close(fig);

end

%% Helper Function 1: PM Reduction Efficacy
function plotReductionEfficacy(costTable, pollutant)
    % Extract data for non-baseline scenarios
    data = costTable(~strcmp(costTable.mode, 'baseline'), :);

    readablePollutant = format_pollutant_label(pollutant);
    
    % Group by location and filter type
    locations = unique(data.location);
    filters = unique(data.filterType);
    % Treat "active" and "triggered" as the same scenario
    modeVar = data.mode;
    if iscell(modeVar)
        modeVar(strcmp(modeVar,'triggered')) = {'active'};
    else
        modeVar(modeVar=="triggered") = "active";
    end
    modes = unique(modeVar);
    
    % Prepare data for grouped bar chart
    nLocs = length(locations);
    nFilts = length(filters);
    nModes = length(modes);
    
    % Create data matrix: rows = location-filter combos, cols = modes
    dataMatrix = zeros(nLocs * nFilts, nModes);
    errorMatrix = zeros(nLocs * nFilts, nModes);
    labels = cell(nLocs * nFilts, 1);
    
    idx = 0;
    for l = 1:nLocs
        for f = 1:nFilts
            idx = idx + 1;
            labels{idx} = sprintf('%s\n%s', locations{l}, filters{f});
            
            for m = 1:nModes
                % Get tight and leaky values
                baseMask = strcmp(data.location, locations{l}) & ...
                           strcmp(data.filterType, filters{f});
                if modes{m}=="active"
                    maskTight = baseMask & ...
                               (strcmp(data.mode, 'active') | strcmp(data.mode, 'triggered')) & ...
                               strcmp(data.leakage, 'tight');
                    maskLeaky = baseMask & ...
                               (strcmp(data.mode, 'active') | strcmp(data.mode, 'triggered')) & ...
                               strcmp(data.leakage, 'leaky');
                else
                    maskTight = baseMask & strcmp(data.mode, modes{m}) & ...
                               strcmp(data.leakage, 'tight');
                    maskLeaky = baseMask & strcmp(data.mode, modes{m}) & ...
                               strcmp(data.leakage, 'leaky');
                end
                
                if strcmp(pollutant, 'PM2.5')
                    valTight = data.percent_PM25_reduction(maskTight);
                    valLeaky = data.percent_PM25_reduction(maskLeaky);
                else
                    valTight = data.percent_PM10_reduction(maskTight);
                    valLeaky = data.percent_PM10_reduction(maskLeaky);
                end
                
                if ~isempty(valTight) && ~isempty(valLeaky)
                    dataMatrix(idx, m) = mean([valTight; valLeaky]);
                    errorMatrix(idx, m) = (max([valTight; valLeaky]) - min([valTight; valLeaky]))/2;
                end
            end
        end
    end
    
    % Create grouped bar chart with error bars
    b = bar(dataMatrix, 'grouped');
    hold on;
    
    % Add error bars
    ngroups = size(dataMatrix, 1);
    nbars = size(dataMatrix, 2);
    groupwidth = min(0.8, nbars/(nbars + 1.5));
    
    for i = 1:nbars
        x = (1:ngroups) - groupwidth/2 + (2*i-1) * groupwidth / (2*nbars);
        errorbar(x, dataMatrix(:,i), errorMatrix(:,i), 'k', 'linestyle', 'none', 'LineWidth', 1);
    end
    
    % Customize appearance
    set(gca, 'XTick', 1:length(labels), 'XTickLabel', labels);
    ylabel(sprintf('%s Concentration Reduction (Percent)', readablePollutant));
    title(sprintf('%s Reduction Efficacy', readablePollutant), 'FontWeight', 'bold');
    legend(modes, 'Location', 'best', 'Interpreter', 'none');
    grid on;
    ylim([0 max(dataMatrix(:) + errorMatrix(:)) * 1.1]);
    
    % Add reference line at 50% reduction
    yline(50, '--', 'LineWidth', 1, 'Color', [0.5 0.5 0.5], 'Label', '50% Target');
end

%% Helper Function 2: Scenario Bounds
function plotScenarioBounds(costTable, summaryTable)
    % Focus on PM2.5 reduction range
    data = costTable(~strcmp(costTable.mode, 'baseline'), :);
    
    % Calculate ranges
    configs = unique(data(:, {'location', 'filterType', 'mode'}));
    nConfigs = height(configs);
    
    boundsData = zeros(nConfigs, 3); % [mean, lower, upper]
    configLabels = cell(nConfigs, 1);
    
    for i = 1:nConfigs
        mask = strcmp(data.location, configs.location{i}) & ...
               strcmp(data.filterType, configs.filterType{i}) & ...
               strcmp(data.mode, configs.mode{i});
        
        tightMask = mask & strcmp(data.leakage, 'tight');
        leakyMask = mask & strcmp(data.leakage, 'leaky');
        
        if any(tightMask) && any(leakyMask)
            tightVal = data.percent_PM25_reduction(tightMask);
            leakyVal = data.percent_PM25_reduction(leakyMask);
            
            boundsData(i, 1) = mean([tightVal; leakyVal]);
            boundsData(i, 2) = min([tightVal; leakyVal]);
            boundsData(i, 3) = max([tightVal; leakyVal]);
            
            configLabels{i} = sprintf('%s-%s-%s', ...
                configs.location{i}(1:3), ...
                configs.filterType{i}(1:4), ...
                configs.mode{i}(1:4));
        end
    end
    
    % Sort by mean efficacy
    [~, sortIdx] = sort(boundsData(:,1), 'descend');
    
    % Create horizontal bar chart with error bars
    y = 1:nConfigs;
    barh(y, boundsData(sortIdx, 1), 'FaceColor', [0.3 0.6 0.9]);
    hold on;
    
    % Add error bars
    errorbar(boundsData(sortIdx, 1), y, ...
             boundsData(sortIdx, 1) - boundsData(sortIdx, 2), ...
             boundsData(sortIdx, 3) - boundsData(sortIdx, 1), ...
             'horizontal', 'k', 'LineStyle', 'none', 'LineWidth', 1.5);
    
    % Add annotations for range width
    for i = 1:nConfigs
        rangeWidth = boundsData(sortIdx(i), 3) - boundsData(sortIdx(i), 2);
        text(boundsData(sortIdx(i), 3) + 1, i, ...
             sprintf('±%.1f%%', rangeWidth/2), ...
             'VerticalAlignment', 'middle', 'FontSize', 8);
    end
    
    set(gca, 'YTick', y, 'YTickLabel', configLabels(sortIdx));
    xlabel('Particulate Matter 2.5 Reduction (Percent)');
    title('Efficacy Bounds Across Tight and Leaky Homes', 'FontWeight', 'bold');
    grid on;
    xlim([0, max(boundsData(:,3)) * 1.1]);
end

%% Helper Function 3: Cost-Effectiveness Bubble Chart
function plotCostEffectivenessBubble(costTable)
    data = costTable(~strcmp(costTable.mode, 'baseline'), :);
    
    % Prepare data
    x = data.percent_PM25_reduction;
    y = data.cost_per_ug_pm25_removed;
    z = data.AQI_hours_avoided;
    
    % Create color map based on intervention type
    colorMap = zeros(height(data), 3);
    for i = 1:height(data)
        if strcmp(data.filterType{i}, 'hepa')
            if strcmp(data.mode{i}, 'active') || strcmp(data.mode{i}, 'triggered')
                colorMap(i,:) = [0.2 0.4 0.8]; % Blue for HEPA active
            else
                colorMap(i,:) = [0.1 0.2 0.6]; % Dark blue for HEPA always on
            end
        else % MERV
            if strcmp(data.mode{i}, 'active') || strcmp(data.mode{i}, 'triggered')
                colorMap(i,:) = [0.8 0.3 0.3]; % Red for MERV active
            else
                colorMap(i,:) = [0.6 0.1 0.1]; % Dark red for MERV always on
            end
        end
    end
    
    % Create bubble chart
    scatter(x, y, z*2, colorMap, 'filled', 'MarkerEdgeColor', 'k', 'LineWidth', 0.5);
    
    % Add quadrant lines
    xMed = median(x, 'omitnan');
    yMed = median(y, 'omitnan');
    % Using plot to allow transparency on quadrant lines
    yl = ylim;
    plot([xMed xMed], yl, '--', 'Color', [0 0 0 0.5]);
    ylim(yl);
    xl = xlim;
    plot(xl, [yMed yMed], '--', 'Color', [0 0 0 0.5]);
    xlim(xl);
    
    % Annotations for quadrants
    text(max(x)*0.95, min(y)*1.1, 'High Efficacy, Low Cost', ...
         'HorizontalAlignment', 'right', 'VerticalAlignment', 'top', ...
         'FontWeight', 'bold', 'Color', [0 0.5 0]);
    text(min(x)*1.05, max(y)*0.9, 'Low Efficacy, High Cost', ...
         'HorizontalAlignment', 'left', 'VerticalAlignment', 'bottom', ...
         'FontWeight', 'bold', 'Color', [0.8 0 0]);
    
    xlabel('Particulate Matter 2.5 Reduction (Percent)');
    ylabel('Cost per Microgram per Cubic Meter of Pollutant Removed (Dollars)');
    title('Cost Effectiveness Analysis Across Configurations', 'FontWeight', 'bold');
    
    % Add legend for bubble size
    text(min(x), max(y)*0.8, 'Bubble size = AQI hours avoided', ...
         'FontSize', 9, 'FontAngle', 'italic');
    
    % Set y-axis to log scale if range is large
    if max(y)/min(y) > 100
        set(gca, 'YScale', 'log');
    end
    
    grid on;
end

%% Helper Function 4: Cumulative Benefit
function plotCumulativeBenefit(summaryTable)
    % Show cumulative PM2.5 exposure reduction over first week
    locations = unique(summaryTable.location);
    filters = unique(summaryTable.filterType(~strcmp(summaryTable.filterType, 'baseline')));
    
    colors = lines(length(filters) * 2); % For active and always_on
    legendEntries = {};
    colorIdx = 0;
    
    hold on;
    for loc = 1:length(locations)
        for filt = 1:length(filters)
            for mode = {'active', 'always_on'}
                colorIdx = colorIdx + 1;
                
                % Get baseline
                baselineMask = strcmp(summaryTable.location, locations{loc}) & ...
                              strcmp(summaryTable.mode, 'baseline');
                baselineRow = summaryTable(baselineMask, :);
                
                if isempty(baselineRow), continue; end
                
                % Get intervention
                baseMask = strcmp(summaryTable.location, locations{loc}) & ...
                           strcmp(summaryTable.filterType, filters{filt});
                if strcmp(mode{1}, 'active')
                    intMask = baseMask & (strcmp(summaryTable.mode, 'active') | ...
                                         strcmp(summaryTable.mode, 'triggered'));
                else
                    intMask = baseMask & strcmp(summaryTable.mode, mode{1});
                end
                intRows = summaryTable(intMask, :);
                
                if isempty(intRows), continue; end
                
                % Calculate cumulative benefit (average of tight and leaky)
                baselinePM = mean(cell2mat(baselineRow.indoor_PM25'), 1);
                intPM = mean(cell2mat(intRows.indoor_PM25'), 1);
                
                hourlyBenefit = baselinePM - intPM;
                cumulativeBenefit = cumsum(hourlyBenefit);
                
                % Plot first 168 hours (1 week)
                hours = 1:min(168, length(cumulativeBenefit));
                
                if loc == 1 % Only add to legend for first location
                    plot(hours, cumulativeBenefit(hours), ...
                         'Color', colors(colorIdx,:), 'LineWidth', 2, ...
                         'DisplayName', sprintf('%s-%s', filters{filt}, mode{1}));
                else
                    plot(hours, cumulativeBenefit(hours), ...
                         'Color', colors(colorIdx,:), 'LineWidth', 2, ...
                         'LineStyle', '--', 'HandleVisibility', 'off');
                end
            end
        end
    end
    
    xlabel('Time in Hours');
    ylabel('Cumulative Particulate Matter 2.5 Reduction (Microgram Hours per Cubic Meter)');
    title('Cumulative Exposure Benefit During First Week', 'FontWeight', 'bold');
    legend('Location', 'best', 'Interpreter', 'none');
    grid on;
    
    % Add annotation
    text(0.95, 0.05, 'Solid: Adams, Dashed: Baker', ...
         'Units', 'normalized', 'HorizontalAlignment', 'right', ...
         'VerticalAlignment', 'bottom', 'FontSize', 8, 'FontAngle', 'italic');
end

%% Helper Function 5: Building Envelope Sensitivity
function plotBuildingEnvelopeSensitivity(costTable)
    data = costTable(~strcmp(costTable.mode, 'baseline'), :);
    configs = unique(data(:, {'location', 'filterType', 'mode'}));
    
    sensitivity = zeros(height(configs), 2); % [PM2.5 sensitivity, Cost sensitivity]
    labels = cell(height(configs), 1);
    
    for i = 1:height(configs)
        mask = strcmp(data.location, configs.location{i}) & ...
               strcmp(data.filterType, configs.filterType{i}) & ...
               strcmp(data.mode, configs.mode{i});
        
        tightData = data(mask & strcmp(data.leakage, 'tight'), :);
        leakyData = data(mask & strcmp(data.leakage, 'leaky'), :);
        
        if ~isempty(tightData) && ~isempty(leakyData)
            % Calculate percent change from tight to leaky
            pm25Sens = 100 * (leakyData.percent_PM25_reduction - tightData.percent_PM25_reduction) / ...
                       tightData.percent_PM25_reduction;
            costSens = 100 * (leakyData.total_cost - tightData.total_cost) / ...
                       tightData.total_cost;
            
            sensitivity(i, :) = [abs(pm25Sens), abs(costSens)];
            labels{i} = sprintf('%s\n%s\n%s', ...
                               configs.location{i}, ...
                               configs.filterType{i}, ...
                               configs.mode{i});
        end
    end
    
    % Create diverging bar chart
    [~, sortIdx] = sort(sensitivity(:,1), 'descend');
    
    % Normalize data for visualization
    maxSens = max(sensitivity(:));
    normSens = sensitivity / maxSens * 100;
    
    x = 1:height(configs);
    
    % Plot PM2.5 sensitivity (positive direction)
    barh(x, normSens(sortIdx, 1), 'FaceColor', [0.3 0.6 0.9]);
    hold on;
    
    % Plot cost sensitivity (negative direction)
    barh(x, -normSens(sortIdx, 2), 'FaceColor', [0.9 0.3 0.3]);
    
    set(gca, 'YTick', x, 'YTickLabel', labels(sortIdx));
    xlabel('Relative Sensitivity to the Building Envelope (Percent)');
    title('Building Envelope Impact on Performance Metrics', 'FontWeight', 'bold');
    
    % Add center line
    xline(0, 'k', 'LineWidth', 1);
    
    % Add legend
    legend({'PM2.5 Efficacy', 'Operating Cost'}, 'Location', 'best');
    
    grid on;
    xlim([-100 100]);
end

%% Helper Function 6: Efficacy Scorecard
function plotEfficacyScorecard(costTable, healthExposureTable)
    % Calculate composite efficacy scores
    data = costTable(~strcmp(costTable.mode, 'baseline'), :);
    configs = unique(data(:, {'location', 'filterType', 'mode'}));
    
    scores = table();
    
    for i = 1:height(configs)
        loc = configs.location{i};
        filt = configs.filterType{i};
        mode = configs.mode{i};
        
        % Get average values across tight/leaky
        mask = strcmp(data.location, loc) & ...
               strcmp(data.filterType, filt) & ...
               strcmp(data.mode, mode);
        
        configData = data(mask, :);
        
        if isempty(configData), continue; end
        
        % Calculate metrics
        pm25Red = mean(configData.percent_PM25_reduction);
        pm10Red = mean(configData.percent_PM10_reduction);
        costEff = mean(1 ./ configData.cost_per_ug_pm25_removed) * 1000; % Normalize
        aqiAvoid = mean(configData.AQI_hours_avoided);
        
        % Calculate composite score (0-100 scale)
        % Weights: PM2.5 (40%), PM10 (20%), Cost (20%), AQI (20%)
        score = 0.4 * min(pm25Red, 100) + ...
                0.2 * min(pm10Red, 100) + ...
                0.2 * min(costEff, 100) + ...
                0.2 * min(aqiAvoid/10, 100); % Scale AQI hours
        
        % Build row
        row = table({loc}, {filt}, {mode}, pm25Red, pm10Red, ...
                   mean(configData.total_cost), aqiAvoid, score, ...
                   'VariableNames', {'location', 'filterType', 'mode', ...
                   'PM25_reduction', 'PM10_reduction', 'annual_cost', ...
                   'AQI_hours_avoided', 'efficacy_score'});
        
        scores = [scores; row];
    end
    
    % Sort by efficacy score
    scores = sortrows(scores, 'efficacy_score', 'descend');
    
    % Create table visualization
    cla; % Clear current axes
    axis off;
    
    % Title
    text(0.5, 0.95, 'Intervention Efficacy Scorecard', ...
         'HorizontalAlignment', 'center', 'FontSize', 14, 'FontWeight', 'bold');
    
    % Headers
    headers = {'Rank', 'Location', 'Filter', 'Mode', 'PM2.5↓', 'Cost/yr', 'Score'};
    y = 0.85;
    xPos = [0.05, 0.15, 0.3, 0.45, 0.6, 0.75, 0.9];
    
    for j = 1:length(headers)
        text(xPos(j), y, headers{j}, 'FontWeight', 'bold', 'FontSize', 10);
    end
    
    % Data rows (top 8)
    nRows = min(8, height(scores));
    for i = 1:nRows
        y = y - 0.08;
        
        % Rank
        text(xPos(1), y, num2str(i), 'FontSize', 9);
        
        % Location
        text(xPos(2), y, scores.location{i}, 'FontSize', 9);
        
        % Filter
        text(xPos(3), y, scores.filterType{i}, 'FontSize', 9);
        
        % Mode
        text(xPos(4), y, scores.mode{i}, 'FontSize', 9);
        
        % PM2.5 reduction
        text(xPos(5), y, sprintf('%.1f%%', scores.PM25_reduction(i)), 'FontSize', 9);
        
        % Cost
        text(xPos(6), y, sprintf('$%.0f', scores.annual_cost(i)), 'FontSize', 9);
        
        % Score with color coding
        scoreColor = [0 0.5 0]; % Green for good
        if scores.efficacy_score(i) < 50
            scoreColor = [0.8 0.8 0]; % Yellow for medium
        end
        if scores.efficacy_score(i) < 30
            scoreColor = [0.8 0 0]; % Red for poor
        end
        text(xPos(7), y, sprintf('%.1f', scores.efficacy_score(i)), ...
             'FontSize', 9, 'FontWeight', 'bold', 'Color', scoreColor);
    end
    
    % Add note at bottom
    text(0.5, 0.05, 'Score = 40% PM2.5 + 20% PM10 + 20% Cost-effectiveness + 20% AQI benefit', ...
         'HorizontalAlignment', 'center', 'FontSize', 8, 'FontAngle', 'italic');
    
    xlim([0 1]);
    ylim([0 1]);
end

function label = format_pollutant_label(pollutant)
%FORMAT_POLLUTANT_LABEL Provide descriptive pollutant labels for titles.

switch lower(pollutant)
    case {'pm2.5', 'pm25', 'pm_25'}
        label = 'Fine Particulate Matter Under 2.5 Micrometers';
    case {'pm10', 'pm_10'}
        label = 'Coarse Particulate Matter Under 10 Micrometers';
    otherwise
        label = strrep(pollutant, '_', ' ');
end
end
