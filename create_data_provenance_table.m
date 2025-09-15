function provenance = create_data_provenance_table(summaryTable)
% CREATE_DATA_PROVENANCE_TABLE  Record source information for each variable
vars = summaryTable.Properties.VariableNames;
source = repmat("simulation_file", numel(vars),1);
provenance = table(vars', source, 'VariableNames', {'field','source'});
end