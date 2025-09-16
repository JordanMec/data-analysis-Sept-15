function validate_simulation_data(simData)
% VALIDATE_SIMULATION_DATA  Verify required fields and scenario completeness

requiredFields = {'outdoor_PM25','outdoor_PM10','indoor_PM25','indoor_PM10','total_cost'};
for i = 1:numel(simData)
    for j = 1:numel(requiredFields)
        fld = requiredFields{j};
        if ~isfield(simData(i), fld) || isempty(simData(i).(fld))
            error('Missing %s for simulation %d', fld, i);
        end
    end
end

% --- Verify that every location/filter/mode has both tight and leaky entries ---
locationsAll    = string({simData.location});
leakagesAll     = string({simData.leakage});
filterTypesAll  = string({simData.filterType});
rawModesAll     = string({simData.mode});

normalizedModes = strings(size(rawModesAll));
for i = 1:numel(simData)
    normalizedModes(i) = normalize_mode(filterTypesAll(i), rawModesAll(i));
end

locations = unique(locationsAll);
filters   = unique(filterTypesAll);
modes     = unique(normalizedModes);

for l = 1:numel(locations)
    loc = locations(l);
    % Baseline must exist for tight and leaky homes
    for leak = ["tight","leaky"]
        mask = (locationsAll == loc) & (leakagesAll == leak) & ...
               (filterTypesAll == "baseline");
        if ~any(mask)
            error('Missing baseline simulation for %s / %s', char(loc), char(leak));
        end
    end
end

% Exclude baseline when checking filters
filters = setdiff(filters, "baseline");
modes = setdiff(modes, "baseline");

for l = 1:numel(locations)
    loc = locations(l);
    for f = 1:numel(filters)
        filt = filters(f);
        for m = 1:numel(modes)
            mode = modes(m);
            for leak = ["tight","leaky"]
                mask = (locationsAll == loc) & ...
                       (leakagesAll == leak) & ...
                       (filterTypesAll == filt) & ...
                       (normalizedModes == mode);
                if ~any(mask)
                    error('Missing simulation for %s filter (%s) in %s / %s', ...
                        char(filt), char(mode), char(loc), char(leak));
                end
            end
        end
    end
end

fprintf('✓ Simulation data validated (completeness enforced)\n');
end

function modeKey = normalize_mode(filterType, rawMode)
%NORMALIZE_MODE  Map raw filename-derived mode labels to canonical tokens.

filterType = string(filterType);
rawMode    = string(rawMode);

if filterType == "baseline"
    modeKey = "baseline";
    return;
end

if ismissing(rawMode) || strlength(rawMode) == 0
    modeKey = "";
    return;
end

parts = split(rawMode, "_");
parts(parts == "") = [];
partsLower = lower(parts);

modeKey = "";
for k = 1:numel(partsLower)
    token = partsLower(k);
    if token == "active"
        modeKey = "active";
        return;
    elseif token == "always_on" || token == "alwayson"
        modeKey = "always_on";
        return;
    elseif token == "always" && k < numel(partsLower) && partsLower(k+1) == "on"
        modeKey = "always_on";
        return;
    end
end

if modeKey == "" && ~isempty(parts)
    modeKey = lower(parts(1));
end
end
