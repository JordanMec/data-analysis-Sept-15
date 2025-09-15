function uncertaintyAnalysis = quantify_envelope_uncertainty(activeData, summaryTable)
%QUANTIFY_ENVELOPE_UNCERTAINTY Estimate envelope-driven uncertainty.
%   uncertaintyAnalysis = quantify_envelope_uncertainty(activeData, summaryTable)
%   calculates bounds for each configuration treating the tight and leaky homes
%   as the lower and upper extremes of an uncertainty envelope. If a
%   summaryTable with baseline results is provided, the function also computes
%   reduction percentages relative to the baseline case.

if nargin < 2
    summaryTable = [];  % Baseline comparison optional
end

uncertaintyAnalysis = struct();
configs = fieldnames(activeData);

for i = 1:length(configs)
    config = configs{i};
    data = activeData.(config);

    uncertaintyAnalysis.(config) = struct();

    % Mean concentrations for tight and leaky cases
    pm25_tight_mean = mean(data.indoor_PM25_tight);
    pm25_leaky_mean = mean(data.indoor_PM25_leaky);
    pm10_tight_mean = mean(data.indoor_PM10_tight);
    pm10_leaky_mean = mean(data.indoor_PM10_leaky);

    % Bounds (min/max) and means
    pm25_lower = min(pm25_tight_mean, pm25_leaky_mean);
    pm25_upper = max(pm25_tight_mean, pm25_leaky_mean);
    pm10_lower = min(pm10_tight_mean, pm10_leaky_mean);
    pm10_upper = max(pm10_tight_mean, pm10_leaky_mean);

    pm25_mean = (pm25_tight_mean + pm25_leaky_mean) / 2;
    pm10_mean = (pm10_tight_mean + pm10_leaky_mean) / 2;

    uncertaintyAnalysis.(config).pm25_bounds = [pm25_lower, pm25_upper];
    uncertaintyAnalysis.(config).pm10_bounds = [pm10_lower, pm10_upper];

    uncertaintyAnalysis.(config).pm25_range_percent = 100 * (pm25_upper - pm25_lower) / pm25_mean;
    uncertaintyAnalysis.(config).pm10_range_percent = 100 * (pm10_upper - pm10_lower) / pm10_mean;

    % Optional comparison to baseline case
    if ~isempty(summaryTable)
        baseTight = summaryTable(strcmp(summaryTable.location, data.location) & ...
            strcmp(summaryTable.leakage, 'tight') & ...
            strcmp(summaryTable.mode, 'baseline'), :);
        baseLeaky = summaryTable(strcmp(summaryTable.location, data.location) & ...
            strcmp(summaryTable.leakage, 'leaky') & ...
            strcmp(summaryTable.mode, 'baseline'), :);

        if ~isempty(baseTight) && ~isempty(baseLeaky)
            base_pm25_tight = baseTight.avg_indoor_PM25;
            base_pm25_leaky = baseLeaky.avg_indoor_PM25;
            base_pm10_tight = baseTight.avg_indoor_PM10;
            base_pm10_leaky = baseLeaky.avg_indoor_PM10;

            red_pm25_tight = 100 * (base_pm25_tight - pm25_tight_mean) / base_pm25_tight;
            red_pm25_leaky = 100 * (base_pm25_leaky - pm25_leaky_mean) / base_pm25_leaky;
            red_pm10_tight = 100 * (base_pm10_tight - pm10_tight_mean) / base_pm10_tight;
            red_pm10_leaky = 100 * (base_pm10_leaky - pm10_leaky_mean) / base_pm10_leaky;

            uncertaintyAnalysis.(config).pm25_reduction_percent = ...
                (red_pm25_tight + red_pm25_leaky) / 2;
            uncertaintyAnalysis.(config).pm25_reduction_bounds = ...
                [min(red_pm25_tight, red_pm25_leaky), max(red_pm25_tight, red_pm25_leaky)];

            uncertaintyAnalysis.(config).pm10_reduction_percent = ...
                (red_pm10_tight + red_pm10_leaky) / 2;
            uncertaintyAnalysis.(config).pm10_reduction_bounds = ...
                [min(red_pm10_tight, red_pm10_leaky), max(red_pm10_tight, red_pm10_leaky)];
        end
    end

    % Time-varying uncertainty
    pm25_uncertainty = abs(data.indoor_PM25_tight - data.indoor_PM25_leaky);
    pm10_uncertainty = abs(data.indoor_PM10_tight - data.indoor_PM10_leaky);

    uncertaintyAnalysis.(config).pm25_uncertainty_mean = mean(pm25_uncertainty);
    uncertaintyAnalysis.(config).pm25_range = max(pm25_uncertainty) - min(pm25_uncertainty);
    uncertaintyAnalysis.(config).pm10_uncertainty_mean = mean(pm10_uncertainty);
    uncertaintyAnalysis.(config).pm10_range = max(pm10_uncertainty) - min(pm10_uncertainty);

    % Store hourly confidence interval bounds and mean
    ci_pm25_lower = min(data.indoor_PM25_tight, data.indoor_PM25_leaky);
    ci_pm25_upper = max(data.indoor_PM25_tight, data.indoor_PM25_leaky);
    ci_pm10_lower = min(data.indoor_PM10_tight, data.indoor_PM10_leaky);
    ci_pm10_upper = max(data.indoor_PM10_tight, data.indoor_PM10_leaky);

    uncertaintyAnalysis.(config).hourly_ci_pm25 = [ci_pm25_lower'; ci_pm25_upper'];
    uncertaintyAnalysis.(config).hourly_ci_pm10 = [ci_pm10_lower'; ci_pm10_upper'];
    uncertaintyAnalysis.(config).hourly_mean_pm25 = (data.indoor_PM25_tight + data.indoor_PM25_leaky) / 2;
    uncertaintyAnalysis.(config).hourly_mean_pm10 = (data.indoor_PM10_tight + data.indoor_PM10_leaky) / 2;

    % Deterministic attribution of uncertainty contributions
    % (not a statistical variance decomposition)
    envelope_delta = 100 * abs(pm25_tight_mean - pm25_leaky_mean) / pm25_mean;
    outdoor_delta = 100 * (max(data.outdoor_PM25) - min(data.outdoor_PM25)) / ...
                    mean(data.outdoor_PM25);
    system_delta = max(0, 100 - envelope_delta - outdoor_delta);

    % [envelope, outdoor, system, measurement]
    uncertaintyAnalysis.(config).uncertainty_contributions = ...
        [envelope_delta; outdoor_delta; system_delta; 0];
end
end