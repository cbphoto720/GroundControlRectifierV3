function gps_map_gui(UserPrefs, GPSpoints)
    % Load Colormap
    load("hawaiiS.txt"); % Load color map
    savefilename=fullfile(UserPrefs.OutputFolder,UserPrefs.OutputFolderName,strcat("GCPSaveState_",num2str(UserPrefs.CamSN),".mat"));

    % Get screen size for positioning the figure
    set(0, 'units', 'pixels');
    scr_siz = get(0, 'ScreenSize');
    
    % Define figure width and height as a percentage of screen size
    figWidth = 0.8 * scr_siz(3);
    figHeight = 0.7 * scr_siz(4);
    figX = (scr_siz(3) - figWidth) / 2;  % Center horizontally
    figY = (scr_siz(4) - figHeight) / 2; % Center vertically

    % Create main UI figure
    GCPapp = uifigure('Name', 'Ground Control Picker', ...
        'Position', [figX, figY, figWidth, figHeight]);
    GCPapp.CloseRequestFcn = @CloseRequest

    % Create GridLayout for the main figure
    app.MainGridLayout = uigridlayout(GCPapp);
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
    % GPSpoints.scatterHandle=gobjects(height(GPSpoints), 1);

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
    highlightSAVEDGCPPlot = geoscatter(app.UIAxes, NaN, NaN, 100,'pentagram','filled', 'MarkerFaceColor', '#000000'); % Initially empty
    highlightSETPlot = geoscatter(app.UIAxes, NaN, NaN, 100, 'r', 'pentagram','filled'); % Initially empty
    highlightSINGLEPlot = geoscatter(app.UIAxes, NaN, NaN, 100,'pentagram','filled', 'MarkerFaceColor', '#f024d1'); % Initially empty

    % Add Legend
    legend(app.UIAxes, ...
    [highlightSAVEDGCPPlot, highlightSETPlot, highlightSINGLEPlot], ...
    {'Saved GCP', 'Set Highlight', 'User Selection'}, ...
    'Location', 'northeast');

    hold(app.UIAxes, 'off');

    %% GUI Elements

    % Create UIAxes2 (right side for image display)
    app.IMGaxes = axes(app.MainGridLayout);
    app.IMGaxes.Layout.Row = 1;
    app.IMGaxes.Layout.Column = 2;

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

    % Create GridLayout2 for buttons at the bottom of GPS axis
    app.GPSButtonGrid = uigridlayout(app.MainGridLayout);
    app.GPSButtonGrid.Layout.Row = 2;
    app.GPSButtonGrid.Layout.Column = 1;
    app.GPSButtonGrid.ColumnWidth = {'1x', '1x', '1x', '0.5x', '1x','0.5x'};
    app.GPSButtonGrid.RowHeight = {'1x', '1x'};

    % Create Export Button
    app.ExportButton = uibutton(app.GPSButtonGrid, 'push', 'Text', 'Export points');
    app.ExportButton.ButtonPushedFcn = @(~,~) ExportCallback();
    app.ExportButton.Layout.Row = 2;
    app.ExportButton.Layout.Column = 1;

    % Create Save Button
    app.SaveButton = uibutton(app.GPSButtonGrid, 'push', 'Text', 'Save Progress');
    app.SaveButton.ButtonPushedFcn = @(~,~) saveCallback();
    app.SaveButton.Layout.Row = 2;
    app.SaveButton.Layout.Column = 2;

    % Create Import Button
    app.ImportButton = uibutton(app.GPSButtonGrid, 'push', 'Text', 'Import points');
    app.ImportButton.ButtonPushedFcn = @(~,~) ImportCallback();
    app.ImportButton.Layout.Row = 1;
    app.ImportButton.Layout.Column = 1;

    % Create Back Button
    app.BackButton = uibutton(app.GPSButtonGrid, 'push', 'Text', '<< Prev set');
    app.BackButton.ButtonPushedFcn = @(~,~) prevSETCallback();
    app.BackButton.Layout.Row = 1;
    app.BackButton.Layout.Column = 3;

    % Create a description label for the current set
    app.GPS_desc_label = uilabel(app.GPSButtonGrid, 'Text', setnames{1}, ...
        'FontSize', 14, 'HorizontalAlignment', 'center');
    app.GPS_desc_label.Layout.Row = 1;
    app.GPS_desc_label.Layout.Column = 4;

    % Create Forward Button
    app.ForwardButton = uibutton(app.GPSButtonGrid, 'push', 'Text', 'Next set >>');
    app.ForwardButton.ButtonPushedFcn = @(~,~) nextSETCallback();
    app.ForwardButton.Layout.Row = 1;
    app.ForwardButton.Layout.Column = 5;

    % Prev GCP button
    app.PrevGCP = uibutton(app.GPSButtonGrid, 'push', 'Text', 'Up');
    app.PrevGCP.ButtonPushedFcn = @(~,~) prevGCPCallback();
    app.PrevGCP.Layout.Row = 1;
    app.PrevGCP.Layout.Column = 6;

    % % GCPsetIDX Label 
    % app.GCPlabel = uilabel(app.GPSButtonGrid, 'Text', string(app.UITable.Data.PointNum(app.gcpIDX)), ...
    %     'FontSize', 14, 'HorizontalAlignment', 'center');
    % app.GCPlabel.Layout.Row = 2;
    % app.GCPlabel.Layout.Column = 6;

    % Next GCP button
    app.NextGCP = uibutton(app.GPSButtonGrid, 'push', 'Text', 'Down');
    app.NextGCP.ButtonPushedFcn = @(~,~) nextGCPCallback();
    app.NextGCP.Layout.Row = 2;
    app.NextGCP.Layout.Column = 6;

    % Function to update highlighted points
    function updateFullFrame()
        updatePoints();
        updateTable();
        updateImage();
    end

    function updatePoints()
        mask = strcmp(GPSpoints{:,2}, setnames{setIDX});

        % Update color for all saved GCPs
        highlightSAVEDGCPPlot.LatitudeData = GPSpoints.Latitude(GPSpoints.ImageU~=0);
        highlightSAVEDGCPPlot.LongitudeData = GPSpoints.Longitude(GPSpoints.ImageU~=0);

        % Update set highlight
        highlightSETPlot.LatitudeData = GPSpoints.Latitude(mask);
        highlightSETPlot.LongitudeData = GPSpoints.Longitude(mask);

        % Update single point highlight
        highlightSINGLEPlot.LatitudeData = highlightSETPlot.LatitudeData(app.gcpIDX);
        highlightSINGLEPlot.LongitudeData = highlightSETPlot.LongitudeData(app.gcpIDX);

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

        hold(app.IMGaxes, 'on'); % add overlays

        % only plot points that aren't at 0,0
        GPSpoints_GCPplot=GPSpoints(GPSpoints.ImageU~=0,:);
        for i=1:height(GPSpoints_GCPplot)
            scatter(app.IMGaxes, GPSpoints_GCPplot.ImageU(i), GPSpoints_GCPplot.ImageV(i), ...
                    10, [66, 245, 99]/255, 'filled', 'o', 'Tag', 'GCPscatter'); % Green color
        end
        
        % plot the highlighted point in pink (even if the coords are 0,0
        scatter(app.IMGaxes,GPSpoints.ImageU(Pointnum), GPSpoints.ImageV(Pointnum), ...
            10, [240, 36, 209]/255, 'filled', 'o', 'Tag', 'GCPscatter'); % Pink color

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

    function redrawGCPS()
        for i=1:height(GPSpoints(GPSpoints.ImageU~=0,:))
            
        end
    end

    function ExportCallback();
        outputmask=(GPSpoints.ImageU~=0);
        outtable=[GPSpoints.Northings(outputmask),GPSpoints.Eastings(outputmask),GPSpoints.H(outputmask),...
            GPSpoints.ImageU(outputmask),GPSpoints.ImageV(outputmask)];

        % Print data to console
        for i=1:length(outtable)
            fprintf('- [%.6f, %.6f, %.6f, %d, %d]\n',outtable(i,1),outtable(i,2),outtable(i,3),outtable(i,4),outtable(i,5));
        end

    end

    function saveCallback()
        save(savefilename,"GPSpoints","UserPrefs") %WIP - Save file should be to outputfolder path in user prefs.
        fprintf("saved progress to output folder: %s\n",savefilename);
    end

    function ImportCallback()

        fig = uifigure;
        msg = "Do you want to save your current progress before over-writing?";
        title = "Save Progress";
        selection=uiconfirm(fig,msg,title, ...
            "Options",{'Save','Do not save'}, ...
            "DefaultOption",1);
        switch selection
            case 'Save'
                saveCallback()
            case 'Do not save'
                close(fig);
        end

        disp('CONTINUING') %DEBUG

        [file, path] = uigetfile('*.mat', 'Select MAT file');
        if isequal(file, 0)
            disp('User canceled file selection.');
            return;
        end
    
        fullFile = fullfile(path, file);
        vars = who('-file', fullFile);
    
        requiredVars = {'GPSpoints', 'UserPrefs'};
        missingVars = setdiff(requiredVars, vars);
    
        if ~isempty(missingVars)
            error('Missing required variables: %s', strjoin(missingVars, ', '));
        end
    
        S=load(fullFile, requiredVars{:});
        assignin('base', 'GPSpoints', S.GPSpoints);
        assignin('base', 'UserPrefs', S.UserPrefs);

        if~any(ismember(S.GPSpoints.Properties.VariableNames,"ImageU"))
            error('.mat file contains GPSpoints but does not contain any importable GCP coordinates')
        else
            load(fullFile, requiredVars{:}); % this line will over0write current GPSpoints
        end

        updateFullFrame();
        % redrawGCPS();
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

    function PickGCPcallback
        app.isPickingGCP = ~app.isPickingGCP;  % Set state
        if app.isPickingGCP % Button pressed
            app.PickGCP.BackgroundColor = '#f024d1';
        else % Button de-pressed
            app.PickGCP.BackgroundColor = [0.94, 0.94, 0.94];  % default uifigure gray 
        end
    end

    function DeleteGCPcallback()
        % Remove the point overlay if an entry exists
        Pointnum=app.UITable.Data.PointNum(app.gcpIDX);
        Pointnum=Pointnum{1};

        % Remove data in table
        GPSpoints.ImageU(Pointnum)=0;
        GPSpoints.ImageV(Pointnum)=0;

        updateTable();
        updateImageOverlay();
    end

    function IMGclickCallback(src, event)     
        % Normal click behavior when not in pan mode
        if app.isPickingGCP
            clickedPoint = event.IntersectionPoint;
            x = round(clickedPoint(1));
            y = round(clickedPoint(2));
            % disp(['Clicked at (', num2str(x), ', ', num2str(y), ')']); %DEBUG
    
            % Store the marker info so it persists
            
            Pointnum=app.UITable.Data.PointNum(app.gcpIDX);
            Pointnum=Pointnum{1};

            GPSpoints.ImageU(Pointnum)=x;
            GPSpoints.ImageV(Pointnum)=y;
            % GPSpoints.scatterHandle(Pointnum)=scatterHandle;

            updateImageOverlay();
            updateTable();
        end
    end

    function CloseRequest(src, event)
        fig = uifigure;
        msg = "Do you want to save your current progress before closing?";
        title = "Save Progress";
        selection=uiconfirm(fig,msg,title, ...
            "Options",{'Save','Do not save'}, ...
            "DefaultOption",1);
        switch selection
            case 'Save'
                saveCallback()
                close(fig);
            case 'Do not save'
                close(fig);
        end

        delete(src)
    end
    
    pause(2); % pause to help elements load before trying to update the frame
    % Initial Highlight and Image Update
    updateFullFrame();
end

%% Scatch paper

% scatterHandle = scatter(app.IMGaxes, x, y, 100, [240/255, 36/255, 0.7059], 'filled', 'o');