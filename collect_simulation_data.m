function simulationData = collect_simulation_data(dataDir)
%COLLECT_SIMULATION_DATA Load simulation results allowing UUID-suffixed files.
%   This function searches for the expected simulation scenarios by prefix so
%   that files produced by parallel processing with random UUIDs can be loaded
%   automatically.  The core filename prefix (e.g. `adams_leaky_HEPA_active`)
%   is matched while any trailing UUID and run identifier segments are
%   ignored.

% Base filename prefixes for the 20 expected scenarios
prefixes = {
    'adams_leaky_baseline'
    'adams_leaky_HEPA_active'
    'adams_leaky_HEPA_always_on'
    'adams_leaky_MERV_active'
    'adams_leaky_MERV_always_on'
    'adams_tight_baseline'
    'adams_tight_HEPA_active'
    'adams_tight_HEPA_always_on'
    'adams_tight_MERV_active'
    'adams_tight_MERV_always_on'
    'baker_leaky_baseline'
    'baker_leaky_HEPA_active'
    'baker_leaky_HEPA_always_on'
    'baker_leaky_MERV_active'
    'baker_leaky_MERV_always_on'
    'baker_tight_baseline'
    'baker_tight_HEPA_active'
    'baker_tight_HEPA_always_on'
    'baker_tight_MERV_active'
    'baker_tight_MERV_always_on'
    };

simulationData = struct();
idx = 0;
missing = {};

for i = 1:length(prefixes)
    prefix = prefixes{i};
    files = dir(fullfile(dataDir, [prefix '*.mat']));
    if isempty(files)
        % Track missing scenarios; wildcard shown for clarity in error
        missing{end+1} = [prefix '*.mat']; %#ok<AGROW>
        continue;
    end

    filename = files(1).name;
    filepath = fullfile(dataDir, filename);
    loaded = load(filepath);
    if isstruct(loaded) && isfield(loaded, 'data')
        dataStruct = loaded.data;
    else
        dataStruct = loaded;
    end

    % Extract metadata from the known prefix that matched this file. The
    % prefix encodes the scenario without any UUID/run suffix, so it is a
    % reliable source even when filenames contain new alphanumeric tokens.
    parts = cellstr(split(prefix, '_'));

    location = parts{1};       % e.g., 'adams' or 'baker'
    leakage  = parts{2};       % 'tight' or 'leaky'

    if numel(parts) == 3 && strcmp(parts{3}, 'baseline')
        % <location>_<leakage>_baseline
        filterType = 'baseline';
        mode = 'baseline';
    else
        % <location>_<leakage>_<filterType>[_<mode>]
        filterType = parts{3};
        if numel(parts) > 3
            mode = strjoin(parts(4:end), '_');
        else
            mode = '';
        end
    end

    % Store into structured array
    idx = idx + 1;
    simulationData(idx).filename   = filename;
    simulationData(idx).location   = location;
    simulationData(idx).leakage    = leakage;
    simulationData(idx).filterType = filterType;
    simulationData(idx).mode       = mode;

    % Assign data arrays
    simulationData(idx).outdoor_PM25      = dataStruct.outdoor_PM25;
    simulationData(idx).outdoor_PM10      = dataStruct.outdoor_PM10;
    simulationData(idx).indoor_PM25       = dataStruct.indoor_PM25;
    simulationData(idx).indoor_PM10       = dataStruct.indoor_PM10;
    simulationData(idx).total_cost        = dataStruct.total_cost;
    simulationData(idx).filter_life_series = dataStruct.filter_life_series;

    % Air change rate time series may be stored under different field names
    if isfield(dataStruct, 'ach_series')
        simulationData(idx).ach_series = dataStruct.ach_series;
    elseif isfield(dataStruct, 'ach')
        simulationData(idx).ach_series = dataStruct.ach;
    else
        simulationData(idx).ach_series = [];
    end
end

if ~isempty(missing)
    error('Missing required simulation files: %s', strjoin(missing, ', '));
elseif idx == 0
    error('No simulation files were loaded from %s', dataDir);
else
    fprintf('✓ Loaded %d simulation files successfully\n', idx);
end
end