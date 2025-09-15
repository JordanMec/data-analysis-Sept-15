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

% Detect UI components like uitable/uicontrol that require exportapp
uiComponents = findall(fig, 'Type', 'uitable', '-or', 'Type', 'uicontrol');
if ~isempty(uiComponents)
    try
        exportapp(fig, outFile);
    catch
        exportgraphics(fig, outFile);
    end
else
    exportgraphics(fig, outFile);
end
end