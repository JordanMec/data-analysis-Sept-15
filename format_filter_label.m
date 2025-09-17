function formatted = format_filter_label(label)
%FORMAT_FILTER_LABEL Normalize filter labels to include HEPA 13 and MERV 15 names.
%   formatted = FORMAT_FILTER_LABEL(label) replaces underscores with spaces and
%   ensures any standalone "HEPA" or "MERV" tokens are shown as "HEPA 13" and
%   "MERV 15", respectively.

formatted = strrep(label, '_', ' ');
formatted = regexprep(formatted, '\bHEPA\b', 'HEPA 13', 'ignorecase');
formatted = regexprep(formatted, '\bMERV\b', 'MERV 15', 'ignorecase');
end
