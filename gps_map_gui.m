function GCPapp = gps_map_gui(UserPrefs, GPSpoints, FullCamDB)
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
    GCPapp = uifigure('Name', 'Ground Control Picker', ...
        'Position', [figX, figY, figWidth, figHeight]);
    GCPapp.CloseRequestFcn = @CloseRequest

    % Create GridLayout for the main figure
    app.MainGridLayout = uigridlayout(GCPapp);
    app.MainGridLayout.RowHeight = {'4x', '1x'};
    app.MainGridLayout.ColumnWidth = {'1x', '1x'};

    % Create Left tab group
    app.Lefttabgroup = uitabgroup(app.MainGridLayout);
    app.Lefttabgroup.Layout.Row = 1;
    app.Lefttabgroup.Layout.Column = 1;
    app.tab1 = uitab(app.Lefttabgroup,"Title","GoogleMap");
    app.tab2 = uitab(app.Lefttabgroup,"Title","Rectification");
    app.tab3 = uitab(app.Lefttabgroup,"Title","Rectification Stats");

    % Create EarthViewAxes (left side for GPS map)
    app.EarthViewAxes = geoaxes(app.tab1);
    % app.UIAxes.Layout.Row = 1;
    % app.UIAxes.Layout.Column = 1;
    hold(app.EarthViewAxes, 'on'); % Allow multiple drawings
    title(app.EarthViewAxes, 'GPS Map');

    % Create RectificationAxes
    app.RectificationAxes=axes(app.tab2);
    title(app.RectificationAxes, 'Rectification Map');

    % Create Rectification Stats Axes
    app.RectStatsLayout = uigridlayout(app.tab3);
    app.RectStatsLayout.RowHeight = {'1x', '1x'};
    app.RectStatsLayout.ColumnWidth = {'2x', '1x'};

    % Create Rectification Histogram Axes
    app.RectificationHistogramAxes = axes(app.RectStatsLayout);
    app.RectificationHistogramAxes.Layout.Row = 1;
    app.RectificationHistogramAxes.Layout.Column = 1;

    % Create Error table
    app.RectificationErrorTable = uitable(app.RectStatsLayout);
    app.UITable.Layout.Row = 2;
    app.UITable.Layout.Column = 2;
    app.UITable.ColumnWidth={'1x','1x'};
    app.UITable.ColumnEditable = [false, false];

    % Create Error vs Distance Axes
    app.RectificationDistanceError = axes(app.RectStatsLayout);
    app.RectificationDistanceError.Layout.Row = 2;
    app.RectificationDistanceError.Layout.Column = 1;
    

    %% Variables

    GPSpoints.ImageU=zeros(height(GPSpoints),1);
    GPSpoints.ImageV=GPSpoints.ImageU;
    GPSpoints.Reprojectu1=GPSpoints.ImageU;
    GPSpoints.Reprojectv1=GPSpoints.ImageU;
    % GPSpoints.scatterHandle=gobjects(height(GPSpoints), 1);

    % Get unique descriptions (setnames)
    setnames = getSetNames(GPSpoints);
    NUM_IMGsets = numel(setnames); % Get number of unique sets

       % Initialize the current index tracker for setnames
    setIDX = 1;
    app.isPickingGCP = false;  % Set state sp that clicking on the image will not select A GCP yet
    app.DisplayProjection = false; % flag to turn of rectified coordinates
    app.gcpIDX=1; % IDX for individual GPS points within the set (for UV-picking)

    app.gcpHighlightMarker = [];  % Holds handles to GCP scatter plot on IMGaxes
    app.gcpPrevMarker = table([], [], [], [], ...
    'VariableNames', {'PointNum', 'X', 'Y', 'Handle'});

    % Plot all GPS points
    geobasemap(app.EarthViewAxes, "satellite");
    for i = 1:NUM_IMGsets
        mask = strcmp(GPSpoints{:,2}, setnames{i});
        geoscatter(app.EarthViewAxes, GPSpoints.Latitude(mask), GPSpoints.Longitude(mask), ...
                   36, hawaiiS(mod(i-1, 100) + 1, :), "filled"); % Wrap colors properly
    end

    % Overlay for highlighted points
    highlightSAVEDGCPPlot = geoscatter(app.EarthViewAxes, NaN, NaN, 100,'pentagram','filled', 'MarkerFaceColor', '#000000'); % Initially empty
    highlightSETPlot = geoscatter(app.EarthViewAxes, NaN, NaN, 100, 'r', 'pentagram','filled'); % Initially empty
    highlightSINGLEPlot = geoscatter(app.EarthViewAxes, NaN, NaN, 100,'pentagram','filled', 'MarkerFaceColor', '#f024d1'); % Initially empty

    % Add Legend
    legend(app.EarthViewAxes, ...
    [highlightSAVEDGCPPlot, highlightSETPlot, highlightSINGLEPlot], ...
    {'Saved GCP', 'Set Highlight', 'User Selection'}, ...
    'Location', 'northeast');

    hold(app.EarthViewAxes, 'off');

    %% GUI Elements

    % Create grid for IMG title (right side for image display)
    app.IMGlayoutGrid = uigridlayout(app.MainGridLayout);
    app.IMGlayoutGrid.Layout.Row = 1;
    app.IMGlayoutGrid.Layout.Column = 2;
    app.IMGlayoutGrid.RowHeight = {'0.1x', '1x'};
    app.IMGlayoutGrid.ColumnWidth = {'1x', '0.1x'};
    app.IMGlayoutGrid.Padding= [0 0 0 0];
    app.IMGlayoutGrid.RowSpacing = 0;

    % Create title for the img
    app.IMG_desc_label = uilabel(app.IMGlayoutGrid, 'Text', sprintf("%s, %s, SN %d", UserPrefs.CamFieldSite, UserPrefs.CamNickName, UserPrefs.CamSN), ...
        'FontSize', 20, 'FontWeight', 'bold', 'HorizontalAlignment', 'right');
    app.IMG_desc_label.Layout.Row = 1;
    app.IMG_desc_label.Layout.Column = 1;

    % Create UIAxes2 (right side for image display)
    app.IMGaxes = axes(app.IMGlayoutGrid);
    app.IMGaxes.Layout.Row = 2;
    app.IMGaxes.Layout.Column = [1 2];

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

    % Create Calculate button
    app.CalcButton = uibutton(app.GPSButtonGrid, 'push', 'Text', 'Calculate!');
    app.CalcButton.ButtonPushedFcn = @(~,~) CalculateCallback();
    app.CalcButton.Layout.Row = 2;
    app.CalcButton.Layout.Column = 3;

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
        imgfile = imgfile(1); %DEBUG remove ; to get the filename in the command window

        %update title in the top corner:
        app.IMG_desc_label.Text=sprintf("%s, %s, SN %d, \n IMG: %s", UserPrefs.CamFieldSite, UserPrefs.CamNickName, UserPrefs.CamSN, imgfile);
        
        if strcmp(imgfile, "")
            app.img = uint8(255 * ones(100,100,3)); % white 100x100 placeholder
            hImg = imshow(app.img, 'Parent', app.IMGaxes);
            set(hImg, 'ButtonDownFcn', @(src, event) IMGclickCallback(src, event));
        else
            checkFile = dir(fullfile(UserPrefs.UsableIMGsFolder, '**', imgfile));
            if ~isempty(checkFile)
            % Load and show actual image
                app.img = imread(fullfile(checkFile.folder,imgfile));
                hImg = imshow(app.img, 'Parent', app.IMGaxes);
                set(hImg, 'ButtonDownFcn', @(src, event) IMGclickCallback(src, event));
            else
                title = "UsableIMGsFolder";
                quest = [sprintf("Unable to find img: %s",imgfile), "Would you like to re-select the Usable-imgs folder?"];
                pbtns = ["Yes","No"];
                
                Switchfolder = questdlg(quest,title, pbtns);
                if strcmp(Switchfolder,"Yes")
                    UserPrefs.UsableIMGsFolder=uigetdir(UserPrefs.UsableIMGsFolder);
                    updateImage();
                end
            end
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
        scatter(app.IMGaxes,GPSpoints.ImageU(find(GPSpoints.Name==Pointnum)), GPSpoints.ImageV(find(GPSpoints.Name==Pointnum)), ...
            10, [240, 36, 209]/255, 'filled', 'o', 'Tag', 'GCPscatter'); % Pink color
        
        % Plot rectified image U V projections
        if app.DisplayProjection
            PROJECTIONpoints_GCPplot=GPSpoints(GPSpoints.Reprojectu1~=0,:);
            for i=1:height(PROJECTIONpoints_GCPplot)
                scatter(app.IMGaxes, GPSpoints.Reprojectu1(i), GPSpoints.Reprojectv1(i), ...
                        20, [252, 86, 3]/255, 'o', 'Tag', 'GCPscatter'); % Orange color
            end
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

    function Rectification = CalcRectification(icp, betaOUT, xyzGCP, k, GPSpixel_dims)
        % k = Compression factor = 1, 2, 4, 8, 16, ... etc (for graphic performance reasons)
        % GPSpixel_dims = [offsetx , offsety].  [2,1] is the standard value
        % How many pixels will a GPS point highlight on the rectification map
        outputmask=find(GPSpoints.ImageU~=0);
        

        Rectification=struct();
        Rectification.k=k;

        Uvals = repelem(0:k:(k*(icp.NU/k - 1)), k);   % U axis with repeats
        Vvals = repelem(0:k:(k*(icp.NV/k - 1)), k);   % V axis with repeats
        [U, V] = meshgrid(Uvals, Vvals);
        
        Rectification.Zplane=mean(xyzGCP(:,3));

        [Xa, Ya, Za] = getXYZfromUV(U, V, icp, betaOUT, Rectification.Zplane, '-z',2.5);
        
        % Compress the grid and image for better performance`
        Rectification.Xab=compressmatrix(Xa,k,k);
        Rectification.Yab=compressmatrix(Ya,k,k);
        Rectification.Zab=compressmatrix(Za,k,k);
        
        % Create GPS overlay:
        GPSsurface=compressmatrix((Rectification.Zplane-1)*ones(icp.NV,icp.NU,1),k,k); % create a surface below
        indexX=[];
        indexY=[];
        
        for i=1:length(outputmask)
            if and(GPSpoints.ImageV(outputmask(i))~=0, GPSpoints.ImageU(outputmask(i))~=0)
                % indexX(end+1,:)=round(GPSpoints.ImageV(outputmask(i))/k)-GPSpixel_dims(2):round(GPSpoints.ImageV(outputmask(i))/k)+GPSpixel_dims(2);
                % indexY(end+1,:)=round(GPSpoints.ImageU(outputmask(i))/k)-GPSpixel_dims(1):round(GPSpoints.ImageU(outputmask(i))/k)+GPSpixel_dims(1);

                GPSsurface(round(GPSpoints.ImageV(outputmask(i))/k)-GPSpixel_dims(2):round(GPSpoints.ImageV(outputmask(i))/k)+GPSpixel_dims(2),...
                    round(GPSpoints.ImageU(outputmask(i))/k)-GPSpixel_dims(1):round(GPSpoints.ImageU(outputmask(i))/k)+GPSpixel_dims(1))=Rectification.Zplane; %Store a group of pixels instead just a single point
            end
        end

        Rectification.GPSsurface=GPSsurface;

        % --- Calculate the error of the Projection vs the actual coordinates ---
        % Extract (X,Y) where surface overlay hits z=0
        % mask = (Rectification.GPSsurface == Rectification.Zplane);   % logical mask
        % Xz = Rectification.Xab(mask);
        % Yz = Rectification.Yab(mask);
        % Zz = Rectification.GPSsurface(mask);      % should all be 0
        % 
        % surfZeroPoints = [Xz(:), Yz(:), Zz(:)];   % Mx3 list of surface z=0 points

        [surfZeroPoints(:,1),surfZeroPoints(:,2),surfZeroPoints(:,3)] = getXYZfromUV(GPSpoints.ImageU(outputmask), GPSpoints.ImageV(outputmask), icp, betaOUT, xyzGCP(:,3), '-z',2.5);
        
        
        % Your scatter3 points (already nx3, with z=0)
        scatterPoints = xyzGCP;
        % scatterPoints(:,3)=Rectification.Zplane; % don't calculate vertical distance
        
        % Calc distance
        Rectification.errors = zeros(size(surfZeroPoints,1),1);
        for i=1:size(surfZeroPoints,1)
            Rectification.errors(i)=norm(scatterPoints(i,:)- surfZeroPoints(i,:));
        end
        
        % [Rectification.errors, ~] = min(D, [], 2);
    end

    function DrawRectification(ax,Rectification,xyzGCP); % create axes inside your figure)
        cla(ax)
        % - - - Start plotting - - -
        % Get background img
        mask = strcmp(GPSpoints{:,2}, setnames{setIDX});
        imgfile = GPSpoints.FileIDX(mask);
        imgfile = imgfile(1);
        checkFile = dir(fullfile(UserPrefs.UsableIMGsFolder, '**', imgfile));
        ocean = imread(fullfile(checkFile.folder,imgfile));
        ocean = double(rgb2gray(ocean));
        oceanb=compressmatrix(ocean,Rectification.k,Rectification.k);

        % start the plot

        ImageUVcolor = repmat(reshape([66, 245, 99]/255,1,1,3), size(Rectification.Xab)); % Green color
        hold(ax, 'on')
        app.rectsurface = surf(ax,Rectification.Xab,Rectification.Yab,Rectification.Zab,'Cdata',repmat(oceanb,1,1,3)/255,'FaceColor','texturemap','EdgeColor','none','CDataMapping','direct');
        
        app.gpssurface = surf(ax,Rectification.Xab,Rectification.Yab,Rectification.GPSsurface,'Cdata',ImageUVcolor,'FaceColor','texturemap','EdgeColor','none','CDataMapping','direct');
        
        app.gpspoints = scatter3(ax,xyzGCP(:,1),xyzGCP(:,2),Rectification.Zplane*ones(1,size(xyzGCP,1)),36,[252, 86, 3]/255); % Orange color

        shading(ax, 'flat');
        set(ax,'DataAspectRatio', [1 1 1]);
        ylabel(ax,'Alongshore (m)')
        xlabel(ax,'Cross-shore (m)')

        % - - - Plot error bars - - - 
        histogram(app.RectificationHistogramAxes,Rectification.errors,ceil(max(Rectification.errors)));
        xlabel(app.RectificationHistogramAxes,'Error distance');
        ylabel(app.RectificationHistogramAxes,'Count');
        title(app.RectificationHistogramAxes,'Histogram of GCP distance pixel projection distance');

        updateFullFrame()
    end

    function M_small = compressmatrix(M, krow, kcol)
            % Collapse a matrix where values repeat in blocks of krow × kcol
            
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
        savefilename=fullfile(UserPrefs.OutputFolder,UserPrefs.OutputFolderName,strcat("GCR-",num2str(UserPrefs.SurveyDate),UserPrefs.CamFieldSite, UserPrefs.CamNickName, "_SN",num2str(UserPrefs.CamSN),".mat"));
        temp=savefilename;
        [savefilename,savelocation]=uiputfile('*.mat', 'Save As',savefilename); % pull up SaveAs dialog (write new name if user wants to change it)
        if savefilename == 0 % handle user cancel input
            savefilename=temp;
            return % do not proceed with saving, because user cancelled
        else
            save(fullfile(savelocation,savefilename),"GPSpoints","UserPrefs") %WIP - Save file should be to outputfolder path in user prefs.
            fprintf("saved progress to output folder: %s\n",fullfile(savelocation,savefilename));
        end
    end

    function CalculateCallback()
        app.DisplayProjection = true;
        outputmask=find(GPSpoints.ImageU~=0); % find indexes that have an associated Image pixel coordinate (GPS points visible to the camera)
        [pose, xyzGCP] = EstimateCameraPose(FullCamDB.(UserPrefs.DateofICP),GPSpoints(outputmask,:));

        % Generate ICP (Internal Camera Parameters [Intrinsics])
        readDB=readCPG_CamDatabase(CamSN=UserPrefs.CamSN,Date=string(UserPrefs.DateofICP(2:end)),format="compact");
        icp=readDB.icp;
        icp = makeRadialDistortion(icp);
        icp = makeTangentialDistortion(icp);
                
        betaOUT = constructCameraPose(xyzGCP, [GPSpoints.ImageU(outputmask,:), GPSpoints.ImageV(outputmask,:)], icp, [0,0,0,pose]);

        % Fill in the U,V reprojection for the camera view
        for i=1:length(outputmask)
            [GPSpoints.Reprojectu1(outputmask(i)), GPSpoints.Reprojectv1(outputmask(i))] = getUVfromXYZ(xyzGCP(i,1), xyzGCP(i,2), xyzGCP(i,3), icp, betaOUT);
        end

        % Print Beta parameters to add to the database
        fprintf("Beta parameters:\n");
        fprintf("%16.6f",betaOUT);
        fprintf("\n");

        Rectification_compressed = CalcRectification(icp, betaOUT, xyzGCP, 2, [2,1]);
        Rectification = CalcRectification(icp, betaOUT, xyzGCP, 1, [1,1]);
        
        DrawRectification(app.RectificationAxes,Rectification_compressed,xyzGCP);

        %--- Histogram of errors ---
        histogram(app.RectificationHistogramAxes, Rectification.errors,30);
        xlabel(app.RectificationHistogramAxes,'Error distance (m)');
        ylabel(app.RectificationHistogramAxes,'Count');
        title(app.RectificationHistogramAxes,'Raw Projection error vs Survey point (m)');

        app.RectificationErrorTable.Data= table(num2cell(GPSpoints.Name(outputmask,:)),num2cell(Rectification.errors) ,'VariableNames',{'PointNum', 'Error Distance (m)'});

        %--- Error based on distance to cam ---
        % Calc distance
        GCPdistancetoCamera = pdist2(xyzGCP, repmat([0,0,0],size(xyzGCP,1),1));


        cla(app.RectificationDistanceError)
        scatter(app.RectificationDistanceError, GCPdistancetoCamera,Rectification.errors)
        hold(app.RectificationDistanceError, 'on')
        title(app.RectificationDistanceError, 'GCP XY Errors vs projection distance');
        xlabel(app.RectificationDistanceError, 'Distance to camera (m)');
        ylabel(app.RectificationDistanceError, 'XY Error (m)');
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
        app.DisplayProjection = false;
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
        GPSpoints.ImageU(find(GPSpoints.Name==Pointnum))=0;
        GPSpoints.ImageV(find(GPSpoints.Name==Pointnum))=0;

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

            GPSpoints.ImageU(find(GPSpoints.Name==Pointnum))=x;
            GPSpoints.ImageV(find(GPSpoints.Name==Pointnum))=y;
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