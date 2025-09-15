function h = scatter_with_errorbars(xMean, yMean, xErr, yErr, color, marker)
if nargin < 5 || isempty(color)
    color = [0 0.4470 0.7410];
end
if nargin < 6 || isempty(marker)
    marker = 'o';
end
h = scatter(xMean, yMean, 70, 'Marker', marker, ...
    'MarkerFaceColor', color, 'MarkerEdgeColor', 'k');
vErr = errorbar(xMean, yMean, yErr(1), yErr(2), 'vertical', ...
    'LineStyle', 'none', 'Color', color);
hErr = errorbar(xMean, yMean, xErr(1), xErr(2), 'horizontal', ...
    'LineStyle', 'none', 'Color', color);
set([vErr hErr], 'HandleVisibility', 'off');
end