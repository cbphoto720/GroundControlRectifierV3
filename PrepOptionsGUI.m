function [answers, cancelled] = PrepOptionsGUI(DefaultOptions)
    % SurveyInputGUI - Custom GUI for survey input using INPUTSDLG
    % Outputs:
    %   answers         =   Structure containing user input
    %   cancelled       =   Boolean indicating if user cancelled
    % Optional Inputs:
    %   DefaultOptions  =   .mat file that specifies GUI defaults
    
    % Handle custom defaults if specified
    if nargin<1
        DefAns = struct([]);
    elseif(exist(DefaultOptions,'file'))
        loadedPrefs = load(DefaultOptions);
        DefAns = loadedPrefs.DefAns;
    end
    
    Title = 'Survey Input GUI';
    Options.Resize = 'on';
    Options.Interpreter = 'tex';
    Options.CancelButton = 'on';
    Options.ApplyButton = 'off';
    Options.ButtonNames = {'Continue','Cancel'};
    
    Prompt = {};
    Formats = {};
    r = 1;
    c = 1;

    Prompt(1,:) = {['Global Options:'], [], []};
    Formats(r,c).type = 'text';
    Formats(r,c).size = [-1 0];
    c = c + 1;

    Prompt(end+1,:) = {['Your survey:'], [], []};
    Formats(r,c).type = 'text';
    Formats(r,c).size = [-1 0];
    r = r + 1;
    c = 1;

    % Prompt(end+1,:) = {'Max Points in Set', 'MaxPoints', []};
    % Formats(r,c).type = 'edit';
    % Formats(r,c).format = 'integer';
    % Formats(r,c).limits = [1 inf]; % Must be positive integer
    % Formats(r,c).size = 50;
    % if isfield(DefAns, 'MaxPoints')
    %     % Formats(r,c).defAns = DefAns.MaxPoints; % Use saved preference if available
    % else
    %     DefAns(1).MaxPoints = 5; % Default value
    % end
    c = c + 1;

    Prompt(end+1,:) = {'Date of Survey (YYYYMMDD)', 'SurveyDate', []};
    Formats(r,c).type = 'edit';
    Formats(r,c).format = 'text';
    Formats(r,c).size = 100;
    if ~isfield(DefAns, 'SurveyDate')
        DefAns(1).SurveyDate = char(datetime('now', 'Format', 'yyyyMMdd')); % Default to today's date
    end
    r = r + 1;
    c = 1;

    Prompt(end+1,:) = {'Camera Database File', 'CameraDB', []};
    Formats(r,c).type = 'edit';
    Formats(r,c).format = 'file';
    Formats(r,c).items = {'*.yaml;*.yml','YAML file';'*.*','All Files'};
    Formats(r,c).limits = [0 1]; % Single file selection
    Formats(r,c).size = [-1 0];
    if isfield(DefAns, 'CameraDB')
        % Formats(r,c).defAns = DefAns.CameraDB; % Use saved preference if available
    else
        DefAns.CameraDB = ''; % Default to empty
    end
    c = c + 1;

    Prompt(end+1,:) = {'GPS Survey File', 'GPSSurveyFile', []};
    Formats(r,c).type = 'edit';
    Formats(r,c).format = 'file';
    Formats(r,c).items = {'*.txt;*.csv','Text/CSV Files';'*.*','All Files'};
    Formats(r,c).limits = [0 1]; % Single file selection
    Formats(r,c).size = [-1 0];
    if ~isfield(DefAns, 'GPSSurveyFile')
        DefAns.GPSSurveyFile = ''; % Default to empty
    end
    r = r + 1;
    c = 1;

    Prompt(end+1,:) = {'Usable Images Folder', 'UsableIMGsFolder', []};
    Formats(r,c).type = 'edit';
    Formats(r,c).format = 'dir';
    Formats(r,c).size = [-1 0];
    Formats(r,c).span = [1 2]; % Spanning across columns
    if ~isfield(DefAns, 'OutputFolder')
        DefAns.OutputFolder = pwd; % Default to current directory
    end
    if ~isfield(DefAns, 'UsableIMGsFolder')
        DefAns.UsableIMGsFolder = ''; % Default to empty
    end
    r = r + 1;
    c = 1;

    % EXPORTS
    r = r + 2; % Extra space

    Prompt(end+1,:) = {['Outputs'], [], []};
    Formats(r,c).type = 'text';
    Formats(r,c).size = [-1 0];
    Formats(r,c).span = [1 2];
    r = r + 1;

    Prompt(end+1,:) = {'Output Folder Path', 'OutputFolder', []};
    Formats(r,c).type = 'edit';
    Formats(r,c).format = 'dir';
    Formats(r,c).size = [-1 0];
    Formats(r,c).span = [1 2]; % Spanning across columns
    if ~isfield(DefAns, 'OutputFolder')
        DefAns.OutputFolder = pwd; % Default to current directory
    end
    r = r + 1;

    Prompt(end+1,:) = {'Output Folder Name', 'OutputFolderName', []};
    Formats(r,c).type = 'edit';
    Formats(r,c).format = 'text';
    Formats(r,c).size = [-1 0];
    Formats(r,c).span = [1 2]; % Spanning across columns
    if ~isfield(DefAns, 'OutputFolderName')
        DefAns.OutputFolderName = strcat(sprintf('%s',datetime(now(),'convertfrom','datenum','Format','yyyyMMdd')),'_GCPpickerOutput'); % Default to current directory
    end
    r = r + 1;

    Prompt(end+1,:) = {'Set these options as defaults for next time','SetOptAsDefault', []};
    Formats(r,2).type = 'check';
    if ~isfield(DefAns, 'SetOptAsDefault')
        DefAns.SetOptAsDefault = true; % Default to true
    end

    % Run INPUTSDLG
    [answers, cancelled] = inputsdlg(Prompt, Title, Formats, DefAns, Options);
    
    if ~cancelled
        addpath(answers.OutputFolder);
        mkdir(fullfile(answers.OutputFolder,answers.OutputFolderName))
    end
end
