% Conver alll variables into .txt docs (used to help make SIO_camDatabase)

% Get all variables in the workspace
vars = whos; 

% Open a file to write
fileID = fopen('workspace_variables.txt', 'w');

% Loop through each variable
for i = 1:length(vars)
    varValue = eval(vars(i).name); % Get variable value
    
    % Check if numeric and matrix
    if ismatrix(varValue) && isnumeric(varValue)
        fprintf(fileID, '%g\t', varValue); % Print values with tabs
    end
end

% Close file
fclose(fileID);

disp('Workspace variables saved to workspace_variables.txt');