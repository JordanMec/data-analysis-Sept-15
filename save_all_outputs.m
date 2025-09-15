function save_all_outputs(baseResultsDir, baseFiguresDir)
% SAVE_ALL_OUTPUTS Create timestamped folders for results
% SAVE_ALL_OUTPUTS(BASERESULTSDIR) creates new subfolder
% suffixed with the current timestamp (MMMM_dd_HH_mm_ss) and confirms the
% results directory exists.

if nargin < 1 || isempty(baseResultsDir)
    baseResultsDir = fullfile(pwd, 'results');
end

% Create timestamp
timestamp = datestr(now, 'mmmm_dd_HH_MM_SS');

% Create full output paths with timestamp
resultsDir = fullfile(baseResultsDir, ['run_' timestamp]);

% Create directories if they don't exist
if ~exist(resultsDir, 'dir')
    mkdir(resultsDir);
end

% Only confirm directory creation (no .mat handling)
disp(['✓ Timestamped results folder created: ', resultsDir]);

end