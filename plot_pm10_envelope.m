function plot_pm10_envelope(summaryTable, figuresDir, showThresholds)
% Wrapper for PM10 envelope plot
%   showThresholds - pass true to draw EPA AQI horizontal lines
if nargin < 3
    showThresholds = false;
end
plot_pm_envelope(summaryTable, figuresDir, 'indoor_PM10', 'PM10', 'indoor_pm10_envelope', showThresholds);
end