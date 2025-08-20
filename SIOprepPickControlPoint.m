% Tehcnically PrepControlPointV1
% now this is scratch paper for trying out pieces of the code

%% Ask before deleting
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
    case 'Cancel'
        close(fig);
        error('User selected cancel.  Please save you variables before getting started.')
end
% mfilename('fullpath') 
%% For GUI work
addpath(genpath("C:\Users\Carson\Documents\Git\SIOCameraRectification"));
addpath("C:\Users\Carson\Documents\Git\cmcrameri\cmcrameri\cmaps") %Scientific color maps

%% For Database work
addpath(genpath("C:\Users\Carson\Documents\Git\CPG_CameraDatabase"));

%% Options
maxPointsInSet=5; % The max number of ground control targets in a single frame (usually 5)
date="20250122"; %date of survey

cameraSerialNumber=21217396; %The camera "Serial Number" is the 8 digit code included in the filename of the image e.g. 21217396
% Seacliff Camera coordinates: ** VERY APPROXIMATE:    
GPSCamCoords=[36.9699953088, -121.9075239352, 31.333];


outputfolderpath="C:\Users\Carson\Documents\Git\SIOCameraRectification\data\20250122\CamB";
if ~isfolder(outputfolderpath)
    mkdir(outputfolderpath);
elseif isfolder(outputfolderpath)
    f=msgbox("Output folder already exists, make sure you don't overwrite another camera!",outputfolderpath);
    warning("Output folder already exists, make sure you don't overwrite another camera!\n%s",outputfolderpath);
end


%% Import iG8 data
f=msgbox("Please select the GPS survey file");
uiwait(f);

[file,location] = uigetfile('*.txt',"Select the GPS survey");
if isequal(file,0)
   disp('User selected Cancel');
else
   disp(['User selected ', fullfile(location,file)]);
   GPSpoints=importGPSpoints(fullfile(location,file));
end

%% Plot GPS points on a Map
load("hawaiiS.txt"); %load color map
NUM_IMGsets=size(unique(GPSpoints(:,2)),1);

plt=geoscatter(GPSpoints.Latitude(1),GPSpoints.Longitude(1),36,hawaiiS(1), "filled"); %plot the first point
geobasemap satellite
hold on
for i=1:NUM_IMGsets+1
    setname="set"+i;
    mask=strcmp(GPSpoints{:,2},setname);
    plt=geoscatter(GPSpoints.Latitude(mask,:),GPSpoints.Longitude(mask,:),36,hawaiiS(i,:),"filled");
end    
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

%% Select GPS points visible in cam
% GPSmask=false(size(GPSpoints,1),1);

f=msgbox("Draw a polygon around the points visible to the cam");
uiwait(f);
roi=drawpolygon();

if size(roi.Position)==[0,0]
    disp("failed to detect region of interest.  Try again.")
else
    GPSmask=inROI(roi,GPSpoints.Latitude,GPSpoints.Longitude);
end

%% Create new survey file base off points in ROI
% Prompt user for Camera number
prompt = {'Enter the Camera Letter for this site:'};
dlgtitle = 'Camera Name';
dims = [1 50];
definput = {'A'};
camnumber = inputdlg(prompt,dlgtitle,dims,definput);

% Create new file extension
smallfile=file;
smallfile=smallfile(1:end-4);
smallfile=smallfile+"_Camera"+camnumber{1}+".txt";

writetable(GPSpoints(GPSmask,:),fullfile(location,smallfile),"Delimiter"," ");
clear GPSpoints, GPSmask;
fprintf('Saved new GPS survey file of points visible to cam%s.  \nPlease re-load the file here to continue: %s\n',camnumber{1},fullfile(location,smallfile))

%% Generate the files

% Generate number of frames from each survey set
num_of_IMGsets=unique(GPSpoints.Code(:));
IMGsetIDX=zeros(length(num_of_IMGsets),1);
for i=1:length(num_of_IMGsets)
    IMGsetIDX(i)=sum(GPSpoints.Code(:)==num_of_IMGsets(i));
end


% Generate .utc
imgtime=generateLeviUTC(size(num_of_IMGsets,1), IMGsetIDX, date, outputfolderpath);

% Genereate .llz
firstpointOrigin=generateLeviLLZ(GPSpoints, date, imgtime, outputfolderpath);

% Copy images to the proper
imgcopiersaver('\\sio-smb.ucsd.edu\CPG-Projects-Ceph\SeacliffCam\20250123_GCP\usable-imgs',...
    outputfolderpath, IMGsetIDX,cameraSerialNumber);






%% Start of Scratch paper



%% Generate Camera Params (levi software)

 LocalCamCoordinates = GenerateCamExtrinsicEstimate(firstpointOrigin,GPSCamCoords, outputfolderpath);

%% read in the CamDatabase

opts = detectImportOptions("SIO_CamDatabase.txt", "Delimiter", "\t");

opts.SelectedVariableNames = ["CamSN","CamNickname","Date"];
opts.MissingRule="omitrow";
readtable("SIO_CamDatabase.txt",opts)

%%

function interactive_zoom_display(imgfile)
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
    imshow(zeros(200, 200, 3)); % Placeholder blank image
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
    zoomed_img = imresize(zoomed_img, [200 200]); 

    % Update zoom figure
    imshow(zoomed_img, 'Parent', ax_zoom);
end

function adjust_zoom_level(fig, event)
    % Get stored data
    data = guidata(fig);
    
    % Adjust zoom size
    zoom_change = -30;
    data.zoom_size = max(10, min(1000, data.zoom_size - zoom_change * event.VerticalScrollCount));

    % Set new zoom limits: Min = 200px (1:1), Max = 1000px (5x zoom)
    % data.zoom_size = max(200, min(1000, data.zoom_size + zoom_change * event.VerticalScrollCount));


    % Update zoom level bar text (flipped scale)
    set(data.zoom_bar, 'String', sprintf('Zoom Level: %d', data.zoom_size)); 

    % Save updated zoom size
    guidata(fig, data);
end

function button_callback(num)
    disp(['Button ' num2str(num) ' pressed!']);
end

imgfile='Seacliff_22296748_1737653186039.tif';
interactive_zoom_display(imgfile);

%% PickControlPoint tests


%%
dif=files.datetime-repmat(GPSpoints.Time(14),length(files.datetime),1)


%%


%%
% Get img filenames
files = dir('C:\Users\Carson\Documents\Git\SIOCameraRectification\data\20250122\usable-imgs\*.tif');
filenames = {files.name};

for fileIDX=1:length(filenames)
    interactive_zoom_display(files(fileIDX).name);
end

%% Import the iG8 file
close all; clear all; clc
fprintf('Thinking ... ')
GPSpointTable=importGPSpoints('20250122_Seacliff_set-corrected.txt');
fprintf('Done Importing!\n')
%% Find the Average of some GPS points
rows=4:6;
j=5;
a=0; %preallocate avg
for i=1:length(rows)
    a=a+GPSpointTable(rows(i),j);
end
a=a./length(rows);

% Work out precision
get_precision = @(x) find(mod(x, 10.^-(1:15)) == 0, 1, 'first');
% Get precision for each row element
decimal_places = arrayfun(get_precision, GPSpointTable{rows,j});
max_precision = max(decimal_places); 
round_a = round(a, max_precision); % Round 'a' to the detected max precision (sometimes the iG8a will round values)

%Get headers
headers = GPSpointTable.Properties.VariableNames;
VariableName = headers{j};


fprintf(['%s AVG:     %f \n%s Rounded: %.',num2str(max_precision),'f\n'],VariableName,a{1,1}, VariableName,round_a{1,1})


%% Matlab YAML

TestreadYAML = yaml.loadFile("SIO_CamDatabaseYAML.yaml");

%% Test write YAML

Path_to_CPG_CamDatabase="CPG_CamDatabase.yaml";

appendSIO_CamDatabase("Carson's Camera", 1234, 20250221, cameraparams, Path_to_CPG_CamDatabase)

%% Convert column vector of data into cell array (to hold multiple values)
camDB.Northings=arrayfun(@(dIn) {dIn},camDB.Northings); %convert column to same values but cells
camDB.Northings{5}=[1111,2222,3333,44,55] %put in a vector into one of the positions.
%% CPG_CamDatabase path
Path_to_CPG_CamDatabase='C:\Users\Carson\Documents\Git\CPG_CameraDatabase\CPG_CamDatabase.yaml'

%% appendSIO_CamDatabase tests

appendSIO_CamDatabase(12345, 20240311, Path_to_SIO_CamDatabase, CamNickname="test", CameraParams=camB_cameraParams)



% import GPS table
GPSimport=importGPSpoints(options.GCPSurveyFile);

% === Enforce Rule: If GCPSurveyFile is set, LCSorigin must also be set ===
if ~strcmp(options.GCPSurveyFile, defaults.GCPSurveyFile) % User modified GCPSurveyFile
    if all(isnan(options.LCSorigin)) || isequal(options.useCameraLCS, defaults.useCameraLCS)
        error("If 'GCPSurveyFile' is provided, 'LCSorigin' must also be specified.");
    end
end

% Calculate world coordinates of GPS survey
GRS80 = referenceEllipsoid('GRS80'); % Define ellipsoid
% Convert lat, lon to local coordinate system.  (use UTM elevation as Z coordinate
[local.xEast,local.yNorth,local.zUp] = geodetic2enu(GPSpoints.Latitude,GPSpoints.Longitude,GPSpoints.Elevation,options.LCSorigin_UTM(1),options.LCSorigin_UTM(2),options.LCSorigin_UTM(3),GRS80);

%%
GPSimport=importGPSpoints('20250122_Seacliff_set-corrected_CameraB.txt')

LatLonElevation=[GPSimport.Latitude,GPSimport.Longitude,GPSimport.Elevation];

%% Estimate Camera Pose
CamLatLonElevation=[36.9699952937,-121.9075239478, 31.334]; % Seacliff Cam_B
GCPtable=importGPSpoints('20250122_Seacliff_set-corrected_CameraC.txt');

EstimateCameraPose(CamLatLonElevation,GCPtable)

%%

GPSimport=importGPSpoints('20250122_Seacliff_set-corrected_CameraA.txt')
%%
scope=1:length(PointNumber);
file='';
if all(PointNumber==GPSimport.Name)
    for i=scope;
        file=append(file,sprintf('      - [%.5f, %.5f, %.3f, %.f, %.f]\n',GPSimport.Northings(i), GPSimport.Eastings(i), GPSimport.Elevation(i), U(i), V(i)));
    end
end
fprintf(file)
% fopen()

%% readCPG_CamDatabase
% yamlData = yaml.loadFile(Path_to_SIO_CamDatabase);

scope=length(yamlData);
searchmatrix={};
for i=1:scope
    elements=fieldnames(yamlData{i});
    for j=1:length(elements)
        if elements{j}=="CamSN"
            searchmatrix{i,j}=yamlData{i}.CamSN;
        elseif elements{j}=="CamNickname"
            searchmatrix{i,j}=yamlData{i}.CamNickname;
        elseif checkDDateFormat(elements{j}) %handle date entries
            searchmatrix{i,j}=datetime(str2num(elements{j}(2:end)), 'ConvertFrom','yyyymmdd');
            % temp.stealdate(i)=datetime(str2num(elements{j}(2:end)), 'ConvertFrom','yyyymmdd');
        else
            searchmatrix{i,j}=elements{j};
        end
    end
end

datetimeIdx = cellfun(@(x) isa(x, 'datetime'), searchmatrix);

% Extract datetime values
datetimeValues = searchmatrix(datetimeIdx)


% function isValid = checkDDateFormat(inputStr)
%     pattern = '^D\d{8}$'; % D followed by exactly 8 digits
%     isValid = ~isempty(regexp(inputStr, pattern, 'once'));
% end

%% 20250421
yamlData = yaml.loadFile('CPG_CamDatabase.yaml');
DBstruct=struct();
searchtable=table( strings(0,1), strings(0,1), strings(0,1), cell(0,1),'VariableNames', {'CamSN', 'CamID', 'Site', 'Date'});

r=1; % set searchtable counter to 0
for i=1:length(yamlData) % make a struct for each site
    DBstruct.(yamlData{i}.SiteID)={};
    for j=1:numel(yamlData{i}.Cameras) % make a struct for each camera
        DBstruct.(yamlData{i}.SiteID).(yamlData{i}.Cameras{j}.CamID)=yamlData{i}.Cameras{j};
        surveydates=fieldnames(yamlData{i}.Cameras{j});
        surveydates(ismember(surveydates, {'CamID', 'CamSN'})) = []; % remove non-date elements
        searchtable(r, :) = {yamlData{i}.Cameras{j}.CamSN, yamlData{i}.Cameras{j}.CamID, yamlData{i}.SiteID, surveydates};
        r=r+1;
    end
end
clear i j r

%% 20250421

for i=1:length(surveydates)
    if checkDDateFormat(surveydates{i})
        datetime(surveydates{i}, "InputFormat", "'D'yyyyMMdd'T'HHmmss'Z'")
    end
end

function isValid = checkDDateFormat(inputStr)
    pattern = '^D\d{8}T\d{6}Z$'; % D + 8 digits (date) + T + 6 digits (time) + Z
    isValid = ~isempty(regexp(inputStr, pattern, 'once'));
end

function DToutput = parseDDate(dateinput)
     % Parse the date in ISO 8601 format
        % date=extractBefore(extractAfter(dateinput,"D"), "T");
        % time=extractBefore(extractAfter(dateinput,"T"),"Z"); % Notice that non-UTC times are NOT SUPPORTED
        % date=strcat(date,time);
        % date=str2double(date);

        % date=extractAfter(dateinput,"D");
        
        DToutput = datetime(dateinput, "InputFormat", "'D'yyyyMMdd'T'HHmmss'Z'");
end

%% 20250422

options.Date=searchtable.Date{4}{2}; % sample date choice
% Mask=zeros(size(searchtable,1),size(searchtable,2));

% for i=1:height(searchtable) % Loop through searchtable
%     for j=1:numel(searchtable.Date{i}) % loop through dates within each camera
% 
%     end
% end

% Helper function
function dtArray = normalizeDateEntry(x)
    if iscell(x) && all(cellfun(@isdatetime, x))
        dtArray = datetime([x{:}]);
    elseif isdatetime(x)
        dtArray = x;
    else
        dtArray = NaT;
    end
end

function [outflag,outIND] = CompareDTarray(x, target, threshold)
    diff=x - target;
    diff(diff<0)=days(9999); % set placeholder value
    
    [outflag,outIND]=min(diff);
end

% ChooseBestSurveyDate = @(x, target, threshold) any(x - target < threshold);
% ChooseBestSurveyDate = @(x, target, threshold) x - target;


% target=datetime(now(),'ConvertFrom','datenum','TimeZone','UTC');
target=searchtable.Date{2}{1};
threshold=hours(1);

% Apply it
normalizedDateCells = cellfun(@normalizeDateEntry, searchtable.Date, 'UniformOutput', false);

result = cellfun(@(x) CompareDTarray(x, target), normalizedDateCells, 'UniformOutput', false);

for i=1:height(result)
    result2(i)=result{i};
end


disp(result2)

%%

Seaclifftable=readCPG_CamDatabase(Fieldsite="Seacliff",format="searchtable")
OCT23toJAN22=Seaclifftable.Date{1}(1);
JAN23toPRESENT=Seaclifftable.Date{1}(1);
SeaclifCam1=readCPG_CamDatabase(Fieldsite="Seacliff",CamSN=22296748,Date=Oldestdate,format="compact")

%% 20250513
avgGPS(GPSpoints,"Northings",[3:5]);
avgGPS(GPSpoints,"Eastings",[3:5]);
avgGPS(GPSpoints,"Elevation",[3:5]);

%% 20250519
CPGDB=readCPG_CamDatabase()
CPGDB.Seacliff.Cam3.D20250122T220000Z.CamPose.Northings

% cam_21217396POS=[36.9699952963,-121.9075239770,31.334]


outputmask = GPSpoints.ImageU~=0;
pose = EstimateCameraPose(cam_21217396POS,GPSpoints(outputmask,:))

%% 20250521

CPGDB=readCPG_CamDatabase()
CPGDB.Seacliff.Cam3.D20250122T220000Z.CamPose.Northings

utmstruct = defaultm('utm');
utmstruct.zone = '10N';
utmstruct.geoid = wgs84Ellipsoid;
utmstruct = defaultm(utmstruct);

[lat, lon] = projinv(utmstruct,str2num(CPGDB.Seacliff.Cam3.D20250122T220000Z.CamPose.Eastings),str2num(CPGDB.Seacliff.Cam3.D20250122T220000Z.CamPose.Northings))

%% CALCULATE 
% load the savestate from the PrepControlPoint GUI (GPSpoints with UV coordinates)
addpath(genpath("C:\Users\Carson\Documents\Carson\Projects\Seacliff_Cam_Station\Rectification"))
CPGDB=readCPG_CamDatabase();
load("20250508_GCPSaveState_Cam21217396.mat"); %Load savestate from Cam2

% outputmask = GPSpoints.ImageU~=0; % ignore GPS points that don't have pixel coordinates ** Can't exactly do this because we loose which ponits go to which GPS column.
outputmask=find(GPSpoints.ImageU~=0); % find indexes that have an associated Image pixel coordinate (GPS points visible to the camera)
[pose, xyzGCP] = EstimateCameraPose(CPGDB.Seacliff.Cam2.D20250122T220000Z,GPSpoints(outputmask,:)); % get initial pose estimate & GCPs in local coordinates camera=[0,0,0]

readDB=readCPG_CamDatabase(CamSN=22296760,Date="20250122T220000Z",format="compact"); % Generate ICP (Intrinsics) based on a previous survey
icp=readDB.icp;
icp = makeRadialDistortion(icp);
icp = makeTangentialDistortion(icp);

betaOUT = constructCameraPose(xyzGCP, [GPSpoints.ImageU(outputmask,:), GPSpoints.ImageV(outputmask,:)], icp, [0,0,0,pose]);
%% Use betaOUT to rectify!
% [U, V] = meshgrid(0:icp.NU-1, 0:icp.NV-1);  %find U, V coordinates

k = 4;  % scale factor: MUST BE EVENLY DIVISABLE BY icp.Nu and icp.NV (1, 2, 4, 8)

Uvals = repelem(0:k:(k*(icp.NU/k - 1)), k);   % U axis with repeats
Vvals = repelem(0:k:(k*(icp.NV/k - 1)), k);   % V axis with repeats
[U, V] = meshgrid(Uvals, Vvals);

[Xa, Ya, ~] = getXYZfromUV(U, V, icp, betaOUT, 0, '-z');    %find FRF X, Y coordinates

function M_small = compressmatrix(M, krow, kcol)
    % Collapse a matrix where values repeat in blocks of krow × kcol
    % Example: krow=2, kcol=2 for your case
    
    % Get original size
    [nr, nc] = size(M);
    
    % Trim to multiples of block size
    nr_trim = floor(nr/krow)*krow;
    nc_trim = floor(nc/kcol)*kcol;
    M = M(1:nr_trim, 1:nc_trim);

    % New collapsed size
    nr_new = nr_trim / krow;
    nc_new = nc_trim / kcol;

    % Reshape into 4D: (krow, nr_new, kcol, nc_new)
    M = reshape(M, krow, nr_new, kcol, nc_new);

    % Take the first element of each block (all values in block are equal)
    M_small = squeeze(M(1,:,1,:));
end

ocean = imread('\\reefbreak.ucsd.edu\camera\Seacliff\Calibration\20250508\usable-images\Seacliff_21217396_1746729385681.tif');
ocean = double(rgb2gray(ocean));

% Compress the grid and image for better performance`
Xab=compressmatrix(Xa,k,k);
Yab=compressmatrix(Ya,k,k);
oceanb=compressmatrix(ocean,k,k);

figure
hold on
view = pcolor(Xab,Yab,oceanb);
set(view,'EdgeColor','none');

colormap('gray')
ylim([-50 150])
xlim([-100 100])
ax = gca;
set(ax,'DataAspectRatio', [1 1 1]);
ylabel('Alongshore (m)')
xlabel('Cross-shore (m)')

%% Use beta to back-calculate the expected Image Coords of real-world coordinate (converted to the camera LCS)
[IMAGEu1, IMAGEv1] = getUVfromXYZ(xyzGCP(1,1), xyzGCP(1,2), xyzGCP(1,3), icp, betaOUT)

% then you could do math like GPSpoints.ImageU(outputmask,1)

%% 20250709 Comparing structs from previous save states

function diffReport = compareStructs(struct1, struct2)
    % Compare two structs with the same fields
    % Returns a struct with fields where values differ

    % Get all field names
    fields1 = fieldnames(struct1);
    diffReport = struct();  % Output struct to hold differences

    for i = 1:numel(fields1)
        field = fields1{i};
        val1 = struct1.(field);
        val2 = struct2.(field);

        % Use isequaln to compare (treats NaN == NaN as true)
        if ~isequaln(val1, val2)
            diffReport.(field).struct1 = val1;
            diffReport.(field).struct2 = val2;
        end
    end
end

compareStructs(UserPrefsCORRECT,UserPrefs)

%%

GPSpointsTEMP=importGPShandheld("20250614_DelMar17_GCPs.txt")