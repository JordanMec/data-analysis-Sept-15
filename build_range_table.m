function rangeTable = build_range_table(summaryTable, metricNames)
% BUILD_RANGE_TABLE Compute tight/leaky bounds with enhanced statistics
keys = unique(summaryTable(:, {'location','filterType','mode'}));
rows = height(keys);
nMetrics = numel(metricNames);

% Preallocate
loc = strings(rows*nMetrics,1);
filt = strings(rows*nMetrics,1);
mode = strings(rows*nMetrics,1);
metric = strings(rows*nMetrics,1);
tight_val = nan(rows*nMetrics,1);
leaky_val = nan(rows*nMetrics,1);
lower_bound = nan(rows*nMetrics,1);
upper_bound = nan(rows*nMetrics,1);
mean_val = nan(rows*nMetrics,1);
range_width = nan(rows*nMetrics,1);
range_percent = nan(rows*nMetrics,1);
% Range factor represents deterministic envelope spread (tight vs leaky)
range_factor = nan(rows*nMetrics,1);

idx = 0;
for i = 1:rows
    sel = strcmp(summaryTable.location, keys.location{i}) & ...
        strcmp(summaryTable.filterType, keys.filterType{i}) & ...
        strcmp(summaryTable.mode, keys.mode{i});
    tightRow = summaryTable(sel & strcmp(summaryTable.leakage,'tight'), :);
    leakyRow = summaryTable(sel & strcmp(summaryTable.leakage,'leaky'), :);

    if isempty(tightRow) || isempty(leakyRow)
        warning('build_range_table:MissingPair', ...
            'Missing tight or leaky results for %s-%s-%s', ...
            keys.location{i}, keys.filterType{i}, keys.mode{i});
        for m = 1:nMetrics
            idx = idx + 1;
            loc(idx) = keys.location{i};
            filt(idx) = keys.filterType{i};
            mode(idx) = keys.mode{i};
            metric(idx) = metricNames{m};
            tight_val(idx) = NaN;
            leaky_val(idx) = NaN;
            lower_bound(idx) = NaN;
            upper_bound(idx) = NaN;
            mean_val(idx) = NaN;
            range_width(idx) = NaN;
            range_percent(idx) = NaN;
            range_factor(idx) = NaN;
        end
        continue;
    end

    for m = 1:nMetrics
        idx = idx + 1;
        metricName = metricNames{m};
        valT = tightRow.(metricName);
        valL = leakyRow.(metricName);

        % Store base values
        loc(idx) = keys.location{i};
        filt(idx) = keys.filterType{i};
        mode(idx) = keys.mode{i};
        metric(idx) = metricName;
        tight_val(idx) = valT;
        leaky_val(idx) = valL;

        % Compute bounds (min/max regardless of which is tight/leaky)
        lower_bound(idx) = min(valT, valL);
        upper_bound(idx) = max(valT, valL);
        mean_val(idx) = (valT + valL) / 2;

        % Range metrics
        range_width(idx) = upper_bound(idx) - lower_bound(idx);
        if mean_val(idx) ~= 0
            range_percent(idx) = 100 * range_width(idx) / abs(mean_val(idx));
        else
            range_percent(idx) = 0;
        end

        % Range factor (deterministic envelope spread relative to mean)
        if mean_val(idx) ~= 0
            range_factor(idx) = upper_bound(idx) / mean_val(idx);
        else
            range_factor(idx) = 1;
        end
    end
end

% Create enhanced range table
rangeTable = table(loc(1:idx), filt(1:idx), mode(1:idx), metric(1:idx), ...
    tight_val(1:idx), leaky_val(1:idx), ...
    lower_bound(1:idx), upper_bound(1:idx), mean_val(1:idx), ...
    range_width(1:idx), range_percent(1:idx), range_factor(1:idx), ...
    'VariableNames',{ 'location','filterType','mode','metric', ...
    'tight_value','leaky_value', ...
    'lower_bound','upper_bound','mean', ...
    'range_width','range_percent','range_factor'});

% Sort by range_percent to identify metrics with highest uncertainty
rangeTable = sortrows(rangeTable, 'range_percent', 'descend');
end