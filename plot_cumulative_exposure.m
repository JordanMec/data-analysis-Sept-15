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

readablePmLabel = expand_pm_label(pmLabel);
if isempty(envLabel)
    yLabelText = sprintf('Cumulative %s Exposure (Microgram Hours per Cubic Meter)', readablePmLabel);
else
    yLabelText = sprintf('Cumulative %s %s Exposure (Microgram Hours per Cubic Meter)', envLabel, readablePmLabel);
end

if isempty(summaryTable)
    warning('plot_cumulative_exposure: no data provided, skipping plot.');
    return;
end

fig = figure('Visible','off');
set_figure_fullscreen(fig);
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
    title(sprintf('Cumulative Exposure for %s with %s Filter', ...
        strrep(loc, '_', ' '), strrep(filt, '_', ' ')));
    xlabel('Hour of the Year');
    ylabel(yLabelText);
    legend(legendEntries, 'Location','eastoutside');
    grid on;
end

if isempty(envLabel)
    sgTxt = sprintf('Cumulative %s Exposure Over Time', readablePmLabel);
else
    sgTxt = sprintf('Cumulative %s %s Exposure Over Time', envLabel, readablePmLabel);
end
sgtitle(sgTxt);
add_figure_caption(fig, sprintf(['Each panel compares baseline cumulative exposure against alternative operating modes for a given location and filter.' newline ...
    'Solid lines trace the average cumulative exposure while shaded ribbons bracket the full range observed across tight and leaky simulations.' newline ...
    'Seeing how quickly the colored curves diverge from the dashed baseline reveals when interventions meaningfully cut indoor pollutant dose.']));
save_figure(fig, figuresDir, fileName);
close(fig);
end

function readable = expand_pm_label(label)
%EXPAND_PM_LABEL Provide a descriptive particulate matter label for titles.

switch lower(label)
    case {'pm2.5', 'pm25', 'pm_25'}
        readable = 'Fine Particulate Matter Under 2.5 Micrometers';
    case {'pm10', 'pm_10'}
        readable = 'Coarse Particulate Matter Under 10 Micrometers';
    otherwise
        readable = strrep(label, '_', ' ');
end
end
