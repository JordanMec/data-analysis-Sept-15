function eventTable = compute_event_metrics_table(config, pollutant, events, outdoor, indoor, params, timeVec, outFile)
%COMPUTE_EVENT_METRICS_TABLE Per-event metrics in tidy table form
%  TBL = COMPUTE_EVENT_METRICS_TABLE(CONFIG, POLLUTANT, EVENTS, OUTDOOR, INDOOR,
%  TIMEVEC, PARAMS, OUTFILE) computes metrics for each pollution event and
%  returns a table.  If OUTFILE is provided the table is also written using
%  writetable.  TIMEVEC may be empty if EVENTS already contain timestamps.
%
%  Metrics include:
%    - Timestamps: start, peaks, first indoor response, return-to-baseline (RTB), end
%    - Durations: event length, lag times, recovery time
%    - Amplitudes and attenuation
%    - AUC above baseline
%    - Optional decay half-life with fit quality
%    - Quality/diagnostic flags
%
%  The returned table stores metadata in TBL.Properties.UserData with fields
%  config, pollutant, params_version, created_at and git_hash.

% Input validation for Octave compatibility
if nargin < 7
    error('compute_event_metrics_table requires at least 7 inputs.');
end
if nargin < 8 || isempty(outFile)
    outFile = "";
end
if nargin < 6 || isempty(timeVec)
    timeVec = (1:numel(outdoor))';
end

validateattributes(config, {'char','string'}, {'scalartext'});
config = string(config);
validateattributes(pollutant, {'char','string'}, {'scalartext'});
assert(ismember(string(pollutant),["PM2.5","PM10"]), ...
    'compute_event_metrics_table:pollutant', ...
    'pollutant must be ''PM2.5'' or ''PM10''.');
pollutant = string(pollutant);

validateattributes(events, {'struct'}, {});
validateattributes(outdoor, {'numeric'}, {'column'});
validateattributes(indoor,  {'numeric'}, {'column'});
validateattributes(timeVec, {'numeric'}, {'column'});
validateattributes(params, {'struct'}, {});
validateattributes(outFile, {'char','string'}, {'row'});
outFile = string(outFile);

n = numel(events);
varNames = [
    "config","pollutant","event_id","start_idx","start_time","peak_out_idx",...
    "peak_out_time","peak_in_idx","peak_in_time","first_resp_idx",...
    "first_resp_time","rtb_idx","rtb_time","end_idx","end_time",...
    "duration","lag_peak","lag_first","recovery_time","amp_out",...
    "amp_in","attenuation","auc_out","auc_in","auc_reduction",...
    "half_life","fit_r2","flags"];
% There are 28 table variables total: two string columns at the beginning,
% one string column for flags at the end, and 25 numeric columns in between.
% Use a single repmat for the numeric columns to keep the counts in sync with
% varNames.
varTypes = [repmat("string",1,2), repmat("double",1,25), "string"];

eventTable = table('Size',[n,numel(varNames)], ...
    'VariableTypes',varTypes,'VariableNames',varNames);

for j = 1:n
    ev = events(j);
    win = ev.start:min(length(outdoor), ev.end + params.response.lookahead_hours);
    pre = max(1, ev.start - params.first_response.baseline_window_hours):ev.start-1;

    if isempty(pre)
        base_in = NaN;
        var_in = NaN;
    else
        if params.first_response.baseline_statistic=="median"
            base_in = median(indoor(pre),'omitnan');
        else
            base_in = mean(indoor(pre),'omitnan');
        end
        if params.first_response.variability_method=="mad"
            var_in = mad(indoor(pre),1,'omitnan');
        else
            var_in = std(indoor(pre),'omitnan');
        end
    end

    [in_peak, idx] = max(indoor(win));
    in_peak_idx = win(idx);
    first_idx = NaN;
    thr = base_in + max(params.first_response.abs_threshold, ...
        params.first_response.departure_multiplier*var_in);
    look = ev.start:min(numel(indoor), ev.start + params.response.lookahead_hours);
    r = find(indoor(look) > thr,1);
    if ~isempty(r)
        first_idx = look(r);
    end

    rtb_idx = NaN;
    hold = params.rtb.hold_time_hours;
    minAfter = params.rtb.min_data_hours;
    post = ev.end:min(numel(indoor), ev.end + params.response.lookahead_hours);
    if numel(indoor) - ev.end >= minAfter
        bandLow = base_in*(1 - params.rtb.tolerance_fraction);
        bandHigh = base_in*(1 + params.rtb.tolerance_fraction);
        for t = ev.end:post(end)-hold+1
            seg = indoor(t:t+hold-1);
            if all(seg >= bandLow & seg <= bandHigh)
                rtb_idx = t;
                break
            end
        end
    end

    amp_out = ev.peak_value - ev.baseline;
    amp_in = in_peak - base_in;
    if amp_out > 0
        attenuation = amp_in / amp_out;
    else
        attenuation = NaN;
    end

    out_excess = outdoor(win) - ev.baseline;
    in_excess = indoor(win) - base_in;
    auc_out = sum(out_excess(out_excess>0));
    auc_in  = sum(in_excess(in_excess>0));
    if auc_out>0
        auc_red = 1 - auc_in/auc_out;
    else
        auc_red = NaN;
    end

    half_life = NaN; r2 = NaN;
    tailEnd = post(end);
    decay_win = in_peak_idx:tailEnd;
    y = indoor(decay_win) - base_in;
    y = y(y>0);
    if numel(y) >= 3
        t = (0:numel(y)-1)';
        logy = log(y);
        p = polyfit(t,logy,1);
        k = -p(1);
        half_life = log(2)/k;
        yfit = polyval(p,t);
        ssres = sum((logy - yfit).^2);
        sstot = sum((logy - mean(logy)).^2);
        r2 = 1 - ssres/sstot;
    end

    fl = string.empty(0,1);
    if isfield(ev,'quality')
        qf = fieldnames(ev.quality);
        for q = qf'
            if ev.quality.(q{1})
                fl(end+1) = q{1};
            end
        end
    end
    if isnan(first_idx); fl(end+1) = "no_first_response"; end
    if isnan(rtb_idx) && params.rtb.flag_no_return
        fl(end+1) = "no_rtb";
    end
    if isnan(half_life); fl(end+1) = "decay_fit_fail"; end

    eventTable.config(j)       = config;
    eventTable.pollutant(j)    = pollutant;
    eventTable.event_id(j)     = j;
    eventTable.start_idx(j)    = ev.start;
    if isfield(ev,'start_time')
        eventTable.start_time(j) = ev.start_time;
    else
        eventTable.start_time(j) = NaN;
    end
    eventTable.peak_out_idx(j) = ev.peak_time;
    if isfield(ev,'peak_timestamp')
        eventTable.peak_out_time(j) = ev.peak_timestamp;
    else
        eventTable.peak_out_time(j) = NaN;
    end
    eventTable.peak_in_idx(j)  = in_peak_idx;
    if ~isempty(timeVec)
        eventTable.peak_in_time(j) = timeVec(in_peak_idx);
    else
        eventTable.peak_in_time(j) = NaN;
    end
    eventTable.first_resp_idx(j) = first_idx;
    if ~isnan(first_idx) && ~isempty(timeVec)
        eventTable.first_resp_time(j) = timeVec(first_idx);
    else
        eventTable.first_resp_time(j) = NaN;
    end
    eventTable.rtb_idx(j)     = rtb_idx;
    if ~isnan(rtb_idx) && ~isempty(timeVec)
        eventTable.rtb_time(j) = timeVec(rtb_idx);
    else
        eventTable.rtb_time(j) = NaN;
    end
    eventTable.end_idx(j)     = ev.end;
    if isfield(ev,'end_time')
        eventTable.end_time(j) = ev.end_time;
    else
        eventTable.end_time(j) = NaN;
    end
    eventTable.duration(j)    = ev.duration;
    eventTable.lag_peak(j)    = in_peak_idx - ev.peak_time;
    eventTable.lag_first(j)   = first_idx - ev.start;
    eventTable.recovery_time(j)= rtb_idx - ev.end;
    eventTable.amp_out(j)     = amp_out;
    eventTable.amp_in(j)      = amp_in;
    eventTable.attenuation(j) = attenuation;
    eventTable.auc_out(j)     = auc_out;
    eventTable.auc_in(j)      = auc_in;
    eventTable.auc_reduction(j)= auc_red;
    eventTable.half_life(j)   = half_life;
    eventTable.fit_r2(j)      = r2;
    eventTable.flags(j)       = strjoin(fl,';');
end

meta = struct();
meta.config = config;
meta.pollutant = pollutant;
meta.params_version = params.params_version;
meta.created_at = datestr(now,'yyyy-mm-dd HH:MM:SS');
meta.git_hash = params.git_hash;

eventTable.Properties.UserData = meta;

if strlength(outFile) > 0
    try
        writetable(eventTable,outFile)
    catch ME
        warning('Failed to write event table: %s', getReport(ME,'basic'))
    end
end

end