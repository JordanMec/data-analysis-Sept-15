function plot_pm25_envelope(summaryTable, figuresDir, showThresholds)
% Wrapper for PM2.5 envelope plot
%   showThresholds - pass true to draw EPA AQI horizontal lines
if nargin < 3
    showThresholds = false;
end
plot_pm_envelope(summaryTable, figuresDir, 'indoor_PM25', 'PM2.5', 'indoor_pm25_envelope', showThresholds);
end