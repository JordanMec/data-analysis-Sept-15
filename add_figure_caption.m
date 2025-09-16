function add_figure_caption(fig, captionText)
%ADD_FIGURE_CAPTION Add a descriptive caption to the bottom of a figure.
%
%   ADD_FIGURE_CAPTION(FIG, CAPTIONTEXT) adds CAPTIONTEXT as centered text
%   across the bottom of the figure window. Existing captions created by
%   this helper are removed so the caption can be updated when figures are
%   regenerated.

if nargin < 1 || isempty(fig)
    fig = gcf;
end
if nargin < 2 || strlength(strtrim(captionText)) == 0
    return;
end

existing = findall(fig, 'Tag', 'autoFigureCaption');
if ~isempty(existing)
    delete(existing);
end

if isstring(captionText)
    captionText = join(captionText, newline);
end

annotation(fig, 'textbox', [0.05 0.005 0.9 0.11], ...
    'String', char(captionText), ...
    'Tag', 'autoFigureCaption', ...
    'Interpreter', 'none', ...
    'HorizontalAlignment', 'center', ...
    'VerticalAlignment', 'top', ...
    'FontSize', 10, ...
    'EdgeColor', 'none', ...
    'BackgroundColor', 'white', ...
    'Margin', 2, ...
    'FitBoxToText', 'off', ...
    'LineStyle', 'none');
end
