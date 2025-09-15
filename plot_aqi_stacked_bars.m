function plot_aqi_stacked_bars(healthExposureTable, figuresDir)
% PLOT_AQI_STACKED_BARS Create AQI exposure comparison with uncertainty bounds
% Shows stacked bars for mean exposure with error bars for tight/leaky bounds

arguments
    healthExposureTable table
    figuresDir          string
end

if isempty(healthExposureTable)
    warning('plot_aqi_stacked_bars: no data provided, skipping plot.');
    return;
end

% Check required columns
aqiNames = ["Good","Moderate","Unhealthy for Sensitive Groups", ...
    "Unhealthy","Very Unhealthy","Hazardous"];
requiredCols = ["location","filterType","scenario", aqiNames];
missingCols = setdiff(requiredCols, healthExposureTable.Properties.VariableNames);
if ~isempty(missingCols)
    error('Missing column: %s', missingCols{1});
end

if ~isfolder(figuresDir)
    mkdir(figuresDir);
end

% Get unique configurations (without leakage)
configs = unique(healthExposureTable(:,["location","filterType"]),"rows");
scenarios = ["baseline","active","always_on"];

% Create figure with proper sizing for publication quality
hFig = figure('Visible','off', 'Position',[0 0 1400 900]);
tiledlayout('flow','TileSpacing','compact','Padding','compact');

% AQI category colors (EPA standard) - ensure colorblind accessibility
aqiColors = [
    0.0 0.8 0.0;  % Good - Green
    1.0 1.0 0.0;  % Moderate - Yellow
    1.0 0.5 0.0;  % USG - Orange
    1.0 0.0 0.0;  % Unhealthy - Red
    0.5 0.0 0.5;  % Very Unhealthy - Purple
    0.5 0.0 0.0   % Hazardous - Maroon
];

for i = 1:height(configs)
    loc = configs.location{i};
    filt = configs.filterType{i};
    
    nexttile;
    
    % Get data for both envelopes
    dataTight = healthExposureTable(strcmp(healthExposureTable.location,loc) & ...
        strcmp(healthExposureTable.filterType,filt) & ...
        strcmp(healthExposureTable.leakage,'tight'), :);
    dataLeaky = healthExposureTable(strcmp(healthExposureTable.location,loc) & ...
        strcmp(healthExposureTable.filterType,filt) & ...
        strcmp(healthExposureTable.leakage,'leaky'), :);
    
    % Initialize data matrices
    meanData = zeros(numel(scenarios), numel(aqiNames));
    lowerData = zeros(numel(scenarios), numel(aqiNames));
    upperData = zeros(numel(scenarios), numel(aqiNames));
    totalMean = zeros(numel(scenarios), 1);
    totalLower = zeros(numel(scenarios), 1);
    totalUpper = zeros(numel(scenarios), 1);
    
    % Process each scenario
    for s = 1:numel(scenarios)
        scen = scenarios(s);
        
        % Handle active mode (includes triggered)
        if scen=="active"
            rowT = dataTight(strcmp(dataTight.scenario,"active") | ...
                             strcmp(dataTight.scenario,"triggered"), :);
            rowL = dataLeaky(strcmp(dataLeaky.scenario,"active") | ...
                             strcmp(dataLeaky.scenario,"triggered"), :);
        else
            rowT = dataTight(strcmp(dataTight.scenario,scen), :);
            rowL = dataLeaky(strcmp(dataLeaky.scenario,scen), :);
        end
        
        if ~isempty(rowT) && ~isempty(rowL)
            % Get hours for each AQI category
            hoursT = rowT{1, aqiNames};
            hoursL = rowL{1, aqiNames};
            
            % Calculate mean and bounds
            meanData(s,:) = (hoursT + hoursL) / 2;
            lowerData(s,:) = min(hoursT, hoursL);
            upperData(s,:) = max(hoursT, hoursL);
            
            % Total hours across all categories
            totalMean(s) = sum(meanData(s,:));
            totalLower(s) = sum(lowerData(s,:));
            totalUpper(s) = sum(upperData(s,:));
        end
    end
    
    % Create stacked bar chart
    b = bar(meanData, 'stacked', 'BarWidth', 0.7, 'LineWidth', 0.5);
    for k = 1:numel(b)
        b(k).FaceColor = aqiColors(k,:);
        b(k).EdgeColor = [0.2 0.2 0.2];
    end
    
    hold on;
    

    % Add error bars for each stacked category using individual bounds.
    % The error bars start at the top of each mean segment and extend to
    % the corresponding tight/leaky upper and lower limits.
    baseMean = [zeros(numel(scenarios),1) cumsum(meanData(:,1:end-1),2)];
    baseLower = [zeros(numel(scenarios),1) cumsum(lowerData(:,1:end-1),2)];
    baseUpper = [zeros(numel(scenarios),1) cumsum(upperData(:,1:end-1),2)];
    for s = 1:numel(scenarios)
        for j = 1:numel(aqiNames)
            if upperData(s,j) > 0 || lowerData(s,j) > 0
                yTopMean = baseMean(s,j) + meanData(s,j);
                yTopLower = baseLower(s,j) + lowerData(s,j);
                yTopUpper = baseUpper(s,j) + upperData(s,j);
                errLow = yTopMean - yTopLower;
                errHigh = yTopUpper - yTopMean;
                % Color coded error bars matching the AQI segment color
                errorbar(s, yTopMean, errLow, errHigh, ...
                    'Color', aqiColors(j,:), 'LineStyle', 'none', ...
                    'LineWidth', 1.5, 'CapSize', 8);
            end
        end
    end
    
    % Calculate hours avoided relative to baseline
    avoidedMean = zeros(numel(scenarios), 1);
    avoidedLower = zeros(numel(scenarios), 1);
    avoidedUpper = zeros(numel(scenarios), 1);
    
    for s = 2:numel(scenarios)  % Skip baseline
        % Corrected calculation using consistent envelope comparisons
        avoidedMean(s) = max(0, totalMean(1) - totalMean(s));
        
        % Conservative: compare best case baseline to worst case intervention
        avoidedLower(s) = max(0, totalLower(1) - totalUpper(s));
        
        % Optimistic: compare worst case baseline to best case intervention
        avoidedUpper(s) = max(0, totalUpper(1) - totalLower(s));
    end
    
    % Add avoided hours indicators with secondary error bars
    for s = 2:numel(scenarios)
        if avoidedMean(s) > 0 || avoidedUpper(s) > 0
            % Position secondary error bar at top of main bar
            yBase = totalMean(s);
            
            % Calculate asymmetric error for avoided hours
            errLowAvoided = avoidedMean(s) - avoidedLower(s);
            errHighAvoided = avoidedUpper(s) - avoidedMean(s);
            
            % Secondary error bar for avoided hours - positioned above the bar
            yCenter = totalUpper(s) + max(totalUpper)*0.03;
            
            h_avoided_err = errorbar(s, yCenter, errLowAvoided, errHighAvoided, ...
                'Color', [0.5 0.5 0.5], 'LineStyle', '-', 'LineWidth', 1.2, ...
                'CapSize', 6, 'Marker', 'o', 'MarkerSize', 4, ...
                'MarkerFaceColor', [0.5 0.5 0.5]);
            
            % Add text label positioned above the secondary error bar
            textYPos = yCenter + errHighAvoided + max(totalUpper)*0.02;
            text(s, textYPos, sprintf('−%.0f h', avoidedMean(s)), ...
                'HorizontalAlignment', 'center', 'VerticalAlignment', 'bottom', ...
                'FontSize', 10, 'FontWeight', 'bold');
        end
    end
    
    % Format axes
    set(gca, 'XTick', 1:numel(scenarios), 'XTickLabel', cellstr(scenarios), ...
        'FontSize', 10);
    ylabel('Hours', 'FontSize', 11);
    
    % Clean title formatting
    titleStr = sprintf('%s - %s', ...
        strrep(loc,'_',' '), strrep(filt,'_',' '));
    title(titleStr, 'FontSize', 12);
    
    grid on;
    box on;
    
    % Set y-limits with padding for annotations
    ylim([0 max(totalUpper) * 1.15]);
    
    % Add legend only to first subplot
    if i == 1
        lg = legend(cellstr(aqiNames), 'Location', 'eastoutside', 'FontSize', 9);
        lg.Title.String = 'AQI Categories';
    end

    % Add annotation about error bars (only once)
    if i == 1
        text(0.02, 0.98, 'Primary error bars: tight/leaky envelope bounds', ...
            'Units', 'normalized', 'VerticalAlignment', 'top', ...
            'FontSize', 9, 'FontAngle', 'italic', 'BackgroundColor', [1 1 1 0.8]);
        text(0.02, 0.93, 'Secondary error bars: avoided hours uncertainty', ...
            'Units', 'normalized', 'VerticalAlignment', 'top', ...
            'FontSize', 9, 'FontAngle', 'italic', 'BackgroundColor', [1 1 1 0.8]);
    end
end

% Overall title with clear description
sgtitle('Indoor AQI Exposure: Mean Values with Building Envelope Uncertainty', ...
    'FontSize', 14, 'FontWeight', 'bold');

% Save with high resolution
print(hFig, fullfile(figuresDir, 'aqi_exposure_with_bounds.png'), '-dpng', '-r300');
close(hFig);

end