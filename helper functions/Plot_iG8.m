%% Simple GPS plot
% Import points from an iG8 text file and plot on a map
% (you points should always include a "Code" header from the iG8 because
% you were a good surveyor and labelled the points you were taking

%% Options
load("hawaiiS.txt"); % Load color map

filename="C:\Users\Carson\Downloads\20251118_SeacliffGCP (1).txt";

Addlabels=true; % (boolean) Add labels to each point based on Code description
drawcircles=0; % (m) Draw circles around each point set to "0" meters to turn off

GPSpoints=importiG8points(filename);
%% Generate Map

% Create main UI figure
set(0, 'units', 'pixels');
scr_siz = get(0, 'ScreenSize');

% Define figure width and height as a percentage of screen size
figWidth = 0.8 * scr_siz(3);
figHeight = 0.7 * scr_siz(4);
figX = (scr_siz(3) - figWidth) / 2;  % Center horizontally
figY = (scr_siz(4) - figHeight) / 2; % Center vertically

% Create centered figure
GPSplot = uifigure('Name', 'GPS Map', ...
    'Position', [figX, figY, figWidth, figHeight]);

% Create a geoaxes inside the UI figure for the GPS map (left side)
geoax = geoaxes(GPSplot); 
hold(geoax, 'on'); % Allow multiple drawings

% Get unique descriptions (setnames)
setnames = unique(GPSpoints.Code);
NUM_IMGsets = numel(setnames); % Get number of unique sets

% Plot all GPS points
geobasemap(geoax, "satellite");
for i = 1:NUM_IMGsets
    mask = strcmp(GPSpoints{:,2}, setnames{i});
    geoscatter(geoax, GPSpoints.Latitude(mask), GPSpoints.Longitude(mask), ...
               36, hawaiiS(mod(i-1, 100) + 1, :), "filled"); % Wrap colors properly
    % geoscatter(geoax, GPSpoints.Latitude(mask), GPSpoints.Longitude(mask), ...
               % 36, [1 0 0], "filled"); % Wrap colors properly
end

% Add labels
if Addlabels
    % a=strcat(GPSpoints.Code,num2str(GPSpoints.Name));
    a=num2str(GPSpoints.Name);
    c=cellstr(a);
    % Randomize the label direction by creating a unit vector.
    vec=-1+(1+1)*rand(length(a),2);
    dir=vec./(((vec(:,1).^2)+(vec(:,2).^2)).^(1/2));
    scale=0.0000000006; % offset text from point
    % dir(:)=0; % turn ON randomization by commenting out this line
    offsetx=-0.000002+dir(:,1)*scale; % offset text on the point
    offsety=-0.00000008+dir(:,2)*scale; % offset text on the point
    % text(geoax,GPSpoints.Latitude+offsety,GPSpoints.Longitude+offsetx,c,'Color','red','FontSize',14)
    text(geoax,GPSpoints.Latitude+offsety,GPSpoints.Longitude+offsetx,c)
end

% Add 2m circles
if drawcircles~=0
    % Convert meters to degrees (approximate, assuming 111,320 meters per degree)
    radius_deg = drawcircles / 111320; 
    
    for i=1:length(GPSpoints.Latitude)
        % Generate the circle points
        [clat, clon] = scircle1(GPSpoints.Latitude(i), GPSpoints.Longitude(i), radius_deg, [], 'degrees');
        
        % Plot the circle
        geoplot(geoax, clat, clon, 'b-', 'LineWidth', 1.5);
    end
end

hold(geoax, 'off');