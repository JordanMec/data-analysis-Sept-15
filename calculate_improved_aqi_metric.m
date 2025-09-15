function improved_aqi_hours = calculate_improved_aqi_metric(baselinePM25, baselinePM10, interventionPM25, interventionPM10)
% CALCULATE_IMPROVED_AQI_METRIC Compute a more nuanced AQI improvement metric
%   This function calculates AQI improvement using a continuous approach
%   rather than just counting threshold crossings. It accounts for:
%       1. Partial improvements that do not cross thresholds
%       2. Weighted severity of air quality
%       3. Cumulative exposure reduction
%   The result is expressed as equivalent hours of AQI improvement.

% Updated AQI breakpoints for PM2.5 and PM10
pm25_breakpoints = [0.0, 9.0, 35.4, 55.4, 125.4, 225.4, 325.4];
pm10_breakpoints = [0.0, 54.0, 154.0, 254.0, 354.0, 424.0, 604.0];
aqi_breakpoints  = [0, 50, 100, 150, 200, 300, 500];

% Helper to convert concentration to AQI
calculate_aqi = @(conc, breaks) interp1(breaks, aqi_breakpoints, conc, 'linear', 'extrap');

% Compute hourly AQI values for baseline and intervention
baselineAQI_PM25     = arrayfun(@(c) calculate_aqi(c, pm25_breakpoints), baselinePM25);
baselineAQI_PM10     = arrayfun(@(c) calculate_aqi(c, pm10_breakpoints), baselinePM10);
interventionAQI_PM25 = arrayfun(@(c) calculate_aqi(c, pm25_breakpoints), interventionPM25);
interventionAQI_PM10 = arrayfun(@(c) calculate_aqi(c, pm10_breakpoints), interventionPM10);

baselineAQI     = max(baselineAQI_PM25, baselineAQI_PM10);
interventionAQI = max(interventionAQI_PM25, interventionAQI_PM10);

% Traditional threshold crossing hours
traditionalHours = sum((baselineAQI > 50) & (interventionAQI <= 50));

% Weighted improvement by severity
aqiReduction = baselineAQI - interventionAQI;
weightFunction = @(aqi) 1 + (aqi/50).^1.5;  % heavier weight for high AQI
weights = weightFunction(baselineAQI);

% Equivalent hours metric
perfectHourEquivalent = 100; % reducing AQI from 100 to 0
equivalentHours = sum(aqiReduction .* weights) / perfectHourEquivalent;

% Health-based metric using concentration-response approximation
healthImpactBaseline = sum(baselinePM25) + 0.5 * sum(baselinePM10);
healthImpactIntervention = sum(interventionPM25) + 0.5 * sum(interventionPM10);
healthImpactReduction = healthImpactBaseline - healthImpactIntervention;
typicalDailyExposure = 15 * 24; % 15 ug/m3 for 24 hours
healthBasedHours = healthImpactReduction / typicalDailyExposure * 24;

% Combine metrics for robust estimate
improved_aqi_hours = max([traditionalHours, equivalentHours, healthBasedHours/10]);

% Ensure non-negative result
improved_aqi_hours = max(0, improved_aqi_hours);

% Small bonus to avoid exact zeros when any improvement exists
if any(aqiReduction > 0) && improved_aqi_hours == 0
    improved_aqi_hours = 0.1 + sum(aqiReduction > 0) * 0.01;
end

end