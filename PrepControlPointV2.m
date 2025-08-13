%{   
  _____                 _____            _             _ _____      _       _    __      _____  
 |  __ \               / ____|          | |           | |  __ \    (_)     | |   \ \    / /__ \ 
 | |__) | __ ___ _ __ | |     ___  _ __ | |_ _ __ ___ | | |__) |__  _ _ __ | |_   \ \  / /   ) |
 |  ___/ '__/ _ \ '_ \| |    / _ \| '_ \| __| '__/ _ \| |  ___/ _ \| | '_ \| __|   \ \/ /   / / 
 | |   | | |  __/ |_) | |___| (_) | | | | |_| | | (_) | | |  | (_) | | | | | |_     \  /   / /_ 
 |_|   |_|  \___| .__/ \_____\___/|_| |_|\__|_|  \___/|_|_|   \___/|_|_| |_|\__|     \/   |____|
                | |                                                                             
                |_|                                                                             

This program was created to streamline the process of rectifying camera
station images with control targets from an iG8 survey.  This program is
designed to work with PickControlPointV3, which is the interface for doing 
the rectifying.  Here, we will prepare a set of images to import into the 
PickControlPoint software, as well as generate the necessary files to link 
the coordinates with the items on screen.  

ᐠ⸜ˎ_ˏ⸝^⸜ˎ_ˏ⸝^⸜ˎ_ˏ⸝ᐟᐠ⸜ˎ_ˏ⸝^⸜ˎ_ˏ⸝^⸜ˎ_ˏ⸝ᐟᐠ⸜ˎ_ˏ⸝^⸜ˎ_ˏ⸝^⸜ˎ_ˏ⸝ᐟᐠ⸜ˎ_ˏ⸝^⸜ˎ_ˏ⸝^⸜ˎ_ˏ⸝ᐟᐠ⸜ˎ_ˏ⸝^⸜

Inputs{
- iG8_file.txt                      =   iG8 file with Code describing the which img set the point was a part of.  
                                        Code should be made in the field during collections (as a point description 
                                        from the iG8) but it can also be made after the fact.  It is common to make 
                                        mistakes or forget, so many GPS files have a _CORRECTED or _set-corrected 
                                        tag to indicate manual editing
        --> usually exported as "[YYYYMMDD]_[Location/Description].txt"
        --> Header= "Name Code Northings Eastings Elevation Longitude Latitude H Antenna_offset Solution Satellites PDOP Horizontal_error Vertical_error Time HRMS VRMS"

- UsableIMGS folder (contains .tif) =   An image set is ~30 seconds of images from the  camera station.  
                                        This is done to avoid beachgoers obscuring the targets.  Someone needs to 
                                        manually go into each image set and pick 1 frame where all GCPs are visible.
                                        For each image set, there needs to be **1 file** that this software uses to
                                        generate the required copies.  All usable images are named with the camera
                                        serial number, so 1 folder can contain images from multiple cameras, but no
                                        duplicate sets.
}

Outputs{
    **All outputs will fall into a defined folder

- [YYYYMMDD]Survey.llz              =    A data file of GPS points and local
                                    coordinates based off of the CAMERA's GPS position
- [YYYYMMDD]UTCimgSets.utc          =    Fake timing information generated to spoof PickControlPoint
                                    into assigning the correct order of image sets for rectification
- [YYYYMMDD]UTCimgSets_[IMG #].tif  =    Images will be copied into this naming structure for use in the 
                                    PickControlPoint.  There will be duplicate images depending on 
                                    the number of ground control targets in view
- CamExtrinsicEst.txt               =   A very rough guess at the local Pitch, Roll, Azimuth of the camera.  
                                    (The GPS position of the camera is the local survey Origin)
}
ᐠ⸜ˎ_ˏ⸝^⸜ˎ_ˏ⸝^⸜ˎ_ˏ⸝ᐟᐠ⸜ˎ_ˏ⸝^⸜ˎ_ˏ⸝^⸜ˎ_ˏ⸝ᐟᐠ⸜ˎ_ˏ⸝^⸜ˎ_ˏ⸝^⸜ˎ_ˏ⸝ᐟᐠ⸜ˎ_ˏ⸝^⸜ˎ_ˏ⸝^⸜ˎ_ˏ⸝ᐟᐠ⸜ˎ_ˏ⸝^⸜

Credit to Levi Gorrell for PickControlPoint
Credit to Crameri, F. (2018). Scientific colour maps (hawaiiS.txt)
Credit to Kesh Ikuma for inputsdlg Enhance Input Dialog Box
Credit to Martin Koch & Alec Hoyland for developing Matlab yaml

Created by Carson Black on 20240212.
%}

%% Ask nicely before deleting
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
        disp(fileparts(mfilename('fullpath')));
    case 'Cancel'
        close(fig);
        error('User selected cancel.  Please save you variables before getting started.')
end

%% Options
DefaultOpsFile="PCP_DefaultOptions.mat"; % Rename this file for multiple defaults!

if ~exist(DefaultOpsFile,'file')
    [UserPrefs,cancelled]=PrepOptionsGUI();
else
    [UserPrefs,cancelled]=PrepOptionsGUI(DefaultOpsFile);
end

if(cancelled==1)
    error('User selected cancel.')
elseif(UserPrefs.SetOptAsDefault) %handle storing new defaults file
    savepath = fullfile(fileparts(mfilename('fullpath')),DefaultOpsFile);
    DefAns=UserPrefs;
    save(savepath,"DefAns","-mat");
    clear DefAns savepath
elseif(exist(fullfile(UserPrefs.OutputFolder,UserPrefs.OutputFolderName),'file')==7) %check if output folder exists
    fig = uifigure;
    selection = uiconfirm(fig,'Warning! Output folder already exists! Ok to over-write?','Output Warning',"Icon","warning");
    switch selection
        case 'OK'
            close(fig);
        case 'Cancel'
            close(fig);
            error('User selected cancel.')
    end
    clear selection fig
end
clear cancelled DefaultOpsFile

%% Pick Camera from database
GPSpoints = importGPSpoints(UserPrefs.GPSSurveyFile);

[path_to_CPG_CamDatabase_folder, ~, ~] = fileparts(UserPrefs.CameraDB);
addpath(genpath(path_to_CPG_CamDatabase_folder));

% Have user select Camera and Intrinsics they want to use for this rectification
[UserPrefs.CamFieldSite,UserPrefs.CamSN,UserPrefs.CamNickName]=PickCamFromDatabase();
[UserPrefs.DateofICP,~]=PickCamIntrinsicsDate(UserPrefs.CamSN);

FullCamDB=readCPG_CamDatabase("CamSN",UserPrefs.CamSN);

% Find files in usable img folder 
files = dir(fullfile(UserPrefs.UsableIMGsFolder,[filesep,'*.tif']));
files=struct2table(files);
files.datetime=datetime(files.datenum,'ConvertFrom','datenum'); % Create datetime column

%
%WIP - Temporary until Filename is added to CPG_CamDatabase
CameraDBentry=readCPG_CamDatabase(format="searchtable", CamSN=UserPrefs.CamSN);
if contains(CameraDBentry.Fieldsite, "Seacliff")
    filemask=contains(files.name, strcat("Seacliff_",string(CameraDBentry.CamSN)));
else
    error(['Could not find any files in usable-imgs folder matching your selected camera SN.\n' ...
        'Filename: %s'],'') %WIP improve this error message to list filename once data is available in CPG_CamDatabase
end
files=files(filemask,:); % Remove files that are captured from different cameras

% Calculate closest survey date with captured image date
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

hFig = gps_map_gui(UserPrefs, GPSpoints, FullCamDB);  % Get figure handle
% uiwait(hFig);  % Wait until the GUI resumes or is closed

%% Generate Cam pose based on the GPS points
disp("GUI closed. Resuming main script...");

% do more actions (like load in the saved data)
outputmask=find(GPSpoints.ImageU~=0); % find indexes that have an associated Image pixel coordinate (GPS points visible to the camera)
[pose, xyzGCP] = EstimateCameraPose(FullCamDB.(UserPrefs.DateofICP),GPSpoints(outputmask,:)); %WIP TEMP get initial pose estimate & GCPs in local coordinates camera=[0,0,0]

% [UserPrefs.DateofICP,~]=PickCamIntrinsicsDate(UserPrefs.CameraDB,UserPrefs.CamSN);

% Generate ICP (Internal Camera Parameters [Intrinsics]) based on a previous survey
readDB=readCPG_CamDatabase(CamSN=UserPrefs.CamSN,Date=string(UserPrefs.DateofICP(2:end)),format="compact");
icp=readDB.icp;
icp = makeRadialDistortion(icp);
icp = makeTangentialDistortion(icp);
        
betaOUT = constructCameraPose(xyzGCP, [GPSpoints.ImageU(outputmask,:), GPSpoints.ImageV(outputmask,:)], icp, [0,0,0,pose]);

%%
%{ 
ᐠ⸜ˎ_ˏ⸝^⸜ˎ_ˏ⸝^⸜ˎ_ˏ⸝ᐟᐠ⸜ˎ_ˏ⸝^⸜ˎ_ˏ⸝^⸜ˎ_ˏ⸝ᐟᐠ⸜ˎ_ˏ⸝^⸜ˎ_ˏ⸝^⸜ˎ_ˏ⸝ᐟᐠ⸜ˎ_ˏ⸝^⸜ˎ_ˏ⸝^⸜ˎ_ˏ⸝ᐟᐠ⸜ˎ_ˏ⸝ᐟᐠ⸜

  ___             _   _             
 | __|  _ _ _  __| |_(_)___ _ _  ___
 | _| || | ' \/ _|  _| / _ \ ' \(_-<
 |_| \_,_|_||_\__|\__|_\___/_||_/__/
                                    
ˏ⸝^⸜ˎ_ˏ⸝^⸜ˎ_ˏ⸝ᐟᐠ⸜ˎ_ˏ⸝^⸜ˎ_ˏ⸝^⸜ˎ_ˏ⸝ᐟᐠ⸜ˎ_ˏ⸝^⸜ˎ_ˏ⸝^⸜ˎ_ˏ⸝ᐟᐠ⸜ˎ_ˏ⸝^⸜ˎ_ˏ⸝^⸜ˎ_ˏ⸝ᐟᐠ⸜ˎ_ˏ⸝ᐟᐠ⸜ˎ_ˏ
%}

%% Pick Camera From Database
function [CamFieldSite,CamSN,CamNickName]=PickCamFromDatabase()
    CameraOptionsTable=readCPG_CamDatabase(format="searchtable");
    CameraOptionsTable.Date=[]; % remove date for display purposes
    CameraOptionsTable.Fieldsite=char(CameraOptionsTable.Fieldsite); % convert to char
    CameraOptionsTable.CamID=char(CameraOptionsTable.CamID); % convert to char
    CameraOptionsTable.Checkbox=false(height(CameraOptionsTable),1); % add checkbox for user selection

    Title = 'Pick camera profile from database';
    Options.Resize = 'on';
    Options.Interpreter = 'tex';
    Options.CancelButton = 'on';
    Options.ApplyButton = 'off';
    Options.ButtonNames = {'Continue','Cancel'};
    
    Prompt = {};
    Formats = {};

    Prompt(1,:) = {'Select only 1 camera station from the checkbox!', [], []};
    Formats(1,1).type = 'text';
    Formats(1,1).size = [-1 0];

    Prompt(end+1,:) = {'Item Table','Table',[]};
    Formats(2,1).type = 'table';
    Formats(2,1).items = {'Fieldsite', 'CamSN', 'CamID', 'Checkbox'};
    Formats(2,1).format = {'char', 'char', 'char', 'logical'};
    Formats(2,1).size = [-1 -1];
    DefAns.Table = table2cell(CameraOptionsTable);



    [answers, cancelled] = inputsdlg(Prompt, Title, Formats, DefAns, Options);

    if ~cancelled
        lastCol = cell2mat(answers.Table(:, end)); % Convert last column to logical/array
        numTrue = sum(lastCol); % Count the number of true values
        
        if numTrue ~= 1
            error('Please select only 1 camera!');
        else
            rowIDX = find(lastCol, 1); % Find the first row where true appears
            CamNickName=answers.Table{rowIDX, 3};
            CamNickName=strtrim(CamNickName); %remove spaces
            CamFieldSite=answers.Table{rowIDX, 1};
            CamFieldSite=strtrim(CamFieldSite); %remove spaces
            CamSN=answers.Table{rowIDX, 2}; % Extract the 2nd column value (CamSN)
        end
    else
        error('User selected cancel!');
    end
end

function [searchKeyoption,rowIDX]=PickCamIntrinsicsDate(CamSerialNumber)
    CamDBread=readCPG_CamDatabase(CamSN=CamSerialNumber,Format="searchtable");
    dateArray = CamDBread.Date{:};
    DateOptionsTable = table(dateArray', 'VariableNames', {'Date'});
    DateOptionsTable.Date = strcat('D',datestr(DateOptionsTable.Date, 'yyyymmddThhMMssZ'));  % or use any format you like
    DateOptionsTable.Checkbox=false(height(DateOptionsTable),1); % add checkbox for user selection

    Title = 'Pick Intrinsics from a GCP date';
    Options.Resize = 'on';
    Options.Interpreter = 'tex';
    Options.CancelButton = 'on';
    Options.ApplyButton = 'off';
    Options.ButtonNames = {'Continue','Cancel'};
    
    Prompt = {};
    Formats = {};

    Prompt(1,:) = {'Select only 1 date from the checkbox!', [], []};
    Formats(1,1).type = 'text';
    Formats(1,1).size = [-1 0];

    Prompt(end+1,:) = {'Item Table','Table',[]};
    Formats(2,1).type = 'table';
    Formats(2,1).items = {'Date','Checkbox'};
    Formats(2,1).format = {'char', 'logical'};
    Formats(2,1).size = [-1 -1];
    DefAns.Table = table2cell(DateOptionsTable);



    [answers, cancelled] = inputsdlg(Prompt, Title, Formats, DefAns, Options);

    if ~cancelled
        lastCol = cell2mat(answers.Table(:, end)); % Convert last column to logical/array
        numTrue = sum(lastCol); % Count the number of true values
        
        if numTrue ~= 1
            error('Please select only 1 camera!');
        else
            rowIDX = find(lastCol, 1); % Find the first row where true appears
            searchKeyoption=answers.Table{rowIDX, 1}; % Extract the 2nd column value (CamSN)
        end
    else
        error('User selected cancel!');
    end
end