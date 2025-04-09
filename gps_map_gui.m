function gps_map_gui(UserPrefs, GPSpoints)
    % Load Colormap
    load("hawaiiS.txt"); % Load color map

    % Get screen size for positioning the figure
    set(0, 'units', 'pixels');
    scr_siz = get(0, 'ScreenSize');
    
    % Define figure width and height as a percentage of screen size
    figWidth = 0.8 * scr_siz(3);
    figHeight = 0.7 * scr_siz(4);
    figX = (scr_siz(3) - figWidth) / 2;  % Center horizontally
    figY = (scr_siz(4) - figHeight) / 2; % Center vertically

    % Create main UI figure
    GPSplot = uifigure('Name', 'GPS Map Viewer', ...
        'Position', [figX, figY, figWidth, figHeight]);

    % Create GridLayout for the main figure
    app.GridLayout = uigridlayout(GPSplot);
    app.GridLayout.RowHeight = {'4x', '1x'};
    app.GridLayout.ColumnWidth = {'1x', '1x'};

    % Create UIAxes (left side for GPS map)
    app.UIAxes = geoaxes(app.GridLayout);
    app.UIAxes.Layout.Row = 1;
    app.UIAxes.Layout.Column = 1;
    hold(app.UIAxes, 'on'); % Allow multiple drawings
    title(app.UIAxes, 'GPS Map');
    
    % Get unique descriptions (setnames)
    setnames = getSetNames(GPSpoints);
    NUM_IMGsets = numel(setnames); % Get number of unique sets

    % Plot all GPS points
    geobasemap(app.UIAxes, "satellite");
    for i = 1:NUM_IMGsets
        mask = strcmp(GPSpoints{:,2}, setnames{i});
        geoscatter(app.UIAxes, GPSpoints.Latitude(mask), GPSpoints.Longitude(mask), ...
                   36, hawaiiS(mod(i-1, 100) + 1, :), "filled"); % Wrap colors properly
    end

    % Overlay for highlighted points
    highlightPlot = geoscatter(app.UIAxes, NaN, NaN, 100, 'r', 'pentagram','filled'); % Initially empty
    hold(app.UIAxes, 'off');

    % Create UIAxes2 (right side for image display)
    app.IMGaxes = axes(app.GridLayout);
    app.IMGaxes.Layout.Row = 1;
    app.IMGaxes.Layout.Column = 2;

    % Create GridLayout2 for buttons at the bottom of GPS axis
    app.GridLayout2 = uigridlayout(app.GridLayout);
    app.GridLayout2.Layout.Row = 2;
    app.GridLayout2.Layout.Column = 1;
    app.GridLayout2.ColumnWidth = {'0.5x', '0.5x', '0.5x', '1x', '0.75x'};

    % Create Back Button (left side)
    app.BackButton = uibutton(app.GridLayout2, 'push', 'Text', 'Back');
    app.BackButton.ButtonPushedFcn = @(~,~) prevCallback();
    app.BackButton.Layout.Row = 1;
    app.BackButton.Layout.Column = 1;

        % Create a description label for the current set
    app.GPS_desc_label = uilabel(app.GridLayout2, 'Text', setnames{1}, ...
        'FontSize', 14, 'HorizontalAlignment', 'center');
    app.ForwardButton.Layout.Row = 1;
    app.ForwardButton.Layout.Column = 2;

    % Create Forward Button (center-right)
    app.ForwardButton = uibutton(app.GridLayout2, 'push', 'Text', 'Forward');
    app.ForwardButton.ButtonPushedFcn = @(~,~) nextCallback();
    app.ForwardButton.Layout.Row = 1;
    app.ForwardButton.Layout.Column = 3;

    % Create "Select Region" Button (far right)
    app.SelectRegionButton = uibutton(app.GridLayout2, 'push', 'Text', 'Select Region');
    app.SelectRegionButton.ButtonPushedFcn = @(~,~) selectRegionCallback();
    app.SelectRegionButton.Layout.Row = 1;
    app.SelectRegionButton.Layout.Column = 5;

    % Create GridLayout3 for buttons at the bottom of the IMG plot
    app.GridLayout3 = uigridlayout(app.GridLayout);
    app.GridLayout3.Layout.Row = 2;
    app.GridLayout3.Layout.Column = 2;
    app.GridLayout3.ColumnWidth = {'1x','1x','1x','1x','1x','1x'};

    % Create Zoom slider
    app.ZoomSliderLabel = uilabel(app.GridLayout3);
    app.ZoomSliderLabel.HorizontalAlignment = 'right';
    app.ZoomSliderLabel.Layout.Row = 1;
    app.ZoomSliderLabel.Layout.Column = 1;
    app.ZoomSliderLabel.Text = 'Zoom';
    app.Zoomslider=uislider(app.GridLayout3);
    app.Zoomslider.Layout.Row = 1;
    app.Zoomslider.Layout.Column = [2 3];

    % Zoom plot
    app.ZoomIMG = axes(app.GridLayout3);
    app.ZoomIMG.Layout.Row = [1 2];
    app.ZoomIMG.Layout.Column = [4 6];

    % image U,V button
    % app.SelectRegionButton = uibutton(app.GridLayout3, 'state', 'Text', 'UV Pick');
    % app.SelectRegionButton.ButtonPushedFcn = @(~,~) UVpickcallback();
    % app.SelectRegionButton.Layout.Row = 1;
    % app.SelectRegionButton.Layout.Column = 5;

     % Initialize the current index tracker for setnames
    currentIndex = 1;

    % Function to update highlighted points
    function updateHighlight()
        mask = strcmp(GPSpoints{:,2}, setnames{currentIndex});
        highlightPlot.LatitudeData = GPSpoints.Latitude(mask);
        highlightPlot.LongitudeData = GPSpoints.Longitude(mask);
        app.GPS_desc_label.Text = setnames{currentIndex}; % Update text display
        updateImage(); % Update the image when the GPS set changes
    end

    % Function to update the image display
    function updateImage()
        % Get the image filename from FileIDX based on currentIndex
        mask = strcmp(GPSpoints{:,2}, setnames{currentIndex});
        imgfile = GPSpoints.FileIDX(mask);
        imgfile = imgfile(1);
        
        if strcmp(imgfile, "")
            % Do nothing for now
        else
            % Load the image and display it in the image axes
            img = imread(imgfile);
            imshow(img, 'Parent', app.IMGaxes);
             % Set the ButtonDownFcn callback for the axes
            % app.IMGaxes.ButtonDownFcn = @(src, event) UVpickcallback(src, event, img);
        end
    end

    % Callback for Previous Button
    function prevCallback()
        if currentIndex > 1
            currentIndex = currentIndex - 1;
            updateHighlight();
        end
    end

    % Callback for Next Button
    function nextCallback()
        if currentIndex < NUM_IMGsets
            currentIndex = currentIndex + 1;
            updateHighlight();
        end
    end

    % Callback for "Ready to Select Region" Button
    function selectRegionCallback()
        % Prompt user to draw a polygon around the points visible to the camera
        f = msgbox("Draw a polygon around the points visible to the cam");
        uiwait(f);  % Wait for the message box to close
        
        % Allow user to draw a polygon
        roi = drawpolygon(app.UIAxes);
        
        % Check if a region was selected
        if size(roi.Position, 1) == 0
            disp("Failed to detect region of interest. Try again.");
        else
            % Get the GPS points inside the drawn polygon (region of interest)
            GPSmask = inROI(roi, GPSpoints.Latitude, GPSpoints.Longitude);
            disp("Region selected successfully.");
            % You can now use 'GPSmask' for further processing
        end
    end

    function UVpickcallback()
        % Get the pixel coordinates of the click
        clickedPoint = event.IntersectionPoint;  % Get the coordinates [x, y]
        
        % Get the row and column indices (in image space)
        x = round(clickedPoint(1));  % X coordinate (column)
        y = round(clickedPoint(2));  % Y coordinate (row)
        
        % Check if the click is within the bounds of the image
        if x >= 1 && x <= size(img, 2) && y >= 1 && y <= size(img, 1)
            % Display the coordinates
            disp(['Clicked at coordinates: (', num2str(x), ', ', num2str(y), ')']);
        else
            disp('Clicked outside of image bounds.');
        end
    end

    % Initial Highlight and Image Update
    updateHighlight();
end