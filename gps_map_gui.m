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
    
    %% Variables

    GPSpoints.ImageU=zeros(height(GPSpoints),1);
    GPSpoints.ImageV=zeros(height(GPSpoints),1);

    % Get unique descriptions (setnames)
    setnames = getSetNames(GPSpoints);
    NUM_IMGsets = numel(setnames); % Get number of unique sets

       % Initialize the current index tracker for setnames
    setIDX = 1;

    app.isPickingGCP = false;  % Set state
    app.gcpIDX=1; % IDX for individual GPS points within the set (for UV-picking)

    app.gcpHighlightMarker = [];  % Holds handles to GCP scatter plot on IMGaxes
    app.gcpPrevMarker = table([], [], [], [], ...
    'VariableNames', {'PointNum', 'X', 'Y', 'Handle'});

    % Plot all GPS points
    geobasemap(app.UIAxes, "satellite");
    for i = 1:NUM_IMGsets
        mask = strcmp(GPSpoints{:,2}, setnames{i});
        geoscatter(app.UIAxes, GPSpoints.Latitude(mask), GPSpoints.Longitude(mask), ...
                   36, hawaiiS(mod(i-1, 100) + 1, :), "filled"); % Wrap colors properly
    end

    % Overlay for highlighted points
    highlightSETPlot = geoscatter(app.UIAxes, NaN, NaN, 100, 'r', 'pentagram','filled'); % Initially empty
    highlightSINGLEPlot = geoscatter(app.UIAxes, NaN, NaN, 100,'pentagram','filled', 'MarkerFaceColor', '#f024d1'); % Initially empty
    hold(app.UIAxes, 'off');

    %% GUI Elements

    % Create UIAxes2 (right side for image display)
    app.IMGaxes = axes(app.MainGridLayout);
    app.IMGaxes.Layout.Row = 1;
    app.IMGaxes.Layout.Column = 2;

    % Create GridLayout2 for buttons at the bottom of GPS axis
    app.GPSButtonGrid = uigridlayout(app.MainGridLayout);
    app.GPSButtonGrid.Layout.Row = 2;
    app.GPSButtonGrid.Layout.Column = 1;
    app.GPSButtonGrid.ColumnWidth = {'1x', '1x', '1x', '1x', '1x'};

    % Create Back Button
    app.BackButton = uibutton(app.GPSButtonGrid, 'push', 'Text', 'Prev set');
    app.BackButton.ButtonPushedFcn = @(~,~) prevSETCallback();
    app.BackButton.Layout.Row = 1;
    app.BackButton.Layout.Column = 2;

        % Create a description label for the current set
    app.GPS_desc_label = uilabel(app.GPSButtonGrid, 'Text', setnames{1}, ...
        'FontSize', 14, 'HorizontalAlignment', 'center');
    app.GPS_desc_label.Layout.Row = 1;
    app.GPS_desc_label.Layout.Column = 3;

    % Create Forward Button
    app.ForwardButton = uibutton(app.GPSButtonGrid, 'push', 'Text', 'Next set');
    app.ForwardButton.ButtonPushedFcn = @(~,~) nextSETCallback();
    app.ForwardButton.Layout.Row = 1;
    app.ForwardButton.Layout.Column = 4;

    % % Create "Select Region" Button (far right)
    % app.SelectRegionButton = uibutton(app.GPSButtonGrid, 'push', 'Text', 'Select Region');
    % app.SelectRegionButton.ButtonPushedFcn = @(~,~) selectRegionCallback();
    % app.SelectRegionButton.Layout.Row = 1;
    % app.SelectRegionButton.Layout.Column = 5;

    % Create IMGButtonGrid for buttons at the bottom of the IMG plot
    app.IMGButtonGrid = uigridlayout(app.MainGridLayout);
    app.IMGButtonGrid.Layout.Row = 2;
    app.IMGButtonGrid.Layout.Column = 2;
    app.IMGButtonGrid.ColumnWidth = {'0.5x','0.5x','0.5x','0.1x','0.5x','0.5x','0.5x'};

    app.UITable = uitable(app.IMGButtonGrid);
    app.UITable.Layout.Row = [1 2];
    app.UITable.Layout.Column = [1 3];
    app.UITable.Data = table(num2cell(GPSpoints.Name(mask)),num2cell(GPSpoints.ImageU(mask)),num2cell(GPSpoints.ImageV(mask)), ...
        'VariableNames',{'PointNum','Image U', 'Image V'}); %FLAG ` make sure to update under updateHighlight as well!
    % app.UITable.ColumnName = {'Name', 'X', 'Y'};
    app.UITable.ColumnWidth={'1x','1x','1x'};
    app.UITable.ColumnEditable = [false, false, false];  % Set this to false for all columns

    % Next GCP button
    app.PrevGCP = uibutton(app.IMGButtonGrid, 'push', 'Text', 'Prev GCP');
    app.PrevGCP.ButtonPushedFcn = @(~,~) prevGCPCallback();
    app.PrevGCP.Layout.Row = 2;
    app.PrevGCP.Layout.Column = 5;

    % GCPsetIDX Label 
    app.GCPlabel = uilabel(app.IMGButtonGrid, 'Text', string(app.UITable.Data.PointNum(app.gcpIDX)), ...
        'FontSize', 14, 'HorizontalAlignment', 'center');
    app.GCPlabel.Layout.Row = 2;
    app.GCPlabel.Layout.Column = 6;

    % Prev GCP button
    app.NextGCP = uibutton(app.IMGButtonGrid, 'push', 'Text', 'Next GCP');
    app.NextGCP.ButtonPushedFcn = @(~,~) nextGCPCallback();
    app.NextGCP.Layout.Row = 2;
    app.NextGCP.Layout.Column = 7;

    % Create Pick GCP button
    app.PickGCP = uibutton(app.IMGButtonGrid, 'push', 'Text', 'Pick GCP');
    app.PickGCP.ButtonPushedFcn = @(~,~) PickGCPcallback();
    app.PickGCP.Layout.Row = 1;
    app.PickGCP.Layout.Column = 7;

    % Create Delete GCP button
    app.DeleteGCP = uibutton(app.IMGButtonGrid, 'push', 'Text', 'Delete GCP');
    app.DeleteGCP.ButtonPushedFcn = @(~,~) DeleteGCPcallback();
    app.DeleteGCP.Layout.Row = 1;
    app.DeleteGCP.Layout.Column = 6;

    % Function to update highlighted points
    function updateFullFrame()
        updatePoints();
        updateTable();
        updateImage();
    end

    function updatePoints()
        mask = strcmp(GPSpoints{:,2}, setnames{setIDX});

        % Update set highlight
        highlightSETPlot.LatitudeData = GPSpoints.Latitude(mask);
        highlightSETPlot.LongitudeData = GPSpoints.Longitude(mask);

        % Update single point highlight
        highlightSINGLEPlot.LatitudeData = highlightSETPlot.LatitudeData(app.gcpIDX);
        highlightSINGLEPlot.LongitudeData = highlightSETPlot.LongitudeData(app.gcpIDX);
        % highlightSINGLEPlot.Color='#f024d1';

        app.GPS_desc_label.Text = setnames{setIDX}; % Update text display
    end

    % Function to update the image display
    function updateImage()
        % Get the image filename from FileIDX based on setIDX
        mask = strcmp(GPSpoints{:,2}, setnames{setIDX});
        imgfile = GPSpoints.FileIDX(mask);
        imgfile = imgfile(1);
        
        if strcmp(imgfile, "")
            app.img = uint8(255 * ones(100,100,3)); % white 100x100 placeholder
            hImg = imshow(app.img, 'Parent', app.IMGaxes);
            set(hImg, 'ButtonDownFcn', @(src, event) IMGclickCallback(src, event));
        else
            % Load and show actual image
            app.img = imread(imgfile);
            hImg = imshow(app.img, 'Parent', app.IMGaxes);
            set(hImg, 'ButtonDownFcn', @(src, event) IMGclickCallback(src, event));
        end
        updateImageOverlay();
    end

    function updateImageOverlay()
        delete(findall(app.IMGaxes, 'Tag', 'GCPscatter'));

        % Calc what point to highlight
        Pointnum=app.UITable.Data.PointNum(app.gcpIDX);
        Pointnum=Pointnum{1};
        if any(app.gcpPrevMarker.PointNum==Pointnum)
            HighlightTarget= app.gcpPrevMarker(find(app.gcpPrevMarker.PointNum ==Pointnum),:);
            app.gcpHighlightMarker = struct('PointNum', HighlightTarget.PointNum,'X', HighlightTarget.X, 'Y', HighlightTarget.Y, 'Handle', HighlightTarget.Handle);
        else
            app.gcpHighlightMarker = struct('PointNum', Pointnum,'X', NaN, 'Y', NaN, 'Handle', NaN);
        end
        
        hold(app.IMGaxes, 'on'); % add overlays
            % add GCP UV coordinates 
            if ~isempty(app.gcpPrevMarker)
                for prevGCPUV = 1:height(app.gcpPrevMarker)
                    scatter(app.IMGaxes, app.gcpPrevMarker.X(prevGCPUV), app.gcpPrevMarker.Y(prevGCPUV), ...
                        10, [66, 245, 99]/255, 'filled', 'o', 'Tag', 'GCPscatter'); % Green color
                end
            end
            if ~isempty(app.gcpHighlightMarker)
                scatter(app.IMGaxes, app.gcpHighlightMarker.X, app.gcpHighlightMarker.Y, ...
                    10, [240, 36, 209]/255, 'filled', 'o', 'Tag', 'GCPscatter'); % Pink color
            end
            hold(app.IMGaxes, 'off');
    end


    function updateTable()
        app.UITable.Data = table(num2cell(GPSpoints.Name(mask)),num2cell(GPSpoints.ImageU(mask)),num2cell(GPSpoints.ImageV(mask)), ...
        'VariableNames',{'PointNum','Image U', 'Image V'}); %update table data

        app.GCPlabel.Text=string(app.UITable.Data.PointNum(app.gcpIDX)); %update table label
        
         % Color Table to represent Which GCP we are editing
        for coloridx=1:height(app.UITable.Data)
            if coloridx==app.gcpIDX
                addStyle(app.UITable,uistyle('BackgroundColor','#f024d1'),'row',coloridx);
            else
                addStyle(app.UITable,uistyle('BackgroundColor','#FFFFFF'),'row',coloridx);
            end
        end

        updatePoints();
    end

    % Callback for Previous Button
    function prevSETCallback()
        if setIDX > 1
            setIDX = setIDX - 1;
            app.gcpIDX=1;
            updateFullFrame();
        end
    end

    % Callback for Next Button
    function nextSETCallback()
        if setIDX < NUM_IMGsets
            setIDX = setIDX + 1;
            app.gcpIDX=1;
            updateFullFrame();
        end
    end

    function nextGCPCallback()
        if app.gcpIDX < height(app.UITable.Data)
            app.gcpIDX = app.gcpIDX+1;
            updateTable();
            updateImageOverlay();
        end
    end

    function prevGCPCallback()
        if app.gcpIDX > 1
            app.gcpIDX = app.gcpIDX-1;
            updateTable();
            updateImageOverlay();
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

    function PickGCPcallback
        app.isPickingGCP = ~app.isPickingGCP;  % Set state
        if app.isPickingGCP % Button pressed
            app.PickGCP.BackgroundColor = '#f024d1';
        else % Button de-pressed
            app.PickGCP.BackgroundColor = [0.94, 0.94, 0.94];  % default uifigure gray 
        end
    end

    function DeleteGCPcallback()
        % Remove data in table
        ImageUset=GPSpoints.ImageU(mask);
        ImageUset(app.gcpIDX)=0;
        GPSpoints.ImageU(mask)=ImageUset;
        
        ImageVset=GPSpoints.ImageV(mask);
        ImageVset(app.gcpIDX)=0;
        GPSpoints.ImageV(mask)=ImageVset;

        % Remove the point overlay if an entry exists
        Pointnum=app.UITable.Data.PointNum(app.gcpIDX);
        Pointnum=Pointnum{1};
        if any(app.gcpPrevMarker.PointNum==Pointnum)
            app.gcpPrevMarker(find(app.gcpPrevMarker.PointNum ==Pointnum),:)=[];
        end

        updateTable();
        updateImageOverlay();
    end

    function IMGclickCallback(src, event)     
        % Normal click behavior when not in pan mode
        if app.isPickingGCP
            clickedPoint = event.IntersectionPoint;
            x = round(clickedPoint(1));
            y = round(clickedPoint(2));
            disp(['Clicked at (', num2str(x), ', ', num2str(y), ')']);

            % Plot a marker at the clicked point
            hold(app.IMGaxes, 'on');
            scatterHandle = scatter(app.IMGaxes, x, y, 10, [240, 36, 209]/255, 'filled', 'o'); %blue
            % scatterHandle = scatter(app.IMGaxes, x, y, 10, [240/255, 36/255, 209/255], 'filled', 'o');
            scatterHandle.Visible = 'off';  % Hide it right away
            hold(app.IMGaxes, 'off');
    
            % Store the marker info so it persists
            Pointnum=app.UITable.Data.PointNum(app.gcpIDX);
            Pointnum=Pointnum{1};
            newRow = table(Pointnum, x, y, scatterHandle, ...
               'VariableNames', {'PointNum', 'X', 'Y', 'Handle'});
            if any(app.gcpPrevMarker.PointNum==Pointnum)
                app.gcpPrevMarker(find(app.gcpPrevMarker.PointNum ==Pointnum),:)=newRow;
            else
                app.gcpPrevMarker(end+1,:) = newRow;
            end
            
            % Save data to table
            ImageUset=GPSpoints.ImageU(mask);
            ImageUset(app.gcpIDX)=x;
            GPSpoints.ImageU(mask)=ImageUset;
            
            ImageVset=GPSpoints.ImageV(mask);
            ImageVset(app.gcpIDX)=y;
            GPSpoints.ImageV(mask)=ImageVset;

            updateImageOverlay();
            updateTable();
        end
    end
    
    % function IMGclickCallback(src, event)
    %     if app.isPickingGCP
    %         clickedPoint = event.IntersectionPoint;
    %         x = round(clickedPoint(1));
    %         y = round(clickedPoint(2));
    %         disp(['Clicked at (', num2str(x), ', ', num2str(y), ')']);
    % 
    %         % Plot a pink marker at the clicked point
    %         hold(app.IMGaxes, 'on');
    %         scatterHandle = scatter(app.IMGaxes, x, y, 100, [240/255, 36/255, 0.7059], 'filled', 'o');
    %         hold(app.IMGaxes, 'off');
    % 
    %         % Store the marker info so it persists
    %         app.gcpMarkers{end+1} = struct('X', x, 'Y', y, 'Handle', scatterHandle);
    %     end
    % end

    % Initial Highlight and Image Update
    updateFullFrame();
end

%% Scatch paper

% scatterHandle = scatter(app.IMGaxes, x, y, 100, [240/255, 36/255, 0.7059], 'filled', 'o');