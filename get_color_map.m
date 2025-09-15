function cmap = get_color_map()
%GET_COLOR_MAP Return a struct of common analysis colors
%   This helper centralizes color choices used across plots so that the
%   same quantity is drawn with a consistent color everywhere.

cmap.pm25 = [0.2 0.4 0.8];    % blue
cmap.pm10 = [0.8 0.3 0.3];    % red
cmap.tight = [0.2 0.6 0.8];   % teal for tight envelopes
cmap.leaky = [0.8 0.4 0.2];   % orange for leaky envelopes
cmap.gray = [0.6 0.6 0.6];    % neutral gray
end
