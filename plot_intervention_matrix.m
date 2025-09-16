function plot_intervention_matrix(costTable, pollutant, figuresDir)
% PLOT_INTERVENTION_MATRIX Heatmap showing intervention efficacy with uncertainty
% Now shows mean values with uncertainty indicators

if isempty(costTable)
    warning('plot_intervention_matrix: no data provided, skipping plot.');
    return;
end

if nargin < 2 || isempty(pollutant)
    pollutant = 'PM25';
end

readablePollutant = format_pollutant_label(pollutant);

% Get unique configurations (no leakage grouping)
locations = unique(costTable.location);
filterTypes = unique(costTable.filterType(~strcmp(costTable.filterType, 'baseline')));
modes = unique(costTable.mode(~strcmp(costTable.mode, 'baseline')));

% Create intervention labels and keep track of modes for annotation
interventions = {};
intModes = {};
for f = 1:length(filterTypes)
    for m = 1:length(modes)
        interventions{end+1} = sprintf('%s\n%s', filterTypes{f}, modes{m});
        intModes{end+1} = modes{m};
    end
end

nLoc = length(locations);
nInt = length(interventions);

% Matrices for mean values and uncertainty
meanValues = nan(nLoc, nInt);
uncertainty = nan(nLoc, nInt);
lowerMatrix = nan(nLoc, nInt);
upperMatrix = nan(nLoc, nInt);

% Fill matrices
for l = 1:nLoc
    intIdx = 0;
    for f = 1:length(filterTypes)
        for m = 1:length(modes)
            intIdx = intIdx + 1;

            % Find matching row
            row = costTable(strcmp(costTable.location, locations{l}) & ...
                strcmp(costTable.filterType, filterTypes{f}) & ...
                strcmp(costTable.mode, modes{m}), :);

            if ~isempty(row)
                if strcmpi(pollutant, 'PM10')
                    meanValues(l, intIdx) = row.percent_PM10_reduction;
                    if ismember('percent_PM10_reduction_lower', row.Properties.VariableNames)
                        lowerMatrix(l, intIdx) = row.percent_PM10_reduction_lower;
                        upperMatrix(l, intIdx) = row.percent_PM10_reduction_upper;
                    else
                        lowerMatrix(l, intIdx) = meanValues(l, intIdx) * 0.9;
                        upperMatrix(l, intIdx) = meanValues(l, intIdx) * 1.1;
                    end
                else
                    meanValues(l, intIdx) = row.percent_PM25_reduction;
                    if ismember('percent_PM25_reduction_lower', row.Properties.VariableNames)
                        lowerMatrix(l, intIdx) = row.percent_PM25_reduction_lower;
                        upperMatrix(l, intIdx) = row.percent_PM25_reduction_upper;
                    else
                        lowerMatrix(l, intIdx) = meanValues(l, intIdx) * 0.9;
                        upperMatrix(l, intIdx) = meanValues(l, intIdx) * 1.1;
                    end
                end
                uncertainty(l, intIdx) = (upperMatrix(l, intIdx) - lowerMatrix(l, intIdx)) / 2;
            end
        end
    end
end

% Create figure
fig = figure('Visible', 'off');
set_figure_fullscreen(fig);
ax1 = axes('Parent', fig);

% Main heatmap
imagesc(ax1, meanValues);
colormap(ax1, parula);
yLimits = [0.5, nLoc + 0.5];
xLimits = [0.5, nInt + 0.5];
set(ax1, 'YDir', 'reverse', 'YLim', yLimits, 'XLim', xLimits);

validLower = lowerMatrix(isfinite(lowerMatrix));
validUpper = upperMatrix(isfinite(upperMatrix));
if isempty(validLower) || isempty(validUpper)
    validMeans = meanValues(isfinite(meanValues));
    vmin = min(validMeans, [], 'omitnan');
    vmax = max(validMeans, [], 'omitnan');
else
    vmin = min(validLower);
    vmax = max(validUpper);
end
if ~isfinite(vmin) || ~isfinite(vmax) || vmin == vmax
    vmin = min(meanValues(:), [], 'omitnan');
    vmax = max(meanValues(:), [], 'omitnan');
end
if ~isfinite(vmin) || ~isfinite(vmax) || vmin == vmax
    vmin = 0; vmax = 1;
end
caxis(ax1, [vmin vmax]);
cb = colorbar(ax1);
ylabel(cb, sprintf('Mean %s Concentration Reduction (Percent)', readablePollutant));

% Set labels
set(ax1, 'XTick', 1:nInt, 'XTickLabel', interventions);
set(ax1, 'YTick', 1:nLoc, 'YTickLabel', locations);
xlabel(ax1, 'Intervention Type');
ylabel(ax1, 'Location');
title(ax1, sprintf('%s Reduction Efficacy Matrix with Uncertainty', readablePollutant));

% Add text annotations with uncertainty
for l = 1:nLoc
    for i = 1:nInt
        if ~isnan(meanValues(l, i))
            lowerVal = lowerMatrix(l, i);
            upperVal = upperMatrix(l, i);
            textColor = 'k';
            if meanValues(l, i) > median(meanValues(:), 'omitnan')
                textColor = 'w';
            end
            label = format_bounds(meanValues(l, i), lowerVal, upperVal, ...
                'MeanFormat', '%.1f', 'BoundFormat', '%.1f', ...
                'Style', 'both', 'IncludeNewline', true);
            text(i, l-0.05, label, 'HorizontalAlignment', 'center', ...
                'Color', textColor, 'FontSize', 8, 'FontWeight', 'normal');
            text(i, l+0.32, intModes{i}, 'HorizontalAlignment', 'center', ...
                'Color', [0.4 0.4 0.4], 'FontSize', 7, 'Interpreter', 'none');
        end
    end
end

% Overlay range bars inside each cell to show tight vs. leaky bounds
axOverlay = axes('Position', get(ax1, 'Position'), 'Color', 'none', ...
    'XLim', [0.5, nInt + 0.5], 'YLim', [0.5, nLoc + 0.5], ...
    'YDir', 'reverse', 'HitTest', 'off');
axis(axOverlay, 'off');
hold(axOverlay, 'on');
scaleDenom = max(vmax - vmin, eps);
for l = 1:nLoc
    for i = 1:nInt
        if ~isnan(lowerMatrix(l, i)) && ~isnan(upperMatrix(l, i))
            lowerNorm = (lowerMatrix(l, i) - vmin) / scaleDenom;
            upperNorm = (upperMatrix(l, i) - vmin) / scaleDenom;
            lowerNorm = min(max(lowerNorm, 0), 1);
            upperNorm = min(max(upperNorm, 0), 1);
            cellLeft = i - 0.4;
            xLeft = cellLeft + lowerNorm * 0.8;
            xRight = cellLeft + upperNorm * 0.8;
            yCenter = l;
            plot(axOverlay, [xLeft xRight], [yCenter yCenter], 'k-', 'LineWidth', 1.2);
            plot(axOverlay, [xLeft xLeft], [yCenter-0.18 yCenter+0.18], 'k-', 'LineWidth', 1.2);
            plot(axOverlay, [xRight xRight], [yCenter-0.18 yCenter+0.18], 'k-', 'LineWidth', 1.2);
        end
    end
end
text(ax1, 0.02, 0.02, 'Range bars span tight (left) to leaky (right) outcomes', ...
    'Units', 'normalized', 'FontSize', 8, 'FontAngle', 'italic', ...
    'Color', [0 0 0]);

save_figure(fig, figuresDir, sprintf('intervention_matrix_%s_with_uncertainty.png', lower(pollutant)));
close(fig);
end

function label = format_pollutant_label(pollutant)
%FORMAT_POLLUTANT_LABEL Create descriptive pollutant labels for titles.

switch lower(pollutant)
    case {'pm2.5', 'pm25', 'pm_25'}
        label = 'Fine Particulate Matter Under 2.5 Micrometers';
    case {'pm10', 'pm_10'}
        label = 'Coarse Particulate Matter Under 10 Micrometers';
    otherwise
        label = strrep(pollutant, '_', ' ');
end
end
