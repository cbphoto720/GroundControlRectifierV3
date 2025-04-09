function UniqueGPSDescriptionsList=getSetNames(GPSpoints)
    % Function to take GPS survey input and returns a string array of all
    % unique descriptions found.  It will also organize descriptions
    % matching "set(i)" where (i) is an incrimenting number used to group
    % sets of GPS points that are all captured within 1 camera frame.  (We
    % usually work with 5 targets at a time)

    setnames = unique(GPSpoints(:,2)); % Find unique sets
    setnames=string(table2cell(setnames)); % convert to string array

    % Regular expression to extract numbers from "set(i)" format
    expr = "set(\d+)";
    
    % Initialize variables
    numValues = nan(size(setnames)); % Default to NaN for non-matching entries
    
    for i = 1:length(setnames)
        match = regexp(setnames(i), expr, 'tokens', 'once'); % Find "set(i)" pattern
        if ~isempty(match)
            numValues(i) = str2double(match{1}); % Convert extracted number to double
        else
            numValues(i) = 99999;
        end
    end
    
    % Sort: Numeric values first, NaNs (non-matching) at the end
    [~, order] = sort(numValues(~isnan(numValues)));
    sortedSetnames = setnames(order);
    
    % Display result
    % disp(sortedSetnames);
    UniqueGPSDescriptionsList=sortedSetnames;
end