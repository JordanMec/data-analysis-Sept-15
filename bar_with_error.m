function bar_with_error(categories, values, errLow, errHigh, color, yLabel, xLabel, titleStr, savePath)
if nargin < 5 || isempty(color)
    cmap = get_color_map();
    color = cmap.tight; % default bar color
end
fig = create_hidden_figure();
nexttile;
bar(categorical(categories), values, 'FaceColor', color);
hold on;
errorbar(1:numel(values), values, errLow, errHigh, 'k','LineStyle','none');
ylabel(yLabel);
xlabel(xLabel);
title(titleStr);
xtickangle(45);
grid on;
add_figure_caption(fig, sprintf(['The bar chart titled "%s" summarizes %s for each category along the %s axis, with error bars representing the provided uncertainty bounds.' newline ...
    'Labels and gridlines make it easy to compare categories and judge the spread implied by the lower and upper estimates.'], titleStr, yLabel, xLabel));
if nargin >= 9 && ~isempty(savePath)
    outDir = fileparts(savePath);
    if ~exist(outDir, 'dir')
        mkdir(outDir);
    end
    saveas(fig, savePath);
end
close(fig);
end
