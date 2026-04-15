function [answers, cancelled] = PrepOptionsGUI(DefaultOptions)
    % Initialize return values
    answers = struct();
    cancelled = true;
    dbTable = table(); % Buffer for database content

    % Handle Defaults
    if nargin < 1 || ~exist(DefaultOptions, 'file')
        DefAns = struct('SurveyDate', datestr(now, 'yyyymmdd'), ...
                        'SiteID', '', 'CamID', '', 'CamSN', '', ...
                        'CameraFilename', '', 'PullDateFromGPS', false, ...
                        'CameraDB', '', 'GCPImages', '', 'GPSSurvey', '', ...
                        'OutputPath', pwd, 'cbDefOps', false);
    else
        loaded = load(DefaultOptions);
        DefAns = loaded.DefAns;
    end

    % Create the main figure
    fig = uifigure('Name', 'Survey Configuration', 'Position', [500 300 550 750]);
    mainGrid = uigridlayout(fig, [5, 1]);
    mainGrid.RowHeight = {'fit', 'fit', 'fit', 'fit', 'fit'};

    % --- SECTION 1: CAMERA DATABASE ---
    dbPanel = uipanel(mainGrid, 'Title', 'Reference Files', 'FontWeight', 'bold');
    dbGrid = uigridlayout(dbPanel, [2, 4]);
    dbGrid.ColumnWidth = {'1x', '2x', 35, 'fit'};
    
    uilabel(dbGrid, 'Text', 'Camera Database YAML:');
    efCamDB = uieditfield(dbGrid, 'text', 'Value', DefAns.CameraDB);
    uibutton(dbGrid, 'Text', '...', 'ButtonPushedFcn', @(btn, evt) browseFile(efCamDB, '*.yaml;*.yml', 'Select Camera DB'));

    btnLoadDB = uibutton(dbGrid, 'Text', 'Load DB','BackgroundColor', '#f0b256', 'ButtonPushedFcn', @loadDatabaseLogic);
    btnLoadDB.Layout.Row = 2;
    btnLoadDB.Layout.Column=[1,4]; 

    % --- SECTION 2: CAMERA INFORMATION PANEL ---
    camPanel = uipanel(mainGrid, 'Title', 'Camera Information', 'FontWeight', 'bold');
    camGrid = uigridlayout(camPanel, [6, 2]);
    camGrid.ColumnWidth = {'1x', '1x','1x'};

    % Manual Entry Toggle
    cbNewCam = uicheckbox(camGrid, 'Text', 'Add New Camera (Manual Entry) OR Load DB to select existing', 'Value', true);
    cbNewCam.Layout.Column = [1 ,3];
    cbNewCam.ValueChangedFcn = @toggleManualEntry;

    % Site ID
    SiteIDlabel=uilabel(camGrid, 'Text', 'Site ID:');
    SiteIDlabel.Layout.Row = 2;
    SiteIDlabel.Layout.Column = 1;
    efSiteID = uieditfield(camGrid, 'text', 'Value', DefAns.SiteID);
    efSiteID.Layout.Column = [2,3];
    ddSiteID = uidropdown(camGrid, 'Visible', 'off', 'ValueChangedFcn', @updateCamOptions);
    ddSiteID.Layout.Column = [2 3];
    ddSiteID.Layout.Row = 2;

    % Camera ID
    CamIDlabel=uilabel(camGrid, 'Text', 'Camera ID:');
    CamIDlabel.Layout.Row = 3;
    CamIDlabel.Layout.Column = 1;
    efCamID = uieditfield(camGrid, 'text', 'Value', DefAns.CamID);
    efCamID.Layout.Column = [2,3];
    ddCamID = uidropdown(camGrid, 'Visible', 'off', 'ValueChangedFcn', @updateCamOptions);
    ddCamID.Layout.Column = [2,3];
    ddCamID.Layout.Row = 3;

    % Camera SN
    CamSNlabel=uilabel(camGrid, 'Text', 'Camera Serial Number:');
    CamSNlabel.Layout.Row = 4;
    CamSNlabel.Layout.Column = 1;
    efCamSN = uieditfield(camGrid, 'text', 'Value', DefAns.CamSN);
    efCamSN.Layout.Column = [2,3];
    ddCamSN = uidropdown(camGrid, 'Visible', 'off');
    ddCamSN.Layout.Column = [2,3];
    ddCamSN.Layout.Row = 4;

    % Camera Filename
    CamFilenamelabel=uilabel(camGrid, 'Text', 'Camera Filename:');
    CamFilenamelabel.Layout.Row = 5;
    CamFilenamelabel.Layout.Column = 1;
    efCamFile = uieditfield(camGrid, 'text', 'Value', DefAns.CameraFilename);
    efCamFile.Layout.Column = [2,3];
    ddCamFile = uidropdown(camGrid, 'Visible', 'off');
    ddCamFile.Layout.Column = [2,3];
    ddCamFile.Layout.Row = 5;

    % Date
    SurveyDatelabel=uilabel(camGrid, 'Text', 'Survey Date (YYYYMMDD):');
    SurveyDatelabel.Layout.Row = 6;
    SurveyDatelabel.Layout.Column = 1;
    efDate = uieditfield(camGrid, 'text', 'Value', DefAns.SurveyDate);
    cbGPSDate = uicheckbox(camGrid, 'Text', 'Pull date from GPS file', 'Value', DefAns.PullDateFromGPS);
    cbGPSDate.Layout.Row = 6;
    cbGPSDate.Layout.Column = 3;
    cbGPSDate.ValueChangedFcn = @(src, event) set(efDate, 'Enable', ~src.Value);
    if DefAns.PullDateFromGPS, efDate.Enable = 'off'; end

    % --- SECTION 3: SURVEY OPTIONS ---
    srvPanel = uipanel(mainGrid, 'Title', 'Survey Options', 'FontWeight', 'bold');
    srvGrid = uigridlayout(srvPanel, [2, 3]);
    srvGrid.ColumnWidth = {'1x', '2x', 35};
    uilabel(srvGrid, 'Text', 'GCP Images Folder:');
    efGCP = uieditfield(srvGrid, 'text', 'Value', DefAns.GCPImages);
    uibutton(srvGrid, 'Text', '...', 'ButtonPushedFcn', @(btn, evt) browseFolder(efGCP));
    uilabel(srvGrid, 'Text', 'GPS Survey File:');
    efGPSFile = uieditfield(srvGrid, 'text', 'Value', DefAns.GPSSurvey);
    uibutton(srvGrid, 'Text', '...', 'ButtonPushedFcn', @(btn, evt) browseFile(efGPSFile, '*.csv;*.txt', 'Select GPS File'));

    % --- SECTION 4: SAVE OPTIONS ---
    savePanel = uipanel(mainGrid, 'Title', 'Save Options', 'FontWeight', 'bold');
    saveGrid = uigridlayout(savePanel, [1, 3]);
    saveGrid.ColumnWidth = {'1x', '2x', 35};
    uilabel(saveGrid, 'Text', 'Output Folder:');
    efOut = uieditfield(saveGrid, 'text', 'Value', DefAns.OutputPath);
    uibutton(saveGrid, 'Text', '...', 'ButtonPushedFcn', @(btn, evt) browseFolder(efOut));

    % --- SECTION 5: ACTIONS ---
    ContinuePanelGrid = uigridlayout(mainGrid, [2, 2]);
    ContinuePanelGrid.ColumnWidth = {'1x', '1x'};
    ContinuePanelGrid.RowHeight = {'fit', 50};

    cbDefOps = uicheckbox(ContinuePanelGrid, 'Text', 'Set these options as default for next time', 'Value', DefAns.cbDefOps);
    cbDefOps.Layout.Row = 1; cbDefOps.Layout.Column = [1 2];

    btnOk = uibutton(ContinuePanelGrid, 'Text', 'Continue','BackgroundColor', '#d6faa5', 'ButtonPushedFcn', @(btn, evt) uiresume(fig));
    btnOk.Layout.Row = 2; btnOk.Layout.Column = 1;

    btnCancel = uibutton(ContinuePanelGrid, 'Text', 'Cancel','BackgroundColor', '#f78b8b', 'ButtonPushedFcn', @(btn, evt) delete(fig));
    btnCancel.Layout.Row = 2; btnCancel.Layout.Column = 2;

    % --- Database Callbacks ---
    function loadDatabaseLogic(~, ~)
        if isempty(efCamDB.Value) || ~exist(efCamDB.Value, 'file')
            uialert(fig, 'Please select a valid YAML database first.', 'File Missing');
            return;
        end
        [p, ~, ~] = fileparts(efCamDB.Value);
        addpath(genpath(p)); % Keep your genpath requirement
        try
            dbTable = readCPG_CamDatabase(Format="searchtable");
            ddSiteID.Items = unique(dbTable.SiteID);
            cbNewCam.Value = false; % Switch to dropdown mode automatically
            toggleManualEntry(cbNewCam, []);
            updateCamOptions([], []);
        catch ME
            uialert(fig, ['Error reading database: ' ME.message], 'Database Error');
        end
    end

    function updateCamOptions(~, ~)
        if isempty(dbTable), return; end
        % Filter Site -> CamID
        siteMatch = dbTable(strcmp(dbTable.SiteID, ddSiteID.Value), :);
        ddCamID.Items = unique(siteMatch.CamID);
        % Filter CamID -> SN & Filename
        camMatch = siteMatch(strcmp(siteMatch.CamID, ddCamID.Value), :);
        ddCamSN.Items = arrayfun(@num2str, camMatch.CamSN, 'UniformOutput', false);
        ddCamFile.Items = camMatch.Filename;
    end

    function toggleManualEntry(src, ~)
        isManual = src.Value;
        set([efSiteID, efCamID, efCamSN, efCamFile], 'Visible', isManual);
        set([ddSiteID, ddCamID, ddCamSN, ddCamFile], 'Visible', ~isManual);
    end

    uiwait(fig);

    % Map values back to structure
    if isvalid(fig)
        if cbNewCam.Value
            answers.SiteID = efSiteID.Value;
            answers.CamID = efCamID.Value;
            answers.CamSN = efCamSN.Value;
            answers.CameraFilename = efCamFile.Value;
        else
            answers.SiteID = ddSiteID.Value;
            answers.CamID = ddCamID.Value;
            answers.CamSN = ddCamSN.Value;
            answers.CameraFilename = ddCamFile.Value;
        end
        
        answers.SurveyDate = efDate.Value;
        answers.PullDateFromGPS = cbGPSDate.Value;
        answers.CameraDB = efCamDB.Value;
        answers.GCPimgPath = efGCP.Value;
        answers.GPSSurveyFile = efGPSFile.Value;
        answers.OutputPath = efOut.Value;
        answers.cbDefOps = cbDefOps.Value;
        
        cancelled = false;
        if cbDefOps.Value
            DefAns = answers;
            save(DefaultOptions, 'DefAns');
        end
        delete(fig);
    end
end

% --- Helper Functions ---
function browseFile(editField, ext, title)
    [file, path] = uigetfile(ext, title);
    if file, editField.Value = fullfile(path, file); end
end

function browseFolder(editField)
    path = uigetdir(pwd, 'Select Folder');
    if path, editField.Value = path; end
end

% function [answers, cancelled] = PrepOptionsGUI(DefaultOptions)
%     % SurveyInputGUI - Custom GUI for survey input using INPUTSDLG
%     % Outputs:
%     %   answers         =   Structure containing user input
%     %   cancelled       =   Boolean indicating if user cancelled
%     % Optional Inputs:
%     %   DefaultOptions  =   .mat file that specifies GUI defaults
% 
%     % Handle custom defaults if specified
%     if nargin<1
%         DefAns = struct([]);
%     elseif(exist(DefaultOptions,'file'))
%         loadedPrefs = load(DefaultOptions);
%         DefAns = loadedPrefs.DefAns;
%     end
% 
%     Title = 'Survey Input GUI';
%     Options.Resize = 'on';
%     Options.Interpreter = 'tex';
%     Options.CancelButton = 'on';
%     Options.ApplyButton = 'off';
%     Options.ButtonNames = {'Continue','Cancel'};
% 
%     Prompt = {};
%     Formats = {};
%     r = 1;
%     c = 1;
% 
%     Prompt(1,:) = {['Global Options:'], [], []};
%     Formats(r,c).type = 'text';
%     Formats(r,c).size = [-1 0];
%     c = c + 1;
% 
%     Prompt(end+1,:) = {['Your survey:'], [], []};
%     Formats(r,c).type = 'text';
%     Formats(r,c).size = [-1 0];
%     r = r + 1;
%     c = 1;
% 
%     % Prompt(end+1,:) = {'Max Points in Set', 'MaxPoints', []};
%     % Formats(r,c).type = 'edit';
%     % Formats(r,c).format = 'integer';
%     % Formats(r,c).limits = [1 inf]; % Must be positive integer
%     % Formats(r,c).size = 50;
%     % if isfield(DefAns, 'MaxPoints')
%     %     % Formats(r,c).defAns = DefAns.MaxPoints; % Use saved preference if available
%     % else
%     %     DefAns(1).MaxPoints = 5; % Default value
%     % end
%     c = c + 1;
% 
%     Prompt(end+1,:) = {'Date of Survey (YYYYMMDD)', 'SurveyDate', []};
%     Formats(r,c).type = 'edit';
%     Formats(r,c).format = 'text';
%     Formats(r,c).size = 100;
%     if ~isfield(DefAns, 'SurveyDate')
%         DefAns(1).SurveyDate = char(datetime('now', 'Format', 'yyyyMMdd')); % Default to today's date
%     end
%     r = r + 1;
%     c = 1;
% 
%     Prompt(end+1,:) = {'Camera Database File', 'CameraDB', []};
%     Formats(r,c).type = 'edit';
%     Formats(r,c).format = 'file';
%     Formats(r,c).items = {'*.yaml;*.yml','YAML file';'*.*','All Files'};
%     Formats(r,c).limits = [0 1]; % Single file selection
%     Formats(r,c).size = [-1 0];
%     if isfield(DefAns, 'CameraDB')
%         % Formats(r,c).defAns = DefAns.CameraDB; % Use saved preference if available
%     else
%         DefAns.CameraDB = ''; % Default to empty
%     end
%     c = c + 1;
% 
%     Prompt(end+1,:) = {'GPS Survey File', 'GPSSurveyFile', []};
%     Formats(r,c).type = 'edit';
%     Formats(r,c).format = 'file';
%     Formats(r,c).items = {'*.txt;*.csv','Text/CSV Files';'*.*','All Files'};
%     Formats(r,c).limits = [0 1]; % Single file selection
%     Formats(r,c).size = [-1 0];
%     if ~isfield(DefAns, 'GPSSurveyFile')
%         DefAns.GPSSurveyFile = ''; % Default to empty
%     end
%     r = r + 1;
%     c = 1;
% 
%     Prompt(end+1,:) = {'Usable Images Folder', 'UsableIMGsFolder', []};
%     Formats(r,c).type = 'edit';
%     Formats(r,c).format = 'dir';
%     Formats(r,c).size = [-1 0];
%     Formats(r,c).span = [1 2]; % Spanning across columns
%     if ~isfield(DefAns, 'OutputFolder')
%         DefAns.OutputFolder = pwd; % Default to current directory
%     end
%     if ~isfield(DefAns, 'UsableIMGsFolder')
%         DefAns.UsableIMGsFolder = ''; % Default to empty
%     end
%     r = r + 1;
%     c = 1;
% 
%     % EXPORTS
%     r = r + 2; % Extra space
% 
%     Prompt(end+1,:) = {['Outputs'], [], []};
%     Formats(r,c).type = 'text';
%     Formats(r,c).size = [-1 0];
%     Formats(r,c).span = [1 2];
%     r = r + 1;
% 
%     Prompt(end+1,:) = {'Output Folder Path', 'OutputFolder', []};
%     Formats(r,c).type = 'edit';
%     Formats(r,c).format = 'dir';
%     Formats(r,c).size = [-1 0];
%     Formats(r,c).span = [1 2]; % Spanning across columns
%     if ~isfield(DefAns, 'OutputFolder')
%         DefAns.OutputFolder = pwd; % Default to current directory
%     end
%     r = r + 1;
% 
%     Prompt(end+1,:) = {'Output Folder Name', 'OutputFolderName', []};
%     Formats(r,c).type = 'edit';
%     Formats(r,c).format = 'text';
%     Formats(r,c).size = [-1 0];
%     Formats(r,c).span = [1 2]; % Spanning across columns
%     if ~isfield(DefAns, 'OutputFolderName')
%         DefAns.OutputFolderName = strcat(sprintf('%s',datetime(now(),'convertfrom','datenum','Format','yyyyMMdd')),'_GCPpickerOutput'); % Default to current directory
%     end
%     r = r + 1;
% 
%     Prompt(end+1,:) = {'Set these options as defaults for next time','SetOptAsDefault', []};
%     Formats(r,2).type = 'check';
%     if ~isfield(DefAns, 'SetOptAsDefault')
%         DefAns.SetOptAsDefault = true; % Default to true
%     end
% 
%     % Run INPUTSDLG
%     [answers, cancelled] = inputsdlg(Prompt, Title, Formats, DefAns, Options);
% 
%     if ~cancelled
%         addpath(answers.OutputFolder);
%         mkdir(fullfile(answers.OutputFolder,answers.OutputFolderName))
%     end
% end
