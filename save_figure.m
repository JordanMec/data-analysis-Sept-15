function save_figure(fig, baseDir, subDir, fileName)
%SAVE_FIGURE Save a figure into an organized directory
%   SAVE_FIGURE(FIG, BASEDIR, FILENAME) saves FIG as FILENAME inside BASEDIR.
%   SAVE_FIGURE(FIG, BASEDIR, SUBDIR, FILENAME) saves FIG inside a
%   subdirectory of BASEDIR. Missing directories are created automatically.
%   If the figure contains UI components, EXPORTAPP is used to ensure they are
%   included in the output. Otherwise EXPORTGRAPHICS is used.

if nargin < 4
    fileName = subDir;
    subDir = '';
end

if nargin < 1 || isempty(fig)
    fig = gcf;
end

if isempty(subDir)
    outDir = baseDir;
else
    outDir = fullfile(baseDir, subDir);
end
if ~exist(outDir, 'dir')
    mkdir(outDir);
end

outFile = fullfile(outDir, fileName);

% Maximize the figure so on-screen windows and exports fill the screen
set_figure_fullscreen(fig);

% Choose a higher resolution automatically for files tagged as "hires"
resolution = 300;
lowerName = lower(fileName);
if contains(lowerName, 'hires') || contains(lowerName, 'highres') || ...
        contains(lowerName, 'hi_res') || contains(lowerName, 'high_res')
    resolution = 450;
end

% Make sure all graphics updates are applied before exporting
drawnow;

% Detect UI components like uitable/uicontrol that require exportapp
uiComponents = findall(fig, 'Type', 'uitable', '-or', 'Type', 'uicontrol');
if ~isempty(uiComponents)
    try
        exportapp(fig, outFile, 'Resolution', resolution);
    catch
        exportgraphics(fig, outFile, 'ContentType', 'image', ...
            'BackgroundColor', 'white', 'Resolution', resolution);
    end
else
    exportgraphics(fig, outFile, 'ContentType', 'image', ...
        'BackgroundColor', 'white', 'Resolution', resolution);
end
end