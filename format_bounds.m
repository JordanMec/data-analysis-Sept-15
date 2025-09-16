function str = format_bounds(meanVal, lowerVal, upperVal, varargin)
%FORMAT_BOUNDS Create a standardized string describing tight/leaky bounds.
%   STR = FORMAT_BOUNDS(MEAN, LOWER, UPPER) returns a string of the form
%   "mean (tight lower – leaky upper)". The helper gracefully handles NaN
%   values and supports custom formatting through optional name-value pairs:
%
%   'MeanFormat'   - sprintf format string applied to the mean value.
%   'BoundFormat'  - sprintf format string applied to the bound values.
%   'Style'        - 'explicit' (default), 'pm', or 'both'. The 'pm' style
%                    expresses the range as mean ± halfRange. The 'both'
%                    style combines the ± notation with the explicit tight
%                    vs. leaky bounds in parentheses.
%   'TightLabel'   - label to use for the lower bound (default 'tight').
%   'LeakyLabel'   - label to use for the upper bound (default 'leaky').
%   'MissingText'  - fallback text when bounds are unavailable.
%   'IncludeNewline' - logical flag that inserts a newline before the
%                      parenthetical bounds when true.
%
%   Example:
%       format_bounds(45.2, 40.1, 52.8, 'MeanFormat', '%.1f%%', ...
%           'BoundFormat', '%.1f%%', 'Style', 'both');
%
%   returns the string
%       "45.2% ± 6.3%\n(tight 40.1% – leaky 52.8%)"
%
%   This helper centralises the textual handling of tight/leaky bounds so
%   that every numerical report can consistently communicate uncertainty.

p = inputParser;
p.addParameter('MeanFormat', '%.1f', @(s)ischar(s) || isstring(s));
p.addParameter('BoundFormat', '%.1f', @(s)ischar(s) || isstring(s));
p.addParameter('Style', 'explicit', @(s)any(strcmpi(s, {'explicit','pm','both'})));
p.addParameter('TightLabel', 'tight', @(s)ischar(s) || isstring(s));
p.addParameter('LeakyLabel', 'leaky', @(s)ischar(s) || isstring(s));
p.addParameter('MissingText', 'bounds unavailable', @(s)ischar(s) || isstring(s));
p.addParameter('IncludeNewline', false, @(x)islogical(x) && isscalar(x));
p.parse(varargin{:});
opts = p.Results;

if nargin < 3
    error('format_bounds:NotEnoughInputs', ...
        'Mean, lower, and upper values must be provided.');
end

if ~isfinite(meanVal)
    str = char(opts.MissingText);
    return;
end

% Ensure bounds follow the conventional lower <= upper ordering
vals = [lowerVal, upperVal];
if all(isfinite(vals))
    lowerVal = min(vals);
    upperVal = max(vals);
end

meanStr = sprintf(opts.MeanFormat, meanVal);
if ~isfinite(lowerVal) || ~isfinite(upperVal)
    switch lower(opts.Style)
        case 'pm'
            str = sprintf('%s ± %s', meanStr, char(opts.MissingText));
        case 'both'
            str = sprintf('%s ± %s%s(%s)', meanStr, char(opts.MissingText), ...
                newlineIfNeeded(opts.IncludeNewline), char(opts.MissingText));
        otherwise
            str = sprintf('%s (%s)', meanStr, char(opts.MissingText));
    end
    return;
end

lowerStr = sprintf(opts.BoundFormat, lowerVal);
upperStr = sprintf(opts.BoundFormat, upperVal);
halfRange = (upperVal - lowerVal) / 2;
halfRangeStr = sprintf(opts.BoundFormat, halfRange);

switch lower(opts.Style)
    case 'pm'
        str = sprintf('%s ± %s', meanStr, halfRangeStr);
    case 'both'
        base = sprintf('%s ± %s', meanStr, halfRangeStr);
        boundsText = sprintf('(%s %s – %s %s)', opts.TightLabel, lowerStr, ...
            opts.LeakyLabel, upperStr);
        str = sprintf('%s%s%s', base, newlineIfNeeded(opts.IncludeNewline), boundsText);
    otherwise % explicit
        boundsText = sprintf('(%s %s – %s %s)', opts.TightLabel, lowerStr, ...
            opts.LeakyLabel, upperStr);
        str = sprintf('%s %s', meanStr, boundsText);
end

end

function nl = newlineIfNeeded(include)
if include
    nl = sprintf('\n');
else
    nl = ' ';
end
end
