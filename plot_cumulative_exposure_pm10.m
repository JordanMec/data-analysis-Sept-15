function plot_cumulative_exposure_pm10(summaryTable, figuresDir)
% Wrapper to plot cumulative indoor PM10 exposure
% Uses plot_cumulative_exposure with PM10 data

plot_cumulative_exposure(summaryTable, figuresDir, 'indoor_PM10', 'PM10', 'indoor_cumulative_pm10_exposure.png');
end