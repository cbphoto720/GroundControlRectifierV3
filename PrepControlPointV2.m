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
        close(fig);
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
% DBinfotable=readCPG_CamDatabase(UserPrefs.CameraDB);

% camStruct=importCameraData(UserPrefs.CameraDB, searchKeyoption); %WIP use rowIDX to verify and date confusion about the selected camera!

%% Select GPS file
GPSpoints=importGPSpoints(UserPrefs.GPSSurveyFile);

% Plot the GPS points as scattered Sets
load("hawaiiS.txt"); %load color map (max 100 sets * # points/set = total GPS points possible)
setnames=unique(GPSpoints(:,2)); % Find unique sets
NUM_IMGsets=size(setnames,1); % Calc size of loop for all sets
if NUM_IMGsets>100
    error('GPS Survey contains more than 100 unique descriptions.  Please group sets appropriately')
end

plt=geoscatter(GPSpoints.Latitude(1),GPSpoints.Longitude(1),36,hawaiiS(1), "filled"); %plot the first point
geobasemap satellite
hold on
for i=1:NUM_IMGsets
    s=setnames.Code(i); % Loop through all unique Code names
    mask=strcmp(GPSpoints{:,2},s); % Search points for number of sets
    plt=geoscatter(GPSpoints.Latitude(mask,:),GPSpoints.Longitude(mask,:),36,hawaiiS(mod(i-1, 100) + 1,:),"filled"); % ensure color rollover
end    
clear i
hold off

% Single out 1 point
% pointofintrest=13;
% geoscatter(GPSpoints.Latitude(pointofintrest),GPSpoints.Longitude(pointofintrest),250,[0,0,0],"filled","p")

% Set figure size
set(0,'units','pixels');
scr_siz = get(0,'ScreenSize');
set(gcf,'Position',[floor([10 150 scr_siz(3)*0.8 scr_siz(4)*0.5])]);


% Add labels
a=GPSpoints.Name;
b=num2str(a); c=cellstr(b);
% Randomize the label direction by creating a unit vector.
vec=-1+(1+1)*rand(length(GPSpoints.Name),2);
dir=vec./(((vec(:,1).^2)+(vec(:,2).^2)).^(1/2));
scale=0.000002; % offset text from point
% dir(:)=0; % turn ON randomization by commenting out this line
offsetx=-0.0000004+dir(:,1)*scale; % offset text on the point
offsety=-0.00000008+dir(:,2)*scale; % offset text on the point
text(GPSpoints.Latitude+offsety,GPSpoints.Longitude+offsetx,c)
clear vec dir scale offsetx offsety a b c % clean up

[~,surveyName,~]=fileparts(UserPrefs.GPSSurveyFile);
figurename=strcat(surveyName,"_PLOT.png");
saveas(plt,fullfile(UserPrefs.OutputFolder,UserPrefs.OutputFolderName,figurename));
clear surveyName figurename

%% %WIP Select a ROI for the GPS points!
% - think about how the image box could also be pulled up to assist.
gps_map_gui(UserPrefs)



%% Create usable img copies
% have user select the number of target in each img to determine how many
% copies (camera-agnostic)  Should be saved in PCP_DefaultOptions.
files = dir(fullfile(UserPrefs.UsableIMGsFolder,[filesep,'*.tif']));
% for fileIDX=1:length(filenames)
    pickGCPsGUI(files(1).name); %WIP pass in filenames and loop through
% end

%%
%{ 
ᐠ⸜ˎ_ˏ⸝^⸜ˎ_ˏ⸝^⸜ˎ_ˏ⸝ᐟᐠ⸜ˎ_ˏ⸝^⸜ˎ_ˏ⸝^⸜ˎ_ˏ⸝ᐟᐠ⸜ˎ_ˏ⸝^⸜ˎ_ˏ⸝^⸜ˎ_ˏ⸝ᐟᐠ⸜ˎ_ˏ⸝^⸜ˎ_ˏ⸝^⸜ˎ_ˏ⸝ᐟᐠ⸜ˎ_ˏ⸝ᐟᐠ⸜

  ___             _   _             
 | __|  _ _ _  __| |_(_)___ _ _  ___
 | _| || | ' \/ _|  _| / _ \ ' \(_-<
 |_| \_,_|_||_\__|\__|_\___/_||_/__/
                                    
ˏ⸝^⸜ˎ_ˏ⸝^⸜ˎ_ˏ⸝ᐟᐠ⸜ˎ_ˏ⸝^⸜ˎ_ˏ⸝^⸜ˎ_ˏ⸝ᐟᐠ⸜ˎ_ˏ⸝^⸜ˎ_ˏ⸝^⸜ˎ_ˏ⸝ᐟᐠ⸜ˎ_ˏ⸝^⸜ˎ_ˏ⸝^⸜ˎ_ˏ⸝ᐟᐠ⸜ˎ_ˏ⸝ᐟᐠ⸜ˎ_ˏ
%}

function [searchKeyoption,rowIDX]=PickCamFromDatabase(path_to_SIO_CamDatabase)
    opts = detectImportOptions(path_to_SIO_CamDatabase, "Delimiter", "\t");

    opts.SelectedVariableNames = ["CamSN","CamNickname","DateofGCP"];
    opts.MissingRule="omitrow";
    CameraOptionsTable=readtable(path_to_SIO_CamDatabase,opts);

    CameraOptionsTable.Checkbox=false(height(CameraOptionsTable),1);

    Title = 'Pick camera profile from database';
    Options.Resize = 'on';
    Options.Interpreter = 'tex';
    Options.CancelButton = 'on';
    Options.ApplyButton = 'off';
    Options.ButtonNames = {'Continue','Cancel'};
    
    Prompt = {};
    Formats = {};

    Prompt(1,:) = {['Select only 1 camera station from the checkbox!'], [], []};
    Formats(1,1).type = 'text';
    Formats(1,1).size = [-1 0];

    Prompt(end+1,:) = {'Item Table','Table',[]};
    Formats(2,1).type = 'table';
    % Formats(1,1).format = {'char', {'left','right'}, 'numeric' 'logical'}; % table (= table in main dialog) / window (= table in separate dialog)
    Formats(2,1).items = {'CamSN' 'CamNickname' 'Date'};
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
            searchKeyoption=answers.Table{rowIDX, 1}; % Extract the first column value
        end
    else
        error('User selected cancel!');
    end
end

%% GPS map GUI
function gps_map_gui(UserPrefs)
    % Load GPS Data and Colormap
    GPSpoints=importGPSpoints(UserPrefs.GPSSurveyFile);
    load("hawaiiS.txt"); % Load color map

    % Determine number of image sets
    NUM_IMGsets = size(unique(GPSpoints(:,2)),1);

    % Create main UI figure
    % Set figure size
    set(0,'units','pixels');
    scr_siz = get(0,'ScreenSize');
    GPSplot = uifigure('Name', 'GPS Map Viewer', 'Position', [floor([10 150 scr_siz(3)*0.8 scr_siz(4)*0.5])]);

    % Create a geoaxes for plotting the GPS map
    geoax = geoaxes(GPSplot, 'Position', [0.05, 0.2, 0.9, 0.75]); % Normalized
    hold(geoax, 'on'); % Allow multiple drawings
    title(geoax, 'GPS Map');

    % Plot the first point
    plt = geoscatter(geoax, GPSpoints.Latitude(1), GPSpoints.Longitude(1), ...
                     36, hawaiiS(1,:), "filled"); 
    geobasemap(geoax, 'satellite');

    % Plot all points
    for i = 1:NUM_IMGsets+1
        setname = "set" + i;
        mask = strcmp(GPSpoints{:,2}, setname);
        geoscatter(geoax, GPSpoints.Latitude(mask), GPSpoints.Longitude(mask), ...
                   36, hawaiiS(mod(i-1,100)+1, :), "filled");
    end    
    hold(geoax, 'off');

    % Store line handles for dynamic editing
    guiData.drawnLine = []; 
    guidata(GPSplot, guiData);

     % Create Buttons (normalized positions)
    btnPrev = uibutton(GPSplot, 'Text', 'Back', ...
        'Position', [90, 20, 120, 40], 'ButtonPushedFcn', @(~,~) prevCallback());

    btnNext = uibutton(GPSplot, 'Text', 'Forward', ...
        'Position', [230, 20, 120, 40], 'ButtonPushedFcn', @(~,~) nextCallback());

    btnDraw = uibutton(GPSplot, 'Text', 'Draw Line', ...
        'Position', [370, 20, 120, 40], 'ButtonPushedFcn', @(~,~) drawLine(geoax, GPSplot));

    btnDelete = uibutton(GPSplot, 'Text', 'Delete Line', ...
        'Position', [510, 20, 120, 40], 'ButtonPushedFcn', @(~,~) deleteLine(GPSplot));

    % Add Labels
    addLabels(geoax, GPSpoints);
end

% Callback Functions

function prevCallback()
    disp('Back button pressed'); % Placeholder for navigation logic
end

function nextCallback()
    disp('Forward button pressed'); % Placeholder for navigation logic
end

function drawLine(ax, fig)
    guiData = guidata(fig);

    % Select two points interactively
    [lon, lat] = ginput(2);
    if numel(lat) == 2 && numel(lon) == 2
        % Draw the new line and store its handle
        newLine = geoplot(ax, lat, lon, 'r-', 'LineWidth', 2); 

        % Ensure GPS points stay visible
        hold(ax, 'on');

        % Store new line in an array
        if ~isfield(guiData, 'drawnLines')
            guiData.drawnLines = [];
        end
        guiData.drawnLines = [guiData.drawnLines; newLine]; 

        guidata(fig, guiData); % Save updated handles
    end
end

function deleteLine(fig)
    guiData = guidata(fig);

    if isfield(guiData, 'drawnLines') && ~isempty(guiData.drawnLines)
        % Ask user which line to delete
        numLines = numel(guiData.drawnLines);
        choice = inputdlg(sprintf('Enter line number (1-%d) to delete:', numLines), ...
                          'Delete Line', 1, {'1'});

        if ~isempty(choice)
            lineNum = str2double(choice{1});
            if lineNum >= 1 && lineNum <= numLines
                % Delete selected line
                delete(guiData.drawnLines(lineNum));

                % Remove from array
                guiData.drawnLines(lineNum) = [];

                guidata(fig, guiData); % Save updated handles
            else
                errordlg('Invalid selection! Choose a valid line number.', 'Error');
            end
        end
    else
        warndlg('No lines to delete!', 'Warning');
    end
end



% Function to Add Labels to Points
function addLabels(ax, GPSpoints)
    a = GPSpoints.Name;
    b = num2str(a);
    c = cellstr(b);
    
    % Randomize the label direction by creating a unit vector.
    vec = -1 + (1+1) * rand(length(GPSpoints.Name), 2);
    dir = vec ./ sqrt(vec(:,1).^2 + vec(:,2).^2);
    
    scale = 0.000002; % Offset text from point
    offsetx = -0.0000004 + dir(:,1) * scale; 
    offsety = -0.00000008 + dir(:,2) * scale; 

    text(ax, GPSpoints.Latitude + offsety, GPSpoints.Longitude + offsetx, c);
end


%% Img copier GUI

function pickGCPsGUI(imgfile,filenames)
    % Load image
    img = imread(imgfile);

    % Ensure the image is RGB
    if size(img, 3) == 1
        img = repmat(img, [1 1 3]); % Convert grayscale to RGB
    elseif size(img, 3) > 3
        img = img(:, :, 1:3); % Remove alpha channel if present
    end

    % Create main figure
    fig = figure('Name', 'Interactive Zoom Display', 'NumberTitle', 'off'); % Adjusted window size
    set(0,'units','pixels');
    scr_siz = get(0,'ScreenSize');
    set(gcf,'Position',[floor([10 scr_siz(4)*0.3 scr_siz(3)*0.65 scr_siz(4)*0.6])]);

    % Create a panel for layout
    main_panel = uipanel(fig, 'Position', [0, 0.15, 1, 0.85]);

    % Parent image subplot (Large)
    ax_main = axes('Parent', main_panel, 'Position', [0.05, 0.1, 0.6, 0.85]);
    imshow(img, 'Parent', ax_main);
    title(ax_main, 'Click to Zoom');

    % Zoomed-in image subplot (Smaller)
    ax_zoom = axes('Parent', main_panel, 'Position', [0.7, 0.35, 0.25, 0.5]);
    imshow(zeros(400, 400, 3)); % Placeholder blank image
    title(ax_zoom, 'Zoomed View');

    % Zoom level bar (directly below zoomed view)
    zoom_bar = uicontrol('Style', 'text', 'Parent', fig, ...
                         'Units', 'normalized', 'Position', [0.7, 0.2, 0.25, 0.05], ...
                         'BackgroundColor', [0.8 0.8 0.8], 'FontSize', 12, ...
                         'String', 'Zoom Level: 1000');

    % Button panel (bottom row)
    button_panel = uipanel(fig, 'Position', [0, 0, 1, 0.15]);
    imax=12; % set max buttons (plus 1 extra for BACK)
    for i = 0:imax
        if i==imax
            uicontrol('Style', 'pushbutton', 'Parent', button_panel, ...
                  'String', 'BACK', 'Units', 'normalized', ...
                  'Position', [(i)*1/(imax+1), 0, 1/(imax+1), 1], ...
                  'FontSize', 12, 'Callback', @(src, event) button_callback(i));
        else
            uicontrol('Style', 'pushbutton', 'Parent', button_panel, ...
                  'String', num2str(i), 'Units', 'normalized', ...
                  'Position', [(i)*1/(imax+1), 0, 1/(imax+1), 1], ...
                  'FontSize', 12, 'Callback', @(src, event) button_callback(i));
        end
    end

    % Shared zoom size
    zoom_size = 1000; % Start with least zoomed-in view

    % Store zoom level using guidata
    data.zoom_size = zoom_size;
    data.img = img;
    data.ax_main = ax_main;
    data.ax_zoom = ax_zoom;
    data.zoom_bar = zoom_bar;
    guidata(fig, data);

    % Set callbacks
    set(fig, 'WindowButtonDownFcn', @(src, event) update_zoom(fig));
    set(fig, 'WindowScrollWheelFcn', @(src, event) adjust_zoom_level(fig, event));
end

function update_zoom(fig)
    % Get stored data
    data = guidata(fig);
    img = data.img;
    ax_main = data.ax_main;
    ax_zoom = data.ax_zoom;
    zoom_size = data.zoom_size;

    % Get mouse click position in main figure
    pt = get(ax_main, 'CurrentPoint');
    x = round(pt(1,1));
    y = round(pt(1,2));

    % Ensure zoom does not go out of bounds
    half_size = floor(zoom_size / 2);
    [rows, cols, ~] = size(img);
    x = max(half_size + 1, min(cols - half_size, x));
    y = max(half_size + 1, min(rows - half_size, y));

    % Extract zoomed region
    zoomed_img = img(y-half_size:y+half_size, x-half_size:x+half_size, :);

    % Resize zoomed image to fit zoom window
    zoomed_img = imresize(zoomed_img, [400 400]); 

    % Update zoom figure
    imshow(zoomed_img, 'Parent', ax_zoom);
end

function adjust_zoom_level(fig, event)
    % Get stored data
    data = guidata(fig);
    
    % Adjust zoom size
    zoom_change = -30;
    data.zoom_size = max(10, min(1000, data.zoom_size - zoom_change * event.VerticalScrollCount));

    % Update zoom level bar text (flipped scale)
    set(data.zoom_bar, 'String', sprintf('Zoom Level: %d', data.zoom_size)); 

    % Save updated zoom size
    guidata(fig, data);
end

function button_callback(num)
    disp(['Button ' num2str(num) ' pressed!']);
end