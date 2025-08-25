function GPSpoints = importiG8points(filename,options)
% Import ig8 data as a .txt file from Carlson Survey handheld (export ASCII) 
% or the LandStar app on android (google drive)
    % use LandStarFormat="Long" to import more variables from the gDrive
    % (default is LandStarFormat="Short")
    arguments
        filename (1,1) string {mustBeText}
        options.LandStarFormat (1,1) string {mustBeText} = getDefaultOptions().LandStarFormat
    end
    %% Input handling
    
    try
    rawtable = readtable(filename); %check if we can even try to read as table
    catch ME
        % Re-throw with a custom error if it's not a table import
        error('InvalidTable:ReadError', ...
              'Unable to import "%s" as a table. Original error: %s', ...
              filename, ME.message);
    end
    tableshape=size(rawtable); % get the dimensions to determine what type of file

    %% Set up the Import Options and import the data
    opts = delimitedTextImportOptions("NumVariables", tableshape(2));
    
    % Specify range and delimiter
    if checkTxtHeader(filename)
        % LandStar File
        opts.DataLines = [2, Inf]; % skip the header
        opts.Delimiter = " ";
    else
        % Handheld iG8 file
        opts.DataLines = [1, Inf]; % read all lines
        opts.Delimiter = "\t";
    end

    % __/\__/\__/\__ Specify Import options 
    if tableshape(2)==29 % LandStar File with Code
        filetype="LandStar+CODE";
        opts.VariableNames = ["Name", "Code", "Northings", "Eastings", "Elevation", "Longitude", "Latitude", "H", "AntennaHeight", "SolutionUsed", "Satellites", "PDOP", "HorizontalError", "VerticalError", "StartTime", "HRMS", "VRMS", "Status", "SATS", "AGE", "PDOP_1", "HDOP", "VDOP", "TDOP", "GDOP", "NRMS", "ERMS", "Date", "Time"];
        opts.SelectedVariableNames = opts.VariableNames;
        opts.VariableTypes = ["double", "string", "string", "string", "double", "string", "string", "double", "double", "categorical", "double", "double", "double", "double", "datetime", "double", "double", "categorical", "double", "double", "string", "double", "double", "double", "double", "double", "double", "string", "string"];

        if strcmp(options.LandStarFormat,"Short")
            opts.SelectedVariableNames = ["Name", "Code", "Northings", "Eastings", "Elevation", "Longitude", "Latitude", "H", "AntennaHeight", "SolutionUsed", "Satellites", "PDOP", "HorizontalError", "VerticalError", "StartTime", "HRMS", "VRMS"];
        end
    
        % Specify variable properties
        opts = setvaropts(opts, ["Code", "Northings", "Eastings", "PDOP_1", "Date", "Time"], "WhitespaceRule", "preserve");
        opts = setvaropts(opts, ["Code", "Northings", "Eastings", "SolutionUsed", "Status", "PDOP_1", "Date", "Time"], "EmptyFieldRule", "auto");
        opts = setvaropts(opts, "StartTime", "InputFormat", "yyyy-MM-dd HH:mm:ss", "DatetimeFormat", "preserveinput");
        opts = setvaropts(opts, ["HRMS", "VRMS", "SATS", "AGE", "HDOP", "VDOP", "TDOP", "GDOP", "NRMS", "ERMS"], "TrimNonNumeric", true);
    elseif tableshape(2)==28 % LandStar file without code
        filetype="LandStar";
        opts.VariableNames = ["Name", "Northings", "Eastings", "Elevation", "Longitude", "Latitude", "H", "AntennaHeight", "SolutionUsed", "Satellites", "PDOP", "HorizontalError", "VerticalError", "StartTime", "HRMS", "VRMS", "Status", "SATS", "AGE", "PDOP_1", "HDOP", "VDOP", "TDOP", "GDOP", "NRMS", "ERMS", "Date", "Time"];
        opts.SelectedVariableNames = opts.VariableNames;
        opts.VariableTypes = ["double", "string", "string", "double", "string", "string", "double", "double", "categorical", "double", "double", "double", "double", "datetime", "double", "double", "categorical", "double", "double", "string", "double", "double", "double", "double", "double", "double", "string", "string"];
        
        if strcmp(options.LandStarFormat,"Short")
            % this solution is ugly because the "Code" column gets added
            % later in a check.  But since these are IMPORT options, it is
            % not included here
            opts.SelectedVariableNames = ["Name", "Northings", "Eastings", "Elevation", "Longitude", "Latitude", "H", "AntennaHeight", "SolutionUsed", "Satellites", "PDOP", "HorizontalError", "VerticalError", "StartTime", "Date", "HRMS", "VRMS"];
        end

        % Specify variable properties
        opts = setvaropts(opts, ["Northings", "Eastings", "PDOP_1", "Date", "Time"], "WhitespaceRule", "preserve");
        opts = setvaropts(opts, ["Northings", "Eastings", "SolutionUsed", "Status", "PDOP_1", "Date", "Time"], "EmptyFieldRule", "auto");
        opts = setvaropts(opts, "StartTime", "InputFormat", "yyyy-MM-dd HH:mm:ss", "DatetimeFormat", "preserveinput");
        opts = setvaropts(opts, ["HRMS", "VRMS", "SATS", "AGE", "HDOP", "VDOP", "TDOP", "GDOP", "NRMS", "ERMS"], "TrimNonNumeric", true);
    elseif tableshape(2)==17
        filetype="LandStar-Short";
        opts.VariableNames = ["Name", "Code", "Northings", "Eastings", "Elevation", "Longitude", "Latitude", "H", "AntennaHeight", "SolutionUsed", "Satellites", "PDOP", "HorizontalError", "VerticalError", "Time", "HRMS", "VRMS"];
        opts.SelectedVariableNames = opts.VariableNames;
        opts.VariableTypes = ["double", "string", "double", "double", "double", "double", "double", "double", "double", "categorical", "double", "double", "double", "double", "datetime", "double", "double"];

        % Specify variable properties
        % opts = setvaropts(opts, ["Var18", "Var19", "Var20", "Var21", "Var22", "Var23", "Var24", "Var25", "Var26", "Var27", "Var28", "Var29"], "WhitespaceRule", "preserve");
        opts = setvaropts(opts, ["Code", "SolutionUsed"], "EmptyFieldRule", "auto");
        opts = setvaropts(opts, "Time", "InputFormat", "yyyy-MM-dd HH:mm:ss", "DatetimeFormat", "preserveinput");
        opts = setvaropts(opts, ["HRMS", "VRMS"], "TrimNonNumeric", true);
    elseif tableshape(2)==23 % Handheld iG8 file
        filetype="CarlsonHandheld";
        opts.VariableNames = ["Name", "Latitude", "Longitude", "H", "Code", "Northings", "Eastings", "Elevation", "HSDV", "VSDV", "STATUS", "SATS", "AGE", "PDOP", "HDOP", "VDOP", "TDOP", "GDOP", "NSDV", "ESDV", "DATE", "TIME", "RODHGT"];
        % opts.SelectedVariableNames = opts.VariableNames;
        opts.VariableTypes = ["double", "double", "double", "double", "string", "double", "double", "double", "double", "double", "categorical", "double", "double", "double", "double", "double", "double", "double", "double", "double", "string", "string", "string"];
    
        % Specify variable properties
        opts = setvaropts(opts, ["Code", "DATE", "TIME", "RODHGT"], "WhitespaceRule", "preserve");
        opts = setvaropts(opts, ["Code", "STATUS", "DATE", "TIME", "RODHGT"], "EmptyFieldRule", "auto");
        opts = setvaropts(opts, ["HSDV", "VSDV", "SATS", "AGE", "PDOP", "HDOP", "VDOP", "TDOP", "GDOP", "NSDV", "ESDV"], "TrimNonNumeric", true);
    else
        error('Unrecognized number of Columns.  File type may not be supported.')
    end
    
    % Specify file level properties
    opts.ExtraColumnsRule = "ignore";
    opts.EmptyLineRule = "read";
    opts.ConsecutiveDelimitersRule = "join";
    opts.LeadingDelimitersRule = "ignore";
    
    % Import the data
    GPSpoints = readtable(filename, opts);

    GPSpoints = addprop(GPSpoints,{'FileType'},'table');

    GPSpoints.Properties.CustomProperties.FileType=filetype;
    
    
    if or(filetype=="LandStar+CODE",filetype=="LandStar")
        if strcmp(options.LandStarFormat,"Short")
            % Ensure all requested new headers exist
            newHeaders = ["Name", "Code", "Northings", "Eastings", "Elevation", ...
                          "Longitude", "Latitude", "H", "AntennaHeight", "SolutionUsed", ...
                          "Satellites", "PDOP", "HorizontalError", "VerticalError", ...
                          "Time", "HRMS", "VRMS"];
            
            if any(GPSpoints.Properties.VariableNames=="StartTime")
                 GPSpoints = renamevars(GPSpoints, "StartTime", "Time");
            end

            % Add missing columns as NaN / empty
            for h = newHeaders
                if ~ismember(h, GPSpoints.Properties.VariableNames)
                    GPSpoints.(h) = NaN(height(GPSpoints),1);
                end
            end
            
            % Reorder columns
            GPSpoints = GPSpoints(:, newHeaders);
        end

        tableshape=size(GPSpoints);       
        % Assign + or - Longitude
        for i=1:tableshape(1)
            if(GPSpoints.Longitude{i}(end)=='W')
                GPSpoints.Longitude{i}=append('-',GPSpoints.Longitude{i});
                GPSpoints.Longitude{i}(end)=[];
            elseif(GPSpoints.Longitude{i}(end)=='E')
                GPSpoints.Longitude{i}(end)=[];
            else
                % error('Longitude import error.  Unknown coordinate reference (define W or E by appending)')
            end
        end
        
        % Assign + or - Latitude
        for i=1:tableshape(1)
            if(GPSpoints.Latitude{i}(end)=='S')
                GPSpoints.Latitude{i}=append('-',GPSpoints.Latitude{i});
                GPSpoints.Latitude{i}(end)=[];
            elseif(GPSpoints.Latitude{i}(end)=='N')
                GPSpoints.Latitude{i}(end)=[];
            else
                % error('Latitude import error.  Unknown coordinate reference (define N or S by appending)')
            end
        end
        
        % Assign + or - Northings
        for i=1:tableshape(1)
            if(GPSpoints.Northings{i}(end)=='S')
                GPSpoints.Northings{i}=append('-',GPSpoints.Northings{i});
                GPSpoints.Northings{i}(end)=[];
            elseif(GPSpoints.Northings{i}(end)=='N')
                GPSpoints.Northings{i}(end)=[];
            else
                % error('Northings import error.  Unknown coordinate reference (define N or S by appending)')
            end
        end
        
        % Assign + or - Eastings
        for i=1:tableshape(1)
            if(GPSpoints.Eastings{i}(end)=='W')
                GPSpoints.Eastings{i}=append('-',GPSpoints.Eastings{i});
                GPSpoints.Eastings{i}(end)=[];
            elseif(GPSpoints.Eastings{i}(end)=='E')
                GPSpoints.Eastings{i}(end)=[];
            else
                % error('Eastings import error.  Unknown coordinate reference (define E or W by appending)')
            end
        end
        
        
        GPSpoints=convertvars(GPSpoints,{'Longitude','Latitude','Northings','Eastings'},'double');
    end

end


%ᐠ⸜ˎ_ˏ⸝^⸜ˎ_ˏ⸝^⸜ˎ_ˏ⸝ᐟᐠ⸜ˎ_ˏ⸝^⸜ˎ_ˏ⸝^⸜ˎ_ˏ⸝ᐟᐠ⸜ˎ_ˏ⸝^⸜ˎ_ˏ⸝^⸜ˎ_ˏ⸝ᐟᐠ⸜ˎ_ˏ⸝^⸜ˎ_ˏ⸝^⸜ˎ_ˏ⸝ᐟᐠ⸜ˎ_ˏ⸝ᐟᐠ
% Internal Functions

function defaults = getDefaultOptions()
    defaults = struct( ...
        'LandStarFormat', "Short" ...
        );
end

function hasHeader = checkTxtHeader(file)
    % Open file
    fid = fopen(file,'r');
    if fid == -1
        error('Could not open file: %s', file);
    end
    
    % Read first line only
    firstLine = fgetl(fid);
    fclose(fid);
    
    % If the first line does NOT contain numbers, it is a Header
    hasHeader = isempty(regexp(firstLine, '\d', 'once'));
end
