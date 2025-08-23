function GPSgDriveVariable = ConvertGPShandheldtoGDrive(handheldGPSVariable)
%Convert iG8 handheld variable to the Google drive format
    arguments
        handheldGPSVariable (:,23) {mustBeValidHandheldVar}
    end
    
    HandheldHeaders = ["Name", "Latitude", "Longitude", "H", "Code", "Northings", "Eastings", "Elevation", "HSDV", "VSDV", "STATUS", "SATS", "AGE", "PDOP", "HDOP", "VDOP", "TDOP", "GDOP", "NSDV", "ESDV", "DATE", "TIME", "RODHGT"];

    renameMap = containers.Map( ...
        {'Name','Code','Northings','Eastings','Elevation','Longitude','Latitude','H', ...
         'RODHGT','STATUS','SATS','PDOP','HSDV','VSDV','TIME','DATE'}, ...
        {'Name','Code','Northings','Eastings','Elevation','Longitude','Latitude','H', ...
         'Antenna_offset','Solution','Satellites','PDOP','Horizontal_error','Vertical_error','Time','Date'} );

end



%ᐠ⸜ˎ_ˏ⸝^⸜ˎ_ˏ⸝^⸜ˎ_ˏ⸝ᐟᐠ⸜ˎ_ˏ⸝^⸜ˎ_ˏ⸝^⸜ˎ_ˏ⸝ᐟᐠ⸜ˎ_ˏ⸝^⸜ˎ_ˏ⸝^⸜ˎ_ˏ⸝ᐟᐠ⸜ˎ_ˏ⸝^⸜ˎ_ˏ⸝^⸜ˎ_ˏ⸝ᐟᐠ⸜ˎ_ˏ⸝ᐟᐠ
% Internal Functions

function defaults = getDefaultOptions()
    defaults = struct( ...
        'Color', "Orange", ...
        'NumSides', 0, ...
        'Date', datetime(0,1,1,'TimeZone','America/Los_Angeles') ... %datime for NaT (like NaN but Not a datetime)
        );
end

function mustBeValidHandheldVar(Input)
    if isa(Input,"table")
        HandheldHeaders = ["Name", "Latitude", "Longitude", "H", "Code", "Northings", "Eastings", "Elevation", "HSDV", "VSDV", "STATUS", "SATS", "AGE", "PDOP", "HDOP", "VDOP", "TDOP", "GDOP", "NSDV", "ESDV", "DATE", "TIME", "RODHGT"];
        if all(Input.Properties.VariableNames==HandheldHeaders)
            return; %passed headers check
        else
            error('Table VariableNames do not align! try importGPShandheld()')
        end
    else
        error('Input is not a table! try importGPShandheld()');
    end
end