function params = get_analysis_params(resultsDir)
%GET_ANALYSIS_PARAMS Accessor for analysis parameters.
%   PARAMS = GET_ANALYSIS_PARAMS(RESULTSDIR) returns a struct containing
%   all tunable parameters for the analysis pipeline. If a parameter file
%   exists in RESULTSDIR named "analysis_params.mat", it is loaded and
%   returned. Otherwise default values are created, saved, and returned.
%
%   Each parameter is documented below. Units are in comments where
%   applicable so future users can adjust values easily.

if nargin < 1
    resultsDir = '';
end

paramFile = fullfile(resultsDir, 'analysis_params.mat');
if ~isempty(resultsDir) && isfile(paramFile)
    loaded = load(paramFile);
    if isfield(loaded, 'params')
        params = loaded.params;
        return;
    else
        warning('Parameter file found but missing ''params'' struct. Using defaults.');
    end
end

params = struct();
params.params_version = 3;    % Increment when parameter schema changes
params.created_at = datestr(now, 'yyyy-mm-dd HH:MM:SS');
params.git_hash = '';
[status, hash] = system('git rev-parse HEAD');
if status == 0
    params.git_hash = strtrim(hash);
end

% --- Event detection parameters ---
params.detection = struct();
params.detection.threshold_multiplier_pm25 = 1.5; % Ratio above baseline to flag PM2.5 events
params.detection.threshold_multiplier_pm10 = 1.5; % Ratio above baseline to flag PM10 events
params.detection.min_duration_hours = 2;          % Minimum duration for an event
params.detection.min_separation_hours = 1;        % Minimum separation between events
params.detection.baseline_window_style = 'global'; % 'global' or 'moving'
params.detection.baseline_window_hours = 24;       % Hours in background window if moving
params.detection.smoothing_hours = 0;             % Optional smoothing before thresholding

% --- Baseline estimation parameters ---
params.baseline = struct();
params.baseline.percentile = 50;   % Percentile used to compute baseline (median)
params.baseline.smooth_hours = 0;  % Optional smoothing window (hours)

% --- Response metrics parameters ---
params.response = struct();
params.response.lookahead_hours = 24;  % Hours to search for indoor response
params.response.diff_threshold = 5;    % Outdoor increase threshold to trigger search
params.response.target_fraction = 0.5; % Fraction of baseline considered "recovered"
% Indoor concentration must drop below baseline*factor to be considered
% recovered. This value should equal 1 + params.rtb.tolerance_fraction.
params.response.recovery_factor = 1.1;
% --- Return to Baseline parameters ---
params.rtb = struct();
params.rtb.tolerance_fraction = 0.10; % Fractional band around pre-event baseline
params.rtb.hold_time_hours = 2;       % Hours concentration must stay within band
params.rtb.min_data_hours = 6;        % Require this much data after event
params.rtb.flag_no_return = true;     % Flag events that never return to baseline


% --- First-response detection ---
params.first_response = struct();
params.first_response.baseline_window_hours = 3;   % Hours before event start for baseline
params.first_response.baseline_statistic = 'median'; % 'mean' or 'median'
params.first_response.variability_method = 'std';   % 'std' or 'mad'
params.first_response.departure_multiplier = 2;     % Multiples of variability
params.first_response.abs_threshold = 5;            % Minimum µg/m^3 above baseline


% --- Active period detection ---
params.active_mode = struct();
params.active_mode.threshold_factor = 0.8; % Fraction of median I/O ratio defining active filtering

if ~isempty(resultsDir)
    try
        save(paramFile, 'params');
    catch ME
        warning('Failed to save parameter file: %s', ME.message);
    end
end
end