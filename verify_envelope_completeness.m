function verify_envelope_completeness(summaryTable)
% VERIFY_ENVELOPE_COMPLETENESS Ensure tight and leaky data exist for all scenarios
% and that summary metrics lie within those bounds.

metrics = {'avg_indoor_PM25','avg_indoor_PM10','total_cost','filter_replaced'};
configs = unique(summaryTable(:, {'location','filterType','mode'}));

for i = 1:height(configs)
    loc  = configs.location{i};
    filt = configs.filterType{i};
    mode = configs.mode{i};

    rows = summaryTable(strcmp(summaryTable.location,loc) & ...
        strcmp(summaryTable.filterType,filt) & ...
        strcmp(summaryTable.mode,mode), :);

    assert(height(rows) >= 2, 'verify_envelope_completeness:MissingData', ...
        'Missing tight or leaky results for %s-%s-%s', loc, filt, mode);

    tRow = rows(strcmp(rows.leakage,'tight'), :);
    lRow = rows(strcmp(rows.leakage,'leaky'), :);

    assert(~isempty(tRow) && ~isempty(lRow), 'verify_envelope_completeness:MissingData', ...
        'Missing tight or leaky results for %s-%s-%s', loc, filt, mode);

    % Indoor time series must have equal length
    lenT = numel(tRow.indoor_PM25{1});
    lenL = numel(lRow.indoor_PM25{1});
    if lenT ~= lenL
        error('verify_envelope_completeness:LengthMismatch', ...
            'Indoor time series length mismatch for %s-%s-%s', loc, filt, mode);
    end

    % Warn if outdoor time series differ
    if any(abs(tRow.outdoor_PM25{1} - lRow.outdoor_PM25{1}) > 1e-6) || ...
       any(abs(tRow.outdoor_PM10{1} - lRow.outdoor_PM10{1}) > 1e-6)
        warning('verify_envelope_completeness:OutdoorMismatch', ...
            'Outdoor time series differ for %s-%s-%s', loc, filt, mode);
    end

    for m = 1:numel(metrics)
        metric = metrics{m};
        low  = min(tRow.(metric), lRow.(metric));
        high = max(tRow.(metric), lRow.(metric));
        vals = rows.(metric);
        if any(vals < low - 1e-6 | vals > high + 1e-6)
            error('verify_envelope_completeness:OutOfBounds', ...
                'Value for %s-%s-%s metric %s outside tight/leaky bounds', ...
                loc, filt, mode, metric);
        end
    end
end

fprintf('✓ Envelope completeness verified\n');
end