function plot_aqi_time_avoided(avoidedTable, figuresDir)
% PLOT_AQI_TIME_AVOIDED Visualize hours avoided in each AQI category
%   Shows stacked bars similar to plot_aqi_stacked_bars but representing
%   how much time was kept below each category compared with outdoor levels.

arguments
    avoidedTable table
    figuresDir   string
end

if isempty(avoidedTable)
    warning('plot_aqi_time_avoided: no data provided, skipping plot.');
    return;
end

if ~isfolder(figuresDir)
    mkdir(figuresDir);
end

aqiNames = ["Good","Moderate","Unhealthy for Sensitive Groups", ...
    "Unhealthy","Very Unhealthy","Hazardous"];

configs = unique(avoidedTable(:,["location","filterType"]),"rows");
scenarios = ["baseline","active","always_on"];

hFig = figure('Visible','off','Position',[0 0 1400 900]);
tiledlayout('flow','TileSpacing','compact','Padding','compact');

aqiColors = [
    0.0 0.8 0.0;
    1.0 1.0 0.0;
    1.0 0.5 0.0;
    1.0 0.0 0.0;
    0.5 0.0 0.5;
    0.5 0.0 0.0];

for i = 1:height(configs)
    loc = configs.location{i};
    filt = configs.filterType{i};

    nexttile;
    dataTight = avoidedTable(strcmp(avoidedTable.location,loc) & ...
        strcmp(avoidedTable.filterType,filt) & strcmp(avoidedTable.leakage,'tight'),:);
    dataLeaky = avoidedTable(strcmp(avoidedTable.location,loc) & ...
        strcmp(avoidedTable.filterType,filt) & strcmp(avoidedTable.leakage,'leaky'),:);

    meanData = zeros(numel(scenarios), numel(aqiNames));
    lowerData = zeros(numel(scenarios), numel(aqiNames));
    upperData = zeros(numel(scenarios), numel(aqiNames));
    totalMean = zeros(numel(scenarios),1);
    totalLower = zeros(numel(scenarios),1);
    totalUpper = zeros(numel(scenarios),1);

    for s = 1:numel(scenarios)
        scen = scenarios(s);
        rowT = dataTight(strcmp(dataTight.mode,scen),:);
        rowL = dataLeaky(strcmp(dataLeaky.mode,scen),:);
        if ~isempty(rowT) && ~isempty(rowL)
            hoursT = rowT{1, aqiNames};
            hoursL = rowL{1, aqiNames};
            meanData(s,:) = (hoursT + hoursL)/2;
            lowerData(s,:) = min(hoursT,hoursL);
            upperData(s,:) = max(hoursT,hoursL);
            totalMean(s) = sum(meanData(s,:));
            totalLower(s) = sum(lowerData(s,:));
            totalUpper(s) = sum(upperData(s,:));
        end
    end

    b = bar(meanData,'stacked','BarWidth',0.7);
    for k = 1:numel(b)
        b(k).FaceColor = aqiColors(k,:);
        b(k).EdgeColor = [0.2 0.2 0.2];
    end
    hold on;


    % Add error bars for each stacked category reflecting the tight and
    % leaky bounds for that segment only.
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
                % Color coded error bars for clarity when segments overlap
                errorbar(s, yTopMean, errLow, errHigh, ...
                    'Color', aqiColors(j,:), 'LineStyle','none', ...
                    'LineWidth',1.5,'CapSize',8);
            end
        end
    end

    set(gca,'XTick',1:numel(scenarios),'XTickLabel',cellstr(scenarios));
    ylabel('Hours Avoided');
    title(sprintf('%s - %s',loc,filt),'Interpreter','none');
    grid on;
    ylim([0 max(totalUpper)*1.1]);

    if i==1
        legend(cellstr(aqiNames),'Location','eastoutside','FontSize',8);
        text(0.98,0.98,'Edges delineate small categories', ...
            'Units','normalized','HorizontalAlignment','right', ...
            'VerticalAlignment','top','FontSize',8,'FontAngle','italic');
        text(0.02,0.98,'Error bars show tight/leaky bounds', ...
            'Units','normalized','VerticalAlignment','top', ...
            'FontSize',8,'FontAngle','italic');
    end
end

sgtitle('Avoided AQI Exposure Time Relative to Outdoors', ...
    'FontSize',14,'FontWeight','bold');

print(hFig, fullfile(figuresDir,'aqi_time_avoided.png'), '-dpng','-r300');
close(hFig);
end