function LocalCamCoords = GenerateCamExtrinsicEstimate(Center_Controlpoint_est,GPSCamCoords, outputfolder)
%GenerateCamExtrinsic will attempt to create a "first pass" estimate of
%camera position, pitch, roll, & azimuth for the Levi PickControlPoint software

%{
Inputs:
    - Center_Controlpoint_est   =   [Lat, Lon, Elevation] GPS Position of a point close to the center 
                                    & bottom of the camera frame. (a point in the middle of the beach)
    - GPSCamCoords              =   [Lat, Lon, Elevation] GPS position of the camera
    - outputfolder              =   Folder location to save the .txt file
    
Outputs:
    - LocalCamCoords            =   [Lat, Lon, Elevation, pitch, roll, azimuth] 
            Roll, pitch, azimuth are estimate by drawing a staright line
            from the camera position to the LocalSurveyOrigin
    - CamExtrinsicsEstimate.txt =  .txt file used to import for the PickControlPoint software
%}


%% Parser


%% Do the math
GRS80 = referenceEllipsoid('GRS80'); % Define ellipsoid

% Convert lat, lon to local coordinate system
[xEast,yNorth,zUp] = geodetic2enu(GPSCamCoords(1),GPSCamCoords(2),GPSCamCoords(3),Center_Controlpoint_est(1),Center_Controlpoint_est(2),Center_Controlpoint_est(3),GRS80);

% Calculate the vector components
dx = -xEast; % Change in x (relative to origin)
dy = -yNorth; % Change in y (relative to origin)
dz = -zUp; % Change in z (relative to origin)

% Calculate the pitch (angle from the horizontal plane, in degrees)
pitch = atan2d(dz, sqrt(dx^2 + dy^2));

% Calculate the azimuth (angle in the horizontal plane, in degrees)
azimuth = atan2d(dx, dy);

% Ensure azimuth is in the range [0, 360]
if azimuth < 0
    azimuth = azimuth + 360;
end

roll= 0; % We will assume roll is close to zero as the horizon should be (mostly) level

LocalCamCoords=[xEast,yNorth,zUp,pitch,roll,azimuth];
%% Generate the File
filename=strcat('CamExtrinsicEst.txt');

% Check if the file already exists
overwriteFile = true; % Default to overwriting or creating new file.
if exist(fullfile(outputfolder,filename),'file')
    promptMessage = sprintf('This file already exists:\n%s\nDo you want to overwrite it?', filename);
    titleBarCaption = 'Overwrite?';
    buttonText = questdlg(promptMessage, titleBarCaption, 'Yes', 'No', 'Yes');
    if strcmpi(buttonText, 'No')
        % User does not want to overwrite. 
        % Set flag to not do the write.
        overwriteFile = false;
        error('user chose not to overwrite the existing file');
    end
end

% Make the .txt file
if overwriteFile
    fid=fopen(fullfile(outputfolder,filename),'w');

    fprintf(fid,'X0 = %.3f\nY0 = %.3f\nZ0 = %.3f\nPitch = %.1f\nRoll = %.1f\nAzimuth = %.1f\n', LocalCamCoords(1),LocalCamCoords(2),LocalCamCoords(3), pitch,roll,azimuth);
    
    fclose(fid);
    
    fprintf('Success! File has been created here: %s\n',fullfile(outputfolder,filename));

end