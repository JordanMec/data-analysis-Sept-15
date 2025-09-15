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
locations = unique({simData.location});
filters   = unique({simData.filterType});
modes     = unique({simData.mode});

for l = 1:numel(locations)
    loc = locations{l};
    % Baseline must exist for tight and leaky homes
    for leak = {"tight","leaky"}
        mask = strcmp({simData.location}, loc) & strcmp({simData.leakage}, leak{1}) & ...
               strcmp({simData.filterType}, 'baseline');
        if ~any(mask)
            error('Missing baseline simulation for %s / %s', loc, leak{1});
        end
    end
end

% Exclude baseline when checking filters
filters = setdiff(filters, {'baseline'});
modes = setdiff(modes, {'baseline'});

for l = 1:numel(locations)
    loc = locations{l};
    for f = 1:numel(filters)
        filt = filters{f};
        for m = 1:numel(modes)
            mode = modes{m};
            for leak = {"tight","leaky"}
                mask = strcmp({simData.location}, loc) & ...
                       strcmp({simData.leakage}, leak{1}) & ...
                       strcmp({simData.filterType}, filt) & ...
                       strcmp({simData.mode}, mode);
                if ~any(mask)
                    error('Missing simulation for %s filter (%s) in %s / %s', ...
                        filt, mode, loc, leak{1});
                end
            end
        end
    end
end

fprintf('✓ Simulation data validated (completeness enforced)\n');
end