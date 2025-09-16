function plot_pm_envelope(summaryTable, figuresDir, pmField, pmLabel, prefix, showThresholds)
% PLOT_PM_ENVELOPE envelope plot with statistical bounds
%   showThresholds - when true, overlay EPA AQI category thresholds

if nargin < 3 || isempty(pmField), pmField = 'indoor_PM25'; end
if nargin < 4 || isempty(pmLabel), pmLabel = 'PM2.5'; end
if nargin < 5 || isempty(prefix), prefix = 'pm25_envelope'; end
if nargin < 6 || isempty(showThresholds), showThresholds = false; end

% Determine indoor/outdoor descriptor based on the pmField name
envLabel = '';
if contains(lower(pmField), 'indoor')
    envLabel = 'Indoor';
elseif contains(lower(pmField), 'outdoor')
    envLabel = 'Outdoor';
end

readablePmLabel = expand_pm_label(pmLabel);
if isempty(envLabel)
    concentrationLabel = sprintf('%s Concentration (Micrograms per Cubic Meter)', readablePmLabel);
else
    concentrationLabel = sprintf('%s %s Concentration (Micrograms per Cubic Meter)', envLabel, readablePmLabel);
end

configs = unique(summaryTable(:, {'location','filterType'}));

for i = 1:height(configs)
    loc = configs.location{i};
    filt = configs.filterType{i};

    % Robustly handle different data types that may appear in the table
    % Convert to char array for consistent handling
    if iscell(loc)
        loc = loc{1};
    end
    if iscell(filt)
        filt = filt{1};
    end

    % Convert to char if not already
    if ~ischar(loc)
        if isstring(loc)
            loc = char(loc);
        else
            loc = char(string(loc));
        end
    end
    if ~ischar(filt)
        if isstring(filt)
            filt = char(filt);
        else
            filt = char(string(filt));
        end
    end

    rows = summaryTable(strcmp(summaryTable.location, loc) & ...
        strcmp(summaryTable.filterType, filt), :);
    if isempty(rows), continue; end

    % Create sophisticated multi-panel figure
    fig = figure('Visible','off');
    set_figure_fullscreen(fig);
    tiledlayout(2,2,'TileSpacing','compact','Padding','compact');

    modes = unique(rows.mode);
    % Use a dynamic palette in case the data contains additional modes
    colors = get_color_palette(numel(modes));

    %% Panel 1: Time series with envelope
    nexttile([1 2]); % Span two columns
    hold on;

    legendEntries = {};
    for m = 1:numel(modes)
        modeName = modes{m};
        tRow = rows(strcmp(rows.leakage,'tight') & strcmp(rows.mode,modeName), :);
        lRow = rows(strcmp(rows.leakage,'leaky') & strcmp(rows.mode,modeName), :);
        if isempty(tRow) || isempty(lRow), continue; end

        seriesT = tRow.(pmField){1};
        seriesL = lRow.(pmField){1};

        % Ensure both series have the same length
        minLen = min(length(seriesT), length(seriesL));
        seriesT = seriesT(1:minLen);
        seriesL = seriesL(1:minLen);
        t = 1:minLen;

        % Calculate envelope statistics
        lowerBound = min(seriesT, seriesL);
        upperBound = max(seriesT, seriesL);

        % Force row orientation so "fill" receives matching vector lengths
        lowerBound = lowerBound(:)';
        upperBound = upperBound(:)';
        t = t(:)';
        mid = (seriesT + seriesL) / 2;

        % Plot envelope with gradient fill
        if strcmp(modeName,'baseline')
            alpha = 0.2;
            lineStyle = '--';
        else
            alpha = 0.3;
            lineStyle = '-';
        end

        fill([t fliplr(t)], [lowerBound fliplr(upperBound)], colors(m,:), ...
            'FaceAlpha',alpha, 'EdgeColor','none','HandleVisibility','off');

        % Plot mean line
        plot(t, mid, 'Color', colors(m,:), 'LineWidth',2, 'LineStyle',lineStyle);

        % Add percentile lines (25th and 75th)
        pct25 = lowerBound + 0.25*(upperBound-lowerBound);
        pct75 = lowerBound + 0.75*(upperBound-lowerBound);
        plot(t, pct25, ':', 'Color', colors(m,:)*0.7, 'LineWidth',1,'HandleVisibility','off');
        plot(t, pct75, ':', 'Color', colors(m,:)*0.7, 'LineWidth',1,'HandleVisibility','off');

        legendEntries{end+1} = sprintf('%s (mean)', modeName);
    end

    xlabel('Hour of the Year');
    ylabel(concentrationLabel);
    title(sprintf('Hourly Concentration Bounds for %s with %s Filter', ...
        strrep(loc, '_', ' '), strrep(filt, '_', ' ')));
    legend(legendEntries, 'Location', 'best');
    grid on;
    xlim([1 length(t)]);

    % Optionally overlay EPA AQI thresholds
    if showThresholds
        switch upper(pmLabel)
            case 'PM2.5'
                % Thresholds between AQI categories (above "Good")
                thresh = [9.0 35.4 55.4 125.4 225.4];
            case 'PM10'
                thresh = [54.0 154.0 254.0 354.0 424.0];
            otherwise
                thresh = [];
        end
        categories = {'Moderate','Unhealthy for Sensitive Groups','Unhealthy', ...
            'Very Unhealthy','Hazardous'};
        colorsAQI = [ ...
            1 1 0;        % Yellow
            1 0.5 0;      % Orange
            1 0 0;        % Red
            0.5 0 0.5;    % Purple
            0.5 0 0];     % Maroon

        for th = 1:numel(thresh)
            if th <= size(colorsAQI,1)
                c = colorsAQI(th,:);
            else
                c = [0 0 0];
            end
            yline(thresh(th), ':', categories{th}, 'Color', c, ...
                'LabelHorizontalAlignment','left', 'LabelVerticalAlignment','bottom');
        end
    end
    legend(legendEntries, 'Location','eastoutside');
    grid on;
    xlim([1 length(t)]);

    %% Panel 2: Statistical distribution
    nexttile;
    hold on;

    binEdges = linspace(0, max(summaryTable.avg_outdoor_PM25)*1.2, 50);
    for m = 1:numel(modes)
        modeName = modes{m};
        tRow = rows(strcmp(rows.leakage,'tight') & strcmp(rows.mode,modeName), :);
        lRow = rows(strcmp(rows.leakage,'leaky') & strcmp(rows.mode,modeName), :);
        if isempty(tRow) || isempty(lRow), continue; end

        % Ensure both series have the same length for combining
        seriesT_hist = tRow.(pmField){1};
        seriesL_hist = lRow.(pmField){1};
        minLen_hist = min(length(seriesT_hist), length(seriesL_hist));

        % Combine tight and leaky data
        allData = [seriesT_hist(1:minLen_hist); seriesL_hist(1:minLen_hist)];
        h = histogram(allData, binEdges, 'FaceColor', colors(m,:), ...
            'FaceAlpha', 0.5, 'EdgeColor', 'none', 'Normalization', 'probability');

        % Add kernel density estimate
        if ~isempty(allData) && numel(unique(allData)) > 1
            [f,xi] = ksdensity(allData, 'Bandwidth', 0.5);
            plot(xi, f*max(h.Values)/max(f), 'Color', colors(m,:), 'LineWidth', 2);
        end
    end

    xlabel(concentrationLabel);
    ylabel('Probability');
    title('Distribution Across Building Envelopes');
    legend(modes, 'Location','eastoutside');
    grid on;

    %% Panel 3: Bounds width over time
    nexttile;
    hold on;

    for m = 1:numel(modes)
        modeName = modes{m};
        tRow = rows(strcmp(rows.leakage,'tight') & strcmp(rows.mode,modeName), :);
        lRow = rows(strcmp(rows.leakage,'leaky') & strcmp(rows.mode,modeName), :);
        if isempty(tRow) || isempty(lRow), continue; end

        seriesT_bounds = tRow.(pmField){1};
        seriesL_bounds = lRow.(pmField){1};

        % Ensure same length
        minLen_bounds = min(length(seriesT_bounds), length(seriesL_bounds));
        seriesT_bounds = seriesT_bounds(1:minLen_bounds);
        seriesL_bounds = seriesL_bounds(1:minLen_bounds);

        % Calculate rolling bounds width
        windowSize = 24; % 24-hour window
        boundsWidth = movmean(abs(seriesT_bounds - seriesL_bounds), windowSize);
        relativeBounds = 100 * boundsWidth ./ movmean((seriesT_bounds+seriesL_bounds)/2, windowSize);

        plot(1:length(boundsWidth), relativeBounds, ...
            'Color', colors(m,:), 'LineWidth', 1.5);
    end

    xlabel('Hour of the Year');
    ylabel('Relative Bounds Width (Percent)');
    title('Concentration Range Over Time');
    legend(modes, 'Location','eastoutside');
    grid on;

    % Overall title
    cleanLoc = strrep(loc, '_', ' ');
    cleanFilt = strrep(filt, '_', ' ');
    if isempty(envLabel)
        sgTitle = sprintf('Comprehensive %s Analysis for %s with %s Filter', ...
            readablePmLabel, cleanLoc, cleanFilt);
    else
        sgTitle = sprintf('Comprehensive %s %s Analysis for %s with %s Filter', ...
            envLabel, readablePmLabel, cleanLoc, cleanFilt);
    end
    sgtitle(sgTitle, 'FontSize',14,'FontWeight','bold');
    % Save
    % Build safe file name components with improved error handling
    locStr = regexprep(loc, '\s+', '_');
    filtStr = regexprep(filt, '\s+', '_');

    % Make filename-safe versions
    locStr = matlab.lang.makeValidName(locStr);
    filtStr = matlab.lang.makeValidName(filtStr);

    fname = sprintf('%s_%s_%s_enhanced.png', prefix, locStr, filtStr);
    add_figure_caption(fig, sprintf(['The top panel shows the hourly concentration envelope for tight and leaky runs, with mean and percentile lines to highlight the typical range.' newline ...
        'The lower left panel compares the overall distribution of concentrations across envelopes, and the lower right panel tracks how wide the bounds are over time.' newline ...
        'Together these views explain both the magnitude and variability of %s concentrations for %s using a %s filter.'], readablePmLabel, cleanLoc, cleanFilt));
    save_figure(fig, figuresDir, fullfile(locStr, filtStr), fname);
    close(fig);
end

end

function readable = expand_pm_label(label)
%EXPAND_PM_LABEL Provide descriptive particulate matter labels for titles.

switch lower(label)
    case {'pm2.5', 'pm25', 'pm_25'}
        readable = 'Fine Particulate Matter Under 2.5 Micrometers';
    case {'pm10', 'pm_10'}
        readable = 'Coarse Particulate Matter Under 10 Micrometers';
    otherwise
        readable = strrep(label, '_', ' ');
end
end
