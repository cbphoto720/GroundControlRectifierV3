function Plot_iG8(filename, options)
%% Plot_iG8 - Plot GPS points from an iG8 text file on a map
% Import points from an iG8 text file and plot on a map.
% (Points should include a "Code" header from the iG8 because you were a
% good surveyor and labelled the points you were taking.)
%
% Usage:
%   Plot_iG8(filename)                    % New figure with one survey
%   Plot_iG8(filename, 'HoldOn', true)    % Add to current map (multiple surveys)
%
% Inputs:
%   filename - Path to iG8 text file (string or char).
%
% Optional name-value pairs (can follow filename):
%   'HoldOn'     - If true, add to the current figure's geographic axes
%                  instead of creating a new figure. Default: false.
%   'AddLabels'  - If true, add point labels. Default: true.
%   'DrawCircles' - Radius in meters for circles around each point;
%                   set to 0 to disable. Default: 0.
%
% Example (multiple GPS surveys on one map):
%   Plot_iG8('survey1.txt');
%   Plot_iG8('survey2.txt', 'HoldOn', true);
%   Plot_iG8('survey3.txt', 'HoldOn', true);

arguments
    filename (1,:) {mustBeTextScalar}
    options.HoldOn (1,1) logical = false
    options.AddLabels (1,1) logical = true
    options.DrawCircles (1,1) double = 0
end

HoldOn = options.HoldOn;
Addlabels = options.AddLabels;
drawcircles = options.DrawCircles;

% Load color map from same folder as this function
helperDir = fileparts(mfilename('fullpath'));
load(fullfile(helperDir, 'hawaiiS.txt'));  % creates variable hawaiiS

GPSpoints = importiG8points(filename);

if HoldOn
    % Reuse geographic axes from last Plot_iG8 call
    if isappdata(0, 'Plot_iG8_geoax')
        geoax = getappdata(0, 'Plot_iG8_geoax');
        if ~isvalid(geoax) || ~isa(geoax, 'matlab.graphics.axis.GeographicAxes')
            rmappdata(0, 'Plot_iG8_geoax');
            error('Plot_iG8:NoGeoAxes', ...
                'No valid GPS map axes found. Call Plot_iG8(filename) without HoldOn first.');
        end
    else
        error('Plot_iG8:NoGeoAxes', ...
            'No GPS map axes found. Call Plot_iG8(filename) without HoldOn first.');
    end

    % Color offset so multiple surveys get distinct colors
    if isfield(geoax.UserData, 'plotSetCount')
        setOffset = geoax.UserData.plotSetCount;
    else
        setOffset = 0;
    end

    hold(geoax, 'on');
else
    % Create new figure and geographic axes
    set(0, 'units', 'pixels');
    scr_siz = get(0, 'ScreenSize');
    figWidth = 0.8 * scr_siz(3);
    figHeight = 0.7 * scr_siz(4);
    figX = (scr_siz(3) - figWidth) / 2;
    figY = (scr_siz(4) - figHeight) / 2;

    GPSplot = uifigure('Name', 'GPS Map', ...
        'Position', [figX, figY, figWidth, figHeight]);

    geoax = geoaxes(GPSplot);
    geoax.Tag = 'GPSMapGeoAxes';
    setOffset = 0;
    geoax.UserData.plotSetCount = 0;

    % Remember axes for subsequent HoldOn=true calls
    setappdata(0, 'Plot_iG8_geoax', geoax);

    hold(geoax, 'on');
    geobasemap(geoax, "satellite");
end

% Get unique descriptions (setnames) and plot
setnames = unique(GPSpoints.Code);
NUM_IMGsets = numel(setnames);

for i = 1:NUM_IMGsets
    mask = strcmp(GPSpoints{:,2}, setnames{i});
    colorIdx = mod(setOffset + i - 1, 100) + 1;
    geoscatter(geoax, GPSpoints.Latitude(mask), GPSpoints.Longitude(mask), ...
               36, hawaiiS(colorIdx, :), "filled");
end

% Update set count for next HoldOn call
geoax.UserData.plotSetCount = setOffset + NUM_IMGsets;

% Add labels
if Addlabels
    plot_iG8_addLabels(geoax, GPSpoints);
end

% Add circles
if drawcircles ~= 0
    radius_deg = drawcircles / 111320;
    for i = 1:length(GPSpoints.Latitude)
        [clat, clon] = scircle1(GPSpoints.Latitude(i), GPSpoints.Longitude(i), radius_deg, [], 'degrees');
        geoplot(geoax, clat, clon, 'b-', 'LineWidth', 1.5);
    end
end

if ~HoldOn
    hold(geoax, 'off');
end

end

function plot_iG8_addLabels(geoax, GPSpoints)
% Place labels with a pixel-based offset that scales with zoom.

labels = cellstr(num2str(GPSpoints.Name));
lat = GPSpoints.Latitude(:);
lon = GPSpoints.Longitude(:);

pxOffsets = plot_iG8_computeLabelOffsetsPx(lat, lon, geoax.FontSize);

% Create labels at the point locations; we'll immediately update positions.
% For geoaxes, text locations are specified as (latitude, longitude).
h = text(geoax, lat, lon, labels, ...
    'Clipping', 'on', ...
    'Interpreter', 'none', ...
    'Color', 'w');

store = struct('lat', [], 'lon', [], 'h', gobjects(0,1), 'pxOffsets', zeros(0,2));
if isstruct(geoax.UserData) && isfield(geoax.UserData, 'Plot_iG8LabelStore') && ~isempty(geoax.UserData.Plot_iG8LabelStore)
    store = geoax.UserData.Plot_iG8LabelStore;
end

store.lat = [store.lat; lat];
store.lon = [store.lon; lon];
store.h = [store.h; h(:)];
store.pxOffsets = [store.pxOffsets; pxOffsets];

geoax.UserData.Plot_iG8LabelStore = store;
plot_iG8_ensureLabelListeners(geoax);
plot_iG8_updateLabels(geoax);
end

function plot_iG8_ensureLabelListeners(geoax)
% Add listeners once so labels stay readable after pan/zoom/resize.

if ~(isstruct(geoax.UserData) && isfield(geoax.UserData, 'Plot_iG8LabelListeners') && ~isempty(geoax.UserData.Plot_iG8LabelListeners))
    L = event.listener.empty;
    k = 0;

    % GeographicAxes latitude/longitude limits are read-only and not observable.
    % Pan/zoom updates MapCenter/ZoomLevel, so listen to those instead.
    try
        k = k + 1;
        L(k) = addlistener(geoax, 'MapCenter', 'PostSet', @(~,~)plot_iG8_updateLabels(geoax));
    catch
    end
    try
        k = k + 1;
        L(k) = addlistener(geoax, 'ZoomLevel', 'PostSet', @(~,~)plot_iG8_updateLabels(geoax));
    catch
    end
    try
        k = k + 1;
        L(k) = addlistener(geoax, 'Position', 'PostSet', @(~,~)plot_iG8_updateLabels(geoax));
    catch
    end

    geoax.UserData.Plot_iG8LabelListeners = L;
end
end

function plot_iG8_updateLabels(geoax)
if ~isvalid(geoax)
    return;
end
if ~(isstruct(geoax.UserData) && isfield(geoax.UserData, 'Plot_iG8LabelStore'))
    return;
end

store = geoax.UserData.Plot_iG8LabelStore;
if isempty(store) || ~isfield(store, 'h') || isempty(store.h)
    return;
end

valid = isvalid(store.h);
store.lat = store.lat(valid);
store.lon = store.lon(valid);
store.h = store.h(valid);
store.pxOffsets = store.pxOffsets(valid, :);
geoax.UserData.Plot_iG8LabelStore = store;

if isempty(store.h)
    return;
end

axPix = getpixelposition(geoax, true);
w = max(axPix(3), 1);
hpx = max(axPix(4), 1);

latlim = geoax.LatitudeLimits;
lonlim = geoax.LongitudeLimits;

latPerPx = diff(latlim) / hpx;
lonPerPx = diff(lonlim) / w;

% dyPx is positive "up" in our offset convention
dLat = store.pxOffsets(:,2) .* latPerPx;
dLon = store.pxOffsets(:,1) .* lonPerPx;

latNew = store.lat + dLat;
lonNew = store.lon + dLon;

% For geoaxes, text locations use (latitude, longitude) order.
pos = [latNew, lonNew, zeros(numel(latNew), 1)];
for i = 1:numel(store.h)
    store.h(i).Position = pos(i,:);

    dx = store.pxOffsets(i,1);
    dy = store.pxOffsets(i,2);
    if dx >= 0
        store.h(i).HorizontalAlignment = 'left';
    else
        store.h(i).HorizontalAlignment = 'right';
    end
    if dy >= 0
        store.h(i).VerticalAlignment = 'bottom';
    else
        store.h(i).VerticalAlignment = 'top';
    end
end
end

function pxOffsets = plot_iG8_computeLabelOffsetsPx(lat, lon, fontSizePts)
% Compute deterministic offsets (pixels) that spread labels for collocated points.

n = numel(lat);
pxOffsets = zeros(n, 2);
if n == 0
    return;
end

% Base radius grows with font size to keep text away from markers.
baseR = max(12, 8 + fontSizePts);   % px
ringStep = max(8, 6 + 0.4*fontSizePts); % px

lat0 = mean(lat, 'omitnan');
if isnan(lat0)
    lat0 = 0;
end

% Group points that are essentially at the same location (within ~0.25 m).
tolMeters = 0.25;
latTol = tolMeters / 111320;
lonTol = tolMeters / (111320 * max(cosd(lat0), 0.2));

g = findgroups(round(lat ./ latTol), round(lon ./ lonTol));
gold = pi * (3 - sqrt(5)); % golden angle (deterministic)

for gi = 1:max(g)
    idx = find(g == gi);
    m = numel(idx);
    if m == 1
        pxOffsets(idx, :) = [baseR, 0.6*baseR];
        continue;
    end

    for j = 1:m
        ring = floor((j-1) / 10); % 10 labels per ring before expanding
        r = baseR + ringStep * ring;
        ang = (j-1) * gold;
        pxOffsets(idx(j), :) = [r*cos(ang), r*sin(ang)];
    end
end
end
