function avoidedTable = analyze_avoided_exposure(summaryTable)
% ANALYZE_AVOIDED_EXPOSURE Calculate hours avoided in each AQI category
%   Compares outdoor vs indoor AQI categories hour by hour to determine
%   how much time was kept below each pollution level.
arguments
      summaryTable table
end

aqiNames = ["Good","Moderate","Unhealthy for Sensitive Groups", ...
    "Unhealthy","Very Unhealthy","Hazardous"];


% Updated AQI thresholds (\xB5g/m^3)
% PM2.5: 0-9 (Good), 9.1-35.4 (Moderate), 35.5-55.4 (Unhealthy for SG),
%        55.5-125.4 (Unhealthy), 125.5-225.4 (Very Unhealthy),
%        225.5-325.4 (Hazardous)
pm25_edges = [0.0, 9.0, 35.4, 55.4, 125.4, 225.4, 325.4];

% PM10: 0-54 (Good), 55-154 (Moderate), 155-254 (Unhealthy for SG),
%       255-354 (Unhealthy), 355-424 (Very Unhealthy),
%       425-604 (Hazardous)
pm10_edges = [0.0, 54.0, 154.0, 254.0, 354.0, 424.0, 604.0];

% Use character vectors for robust compatibility with older versions
combos = unique(summaryTable(:,{'location','leakage','filterType','mode'}),'rows');
varTypes = [repmat("string",1,4), repelem("double",1,numel(aqiNames))];
varNames = ["location","leakage","filterType","mode", aqiNames];
avoidedTable = table('Size',[height(combos),numel(varNames)], ...
    'VariableTypes',varTypes,'VariableNames',varNames);

for i = 1:height(combos)
    loc  = combos.location(i);
    leak = combos.leakage(i);
    filt = combos.filterType(i);
    mode = combos.mode(i);

    row = summaryTable(strcmp(summaryTable.location,loc) & ...
        strcmp(summaryTable.leakage,leak) & ...
        strcmp(summaryTable.filterType,filt) & ...
        strcmp(summaryTable.mode,mode), :);
    if isempty(row)
        continue;
    end

    in25 = row.indoor_PM25{1};
    in10 = row.indoor_PM10{1};
    out25 = row.outdoor_PM25{1};
    out10 = row.outdoor_PM10{1};

    catIn  = max(discretize(in25, pm25_edges), discretize(in10, pm10_edges));
    catOut = max(discretize(out25, pm25_edges), discretize(out10, pm10_edges));

    counts = zeros(1,numel(aqiNames));
    for c = 2:numel(aqiNames)
        counts(c) = sum(catOut >= c & catIn < c);
    end

    avoidedTable.location(i)   = loc;
    avoidedTable.leakage(i)    = leak;
    avoidedTable.filterType(i) = filt;
    avoidedTable.mode(i)       = mode;
    avoidedTable{i, aqiNames}  = counts;
end
end