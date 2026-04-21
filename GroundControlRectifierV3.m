%{   
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
   ____                           _  ____            _             _ ____           _   _  __ _            __     _______ 
  / ___|_ __ ___  _   _ _ __   __| |/ ___|___  _ __ | |_ _ __ ___ | |  _ \ ___  ___| |_(_)/ _(_) ___ _ __  \ \   / /___ / 
 | |  _| '__/ _ \| | | | '_ \ / _` | |   / _ \| '_ \| __| '__/ _ \| | |_) / _ \/ __| __| | |_| |/ _ \ '__|  \ \ / /  |_ \ 
 | |_| | | | (_) | |_| | | | | (_| | |__| (_) | | | | |_| | | (_) | |  _ <  __/ (__| |_| |  _| |  __/ |      \ V /  ___) |
  \____|_|  \___/ \__,_|_| |_|\__,_|\____\___/|_| |_|\__|_|  \___/|_|_| \_\___|\___|\__|_|_| |_|\___|_|       \_/  |____/ 
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~                                                                 

This program was created to streamline the process of rectifying camera
station images with control targets from an iG8 survey.  This is a standalone 
GUI that will produce Beta parameters that can be saved to the
CPG_camDatabase.  The Beta parameters are calculated with an initial guess
and iG8 locations, this process is not perfect and requires the user to be
vigilent in correcting uncertainties that are too large.


% ᐠ⸜ˎ_ˏ⸝^⸜ˎ_ˏ⸝^⸜ˎ_ˏ⸝ᐟᐠ⸜ˎ_ˏ⸝^⸜ˎ_ˏ⸝^⸜ˎ_ˏ⸝ᐟᐠ⸜ˎ_ˏ⸝^⸜ˎ_ˏ⸝^⸜ˎ_ˏ⸝ᐟᐠ⸜ˎ_ˏ⸝^⸜ˎ_ˏ⸝^⸜ˎ_ˏ⸝ᐟᐠ⸜ˎ_ˏ⸝^⸜

Inputs{
- iG8_file.txt                      =   iG8 file with Code describing the which img set the point was a part of.  
                                        Code should be made in the field during collections (as a point description 
                                        from the iG8) but it can also be made after the fact.  It is common to make 
                                        mistakes or forget, so many GPS files have a _CORRECTED or _set-corrected 
                                        tag to indicate manual editing
        --> usually exported as "[YYYYMMDD]_[Location/Description].txt"
        --> Header= "Name Code Northings Eastings Elevation Longitude Latitude H Antenna_offset Solution Satellites PDOP Horizontal_error Vertical_error Time HRMS VRMS"

- UsableIMGS folder (.jpg .tif)     =   An image set is ~30 seconds of images from the  camera station.  
                                        This is done to avoid beachgoers obscuring the targets.  Someone needs to 
                                        manually go into each image set and pick 1 frame where all GCPs are visible.
                                        For each image set, there needs to be **1 file**.  All usable images are named with the camera
                                        serial number, so 1 folder can contain images from multiple cameras, but no
                                        duplicate sets.
- the CPG_CameraDatabase            =   The CPG camera database that contains an "empty" entry for the camera you want to correct.  
        --> a survey date with computed Intrinsics.
        --> everything else will be populated with this program.
}

Outputs{
    **All outputs will fall into a defined folder

- Data to populate the CPG_CamDatabase
        --> Beta Parameters (to run future rectifications)
        --> iG8 points with pixel U, V coordinates
}
ᐠ⸜ˎ_ˏ⸝^⸜ˎ_ˏ⸝^⸜ˎ_ˏ⸝ᐟᐠ⸜ˎ_ˏ⸝^⸜ˎ_ˏ⸝^⸜ˎ_ˏ⸝ᐟᐠ⸜ˎ_ˏ⸝^⸜ˎ_ˏ⸝^⸜ˎ_ˏ⸝ᐟᐠ⸜ˎ_ˏ⸝^⸜ˎ_ˏ⸝^⸜ˎ_ˏ⸝ᐟᐠ⸜ˎ_ˏ⸝^⸜

Credit to Levi Gorrell for PickControlPoint and rectification code
Credit to Crameri, F. (2018). Scientific colour maps (hawaiiS.txt)
Credit to Kesh Ikuma for inputsdlg Enhance Input Dialog Box
Credit to Martin Koch & Alec Hoyland for developing Matlab yaml

Created by Carson Black on 20240212.
%}

%% Clear all variables before starting
fig = uifigure;
msg = "About to wipe all variables! Are you sure you want to continue?";
title = "Start Program";
selection=uiconfirm(fig,msg,title, ...
    "Options",{'Ready to start','Cancel'}, ...
    "DefaultOption",1);
switch selection
    case 'Ready to start'
        % Close all figures, wipe all variables, start the program
        close(findall(groot,'Type','figure'))
        close all; clear all; clc
        addpath(genpath(fileparts(mfilename('fullpath'))))
        % disp(fileparts(mfilename('fullpath')));
    case 'Cancel'
        close(fig);
        error('User selected cancel.  Please save you variables before getting started.')
end

%% Options
DefaultOpsFile="PrepOptionsGUI_Defaults.mat"; % Rename this file for multiple defaults!

if ~exist(DefaultOpsFile,'file')
    [UserPrefs,cancelled]=PrepOptionsGUI();
else
    [UserPrefs,cancelled]=PrepOptionsGUI(DefaultOpsFile);
end

if(cancelled==1)
    error('User selected cancel.')
end
clear cancelled DefaultOpsFile

%% Fix UserPrefs file & import GPS
GPSpoints = importiG8points(UserPrefs.GPSSurveyFile);
GPSshape=size(GPSpoints);
if GPSshape(2)==23 % Check GPS format
    GPSpoints = ConvertGPShandheldtoGDrive(GPSpoints);
end
clear GPSshape

% Automatically select survey date from GPS file
if UserPrefs.PullDateFromGPS
    alldays = dateshift(GPSpoints.Time, 'start', 'day');
    unique_days = unique(alldays);
    if isscalar(unique_days)
       UserPrefs.SurveyDate=string(unique_days, 'yyyyMMdd'); 
    else
        error('GPS file contains points from multiple days!  Please manually choose a survey date')
    end
end

% Convert string input to double
UserPrefs.CamSN=str2double(UserPrefs.CamSN);

[path_to_CPG_CamDatabase_folder, ~, ~] = fileparts(UserPrefs.CameraDB);
addpath(genpath(path_to_CPG_CamDatabase_folder));
IndividualCamDB=readCPG_CamDatabase("SiteId", UserPrefs.SiteID, "CamSN",UserPrefs.CamSN);

% Choose which intrinsics to use
if UserPrefs.UsePrevCalib
    % Use the database to grab the previous Camera Calibration
    IndividualCamDB_ST=readCPG_CamDatabase("CamSN",UserPrefs.CamSN,Format="SearchTable");
    validDateIDX = find(IndividualCamDB_ST.Date{1} <= datetime(UserPrefs.SurveyDate,"InputFormat",'yyyyMMdd','TimeZone','UTC'),1,'last'); % Choose closest date without going over

    UserPrefs.DateofICP=string(datetime(IndividualCamDB_ST.Date{1}(validDateIDX)),'yyyyMMdd'); %Temporarily set as Date yyyyMMdd

    pattern = strcat('D', UserPrefs.DateofICP, 'T');
    list=fieldnames(IndividualCamDB);
    matchIdx = contains(list, pattern);
    if any(matchIdx)
        % Extract the full string (e.g., 'D20250122T220000Z')
        UserPrefs.DateofICP = list{matchIdx}; % change to ISO 8601 naming
    else
        error('No matching date found in the database list.');
    end
    clear pattern list matchIdx\

    PrevCamEntry=readCPG_CamDatabase(CamSN=UserPrefs.CamSN,...
        Date=datetime(UserPrefs.DateofICP(2:end-1), 'InputFormat', 'yyyyMMdd''T''HHmmss','TimeZone','UTC'));

    cameracalib=PrevCamEntry.(UserPrefs.DateofICP);
    UserPrefs.DateofICP=strcat('D',UserPrefs.SurveyDate,'T070000Z');

    NewCamEntry=generate_CameraDBstruct(...
        SiteID=UserPrefs.SiteID,...
        CamID=UserPrefs.CamID,...
        CamSN=UserPrefs.CamSN,...
        Filename=UserPrefs.CameraFilename, ...
        Date=UserPrefs.DateofICP); % Create a workspace var based on User inputs

    NewCamEntry.(UserPrefs.DateofICP)=cameracalib; % copy over previous
    NewCamEntry.(UserPrefs.DateofICP).GroundControl={}; % remove any previous GCPs


else
    % Upload a file to include the camera GCPs
    %UserPrefs.Calib= PATH TO .mat file
    % Use struct2cell to peel the name away immediately
    loadCamParamdata = struct2cell(load(UserPrefs.CalibFile));
    cameracalib = loadCamParamdata{1};

    UserPrefs.DateofICP=strcat('D',UserPrefs.SurveyDate,'T070000Z'); 
    %WIP UserPrefs.DateofICP is the only UserPrefs defined outside of
    %PrepOptionsGUI.  I also dislike that presents itself as a Date, but is
    %in fact a struct name.  

    NewCamEntry=generate_CameraDBstruct(...
        SiteID=UserPrefs.SiteID,...
        CamID=UserPrefs.CamID,...
        CamSN=UserPrefs.CamSN,...
        Filename=UserPrefs.CameraFilename, ...
        Date=UserPrefs.DateofICP,...
        CameraParams=cameracalib); % Create a workspace var based on User inputs

    clear loadCamParamdata
end
clear cameracalib

%WIP Generate a new CPG_CamDatabase now with blank GCP file as an
%intermediate step.  Plug this into gps_map_gui.m
% cpgDB=updateCPG_CamDatabase(NewCamEntry);

%% Find files in usable img folder 
extensions = {'*.tif', '*.TIF', '*.jpg', '*.JPG'};
files = [];
for ext = extensions
    % The '**' tells MATLAB to look in all subfolders
    current_files = dir(fullfile(UserPrefs.GCPimgPath, '**', ext{1}));
    files = [files; current_files];
end
% Convert to table and handle dates
if ~isempty(files)
    files = struct2table(files);
    files.datetime = datetime(files.datenum, 'ConvertFrom', 'datenum');
else
    warning('No images found in the specified directory or subdirectories.');
end

% Mask files that were taken with other cameras
CameraDBentry=readCPG_CamDatabase(format="searchtable", CamSN=UserPrefs.CamSN);
filemask=contains(files.name, CameraDBentry.Filename);
if all(filemask==0)
    error(['Could not find any files in usable-imgs folder matching your selected camera SN.\n' ...
        'Filename from CPG_CamDatabase: %s'],CameraDBentry.Filename)
end
files=files(filemask,:); % Remove files that are captured from different cameras

% Calculate closest survey date with captured image date
if all(abs(files.datetime(1)-files.datetime(:))<=seconds(10))
    % IMG datetimes are not true values, we need to calculate capture time
    % based off the filename:
    files.datetime= NaT(size(files.datetime));
    for i=1:size(files,1)
        files.datetime(i)=extractDatetimeFromFilename(files.name{i});
    end
end

numpoints=length(GPSpoints.Time);
dif=seconds(zeros(numpoints,1));
minIND=zeros(numpoints,1);
for i=1:numpoints
    timediff=files.datetime-repmat(GPSpoints.Time(i),length(files.datetime),1);
    timediff(timediff<0)=NaN;
    [dif(i),minIND(i)]=min(timediff, [], 'omitnan');
end
minIND(isnan(dif))=NaN(); % remove all values associated with NaN

% Link Img filename to survey set number
INDvalues=unique(minIND);
INDvalues(isnan(INDvalues))=[];
GPSpoints.FileIDX(:)=repmat("",height(GPSpoints),1);
for i=1:length(INDvalues)

    mask = minIND== INDvalues(i);
    maskedIndices = find(mask); 
    [DifTimes(i),localIDX]=min(dif(maskedIndices));
    linkedIDX=maskedIndices(localIDX);

    SetMask=GPSpoints.Code(linkedIDX); % Find the set# of associated min value
    % Apply filename to all of that set#
    GPSpoints.FileIDX(GPSpoints.Code==SetMask)=repmat(files.name(INDvalues(i)),length(GPSpoints.FileIDX(GPSpoints.Code==SetMask)),1);
end
disp("Difference between last GPS time and image capture time:")
disp(DifTimes);

% Clean up
clear i dif INDvalues filemask linkedIDX localIDX mask maskedIndicies minIND numpoints SetMask timediff maskedIndices
%% Get UV coordinates from relevant GPS data

hFig = gps_map_gui(UserPrefs, GPSpoints, NewCamEntry);  % Get figure handle
% uiwait(hFig);  % Wait until the GUI resumes or is closedy

%%
%{ 
ᐠ⸜ˎ_ˏ⸝^⸜ˎ_ˏ⸝^⸜ˎ_ˏ⸝ᐟᐠ⸜ˎ_ˏ⸝^⸜ˎ_ˏ⸝^⸜ˎ_ˏ⸝ᐟᐠ⸜ˎ_ˏ⸝^⸜ˎ_ˏ⸝^⸜ˎ_ˏ⸝ᐟᐠ⸜ˎ_ˏ⸝^⸜ˎ_ˏ⸝^⸜ˎ_ˏ⸝ᐟᐠ⸜ˎ_ˏ⸝ᐟᐠ⸜

  ___             _   _             
 | __|  _ _ _  __| |_(_)___ _ _  ___
 | _| || | ' \/ _|  _| / _ \ ' \(_-<
 |_| \_,_|_||_\__|\__|_\___/_||_/__/
                                    
ˏ⸝^⸜ˎ_ˏ⸝^⸜ˎ_ˏ⸝ᐟᐠ⸜ˎ_ˏ⸝^⸜ˎ_ˏ⸝^⸜ˎ_ˏ⸝ᐟᐠ⸜ˎ_ˏ⸝^⸜ˎ_ˏ⸝^⸜ˎ_ˏ⸝ᐟᐠ⸜ˎ_ˏ⸝^⸜ˎ_ˏ⸝^⸜ˎ_ˏ⸝ᐟᐠ⸜ˎ_ˏ⸝ᐟᐠ⸜ˎ_ˏ
%}

function dt = extractDatetimeFromFilename(filename)
    % Extract datetime from filename string
    % Supports:
    %   - Epoch timestamps (10-digit seconds or 13-digit milliseconds)
    %   - Formatted timestamps like yyyy-MM-dd_HH-mm-ss
    %
    % Output:
    %   dt = datetime object in UTC

    % --- 1. Try finding epoch timestamp (13 or 10 digits) ---
    tokens = regexp(filename, '\d{13}|\d{10}', 'match');
    if ~isempty(tokens)
        % Take the first candidate
        numStr = tokens{1};
        epochVal = str2double(numStr);

        % Convert to seconds if it's in milliseconds
        if length(numStr) == 13
            epochVal = epochVal / 1000;
        end

        % Convert to datetime in UTC
        dt = datetime(epochVal, 'ConvertFrom','posixtime');
        return
    end

    % --- 2. Try formatted timestamp yyyy-MM-dd_HH-mm-ss ---
    tokens = regexp(filename, '\d{4}-\d{2}-\d{2}_\d{2}-\d{2}-\d{2}', 'match');
    if ~isempty(tokens)
        try
            dt = datetime(tokens{1}, 'InputFormat','yyyy-MM-dd_HH-mm-ss');
            return
        catch
            % If parsing fails, keep going to error
        end
    end

    % --- 3. If nothing worked, throw an error ---
    error('extractDatetimeFromFilename:NoDateFound', ...
          'Could not find a valid datetime in filename: %s', filename);
end
