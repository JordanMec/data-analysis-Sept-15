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
                        range = row.percent_PM10_reduction_upper - row.percent_PM10_reduction_lower;
                        uncertainty(l, intIdx) = range / 2; % Half-range
                    else
                        uncertainty(l, intIdx) = meanValues(l, intIdx) * 0.1; % 10% estimate
                    end
                else
                    meanValues(l, intIdx) = row.percent_PM25_reduction;
                    if ismember('percent_PM25_reduction_lower', row.Properties.VariableNames)
                        range = row.percent_PM25_reduction_upper - row.percent_PM25_reduction_lower;
                        uncertainty(l, intIdx) = range / 2;
                    else
                        uncertainty(l, intIdx) = meanValues(l, intIdx) * 0.1;
                    end
                end
            end
        end
    end
end

% Create figure
fig = figure('Position', [100 100 1000 600], 'Visible', 'off');
ax1 = axes('Parent', fig);

% Main heatmap
imagesc(ax1, meanValues);
colormap(ax1, parula);
cb = colorbar(ax1);
ylabel(cb, sprintf('%s Reduction (%%) - Mean Value', pollutant));

% Set labels
set(ax1, 'XTick', 1:nInt, 'XTickLabel', interventions);
set(ax1, 'YTick', 1:nLoc, 'YTickLabel', locations);
xlabel(ax1, 'Intervention Type');
ylabel(ax1, 'Location');
title(ax1, sprintf('%s Reduction Efficacy Matrix with Uncertainty', pollutant));

% Add text annotations with uncertainty
for l = 1:nLoc
    for i = 1:nInt
        if ~isnan(meanValues(l, i))
            % Format text based on uncertainty level
            if uncertainty(l, i) < 2
                % Low uncertainty - show just mean
                txt = sprintf('%.1f', meanValues(l, i));
                fontWeight = 'bold';
            elseif uncertainty(l, i) < 5
                % Medium uncertainty - show with ±
                txt = sprintf('%.0f±%.0f', meanValues(l, i), uncertainty(l, i));
                fontWeight = 'normal';
            else
                % High uncertainty - emphasize range
                txt = sprintf('%.0f±%.0f', meanValues(l, i), uncertainty(l, i));
                fontWeight = 'normal';
            end

            % Color text based on value
            if meanValues(l, i) > median(meanValues(:), 'omitnan')
                textColor = 'w';
            else
                textColor = 'k';
            end

            text(i, l-0.1, txt, 'HorizontalAlignment', 'center', ...
                'Color', textColor, 'FontSize', 9, 'FontWeight', fontWeight);

            % Add intervention type annotation slightly below
            text(i, l+0.25, intModes{i}, 'HorizontalAlignment', 'center', ...
                'Color', [0.4 0.4 0.4], 'FontSize', 7, 'Interpreter', 'none');
        end
    end
end

save_figure(fig, figuresDir, sprintf('intervention_matrix_%s_with_uncertainty.png', lower(pollutant)));
close(fig);
end