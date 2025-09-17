function add_figure_caption(fig, captionText)
%ADD_FIGURE_CAPTION Add a descriptive caption to the bottom of a figure.
%
%   ADD_FIGURE_CAPTION(FIG, CAPTIONTEXT) adds CAPTIONTEXT as centered text
%   across the bottom of the figure window. Existing captions created by
%   this helper are removed so the caption can be updated when figures are
%   regenerated. Space is reserved beneath the plots so the caption never
%   overlaps axes labels.

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
captionText = char(captionText);

fontSize = 10;
topPadding = 40;      % pixels between caption and the closest axes
bottomPadding = 16;   % pixels beneath the caption text block

% Switch to pixel units so geometry math is consistent across platforms
originalFigUnits = fig.Units;
cleanup = onCleanup(@() set(fig, 'Units', originalFigUnits));
fig.Units = 'pixels';

textHeight = measure_caption_height(fig, captionText, fontSize);
requiredMargin = textHeight + topPadding + bottomPadding;

[marginPixels, figHeight] = ensure_caption_margin(fig, requiredMargin);

annotationBottom = bottomPadding / figHeight;
annotationTop = (marginPixels - topPadding) / figHeight;
annotationHeight = max(annotationTop - annotationBottom, textHeight / figHeight);
if ~isfinite(annotationHeight) || annotationHeight <= 0
    annotationBottom = 0;
    annotationHeight = max(marginPixels / figHeight, 0.05);
end

annotation(fig, 'textbox', [0.05 annotationBottom 0.9 annotationHeight], ...
    'String', captionText, ...
    'Tag', 'autoFigureCaption', ...
    'Interpreter', 'none', ...
    'Units', 'normalized', ...
    'HorizontalAlignment', 'center', ...
    'VerticalAlignment', 'top', ...
    'FontSize', fontSize, ...
    'EdgeColor', 'none', ...
    'BackgroundColor', 'white', ...
    'Margin', 6, ...
    'FitBoxToText', 'off', ...
    'LineStyle', 'none');
end

function textHeight = measure_caption_height(fig, captionText, fontSize)
%MEASURE_CAPTION_HEIGHT Determine the rendered height of the caption text.
temp = annotation(fig, 'textbox', [0 0 1 1], ...
    'String', captionText, ...
    'Interpreter', 'none', ...
    'Units', 'pixels', ...
    'Visible', 'off', ...
    'FitBoxToText', 'on', ...
    'HorizontalAlignment', 'center', ...
    'VerticalAlignment', 'top', ...
    'FontSize', fontSize, ...
    'Margin', 6, ...
    'LineStyle', 'none');
drawnow limitrate nocallbacks;
pos = temp.Position;
if numel(pos) >= 4
    textHeight = pos(4);
else
    textHeight = 0;
end
delete(temp);
end

function [marginPixels, figHeight] = ensure_caption_margin(fig, requiredMargin)
%ENSURE_CAPTION_MARGIN Expand the figure and shift plots to create space.
storedMargin = getappdata(fig, 'CaptionMarginPixels');
[positionables, measurableObjects] = gather_positionable_objects(fig);
minBottom = compute_min_bottom(measurableObjects);

if isempty(storedMargin)
    currentMargin = minBottom;
else
    currentMargin = max(storedMargin, minBottom);
end

newMargin = max(currentMargin, requiredMargin);
additionalMargin = newMargin - currentMargin;

if additionalMargin > 0
    figPos = fig.Position;
    newBottom = max(figPos(2) - additionalMargin, 0);
    fig.Position = [figPos(1), newBottom, figPos(3), figPos(4) + additionalMargin];
    shift_positionables(positionables, additionalMargin);
end

setappdata(fig, 'CaptionMarginPixels', newMargin);
figHeight = fig.Position(4);
marginPixels = newMargin;
end

function [handles, measurable] = gather_positionable_objects(fig)
%GATHER_POSITIONABLE_OBJECTS Identify objects that should move with margins.
    allObjects = findall(fig);
    moveMask = false(size(allObjects));
    measureMask = false(size(allObjects));

    for idx = 1:numel(allObjects)
        obj = allObjects(idx);
        if obj == fig
            continue;
        end
        if isprop(obj, 'Tag') && strcmp(obj.Tag, 'autoFigureCaption')
            continue;
        end
        if supports_position_measurement(obj)
            measureMask(idx) = true;
        end
        if supports_manual_positioning(obj)
            moveMask(idx) = true;
        end
    end

    handles = allObjects(moveMask);
    if nargout >= 2
        measurable = allObjects(measureMask);
    end
end

function minBottom = compute_min_bottom(objects)
%COMPUTE_MIN_BOTTOM Find the closest object to the bottom of the figure.
if isempty(objects)
    minBottom = 0;
    return;
end

bottoms = inf(numel(objects), 1);
for idx = 1:numel(objects)
    obj = objects(idx);
    try
        originalUnits = obj.Units;
    catch
        originalUnits = 'pixels';
    end
    try
        obj.Units = 'pixels';
        pos = obj.Position;
        if numel(pos) >= 2
            bottoms(idx) = pos(2);
        end
    catch
        % Ignore objects that do not expose position in pixels
    end
    try
        obj.Units = originalUnits;
    catch
        % Some objects do not permit unit assignment; ignore gracefully.
    end
end

finiteBottoms = bottoms(isfinite(bottoms));
if isempty(finiteBottoms)
    minBottom = 0;
else
    minBottom = min(finiteBottoms);
end
end

function shift_positionables(objects, delta)
%SHIFT_POSITIONABLES Move all position-aware objects upward by DELTA pixels.
    if delta <= 0 || isempty(objects)
        return;
    end

for idx = 1:numel(objects)
    obj = objects(idx);
    try
        originalUnits = obj.Units;
    catch
        originalUnits = 'pixels';
    end
    try
        obj.Units = 'pixels';
        pos = obj.Position;
        if numel(pos) >= 2
            pos(2) = pos(2) + delta;
            obj.Position = pos;
        end
    catch
        % Leave objects we cannot move alone.
    end
    try
        obj.Units = originalUnits;
    catch
        % Ignore failures when restoring units.
    end
end
end

function tf = supports_position_measurement(obj)
%SUPPORTS_POSITION_MEASUREMENT True when an object exposes position info.
    tf = isvalid(obj) && isprop(obj, 'Position') && isprop(obj, 'Units');
end

function tf = supports_manual_positioning(obj)
%SUPPORTS_MANUAL_POSITIONING True when the object allows manual positioning.
    tf = false;

    if ~isvalid(obj) || ~isprop(obj, 'Position') || ~isprop(obj, 'Units')
        return;
    end

    try
        if isa(obj, 'matlab.graphics.layout.TiledChartLayout')
            return;
        end
    catch
        % ISA can fail for some graphics objects that do not expose class info.
    end

    try
        parentObj = get(obj, 'Parent');
        if isa(parentObj, 'matlab.graphics.layout.TiledChartLayout')
            return;
        end
    catch
        % Some objects do not expose a Parent property; ignore.
    end

    try
        objType = get(obj, 'Type');
        if ischar(objType)
            if any(strcmpi(objType, {'tiledlayout', 'uigridlayout'}))
                return;
            end
        end
    catch
        % Some objects do not expose a Type property via GET; assume they are
        % positionable if we reach this point.
    end

    tf = true;
end
