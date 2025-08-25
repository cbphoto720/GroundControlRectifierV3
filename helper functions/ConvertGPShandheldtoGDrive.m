function LandStarGPSformat = ConvertGPShandheldtoGDrive(handheldGPSVariable)
%Convert iG8 handheld variable to the Google drive format
    arguments
        handheldGPSVariable (:,23) {mustBeValidHandheldVar}
    end
    
    renameMap = containers.Map( ...
        {'Name','Code','Northings','Eastings','Elevation','Longitude','Latitude','H', ...
         'RODHGT','STATUS','SATS','PDOP','HSDV','VSDV','TIME','DATE'}, ...
        {'Name','Code','Northings','Eastings','Elevation','Longitude','Latitude','H', ...
         'Antenna_offset','Solution','Satellites','PDOP','Horizontal_error','Vertical_error','Time','Date'} );

    % Apply renaming if fields exist
    oldNames = handheldGPSVariable.Properties.VariableNames;
    newNames = oldNames;
    for i = 1:numel(oldNames)
        if isKey(renameMap, oldNames{i})
            newNames{i} = renameMap(oldNames{i});
        end
    end
    handheldGPSVariable.Properties.VariableNames = newNames;

    % Combine Date + Time into new format
    if all(ismember({'Date','Time'}, handheldGPSVariable.Properties.VariableNames))
        % Old date format: "DATE:06-14-2025"
        % Old time format: "TIME:06:50:32"
        oldDate = strrep(handheldGPSVariable.Date, 'DATE:', '');
        oldTime = strrep(handheldGPSVariable.Time, 'TIME:', '');
        
        % Convert to datetime
        dt = datetime(strcat(oldDate, {' '}, oldTime), ...
                      'InputFormat', 'MM-dd-yyyy HH:mm:ss','Format','yyyy-MM-dd HH:mm:ss');
        
        % Store as char in new format
        handheldGPSVariable.Time = dt;

        % Remove old Date column
        handheldGPSVariable.Date = [];
    end

    % Fix "Antenna offset"
    if ismember({'Antenna_offset'}, handheldGPSVariable.Properties.VariableNames)
        handheldGPSVariable.Antenna_offset=strrep(handheldGPSVariable.Antenna_offset, 'RODHGT2:', '');
    end
    % Fix "Solution"
    if ismember({'Solution'}, handheldGPSVariable.Properties.VariableNames)
        oldCats = categories(handheldGPSVariable.Solution);                         % Get existing categories
        newCats = regexprep(oldCats, '^STATUS:', '');           % Remove "STATUS:" prefix
        handheldGPSVariable.Solution = renamecats(handheldGPSVariable.Solution, oldCats, newCats);      % Rename categories
    end
    
    % Ensure all requested new headers exist
    newHeaders = ["Name", "Code", "Northings", "Eastings", "Elevation", ...
                  "Longitude", "Latitude", "H", "Antenna_offset", "Solution", ...
                  "Satellites", "PDOP", "Horizontal_error", "Vertical_error", ...
                  "Time", "HRMS", "VRMS"];
    
    % Add missing columns as NaN / empty
    for h = newHeaders
        if ~ismember(h, handheldGPSVariable.Properties.VariableNames)
            handheldGPSVariable.(h) = NaN(height(handheldGPSVariable),1);
        end
    end
    
    % Reorder columns
    LandStarGPSformat = handheldGPSVariable(:, newHeaders);
end



%ᐠ⸜ˎ_ˏ⸝^⸜ˎ_ˏ⸝^⸜ˎ_ˏ⸝ᐟᐠ⸜ˎ_ˏ⸝^⸜ˎ_ˏ⸝^⸜ˎ_ˏ⸝ᐟᐠ⸜ˎ_ˏ⸝^⸜ˎ_ˏ⸝^⸜ˎ_ˏ⸝ᐟᐠ⸜ˎ_ˏ⸝^⸜ˎ_ˏ⸝^⸜ˎ_ˏ⸝ᐟᐠ⸜ˎ_ˏ⸝ᐟᐠ
% Internal Functions

function mustBeValidHandheldVar(Input)
    if isa(Input,"table")
        HandheldHeaders = ["Name", "Latitude", "Longitude", "H", "Code", "Northings", "Eastings", "Elevation", "HSDV", "VSDV", "STATUS", "SATS", "AGE", "PDOP", "HDOP", "VDOP", "TDOP", "GDOP", "NSDV", "ESDV", "DATE", "TIME", "RODHGT"];
        if all(Input.Properties.VariableNames==HandheldHeaders)
            return; %passed headers check
        else
            error('Table VariableNames do not align! Make sure you are using a handhel ASCII format & try importiG8points()')
        end
    else
        error('Input is not a table! Make sure you are using a handhel ASCII format & try importiG8points()');
    end
end