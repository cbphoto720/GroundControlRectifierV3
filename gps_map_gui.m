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
    app.MainGridLayout = uigridlayout(GPSplot);
    app.MainGridLayout.RowHeight = {'4x', '1x'};
    app.MainGridLayout.ColumnWidth = {'1x', '1x'};

    % Create UIAxes (left side for GPS map)
    app.UIAxes = geoaxes(app.MainGridLayout);
    app.UIAxes.Layout.Row = 1;
    app.UIAxes.Layout.Column = 1;
    hold(app.UIAxes, 'on'); % Allow multiple drawings
    title(app.UIAxes, 'GPS Map');
    
    % Get unique descriptions (setnames)
    setnames = getSetNames(GPSpoints);
    NUM_IMGsets = numel(setnames); % Get number of unique sets

       % Initialize the current index tracker for setnames
    currentIndex = 1;

    app.isPickingGCP = false;  % Set state
    app.GCPsetIDX=1; % IDX for individual GPS points within the set (for UV-picking)


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
    app.IMGaxes = axes(app.MainGridLayout);
    app.IMGaxes.Layout.Row = 1;
    app.IMGaxes.Layout.Column = 2;

    % Create GridLayout2 for buttons at the bottom of GPS axis
    app.GPSButtonGrid = uigridlayout(app.MainGridLayout);
    app.GPSButtonGrid.Layout.Row = 2;
    app.GPSButtonGrid.Layout.Column = 1;
    app.GPSButtonGrid.ColumnWidth = {'0.5x', '0.5x', '0.5x', '1x', '0.75x'};

    % Create Back Button (left side)
    app.BackButton = uibutton(app.GPSButtonGrid, 'push', 'Text', 'Back');
    app.BackButton.ButtonPushedFcn = @(~,~) prevCallback();
    app.BackButton.Layout.Row = 1;
    app.BackButton.Layout.Column = 1;

        % Create a description label for the current set
    app.GPS_desc_label = uilabel(app.GPSButtonGrid, 'Text', setnames{1}, ...
        'FontSize', 14, 'HorizontalAlignment', 'center');
    app.ForwardButton.Layout.Row = 1;
    app.ForwardButton.Layout.Column = 2;

    % Create Forward Button (center-right)
    app.ForwardButton = uibutton(app.GPSButtonGrid, 'push', 'Text', 'Forward');
    app.ForwardButton.ButtonPushedFcn = @(~,~) nextCallback();
    app.ForwardButton.Layout.Row = 1;
    app.ForwardButton.Layout.Column = 3;

    % Create "Select Region" Button (far right)
    app.SelectRegionButton = uibutton(app.GPSButtonGrid, 'push', 'Text', 'Select Region');
    app.SelectRegionButton.ButtonPushedFcn = @(~,~) selectRegionCallback();
    app.SelectRegionButton.Layout.Row = 1;
    app.SelectRegionButton.Layout.Column = 5;

    % Create IMGButtonGrid for buttons at the bottom of the IMG plot
    app.IMGButtonGrid = uigridlayout(app.MainGridLayout);
    app.IMGButtonGrid.Layout.Row = 2;
    app.IMGButtonGrid.Layout.Column = 2;
    app.IMGButtonGrid.ColumnWidth = {'0.5x','0.5x','0.5x','2x','0.5x','1x','0.5x'};

    app.UITable = uitable(app.IMGButtonGrid);
    app.UITable.Layout.Row = [1 2];
    app.UITable.Layout.Column = [1 3];
    app.UITable.Data = table(num2cell(GPSpoints.Name(mask)),num2cell(zeros(length(GPSpoints.Name(mask)),1)),num2cell(zeros(length(GPSpoints.Name(mask)),1)), ...
        'VariableNames',{'PointNum','Image U', 'Image V'}); %FLAG ` make sure to update under updateHighlight as well!
    % app.UITable.ColumnName = {'Name', 'X', 'Y'};
    app.UITable.ColumnWidth={'1x','1x','1x'};
    app.UITable.ColumnEditable = [false, false, false];  % Set this to false for all columns

    % Next GCP button
    app.NextGCP = uibutton(app.IMGButtonGrid, 'push', 'Text', 'Prev GCP');
    app.NextGCP.ButtonPushedFcn = @(~,~) prevGCPCallback();
    app.NextGCP.Layout.Row = 2;
    app.NextGCP.Layout.Column = 5;

    % GCPsetIDX Label 
    app.GCPlabel = uilabel(app.IMGButtonGrid, 'Text', string(app.GCPsetIDX), ...
        'FontSize', 14, 'HorizontalAlignment', 'center');
    app.GCPlabel.Layout.Row = 2;
    app.GCPlabel.Layout.Column = 6;

    % Prev GCP button
    app.PrevGCP = uibutton(app.IMGButtonGrid, 'push', 'Text', 'Next GCP');
    app.PrevGCP.ButtonPushedFcn = @(~,~) nextGCPCallback();
    app.PrevGCP.Layout.Row = 2;
    app.PrevGCP.Layout.Column = 7;

    % Create Pick GCP button
    app.PickGCP = uibutton(app.IMGButtonGrid, 'push', 'Text', 'Select GCP');
    app.PickGCP.ButtonPushedFcn = @(~,~) UVpickcallback();
    app.PickGCP.Layout.Row = 1;
    app.PickGCP.Layout.Column = 6;

    % image U,V button
    % app.SelectRegionButton = uibutton(app.GridLayout3, 'state', 'Text', 'UV Pick');
    % app.SelectRegionButton.ButtonPushedFcn = @(~,~) UVpickcallback();
    % app.SelectRegionButton.Layout.Row = 1;
    % app.SelectRegionButton.Layout.Column = 5;

    % Function to update highlighted points
    function updateHighlight()
        mask = strcmp(GPSpoints{:,2}, setnames{currentIndex});
        highlightPlot.LatitudeData = GPSpoints.Latitude(mask);
        highlightPlot.LongitudeData = GPSpoints.Longitude(mask);
        app.GPS_desc_label.Text = setnames{currentIndex}; % Update text display
        updateImage(); % Update the image when the GPS set changes

        app.UITable.Data = table(num2cell(GPSpoints.Name(mask)),num2cell(zeros(length(GPSpoints.Name(mask)),1)),num2cell(zeros(length(GPSpoints.Name(mask)),1)), ...
        'VariableNames',{'PointNum','Image U', 'Image V'}); %update table
        % Color Table to represent highlighting
        for coloridx=1:height(app.UITable.Data)
            if coloridx==app.GCPsetIDX
                addStyle(app.UITable,uistyle('BackgroundColor','#ebd05b'),'row',coloridx);
            else
                addStyle(app.UITable,uistyle('BackgroundColor','#FFFFFF'),'row',coloridx);
            end
        end
    end

    % Function to update the image display
    function updateImage()
        % Get the image filename from FileIDX based on currentIndex
        mask = strcmp(GPSpoints{:,2}, setnames{currentIndex});
        imgfile = GPSpoints.FileIDX(mask);
        imgfile = imgfile(1);
        
        if strcmp(imgfile, "")
            % Do nothing for now (maybe add a NaN img)
        else
            % Load the image and display it in the image axes
            app.img = imread(imgfile);
            % imshow(img, 'Parent', app.IMGaxes);

             % Set the ButtonDownFcn callback for the img
            hImg = imshow(app.img, 'Parent', app.IMGaxes);
            set(hImg, 'ButtonDownFcn', @(src, event) IMGclickCallback(src, event));
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

    function nextGCPCallback()
        if app.GCPsetIDX < height(app.UITable.Data)
            app.GCPsetIDX = app.GCPsetIDX+1;
            updateHighlight();
        end
    end

    function prevGCPCallback()
        if app.GCPsetIDX > 1
            app.GCPsetIDX = app.GCPsetIDX-1;
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

    function UVpickcallback
        app.isPickingGCP = ~app.isPickingGCP;  % Set state
        if app.isPickingGCP % Button pressed
            app.PickGCP.BackgroundColor = [0 1 0];  % Green
        else % Button de-pressed
            app.PickGCP.BackgroundColor = [0.94, 0.94, 0.94];  % default uifigure gray 
        end
    end

    function IMGclickCallback(src, event)     
        % Normal click behavior when not in pan mode
        if app.isPickingGCP
            clickedPoint = event.IntersectionPoint;
            x = round(clickedPoint(1));
            y = round(clickedPoint(2));
            disp(['Clicked at (', num2str(x), ', ', num2str(y), ')']);
        end
    end

    % Define the callback function
    % function captureSelectedCell(src, event)
    %     % Get the selected row and column indices
    %     selectedRow = event.Indices(1);  % Row of the selected cell
    %     selectedColumn = event.Indices(2);  % Column of the selected cell
    % 
    %     % Get the data of the selected cell
    %     selectedData = src.Data{selectedRow, selectedColumn};  % Data in the selected cell
    % 
    %     s = uistyle('BackgroundColor','#ebd05b'); % way to highlight current row
    %     addStyle(app.UITable,s,'row',selectedRow);
    % 
    %     % Display the selected row, column, and data in the command window
    %     disp(['Selected cell: Row ', string(selectedRow), ', Column ', num2str(selectedColumn)]);
    %     disp(['Selected data: ', string(selectedData)]);
    % end

    % Initial Highlight and Image Update
    updateHighlight();
end