function plot_cumulative_exposure(summaryTable, figuresDir, pmField, pmLabel, fileName)
% PLOT_CUMULATIVE_EXPOSURE  Plot cumulative exposure for a given pollutant
%   plot_cumulative_exposure(T, DIR) plots cumulative PM2.5 exposure using
%   data in table T and saves the output in DIR.  Additional arguments allow
%   customization of the PM field, label and output filename so the same
%   function can be used for PM10 as well.

if nargin < 3 || isempty(pmField);  pmField  = 'indoor_PM25'; end
if nargin < 4 || isempty(pmLabel);  pmLabel  = 'PM2.5';        end
if nargin < 5 || isempty(fileName); fileName = 'cumulative_pm25_exposure.png'; end

% Determine indoor/outdoor descriptor from pmField
envLabel = '';
if contains(lower(pmField), 'indoor')
    envLabel = 'Indoor';
elseif contains(lower(pmField), 'outdoor')
    envLabel = 'Outdoor';
end

if isempty(summaryTable)
    warning('plot_cumulative_exposure: no data provided, skipping plot.');
    return;
end

figure('Visible','off');
tiledlayout('flow');

uniqueConfigs = unique(summaryTable(:, {'location', 'filterType'}));

for i = 1:height(uniqueConfigs)
    nexttile

    loc = uniqueConfigs.location{i};
    filt = uniqueConfigs.filterType{i};

    rows = summaryTable(strcmp(summaryTable.location, loc) & ...
        strcmp(summaryTable.filterType, filt), :);
    if isempty(rows), continue; end

    baseRows = rows(strcmp(rows.mode,'baseline'), :);
    if isempty(baseRows), continue; end

    baseMat = cell2mat(baseRows.(pmField)');
    t = 1:size(baseMat,2);
    baseMean = mean(baseMat,1);
    baseCum = cumsum(baseMean);

    plot(t, baseCum, 'k--', 'LineWidth',1.5); hold on;
    legendEntries = {'Baseline (mean)'};

    modes = setdiff(unique(rows.mode), 'baseline');
    colors = lines(numel(modes));
    for j = 1:numel(modes)
        modeName = modes{j};
        mrows = rows(strcmp(rows.mode, modeName), :);
        if isempty(mrows), continue; end
        mat = cell2mat(mrows.(pmField)');
        cumMat = cumsum(mat,2);
        lowerBound = min(cumMat,[],1);
        upperBound = max(cumMat,[],1);
        mid = mean(cumMat,1);
        fill([t fliplr(t)], [lowerBound fliplr(upperBound)], colors(j,:), 'FaceAlpha',0.25,'EdgeColor','none');
        plot(t, mid, 'Color', colors(j,:), 'LineWidth',2);
        legendEntries{end+1} = sprintf('%s Range', modeName);
        legendEntries{end+1} = sprintf('%s Mean', modeName);
    end
    title(sprintf('%s - %s', loc, filt));
    xlabel('Hour of Year');
    if isempty(envLabel)
        ylabel(sprintf('Cumulative %s Exposure (µg/m³·h)', pmLabel));
    else
        ylabel(sprintf('Cumulative %s %s Exposure (µg/m³·h)', envLabel, pmLabel));
    end
    legend(legendEntries, 'Location','eastoutside');
    grid on;
end

if isempty(envLabel)
    sgTxt = sprintf('Cumulative %s Exposure Over Time', pmLabel);
else
    sgTxt = sprintf('Cumulative %s %s Exposure Over Time', envLabel, pmLabel);
end
sgtitle(sgTxt);
save_figure(gcf, figuresDir, fileName);
close(gcf);
end