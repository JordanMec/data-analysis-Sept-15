function set_figure_fullscreen(fig)
%SET_FIGURE_FULLSCREEN Expand a figure window to fill the available screen.
%   SET_FIGURE_FULLSCREEN(FIG) resizes FIG so it occupies the full screen
%   and configures it for high-resolution export. If FIG is omitted, the
%   current figure (GCF) is used.

if nargin < 1 || isempty(fig)
    fig = gcf;
end

if ~isa(fig, 'matlab.ui.Figure')
    error('set_figure_fullscreen expects a figure handle.');
end

% Ensure the figure has a white background for export consistency
fig.Color = 'white';

% Try to set the figure to fill the available screen real estate. The
% normalized approach works across different monitor sizes and DPI
% settings, while the pixel fallback covers headless or unusual setups.
try
    fig.Units = 'normalized';
    fig.OuterPosition = [0 0 1 1];
catch
    try
        fig.Units = 'pixels';
        screenSize = get(0, 'ScreenSize');
        fig.Position = [screenSize(1:2), screenSize(3), screenSize(4)];
    catch
        % If neither approach works we silently fall back to the existing
        % figure size.
    end
end

% Match on-screen and export sizing
try
    fig.PaperPositionMode = 'auto';
catch
    % Some figure types do not expose PaperPositionMode; ignore gracefully.
end

% Apply the resize immediately so subsequent layout commands see the new
% geometry.
drawnow limitrate nocallbacks;
end
