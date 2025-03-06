function appendSIO_CamDatabase(CamNickname, CamSN, DateofGCP, cameraparams, Path_to_SIO_CamDatabase)
%UNTITLED Summary of this function goes here
%   Detailed explanation goes here
    arguments
        CamNickname (1,1) string {mustBeText}
        CamSN (1,1) {mustBeNumeric}
        DateofGCP (1,1) {mustBeValidDate}
        cameraparams (1,:) {mustBeCameraParameters}
        Path_to_SIO_CamDatabase (1,1) string {mustBeValidFile}
    end
    
    % Convert to YAML-compatible structure
    yamlStruct = struct();
    yamlStruct.CamSN = num2str(CamSN,"%.f");
    yamlStruct.CamNickname = regexprep(CamNickname, '\s', '_');
    if isa(DateofGCP, "datetime") %Handle datetime exceptions
        yamlStruct.DateofGCP = string(datetime(DateofGCP,'Format','yyyyMMdd'));
    else
        yamlStruct.DateofGCP = num2str(DateofGCP);
    end
    yamlStruct.Intrinsics = struct( ...
        'Skew', num2str(cameraparams.Intrinsics.Skew), ...
        'PrincipalPoint_U', num2str(cameraparams.Intrinsics.PrincipalPoint(1)), ...
        'PrincipalPoint_V', num2str(cameraparams.Intrinsics.PrincipalPoint(2)), ...
        'FocalLength_X', num2str(cameraparams.Intrinsics.FocalLength(1)), ...
        'FocalLength_Y', num2str(cameraparams.Intrinsics.FocalLength(2)), ...
        'RadialDistortion_1', num2str(cameraparams.Intrinsics.RadialDistortion(1)), ...
        'RadialDistortion_2', num2str(cameraparams.Intrinsics.RadialDistortion(2)), ...
        'RadialDistortion_3', num2str(cameraparams.Intrinsics.RadialDistortion(3)), ...
        'TangentialDistortion_1', num2str(cameraparams.Intrinsics.TangentialDistortion(1)), ...
        'TangentialDistortion_2', num2str(cameraparams.Intrinsics.TangentialDistortion(2)), ...
        'ImageSize_U', num2str(cameraparams.Intrinsics.ImageSize(1)), ...
        'ImageSize_V', num2str(cameraparams.Intrinsics.ImageSize(2)) ...
    );

    %WIP Add camera Position
    %WIP Add camera Local Coordinate system


    % Create YAML text
    appendtxt=yaml.dump(yamlStruct, "block");
    appendtxt=char(appendtxt);
    appendtxt=regexprep(appendtxt,"\r?\n","\r\t");
    appendtxt=appendtxt(1:end-2);  % Remove the last '\r\t'
    appendtxt=sprintf("\n- ")+appendtxt;

    % % Create file if is doesn't exist             ---->       The SIO_CamDatabase should already exist if we are appending to it!
    % if ~exist(Path_to_SIO_CamDatabase,"file")
    %     mkdir(Path_to_SIO_CamDatabase);
    % end
    fprintf(appendtxt);
    fileID=fopen(Path_to_SIO_CamDatabase,"a");
    fprintf(fileID,"%s",appendtxt);
    fclose(fileID);
    
    fprintf('YAML file saved: \n%s\n', appendtxt);


end

%ᐠ⸜ˎ_ˏ⸝^⸜ˎ_ˏ⸝^⸜ˎ_ˏ⸝ᐟᐠ⸜ˎ_ˏ⸝^⸜ˎ_ˏ⸝^⸜ˎ_ˏ⸝ᐟᐠ⸜ˎ_ˏ⸝^⸜ˎ_ˏ⸝^⸜ˎ_ˏ⸝ᐟᐠ⸜ˎ_ˏ⸝^⸜ˎ_ˏ⸝^⸜ˎ_ˏ⸝ᐟᐠ⸜ˎ_ˏ⸝ᐟᐠ
%% Internal Functions

% Custom validation functions
function mustBeValidDate(dateInput) 
    if ischar(dateInput) || isstring (dateInput) %try to convert to double
        dateInput=str2double(dateInput);
    end

    if isa(dateInput, "datetime")
        % If it's a datetime, it's valid.
        return;
    elseif isnumeric(dateInput) && isscalar(dateInput)
        try datetime(dateInput,"ConvertFrom",'yyyymmdd');
            return
        catch
            error('Could not convert numeric input to datetime.  Please use YYYYMMDD format');
        end
    else % if nothing else
        error("mustBeValidDate:InvalidInput", "Input must be a datetime or a numeric date in YYYYMMDD format.");
    end
end

function mustBeCameraParameters(cameraparams)
    mustBeA(cameraparams,"cameraParameters")
end

function mustBeValidFile(filePath)
    if ~isfile(filePath)
        error("Could not find the SIO_CameraDatabase file.  Please try the fullfile path to 'SIO_CamDatabase.yaml'");
    end
end