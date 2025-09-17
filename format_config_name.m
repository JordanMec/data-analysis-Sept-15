function formatted = format_config_name(config, delimiter)
%FORMAT_CONFIG_NAME Format configuration keys with HEPA 13 and MERV 15 labels.
%   formatted = FORMAT_CONFIG_NAME(config, delimiter) splits an underscore-
%   separated configuration key and rejoins it with the specified delimiter
%   (default space) while ensuring filter tokens are renamed to HEPA 13 and
%   MERV 15.

if nargin < 2
    delimiter = " ";
end

parts = strsplit(config, '_');
for i = 1:numel(parts)
    if any(strcmpi(parts{i}, {'hepa', 'hepa13', 'hepa_13'}))
        parts{i} = 'HEPA 13';
    elseif any(strcmpi(parts{i}, {'merv', 'merv15', 'merv_15'}))
        parts{i} = 'MERV 15';
    else
        parts{i} = strrep(parts{i}, '-', ' ');
    end
end

delimiterStr = string(delimiter);
formatted = strjoin(parts, delimiterStr);

if delimiterStr ~= " "
    formatted = strrep(formatted, "HEPA" + delimiterStr + "13", "HEPA 13");
    formatted = strrep(formatted, "MERV" + delimiterStr + "15", "MERV 15");
end

formatted = char(formatted);
end
