function [pose, xyzGCP] = EstimateCameraPose(CamCoords,GCPtable)
% Estimate the pitch, roll, azimuth of a camera based on ground control
% points taken below the station.
    % CamCoords is a DYYYYMMDDTHHMMSSZ struct from the CPG_CamDatabase OR a [lat, lon, elev] vector
    % GCPtable is an iG8 survey file that only includes points that are
    % visible to the camera.  (try masking the survey with
    % GPSpoints.ImageU~=0)
    arguments
        CamCoords {mustBeValidPoseInput}
        GCPtable (:,:) {checkTableFields}
    end

    % Add Dependancies
    functionFolder = fileparts(mfilename('fullpath')); % get location of current function
    addpath(genpath(fullfile(functionFolder,'helper_functions\'))); % include helper functions
    wgs84 = wgs84Ellipsoid; % Define ellipsoid

    %Handle CPG_CamDatabase struct
    if isstruct(CamCoords.CamPose)
        utmstruct = defaultm('utm');
        utmstruct.zone = convertStringsToChars(CamCoords.CamPose.UTMzone);
        utmstruct.geoid = wgs84Ellipsoid;
        utmstruct = defaultm(utmstruct);
        
        [CAMERAlat, CAMERAlon] = projinv(utmstruct,str2num(CamCoords.CamPose.Eastings),str2num(CamCoords.CamPose.Northings));
        CAMERAheight=str2num(CamCoords.CamPose.Height);
    else
        CAMERAlat=CamCoords(1);
        CAMERAlon=CamCoords(2);
        CAMERAheight=CamCoords(3);
    end
    
    % Convert lat, lon to local coordinate system
    %Pre-allocate
    numpoints=length(GCPtable.Eastings);
    localX=NaN(numpoints,1);
    localY=NaN(numpoints,1);
    localZ=NaN(numpoints,1);
    for i =1:numpoints
        [localX(i),localY(i),localZ(i)] = geodetic2enu(GCPtable.Latitude(i),GCPtable.Longitude(i),GCPtable.Elevation(i),CAMERAlat,CAMERAlon,CAMERAheight,wgs84);
    end

    xyzGCP=[localX,localY,localZ];
    localAVG=mean(xyzGCP,1);

    % Calculate the vector components
    dx = localAVG(1); % Change in x (relative to origin)
    dy = localAVG(2); % Change in y (relative to origin)
    dz = localAVG(3); % Change in z (relative to origin)

    localMIN=min(xyzGCP,[],1);
    localMAX=max(xyzGCP,[],1);
        
    % Calculate the pitch (angle from the horizontal plane, in degrees)
    pitchFromHorizontal = atan2d(dz, sqrt(dx^2 + dy^2));
    pitch = abs(90 + pitchFromHorizontal);

    
    % Calculate the azimuth (angle in the horizontal plane, in degrees)
    azimuth = atan2d(dx, dy);

    %DEBG plot the results
    % scatter3(localX,localY,localZ)
    % hold on
    % scatter3(0,0,0,"color",[1 0 0])
    % scatter3(localAVG(1),localAVG(2),localAVG(3),"color",[1 1 0])
    % plot3([localAVG(1),0],[localAVG(2),0],[localAVG(3),0],"color",[0 1 0])

    % Backtrack & plot unit vector based on the calculated values
    % yawR = deg2rad(azimuth+90);
    % pitchR = deg2rad(pitch);
    % u=cos(yawR)*cos(pitchR);
    % v=sin(yawR)*-cos(pitchR);
    % w=sin(pitchR);
    % scale=pdist([localAVG;0,0,0]);
    % plot3([scale*u,0],[scale*v,0],[scale*w,0],"color",[1 0 0])
    
    % Ensure azimuth is in the range [0, 360]
    if azimuth < 0
        azimuth = azimuth + 360;
    end
    
    roll= 0; % We will assume roll is close to zero as the horizon should be (mostly) level

    % If we have ImageU and ImageV data from pixel coordinates, use it to
    % apply a fudge factor to the pitch of the camera!
    pitch=pitch*(mean(nonzeros(GCPtable.ImageV))/(str2num(CamCoords.Intrinsics.ImageSize_V)/2));
    

    pose=[pitch,roll,azimuth];
end
%ᐠ⸜ˎ_ˏ⸝^⸜ˎ_ˏ⸝^⸜ˎ_ˏ⸝ᐟᐠ⸜ˎ_ˏ⸝^⸜ˎ_ˏ⸝^⸜ˎ_ˏ⸝ᐟᐠ⸜ˎ_ˏ⸝^⸜ˎ_ˏ⸝^⸜ˎ_ˏ⸝ᐟᐠ⸜ˎ_ˏ⸝^⸜ˎ_ˏ⸝^⸜ˎ_ˏ⸝ᐟᐠ⸜ˎ_ˏ⸝ᐟᐠ
%% Internal Functions

function mustBeValidPoseInput(val)
    if isnumeric(val)
        if ~isequal(size(val), [1,3])
            error('Numeric input must be a 1x3 vector: [lat, lon, elev].');
        end
    elseif isstruct(val)
        requiredFields = ["Northings", "Eastings", "Height", "UTMzone"];
        for f = requiredFields
            if ~isfield(val.CamPose, f)
                error("Struct is missing required field: %s", f);
            end
        end
    else
        error("Input must be a numeric 1x3 vector [lat, lon, elev] or a ""(ISO 8601 date)"" struct from CPG_CamDatabase.");
    end
end


function checkTableFields(tbl) 
    istable(tbl) && all(ismember({'Longitude', 'Latitude', 'Elevation'}, tbl.Properties.VariableNames));
end