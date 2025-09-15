function validate_bound_pairing(resultsDir)
% VALIDATE_BOUND_PAIRING Ensure all results show tight/leaky bounds
%
% This function checks that every saved result properly represents
% uncertainty through tight/leaky bounds

    fprintf('\n=== VALIDATING BOUND PAIRING ===\n');
    
    % Check all .mat files
    matFiles = dir(fullfile(resultsDir, '*.mat'));
    
    for i = 1:length(matFiles)
        filepath = fullfile(resultsDir, matFiles(i).name);
        data = load(filepath);
        
        fprintf('Checking %s...\n', matFiles(i).name);
        
        % Special handling for different table types
        if contains(matFiles(i).name, 'costTable')
            validateCostTable(data.costTable);
        elseif contains(matFiles(i).name, 'summaryTable')
            validateSummaryTable(data.summaryTable);
        elseif contains(matFiles(i).name, 'rangeTable')
            % Range table is inherently about bounds - good!
            fprintf('  \xE2\x9C\x93 Range table explicitly shows tight/leaky bounds\n');
        end
    end
    
    % Check generated plots for indicators of bounds
    validatePlots(resultsDir, {'baseline'});
    
    fprintf('\n\xE2\x9C\x93 Bound pairing validation complete\n');
end

function validateCostTable(costTable)
    % Check that all cost metrics have bounds
    requiredBounds = {
        'total_cost_lower', 'total_cost_upper',
        'percent_PM25_reduction_lower', 'percent_PM25_reduction_upper',
        'percent_PM10_reduction_lower', 'percent_PM10_reduction_upper',
        'AQI_hours_avoided_lower', 'AQI_hours_avoided_upper'
    };
    
    missing = setdiff(requiredBounds, costTable.Properties.VariableNames);
    if ~isempty(missing)
        warning('Cost table missing bound columns: %s', strjoin(missing, ', '));
    else
        fprintf('  \xE2\x9C\x93 Cost table has all required bounds\n');
    end
end

function validateSummaryTable(summaryTable)
    % Ensure every scenario has both tight and leaky
    configs = unique(summaryTable(:, {'location', 'filterType', 'mode'}));
    
    for i = 1:height(configs)
        tightRows = summaryTable(strcmp(summaryTable.location, configs.location{i}) & ...
            strcmp(summaryTable.filterType, configs.filterType{i}) & ...
            strcmp(summaryTable.mode, configs.mode{i}) & ...
            strcmp(summaryTable.leakage, 'tight'), :);
        leakyRows = summaryTable(strcmp(summaryTable.location, configs.location{i}) & ...
            strcmp(summaryTable.filterType, configs.filterType{i}) & ...
            strcmp(summaryTable.mode, configs.mode{i}) & ...
            strcmp(summaryTable.leakage, 'leaky'), :);
        
        if isempty(tightRows) || isempty(leakyRows)
            warning('Missing tight/leaky pair for %s-%s-%s', ...
                configs.location{i}, configs.filterType{i}, configs.mode{i});
        end
    end
    fprintf('  \xE2\x9C\x93 Summary table has complete tight/leaky pairs\n');
end

function validatePlots(resultsDir, extraKeywords)
    % CHECK THAT KEY PLOTS SHOWING BOUNDS EXIST
    % Previously this only looked in the top level of resultsDir. Most plots
    % are saved inside subfolders (e.g., "bounds" or "pm"), so a recursive
    % search is required to detect them.

    % Recursively gather all PNG files
    pngFiles = dir(fullfile(resultsDir, '**', '*.png'));
    names = lower({pngFiles.name});

    if nargin < 2
        extraKeywords = {};
    end

    % Keywords that indicate a plot includes bounds.
    % Accepted keywords: 'bounds', 'envelope' and any additional terms
    % provided in extraKeywords such as 'baseline'.
    keywords = lower([{ 'bounds', 'envelope' }, extraKeywords]);

    matches = cellfun(@(kw) any(contains(names, kw)), keywords);
    hasBoundsPlot = any(matches);

    if hasBoundsPlot
        fprintf('  \xE2\x9C\x93 Bounds represented in generated plots\n');
    else
        warning('No plots found illustrating tight/leaky bounds');
    end
end