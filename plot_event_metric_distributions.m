function plot_event_metric_distributions(eventTable, figuresDir)
%PLOT_EVENT_METRIC_DISTRIBUTIONS Create boxplots and ECDFs for event metrics
%   PLOT_EVENT_METRIC_DISTRIBUTIONS(TBL, FIGURESDIR) visualizes the
%   distribution of lag times, recovery times, attenuation and AUC
%   reduction for each configuration and pollutant. Flagged events are
%   removed prior to plotting.  FIGURESDIR specifies where PNG files are
%   saved using SAVE_FIGURE.

arguments
    eventTable table
    figuresDir string = "plots"
end

flagged = strlength(eventTable.flags) > 0;
cleanTbl = eventTable(~flagged,:);

if isempty(cleanTbl)
    warning('plot_event_metric_distributions: no unflagged events to plot.');
    return;
end

metrics = {'lag_peak','recovery_time','attenuation','auc_reduction'};
labels = {'Lag to Indoor Peak (h)','Recovery Time (h)', ...
          'Indoor/Outdoor Amplitude','AUC Reduction (frac)'};

[G, groups] = findgroups(cleanTbl.config, cleanTbl.pollutant);
grpLabels = strcat(strrep(groups(:,1),'_',' '), " (", groups(:,2), ")");

for m = 1:numel(metrics)
    metric = metrics{m};
    fig = figure('Visible','off');
    tiledlayout(1,2);
    % Boxplot
    nexttile;
    boxchart(G, cleanTbl.(metric));
    set(gca,'XTick',1:numel(grpLabels),'XTickLabel',grpLabels);
    xtickangle(45);
    ylabel(labels{m});
    title(sprintf('Distribution of %s', strrep(metric,'_',' ')));
    grid on;

    % ECDF
    nexttile;
    hold on;
    for g = 1:max(G)
        vals = cleanTbl.(metric)(G==g);
        vals = vals(~isnan(vals));
        if isempty(vals), continue; end
        [f,x] = ecdf(vals);
        plot(x,f,'DisplayName',grpLabels(g));
    end
    xlabel(labels{m});
    ylabel('ECDF');
    title(sprintf('ECDF of %s', strrep(metric,'_',' ')));
    legend('Location','best');
    grid on;

    fname = sprintf('%s_distribution.png', metric);
    save_figure(fig, figuresDir, fname);
    close(fig);
end
end