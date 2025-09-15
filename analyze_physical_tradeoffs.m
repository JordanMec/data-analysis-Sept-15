function tradeoffTable = analyze_physical_tradeoffs(summaryTable, hoursPerYear)
% ANALYZE_PHYSICAL_TRADEOFFS Compute filter replacement and airflow metrics with bounds
%   This version uses a consistent physics-based methodology for estimating
%   airflow and energy penalties for both HEPA and MERV filters.
if nargin < 2
    hoursPerYear = 8760;
end

% Group by location, filter, and mode (NOT leakage)
intRows = summaryTable(~strcmp(summaryTable.mode,'baseline'), :);
uniqueConfigs = unique(intRows(:, {'location','filterType','mode'}));

tradeoffTable = table();

for i = 1:height(uniqueConfigs)
    loc = uniqueConfigs.location{i};
    filt = uniqueConfigs.filterType{i};
    mode = uniqueConfigs.mode{i};

    % Get both tight and leaky rows
    rowTight = intRows(strcmp(intRows.location,loc) & ...
        strcmp(intRows.leakage,'tight') & ...
        strcmp(intRows.filterType,filt) & ...
        strcmp(intRows.mode,mode), :);
    rowLeaky = intRows(strcmp(intRows.location,loc) & ...
        strcmp(intRows.leakage,'leaky') & ...
        strcmp(intRows.filterType,filt) & ...
        strcmp(intRows.mode,mode), :);

    if isempty(rowTight) || isempty(rowLeaky), continue; end

    % Calculate bounds for filter replacement frequency
    filter_hours_tight = rowTight.filter_replaced;
    filter_hours_leaky = rowLeaky.filter_replaced;
    
    if ~isnan(filter_hours_tight) && filter_hours_tight > 0
        replacements_per_year_tight = hoursPerYear / filter_hours_tight;
    else
        replacements_per_year_tight = NaN;
    end
    
    if ~isnan(filter_hours_leaky) && filter_hours_leaky > 0
        replacements_per_year_leaky = hoursPerYear / filter_hours_leaky;
    else
        replacements_per_year_leaky = NaN;
    end
    
    % Note: More replacements = worse, so upper bound is the higher number
    replacements_per_year_lower = min(replacements_per_year_tight, replacements_per_year_leaky);
    replacements_per_year_upper = max(replacements_per_year_tight, replacements_per_year_leaky);
    replacements_per_year_mean = nanmean([replacements_per_year_tight, replacements_per_year_leaky]);

    %% IMPROVED Airflow Penalty Estimation
    % Use filter pressure drop characteristics and fan laws

    if strcmpi(filt, 'hepa')
        initial_pressure_drop = 0.5;  % inches w.c. at rated flow
        loaded_pressure_drop  = 1.0;  % inches w.c. when loaded
    else
        initial_pressure_drop = 0.25; % inches w.c. at rated flow
        loaded_pressure_drop  = 0.75; % inches w.c. when loaded
    end

    % Typical system static pressure budget (inches w.c.)
    system_static_budget = 0.5;

    % Fan law approximation: Flow ~ sqrt(1 - DP/Total)
    initial_airflow_penalty = 100 * (1 - sqrt(1 - initial_pressure_drop / system_static_budget));
    loaded_airflow_penalty  = 100 * (1 - sqrt(1 - loaded_pressure_drop  / system_static_budget));

    % Mode dependent loading factor
    if strcmpi(mode, 'always_on')
        avg_loading_factor = 0.7;  % continuous operation loads faster
    else
        avg_loading_factor = 0.4;  % intermittent operation
    end

    avg_airflow_penalty = initial_airflow_penalty + ...
        avg_loading_factor * (loaded_airflow_penalty - initial_airflow_penalty);

    % Building envelope effects on bounds
    if strcmpi(mode, 'always_on')
        airflow_penalty_tight = avg_airflow_penalty * 1.1;
        airflow_penalty_leaky = avg_airflow_penalty * 0.9;
    else
        airflow_penalty_tight = avg_airflow_penalty * 1.05;
        airflow_penalty_leaky = avg_airflow_penalty * 0.95;
    end

    airflow_penalty_tight = min(airflow_penalty_tight, 50); % cap
    airflow_penalty_leaky = max(airflow_penalty_leaky, 0);

    airflow_penalty_lower = min(airflow_penalty_tight, airflow_penalty_leaky);
    airflow_penalty_upper = max(airflow_penalty_tight, airflow_penalty_leaky);
    airflow_penalty_mean  = (airflow_penalty_tight + airflow_penalty_leaky) / 2;

    %% Energy Penalty Estimation using simplified fan law
    energy_factor = 2.0; % 1% airflow reduction -> 2% energy increase
    energy_penalty_lower = min(energy_factor * airflow_penalty_lower, 100);
    energy_penalty_upper = min(energy_factor * airflow_penalty_upper, 100);
    energy_penalty_mean  = min(energy_factor * airflow_penalty_mean , 100);

    % Build output row with bounds
    outRow = table({loc}, {filt}, {mode}, ...
        replacements_per_year_mean, replacements_per_year_lower, replacements_per_year_upper, ...
        airflow_penalty_mean, airflow_penalty_lower, airflow_penalty_upper, ...
        energy_penalty_mean, energy_penalty_lower, energy_penalty_upper, ...
        'VariableNames', {'location','filterType','mode', ...
        'estimated_replacements_per_year','replacements_per_year_lower','replacements_per_year_upper', ...
        'airflow_penalty_percent','airflow_penalty_lower','airflow_penalty_upper', ...
        'energy_penalty_percent','energy_penalty_lower','energy_penalty_upper'});

    tradeoffTable = [tradeoffTable; outRow];
end
end