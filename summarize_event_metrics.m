function summary = summarize_event_metrics(eventTable, outCsv, outJson)
%SUMMARIZE_EVENT_METRICS Summarize pollution event metrics by config/pollutant
%   SUMMARY = SUMMARIZE_EVENT_METRICS(TBL, OUTCSV, OUTJSON) computes median
%   and interquartile range (IQR) of key response metrics grouped by
%   configuration and pollutant. Events with non-empty FLAGS or NaN metrics
%   are excluded from the calculations but counted in the output.  If
%   provided, OUTCSV and OUTJSON are file paths to save the summary table as
%   CSV and JSON respectively.
%
%   Metrics summarized:
%       - lag_peak        (hours)
%       - recovery_time   (hours)
%       - attenuation     (unitless)
%       - auc_reduction   (fraction)

arguments
    eventTable table
    outCsv string = ""
    outJson string = ""
end

% Identify flagged rows
flagged = strlength(eventTable.flags) > 0;

configs = [eventTable.config, eventTable.pollutant];
[G, names] = findgroups(configs);

nGroups = size(names,1);
fields = {"median_lag_peak","iqr_lag_peak",...
          "median_recovery","iqr_recovery",...
          "median_attenuation","iqr_attenuation",...
          "median_auc_reduction","iqr_auc_reduction"};
summaryData = nan(nGroups, numel(fields));
numEvents = zeros(nGroups,1);
numFlagged = zeros(nGroups,1);

for k = 1:nGroups
    idx = (G == k);
    numEvents(k) = sum(idx);
    numFlagged(k) = sum(flagged(idx));
    valid = idx & ~flagged & ...
        ~isnan(eventTable.lag_peak) & ~isnan(eventTable.recovery_time) & ...
        ~isnan(eventTable.attenuation) & ~isnan(eventTable.auc_reduction);
    % Metrics individually handle NaN so build per-metric arrays
    lagVals = eventTable.lag_peak(idx & ~flagged & ~isnan(eventTable.lag_peak));
    recVals = eventTable.recovery_time(idx & ~flagged & ~isnan(eventTable.recovery_time));
    attVals = eventTable.attenuation(idx & ~flagged & ~isnan(eventTable.attenuation));
    aucVals = eventTable.auc_reduction(idx & ~flagged & ~isnan(eventTable.auc_reduction));
    summaryData(k,1) = median(lagVals,'omitnan');
    q = prctile(lagVals,[25 75]);
    summaryData(k,2) = q(2)-q(1);

    summaryData(k,3) = median(recVals,'omitnan');
    q = prctile(recVals,[25 75]);
    summaryData(k,4) = q(2)-q(1);

    summaryData(k,5) = median(attVals,'omitnan');
    q = prctile(attVals,[25 75]);
    summaryData(k,6) = q(2)-q(1);

    summaryData(k,7) = median(aucVals,'omitnan');
    q = prctile(aucVals,[25 75]);
    summaryData(k,8) = q(2)-q(1);
end

summary = table(names(:,1), names(:,2), numEvents, numFlagged, summaryData(:,1), summaryData(:,2), ...
    summaryData(:,3), summaryData(:,4), summaryData(:,5), summaryData(:,6), ...
    summaryData(:,7), summaryData(:,8), ...
    'VariableNames',{ 'config','pollutant','n_events','n_flagged', ...
    'median_lag_peak','iqr_lag_peak', 'median_recovery','iqr_recovery', ...
    'median_attenuation','iqr_attenuation','median_auc_reduction','iqr_auc_reduction'});

if strlength(outCsv) > 0
    try
        writetable(summary,outCsv);
    catch ME
        warning('Failed to write summary CSV: %s',ME.message);
    end
end

if strlength(outJson) > 0
    try
        jsonText = jsonencode(summary);
        fid = fopen(outJson,'w');
        fwrite(fid,jsonText,'char');
        fclose(fid);
    catch ME
        warning('Failed to write summary JSON: %s',ME.message);
    end
end
end