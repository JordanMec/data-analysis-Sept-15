function generate_active_mode_report(results, saveDir)
% Create comprehensive markdown report

fid = fopen(fullfile(saveDir, 'active_mode_analysis_report.md'), 'w');

fprintf(fid, '# Advanced Active Mode Aerosol Analysis Report\n\n');
fprintf(fid, 'Generated: %s\n\n', datestr(now));

fprintf(fid, '## Executive Summary\n\n');
fprintf(fid, 'This report presents a comprehensive analysis of the active mode ');
fprintf(fid, 'air filtration system performance, treating building envelope conditions ');
fprintf(fid, '(tight/leaky) as uncertainty bounds rather than separate scenarios.\n\n');

% Key findings section
fprintf(fid, '## Key Findings\n\n');

configs = fieldnames(results.ioRatios);
for i = 1:numel(configs)
    config = configs{i};
    ioData = results.ioRatios.(config);
    
    fprintf(fid, '### %s - %s Filter\n\n', ioData.location, ioData.filterType);
    fprintf(fid, '- **Average I/O Ratio (PM2.5)**: %.3f (Range: %.3f - %.3f)\n', ...
        ioData.stats.pm25_mean, ioData.stats.pm25_range(1), ioData.stats.pm25_range(2));
    fprintf(fid, '- **Average I/O Ratio (PM10)**: %.3f (Range: %.3f - %.3f)\n', ...
        ioData.stats.pm10_mean, ioData.stats.pm10_range(1), ioData.stats.pm10_range(2));
    fprintf(fid, '- **System Variability**: PM2.5 CV = %.2f%%, PM10 CV = %.2f%%\n\n', ...
        ioData.dynamics.pm25_variability * 100, ioData.dynamics.pm10_variability * 100);
end

fprintf(fid, '\n## Detailed Analysis Sections\n\n');
fprintf(fid, '1. Indoor/Outdoor Ratio Dynamics\n');
fprintf(fid, '2. Trigger Response Characterization\n');
fprintf(fid, '3. Particle Penetration Analysis\n');
fprintf(fid, '4. Pollution Event Response\n');
fprintf(fid, '5. Temporal Patterns\n');
fprintf(fid, '6. Cross-Correlation Analysis\n');
fprintf(fid, '7. Filter Performance Comparison\n');
fprintf(fid, '8. Uncertainty Quantification\n');

fclose(fid);
end