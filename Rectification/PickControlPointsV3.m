% PickControlPointsV3()
% =========================================================================
% Version 3, 11/15/2017
% 
% This program was designed to aid in the selection of ground control
% points from video imagry of a moving, GPS equipped vessel. Image data
% must be GPS time stamped.
% 
% Once ground control points are selected, camera extrinsic parameters can
% be computed using the CIRN/Argus rectification method.
% 
% Inputs
%   1) UTC file that contains a list of image frames and their GPS time
%      stamps.
%   2) images taken during the survey.  Images must have the same name as
%      the UTC file, with the fram number appended.
%   3)The survey file with x, y, z, and time of the survey vessels GPS
%     antenna
% 
% Version History:
%     1) 12/23/2016: Original
%     2) 10/08/2017: Version 2
%           - Added ability to handle different resolution cameras
%             and optical cameras. New cameras can be added by hardcodinng 
%             the new parameters into lOADUTC.m and SelectLoadFiles.m
%     3) 11/15/2017: Version 3
%           - Made stepping through images and picking control points a
%             little more robust.
%           - changed LoadSurvey to take a standard input file format.
%             Seperate programs are now used to take various survey file
%             formats and turn them into the correct input format for
%             PickControlPointsV3 (see FRFRawSurvey2PCP.m, FRFSurvey2PCP,
%             and PvlabSurvey2PCP.m)
%           - Totally redid the rectification side of the program.  The
%             program now uses CIRN/Argus method for getting the camera
%             extrinsic parameters from the GCPs.
% 
% Wish List:
%     Note: The listed changes should fall under a working Version 4
%     1) edit getXYZfromUV.m to the latest version, with the more robust
%        horizon finding algorithm.
%     2) After rectification, plot the estimated horizon on the image.
%     3) Change plotting after rectification to no longer use the
%        interpolation method.
%     4) Change rectification save to include just the camera extrinsics
%        and possibly other vital info.
%     5) Add the ability to not have a camera calibration
%     6) make a save file viewer that lets you view and edit save files
%        for easier changes to work you ahve already done.
% =========================================================================

function PickControlPointsV3()

    
    set(0, 'Units', 'character');
    screenSize = get(0, 'ScreenSize');
    ssW = screenSize(3);
    ssH = screenSize(4);

    %% Set GUI data structures (GUIColor, figData, points, rectParams)
    % ===============================================================
    GUIColors = struct('Figure', [0.082 0.086 0.106],...
                       'Axes', [0.157 0.188 0.29],...
                       'LowerPanel', [0.145 0.267 0.51],...
                       'LowerHighlight', [0.6 0.6 0.6],...
                       'LowerShadow', [0.157 0.188 0.29],...
                       'UpperPanel', [0.145 0.267 0.51],...
                       'UpperHighlight', [0.7 0.7 0.7],...
                       'UpperShadow', [0.063 0.137 0.278],...
                       'ButtonColor', [0.082 0.086 0.106],...
                       'Textbox', [0.42 0.584 0.91],...
                       'TextEdge', [0.7 0.7 0.7],...
                       'Text', [1.0 0.973 0]);

    figdata = struct('CurrentInd',1, 'ChangeFlag', 0,...
                     'PauseFlag',0, 'FrameStep', [],...
                     'AlreadyRunning',0, 'XCP',512, 'YCP',384,...
                     'ImWidth', 1024, 'ImHeight', 768,...
                     'XCPDefault',512, 'YCPDefault',384,...
                     'CameraSelectVal', 1, 'CameraSelectStr', '',...
                     'FrameRate', 30, 'BitDepth', 14, 'CameraType', 'IR',...
                     'CurrentImageSet',[], 'SavePath', [],...
                     'RectificationIteration', 100);
    
    points = struct();
    rectParams = struct('X', [], 'Y', [], 'Z', [], 'Pitch', [], 'Roll', [],...
                        'Azimuth', [], 'Fx', [], 'Fy', [], 'Xp', [],...
                        'Yp', [], 'D1', [], 'D2', [], 'D3', [],...
                        'T1', [], 'T2', [], 'Alpha', [], 'Nx', [], 'Ny', [],...
                        'XPose', [], 'YPose', [], 'ZPose', [], 'PitchPose', [], ...
                        'RollPose', [], 'AzimuthPose', [],...
                        'XRect', [], 'YRect', [], 'ZRect', [], 'ImRect', [],...
                        'XRectLims', [], 'YRectLims', [], 'ZRectLims', []);

    %% Set main GUI figure and axes
    % ============================
    hfig = figure('Units', 'normalized',...
                  'OuterPosition', [0.025 0.1 0.95 0.85],...
                  'DockControls', 'off',...
                  'MenuBar', 'none',...
                  'ToolBar', 'none',...
                  'NumberTitle', 'off',...
                  'Name', 'Point Picker 1.0',...
                  'Color', GUIColors.Figure,...
                  'Visible', 'off',...
                  'CloseRequestFcn', @SAVE,...
                  'SizeChangedFcn', @ADJUSTFIGURE);
              
    haxes = axes('Parent', hfig,...
                 'Units', 'normalized',...
                 'Position', [0.03 0.1 0.6 0.8],...
                 'Color',GUIColors.Axes,...
                 'XColorMode', 'manual',...
                 'XColor', GUIColors.Figure,...
                 'XTickMode', 'manual',...
                 'XTick', [],...
                 'XLim',[0 figdata.ImWidth],...
                 'YColorMode', 'manual',...
                 'YColor', GUIColors.Figure,...
                 'YTickMode', 'manual',...
                 'YTick', [],...
                 'YDir','reverse',...
                 'YLim',[0 figdata.ImHeight],...
                 'CLimMode','Manual',...
                 'CLim',[0 2^figdata.BitDepth],...
                 'NextPlot', 'replacechildren',...
                 'HitTest','off',...
                 'ButtonDownFcn',@ZOOMCENTER);
           
    hzoom = axes('Parent', hfig,...
                 'Units', 'normalized',...
                 'Position', [0.65 0.545 0.2 0.35],...
                 'Color',GUIColors.Axes,...
                 'XColorMode', 'manual',...
                 'XColor', GUIColors.Figure,...
                 'XTickMode', 'manual',...
                 'XTick',[],...
                 'YColorMode', 'manual',...
                 'YColor', GUIColors.Figure,...
                 'YTickMode', 'manual',...
                 'YTick',[],...
                 'YDir','reverse',...
                 'CLimMode','Manual',...
                 'CLim',[0 2^figdata.BitDepth],...
                 'NextPlot', 'replacechildren',...
                 'HitTest','off',...
                 'ButtonDownFcn',@GETPIXEL);
                   
    hSlider = uicontrol(hfig, 'Style', 'slider',...
                              'Units', 'normalized',...
                              'String', 'Test',...
                              'Position', [0.65 0.525 0.2 0.03],...
                              'BackgroundColor', GUIColors.ButtonColor,...
                              'Min', 10,...
                              'Max', 100,...
                              'Value', 55,...
                              'SliderStep', [0.02 0.02],...
                              'Enable', 'off');
                          
    addlistener(hSlider, 'Value', 'PreSet', @ZOOMSLIDER);
                   
    colormap(haxes,bone(256));
    colormap(hzoom,bone(256));
    
    %% Dimensions in characters
    figSize = hfig.Position;
    figWidth = figSize(3).*ssW;
    figHeight = figSize(4).*ssH;
    upperBarHeight = 2.75;
    upperBtnHeight = 2;
    upperBtnWidth = 24;
    upperBtnOffset = 3;
    upperDropdownHeight = 2;
    upperDropdownWidth = 45;
    upperTxtHeight = 2;
    upperTxtWidth = 40;
    lowerBarHeight = 2.75;
    playBtnHeight = 2;
    playBtnWidth = 10;
    playBtnOffset = 2;
    stepBtnHeight = 2;
    stepBtnWidth = 12;
    stepBtnOffset = 2;
    sideBarWidth = 28;
    sideTxtWidth = 26;
    sideTxtHeight = 1.6;
    sideTxtOffset = 0.4;
    sideBtnHeight = 2;
    sideBtnWidth = 22;
    sideBtnOffset = 0.5;
    plotAxesVertOffset = 1.5;
    plotAxesHorOffset = 4;
    zoomAxesVertOffset = 1.5;
    zoomAxesHorOffset = 5;
    sliderHeight = 1.5;
    sliderOffset = 1;
    
    % Dimensions in normalized
    loadPanelWidth = 0.535;
   
    %%  Load and Save Button Group
    % =============================        
    hpanLoad = uipanel(hfig, 'Position', [0 ... % left
                                         (1-(upperBarHeight/figHeight))... % bottom
                                          loadPanelWidth... % width
                                         (upperBarHeight/figHeight)],... % height; old = [0 0.95 0.6 0.05]
                             'BackgroundColor', GUIColors.LowerPanel,...
                             'BorderWidth', 1,...
                             'HighlightColor', GUIColors.LowerHighlight,...
                             'ShadowColor', GUIColors.LowerShadow);
    
      loadRawBtn = uicontrol(hpanLoad, 'Style', 'pushbutton',...
                                       'String', 'Load Raw',...
                                       'Units', 'normalized',...
                                       'Position', [(upperBtnOffset/figWidth)/loadPanelWidth... % left
                                                   ((upperBarHeight-upperBtnHeight)/2)/upperBarHeight... % bottom
                                                   (upperBtnWidth/figWidth)/loadPanelWidth... % width
                                                   upperBtnHeight/upperBarHeight],... % height; old = [0.02 0.1 0.176 0.8]
                                       'FontWeight', 'bold',...
                                       'BackgroundColor', GUIColors.ButtonColor,...
                                       'ForegroundColor', GUIColors.Text,...
                                       'CallBack', @LOADUTC);
                                   
      loadMatBtn = uicontrol(hpanLoad, 'Style', 'pushbutton',...
                                       'String', 'Load Saved',...
                                       'Units', 'normalized',...
                                       'Position', [loadRawBtn.Position(1)+loadRawBtn.Position(3)+(upperBtnOffset/figWidth)/loadPanelWidth... % left
                                                    ((upperBarHeight-upperBtnHeight)/2)/upperBarHeight... % bottom
                                                    (upperBtnWidth/figWidth)/loadPanelWidth... % width
                                                    upperBtnHeight/upperBarHeight],... % height; old = [0.216 0.1 0.176 0.8]
                                       'FontWeight', 'bold',...
                                       'BackgroundColor', GUIColors.ButtonColor,...
                                       'ForegroundColor', GUIColors.Text,...
                                       'CallBack', @LOADMAT);
                                
      saveBtn = uicontrol(hpanLoad, 'Style', 'pushbutton',...
                                    'String', 'Save',...
                                    'Units', 'normalized',...
                                    'Position', [loadMatBtn.Position(1)+loadMatBtn.Position(3)+(upperBtnOffset/figWidth)/loadPanelWidth... % left
                                                 ((upperBarHeight-upperBtnHeight)/2)/upperBarHeight... % bottom
                                                 (upperBtnWidth/figWidth)/loadPanelWidth... % width
                                                 upperBtnHeight/upperBarHeight],... % height; old = [0.412 0.1 0.176 0.8]
                                    'FontWeight', 'bold',...
                                    'BackgroundColor', GUIColors.ButtonColor,...
                                    'ForegroundColor', GUIColors.Text,...
                                    'Enable', 'off',...
                                    'Callback', @SAVE);
                                
      saveasBtn = uicontrol(hpanLoad, 'Style', 'pushbutton',...
                                      'String', 'Save As',...
                                      'Units', 'normalized',...
                                      'Position', [saveBtn.Position(1)+saveBtn.Position(3)+(upperBtnOffset/figWidth)/loadPanelWidth... % left
                                                   ((upperBarHeight-upperBtnHeight)/2)/upperBarHeight... % bottom
                                                   (upperBtnWidth/figWidth)/loadPanelWidth... % width
                                                   upperBtnHeight/upperBarHeight],... % height; old = [0.608 0.1 0.176 0.8]
                                      'FontWeight', 'bold',...
                                      'BackgroundColor', GUIColors.ButtonColor,...
                                      'ForegroundColor', GUIColors.Text,...
                                      'Enable', 'off',...
                                      'Callback', @SAVE);
                                  
      exportBtn = uicontrol(hpanLoad, 'Style', 'pushbutton',...
                                      'String', 'Export',...
                                      'Units', 'normalized',...
                                      'Position', [saveasBtn.Position(1)+saveasBtn.Position(3)+(upperBtnOffset/figWidth)/loadPanelWidth... % left
                                                   ((upperBarHeight-upperBtnHeight)/2)/upperBarHeight... % bottom
                                                   (upperBtnWidth/figWidth)/loadPanelWidth... % width
                                                   upperBtnHeight/upperBarHeight],... % height; old = [0.804 0.1 0.176 0.8]
                                      'FontWeight', 'bold',...
                                      'BackgroundColor', GUIColors.ButtonColor,...
                                      'ForegroundColor', GUIColors.Text,...
                                      'Enable', 'off',...
                                      'Callback', @EXPORT);
                                  
    %%  Play button group
    % ========================
    hpanPlay = uipanel(hfig, 'Units', 'normalized', ...
                             'Position', [0.0... % left
                                          0.0... % bottom
                                          0.3... % width
                                          lowerBarHeight/figHeight],... % height; old = [0.0 0.0 0.3 0.05]
                             'BackgroundColor', GUIColors.LowerPanel,...
                             'BorderWidth', 1,...
                             'HighlightColor', GUIColors.LowerHighlight,...
                             'ShadowColor', GUIColors.LowerShadow);
                         
      playBtn = uicontrol(hpanPlay, 'Style', 'pushbutton',...
                                    'String', '>',...
                                    'Units', 'normalized',...
                                    'Position', [0.5-(playBtnOffset/2+playBtnWidth)/0.3/figWidth... % left
                                                 ((lowerBarHeight-playBtnHeight)/2)/lowerBarHeight... % bottom
                                                 (playBtnWidth/figWidth)/0.3... % width
                                                 playBtnHeight/lowerBarHeight],... % height; old = [0.375 0.1 0.1 0.8]
                                    'FontWeight', 'bold',...
                                    'BackgroundColor', GUIColors.ButtonColor,...
                                    'ForegroundColor', GUIColors.Text,...
                                    'Enable', 'off',...
                                    'Interruptible', 'on',...
                                    'CallBack', @PLAY);
    
      pauseBtn = uicontrol (hpanPlay, 'Style', 'pushbutton',...
                                      'String', '||',...
                                      'Units', 'normalized',...
                                      'Position', [0.5+(playBtnOffset/2)/0.3/figWidth... % left
                                                   ((lowerBarHeight-playBtnHeight)/2)/lowerBarHeight... % bottom
                                                   (playBtnWidth/figWidth)/0.3... % width
                                                   playBtnHeight/lowerBarHeight],... % height
                                      'FontWeight', 'bold',...
                                      'BackgroundColor', GUIColors.ButtonColor,...
                                      'ForegroundColor', GUIColors.Text,...
                                      'Enable', 'off',...
                                      'CallBack', @PAUSE);
    
      ffBtn = uicontrol (hpanPlay, 'Style', 'pushbutton',...
                                   'String', '>>',...
                                   'Units', 'normalized',...
                                   'Position', [0.5+(playBtnOffset*3/2+playBtnWidth)/0.3/figWidth... % left
                                                ((lowerBarHeight-playBtnHeight)/2)/lowerBarHeight... % bottom
                                                (playBtnWidth/figWidth)/0.3... % width
                                                playBtnHeight/lowerBarHeight],... % height
                                   'FontWeight', 'bold',...
                                   'BackgroundColor', GUIColors.ButtonColor,...
                                   'ForegroundColor', GUIColors.Text,...
                                   'Enable', 'off',...
                                   'CallBack', @PLAY);
                               
      rwBtn = uicontrol (hpanPlay, 'Style', 'pushbutton',...
                                   'String', '<<',...
                                   'Units', 'normalized',...
                                   'Position', [0.5-(playBtnOffset*3/2+playBtnWidth*2)/0.3/figWidth... % left
                                                ((lowerBarHeight-playBtnHeight)/2)/lowerBarHeight... % bottom
                                                (playBtnWidth/figWidth)/0.3... % width
                                                playBtnHeight/lowerBarHeight],... % height
                                   'FontWeight', 'bold',...
                                   'BackgroundColor', GUIColors.ButtonColor,...
                                   'ForegroundColor', GUIColors.Text,...
                                   'Enable', 'off',...
                                   'CallBack', @PLAY);
   
    %% Step button group
    % =================
    hpanStep = uipanel(hfig, 'Units', 'normalized',...
                             'Position', [0.3... % left
                                          0.0... % bottom
                                          0.7... % width
                                          lowerBarHeight/figHeight],... % height; old = [0.3 0.0 0.7 0.05]
                             'BackgroundColor', GUIColors.LowerPanel,...
                             'BorderWidth', 1,...
                             'HighlightColor', GUIColors.LowerHighlight,...
                             'ForegroundColor', GUIColors.Text,...
                             'ShadowColor', GUIColors.LowerShadow);
    
      stepb1Btn = uicontrol (hpanStep, 'Style', 'pushbutton',...
                                       'String', '< 1',...
                                       'Units', 'normalized',...
                                       'Position', [0.5-(stepBtnOffset/2+stepBtnWidth)/0.7/figWidth... % left
                                                    ((lowerBarHeight-stepBtnHeight)/2)/lowerBarHeight... % bottom
                                                    (stepBtnWidth/figWidth)/0.7... % width
                                                    playBtnHeight/lowerBarHeight],... % height
                                       'FontWeight', 'bold',...
                                       'BackgroundColor', GUIColors.ButtonColor,...
                                       'ForegroundColor', GUIColors.Text,...
                                       'Enable', 'off',...
                                       'Callback', @STEP);
    
      stepf1Btn = uicontrol (hpanStep, 'Style', 'pushbutton',...
                                       'String', '1 >',...
                                       'Units', 'normalized',...
                                       'Position', [0.5+(stepBtnOffset/2)/0.7/figWidth... % left
                                                    ((lowerBarHeight-stepBtnHeight)/2)/lowerBarHeight... % bottom
                                                    (stepBtnWidth/figWidth)/0.7... % width
                                                    playBtnHeight/lowerBarHeight],... % height
                                       'FontWeight', 'bold',...
                                       'BackgroundColor', GUIColors.ButtonColor,...
                                       'ForegroundColor', GUIColors.Text,...
                                       'Enable', 'off',...
                                       'Callback', @STEP);
    
      stepf10Btn = uicontrol (hpanStep, 'Style', 'pushbutton',...
                                        'String', '10 >',...
                                        'Units', 'normalized',...
                                        'Position', [0.5+(stepBtnOffset*3/2+stepBtnWidth)/0.7/figWidth... % left
                                                     ((lowerBarHeight-stepBtnHeight)/2)/lowerBarHeight... % bottom
                                                     (stepBtnWidth/figWidth)/0.7... % width
                                                     playBtnHeight/lowerBarHeight],... % height
                                        'FontWeight', 'bold',...
                                        'BackgroundColor', GUIColors.ButtonColor,...
                                        'ForegroundColor', GUIColors.Text,...
                                        'Enable', 'off',...
                                        'Callback', @STEP);
    
      stepb10Btn = uicontrol (hpanStep, 'Style', 'pushbutton',...
                                        'String', '< 10',...
                                        'Units', 'normalized',...
                                        'Position', [0.5-(stepBtnOffset*3/2+2*stepBtnWidth)/0.7/figWidth... % left
                                                     ((lowerBarHeight-stepBtnHeight)/2)/lowerBarHeight... % bottom
                                                     (stepBtnWidth/figWidth)/0.7... % width
                                                     playBtnHeight/lowerBarHeight],... % height
                                        'FontWeight', 'bold',...
                                        'BackgroundColor', GUIColors.ButtonColor,...
                                        'ForegroundColor', GUIColors.Text,...
                                        'Enable', 'off',...
                                        'Callback', @STEP);
                                    
      stepf100Btn = uicontrol (hpanStep, 'Style', 'pushbutton',...
                                        'String', '100 >',...
                                        'Units', 'normalized',...
                                        'Position', [0.5+(stepBtnOffset*5/2+2*stepBtnWidth)/0.7/figWidth... % left
                                                     ((lowerBarHeight-stepBtnHeight)/2)/lowerBarHeight... % bottom
                                                     (stepBtnWidth/figWidth)/0.7... % width
                                                     playBtnHeight/lowerBarHeight],... % height
                                        'FontWeight', 'bold',...
                                        'BackgroundColor', GUIColors.ButtonColor,...
                                        'ForegroundColor', GUIColors.Text,...
                                        'Enable', 'off',...
                                        'Callback', @STEP);
    
      stepb100Btn = uicontrol (hpanStep, 'Style', 'pushbutton',...
                                        'String', '< 100',...
                                        'Units', 'normalized',...
                                        'Position', [0.5-(stepBtnOffset*5/2+3*stepBtnWidth)/0.7/figWidth... % left
                                                     ((lowerBarHeight-stepBtnHeight)/2)/lowerBarHeight... % bottom
                                                     (stepBtnWidth/figWidth)/0.7... % width
                                                     playBtnHeight/lowerBarHeight],... % height
                                        'FontWeight', 'bold',...
                                        'BackgroundColor', GUIColors.ButtonColor,...
                                        'ForegroundColor', GUIColors.Text,...
                                        'Enable', 'off',...
                                        'Callback', @STEP);
                                    
      previousBtn = uicontrol (hpanStep, 'Style', 'pushbutton',...
                                         'String', 'Previous',...
                                         'Units', 'normalized',...
                                         'Position', [0.5-(stepBtnOffset*7/2+4*stepBtnWidth)/0.7/figWidth... % left
                                                      ((lowerBarHeight-stepBtnHeight)/2)/lowerBarHeight... % bottom
                                                      (stepBtnWidth/figWidth)/0.7... % width
                                                      playBtnHeight/lowerBarHeight],... % height
                                         'FontWeight', 'bold',...
                                         'BackgroundColor', GUIColors.ButtonColor,...
                                         'ForegroundColor', GUIColors.Text,...
                                         'Enable', 'off',...
                                         'Callback', @STEP);
    
      nextBtn = uicontrol (hpanStep, 'Style', 'pushbutton',...
                                     'String', 'Next',...
                                     'Units', 'normalized',...
                                     'Position', [0.5+(stepBtnOffset*7/2+3*stepBtnWidth)/0.7/figWidth... % left
                                                  ((lowerBarHeight-stepBtnHeight)/2)/lowerBarHeight... % bottom
                                                  (stepBtnWidth/figWidth)/0.7... % width
                                                  playBtnHeight/lowerBarHeight],... % height
                                     'FontWeight', 'bold',...
                                     'BackgroundColor', GUIColors.ButtonColor,...
                                     'ForegroundColor', GUIColors.Text,...
                                     'Enable', 'off',...
                                     'Callback', @STEP);
    
      startBtn = uicontrol (hpanStep, 'Style', 'pushbutton',...
                                      'String', 'Start',...
                                      'Units', 'normalized',...
                                      'Position', [0.5-(stepBtnOffset*9/2+5*stepBtnWidth)/0.7/figWidth... % left
                                                   ((lowerBarHeight-stepBtnHeight)/2)/lowerBarHeight... % bottom
                                                   (stepBtnWidth/figWidth)/0.7... % width
                                                   playBtnHeight/lowerBarHeight],... % height
                                      'FontWeight', 'bold',...
                                      'BackgroundColor', GUIColors.ButtonColor,...
                                      'ForegroundColor', GUIColors.Text,...
                                      'Enable', 'off',...
                                      'Callback', @STEP);
    
      endBtn = uicontrol (hpanStep, 'Style', 'pushbutton',...
                                    'String', 'End',...
                                    'Units', 'normalized',...
                                    'Position', [0.0... % left
                                                 ((lowerBarHeight-stepBtnHeight)/2)/lowerBarHeight... % bottom
                                                 (stepBtnWidth/figWidth)/0.7... % width
                                                 playBtnHeight/lowerBarHeight],... % height
                                    'FontWeight', 'bold',...
                                    'BackgroundColor', GUIColors.ButtonColor,...
                                    'ForegroundColor', GUIColors.Text,...
                                    'Enable', 'off',...
                                    'Callback', @STEP);
                               
    %% Set Files Panel
    % =================
    hpanFile = uipanel(hfig, 'Position', [loadPanelWidth... % left
                                          (1-(upperBarHeight/figHeight))... % bottom
                                          (1-loadPanelWidth)... % width
                                          (upperBarHeight/figHeight)],... % height; old = [0.6 0.95 0.4 0.05]
                             'BackgroundColor', GUIColors.UpperPanel,...
                             'BorderWidth', 1,...
                             'HighlightColor', GUIColors.UpperHighlight,...
                             'ShadowColor', GUIColors.UpperShadow);
    
      setSelect = uicontrol(hpanFile, 'Style', 'popupmenu',...
                                      'String', ' ',...
                                      'Units', 'normalized',...
                                      'BackgroundColor', GUIColors.ButtonColor,...
                                      'ForegroundColor', GUIColors.Text,...
                                      'Position', [(upperBtnOffset/figWidth)/(1-loadPanelWidth)... % left
                                                   ((upperBarHeight-upperDropdownHeight)/2)/upperBarHeight... % bottom
                                                   (upperDropdownWidth/figWidth)/(1-loadPanelWidth)... % width
                                                   upperBtnHeight/upperBarHeight],.... % height; old = [0.05 0.0 0.425 0.8]
                                      'Enable', 'off',...
                                      'Callback', @SETSELECT);
                                
      setSurvey = annotation(hpanFile, 'textbox',...
                                       'LineStyle', '-',...
                                       'String', ' ',...
                                       'FontSize', 10,...
                                       'Interpreter', 'none',...
                                       'BackgroundColor', GUIColors.Textbox,...
                                       'EdgeColor', GUIColors.TextEdge,...
                                       'Units', 'normalized',...
                                       'HorizontalAlignment','left',...
                                       'VerticalAlignment','middle',...
                                       'Position', [setSelect.Position(1)+setSelect.Position(3)+(upperBtnOffset/figWidth)/(1-loadPanelWidth)... % left
                                                    ((upperBarHeight-upperTxtHeight)/2)/upperBarHeight... % bottom
                                                    (upperTxtWidth/figWidth)/(1-loadPanelWidth)... % width
                                                    upperTxtHeight/upperBarHeight]); % height; old = [0.525 0.2 0.425 0.6]
    
      removeSetBtn = uicontrol(hpanFile, 'Style', 'pushbutton',...
                                         'String', 'Remove Set',...
                                         'Units', 'normalized',...
                                         'Position', [setSurvey.Position(1)+setSurvey.Position(3)+(upperBtnOffset/figWidth)/(1-loadPanelWidth)... % left
                                                     ((upperBarHeight-upperBtnHeight)/2)/upperBarHeight... % bottom
                                                     (upperBtnWidth/figWidth)/(1-loadPanelWidth)... % width
                                                     upperBtnHeight/upperBarHeight],... % height;
                                         'FontWeight', 'bold',...
                                         'BackgroundColor', GUIColors.ButtonColor,...
                                         'ForegroundColor', GUIColors.Text,...
                                         'Enable', 'off',...
                                         'Callback', @REMOVESET);
                                   
    %% Display Pixel Points
    % ====================
    hpanImagePoint = uipanel(hfig, 'Position', [1-(sideBarWidth/figWidth)... % left
                                                ((hpanLoad.Position(2)-hpanPlay.Position(4))/2)+hpanPlay.Position(4)... % bottom
                                                sideBarWidth/figWidth... % width
                                                (hpanLoad.Position(2)-hpanPlay.Position(4))/2],... % height; ld = [0.9 0.5 0.1 0.45]
                                   'Title', 'Image Points',...
                                   'FontWeight', 'bold',...
                                   'BackgroundColor', GUIColors.UpperPanel,...
                                   'BorderWidth', 1,...
                                   'HighlightColor', GUIColors.UpperHighlight,...
                                   'ShadowColor', GUIColors.UpperShadow);
      
      frameText = annotation(hpanImagePoint, 'textbox',...
                                             'LineStyle', '-',...
                                             'String', ' ',...
                                             'FontSize', 10,...
                                             'BackgroundColor', GUIColors.Textbox,...
                                             'EdgeColor', GUIColors.TextEdge,...
                                             'Units', 'normalized',...
                                             'HorizontalAlignment','left',...
                                             'VerticalAlignment','middle',...
                                             'Position', [((sideBarWidth-sideTxtWidth)/2)/sideBarWidth... % left
                                                          1-(sideTxtOffset+sideTxtHeight)/((hpanLoad.Position(2)-hpanPlay.Position(4)).*figHeight/2)... % bottom
                                                          sideTxtWidth/sideBarWidth... % width
                                                          sideTxtHeight/((hpanLoad.Position(2)-hpanPlay.Position(4)).*figHeight/2)]); % height; old = [0.02 0.905 0.96 0.075]
                                         
      utcTimeText = annotation(hpanImagePoint, 'textbox',...
                                               'LineStyle', '-',...
                                               'String', '',...
                                               'FontSize', 10,...
                                               'BackgroundColor', GUIColors.Textbox,...
                                               'EdgeColor', GUIColors.TextEdge,...
                                               'Units', 'normalized',...
                                               'HorizontalAlignment','left',...
                                               'VerticalAlignment','middle',...
                                               'Position', [((sideBarWidth-sideTxtWidth)/2)/sideBarWidth... % left
                                                            1-2*(sideTxtOffset+sideTxtHeight)/((hpanLoad.Position(2)-hpanPlay.Position(4)).*figHeight/2)... % bottom
                                                            sideTxtWidth/sideBarWidth... % width
                                                            sideTxtHeight/((hpanLoad.Position(2)-hpanPlay.Position(4)).*figHeight/2)]); % height; old = [0.02 0.81 0.96 0.075]
    
      xText = annotation(hpanImagePoint, 'textbox',...
                                         'LineStyle', '-',...
                                         'String', 'x = ',...
                                         'FontSize', 10,...
                                         'BackgroundColor', GUIColors.Textbox,...
                                         'EdgeColor', GUIColors.TextEdge,...
                                         'Units', 'normalized',...
                                         'HorizontalAlignment','left',...
                                         'VerticalAlignment','middle',...
                                         'Position', [((sideBarWidth-sideTxtWidth)/2)/sideBarWidth... % left
                                                      1-3*(sideTxtOffset+sideTxtHeight)/((hpanLoad.Position(2)-hpanPlay.Position(4)).*figHeight/2)... % bottom
                                                      sideTxtWidth/sideBarWidth... % width
                                                      sideTxtHeight/((hpanLoad.Position(2)-hpanPlay.Position(4)).*figHeight/2)]); % height; old = [0.02 0.715 0.96 0.075]
                                
      yText = annotation(hpanImagePoint, 'textbox',...
                                         'LineStyle', '-',...
                                         'String', 'y = ',...
                                         'FontSize', 10,...
                                         'BackgroundColor', GUIColors.Textbox,...
                                         'EdgeColor', GUIColors.TextEdge,...
                                         'Units', 'normalized',...
                                         'HorizontalAlignment','left',...
                                         'VerticalAlignment','middle',...
                                         'Position', [((sideBarWidth-sideTxtWidth)/2)/sideBarWidth... % left
                                                      1-4*(sideTxtOffset+sideTxtHeight)/((hpanLoad.Position(2)-hpanPlay.Position(4)).*figHeight/2)... % bottom
                                                      sideTxtWidth/sideBarWidth... % width
                                                      sideTxtHeight/((hpanLoad.Position(2)-hpanPlay.Position(4)).*figHeight/2)]); % height; old = [0.02 0.62 096 0.075]
                                     
      hRemove = uicontrol (hpanImagePoint, 'Style', 'pushbutton',...
                                           'String', 'Remove',...
                                           'Units', 'normalized',...
                                           'Position', [((sideBarWidth-sideBtnWidth)/2)/sideBarWidth... % left
                                                        (yText.Position(2)/2)+(sideBtnHeight/2+sideBtnOffset)/((hpanLoad.Position(2)-hpanPlay.Position(4)).*figHeight/2)... % bottom
                                                        sideBtnWidth/sideBarWidth... % width
                                                        sideBtnHeight/((hpanLoad.Position(2)-hpanPlay.Position(4)).*figHeight/2)],... % height
                                           'FontWeight', 'bold',...
                                           'BackgroundColor', GUIColors.ButtonColor,...
                                           'ForegroundColor', GUIColors.Text,...
                                           'Enable', 'off',...
                                           'Callback', @REMOVE);
                                       
      hPlotPoints = uicontrol (hpanImagePoint, 'Style', 'pushbutton',...
                                               'String', 'Plot Points',...
                                               'Units', 'normalized',...
                                               'Position', [((sideBarWidth-sideBtnWidth)/2)/sideBarWidth... % left
                                                            (yText.Position(2)/2)-(sideBtnHeight/2)/((hpanLoad.Position(2)-hpanPlay.Position(4)).*figHeight/2)... % bottom
                                                            sideBtnWidth/sideBarWidth... % width
                                                            sideBtnHeight/((hpanLoad.Position(2)-hpanPlay.Position(4)).*figHeight/2)],... % height
                                               'FontWeight', 'bold',...
                                               'BackgroundColor', GUIColors.ButtonColor,...
                                               'ForegroundColor', GUIColors.Text,...
                                               'Enable', 'off',...
                                               'Callback', @PLOTPOINTS);
                                           
      hRectify = uicontrol (hpanImagePoint, 'Style', 'pushbutton',...
                                            'String', 'Rectify',...
                                            'Units', 'normalized',...
                                            'Position', [((sideBarWidth-sideBtnWidth)/2)/sideBarWidth... % left
                                                         (yText.Position(2)/2)-(sideBtnHeight*3/2+sideBtnOffset)/((hpanLoad.Position(2)-hpanPlay.Position(4)).*figHeight/2)... % bottom
                                                         sideBtnWidth/sideBarWidth... % width
                                                         sideBtnHeight/((hpanLoad.Position(2)-hpanPlay.Position(4)).*figHeight/2)],... % height
                                            'FontWeight', 'bold',...
                                            'BackgroundColor', GUIColors.ButtonColor,...
                                            'ForegroundColor', GUIColors.Text,...
                                            'Enable', 'off',...
                                            'Callback', @RECTIFY);
 
    %% Display Survey Points
    % =====================
    hpanSurveyPoint = uipanel(hfig, 'Position', [1-(sideBarWidth/figWidth)... % left
                                                 hpanPlay.Position(4)... % bottom
                                                 sideBarWidth/figWidth... % width
                                                 (hpanLoad.Position(2)-hpanPlay.Position(4))/2],... % height
                                    'Title', 'Survey Points',...
                                    'FontWeight', 'bold',...
                                    'BackgroundColor', GUIColors.UpperPanel,...
                                    'BorderWidth', 1,...
                                    'HighlightColor', GUIColors.UpperHighlight,...
                                    'ShadowColor', GUIColors.UpperShadow);
                               
      gpsTimeText = annotation(hpanSurveyPoint, 'textbox',...
                                                'LineStyle', '-',...
                                                'String', '',...
                                                'FontSize', 10,...
                                                'BackgroundColor', GUIColors.Textbox,...
                                                'EdgeColor', GUIColors.TextEdge,...
                                                'Units', 'normalized',...
                                                'HorizontalAlignment','left',...
                                                'VerticalAlignment','middle',...
                                                'Position', [((sideBarWidth-sideTxtWidth)/2)/sideBarWidth... % left
                                                             1-(sideTxtOffset+sideTxtHeight)/((hpanLoad.Position(2)-hpanPlay.Position(4)).*figHeight/2)... % bottom
                                                             sideTxtWidth/sideBarWidth... % width
                                                             sideTxtHeight/((hpanLoad.Position(2)-hpanPlay.Position(4)).*figHeight/2)]); % height
                                
      latText = annotation(hpanSurveyPoint, 'textbox',...
                                            'LineStyle', '-',...
                                            'String', 'lat = ',...
                                            'FontSize', 10,...
                                            'BackgroundColor', GUIColors.Textbox,...
                                            'EdgeColor', GUIColors.TextEdge,...
                                            'Units', 'normalized',...
                                            'HorizontalAlignment','left',...
                                            'VerticalAlignment','middle',...
                                            'Position', [((sideBarWidth-sideTxtWidth)/2)/sideBarWidth... % left
                                                         1-2*(sideTxtOffset+sideTxtHeight)/((hpanLoad.Position(2)-hpanPlay.Position(4)).*figHeight/2)... % bottom
                                                         sideTxtWidth/sideBarWidth... % width
                                                         sideTxtHeight/((hpanLoad.Position(2)-hpanPlay.Position(4)).*figHeight/2)]); % height
                                  
      lonText = annotation(hpanSurveyPoint, 'textbox',...
                                            'LineStyle', '-',...
                                            'String', 'lon = ',...
                                            'FontSize', 10,...
                                            'BackgroundColor', GUIColors.Textbox,...
                                            'EdgeColor', GUIColors.TextEdge,...
                                            'Units', 'normalized',...
                                            'HorizontalAlignment','left',...
                                            'VerticalAlignment','middle',...
                                            'Position', [((sideBarWidth-sideTxtWidth)/2)/sideBarWidth... % left
                                                         1-3*(sideTxtOffset+sideTxtHeight)/((hpanLoad.Position(2)-hpanPlay.Position(4)).*figHeight/2)... % bottom
                                                         sideTxtWidth/sideBarWidth... % width
                                                         sideTxtHeight/((hpanLoad.Position(2)-hpanPlay.Position(4)).*figHeight/2)]); % height
                                        
      xsText = annotation(hpanSurveyPoint, 'textbox',...
                                           'LineStyle', '-',...
                                           'String', 'x = ',...
                                           'FontSize', 10,...
                                           'BackgroundColor', GUIColors.Textbox,...
                                           'EdgeColor', GUIColors.TextEdge,...
                                           'Units', 'normalized',...
                                           'HorizontalAlignment','left',...
                                           'VerticalAlignment','middle',...
                                           'Position', [((sideBarWidth-sideTxtWidth)/2)/sideBarWidth... % left
                                                        1-4*(sideTxtOffset+sideTxtHeight)/((hpanLoad.Position(2)-hpanPlay.Position(4)).*figHeight/2)... % bottom
                                                        sideTxtWidth/sideBarWidth... % width
                                                        sideTxtHeight/((hpanLoad.Position(2)-hpanPlay.Position(4)).*figHeight/2)]); % height
                                      
      ysText = annotation(hpanSurveyPoint, 'textbox',...
                                           'LineStyle', '-',...
                                           'String', 'y = ',...
                                           'FontSize', 10,...
                                           'BackgroundColor', GUIColors.Textbox,...
                                           'EdgeColor', GUIColors.TextEdge,...
                                           'Units', 'normalized',...
                                           'HorizontalAlignment','left',...
                                           'VerticalAlignment','middle',...
                                           'Position', [((sideBarWidth-sideTxtWidth)/2)/sideBarWidth... % left
                                                        1-5*(sideTxtOffset+sideTxtHeight)/((hpanLoad.Position(2)-hpanPlay.Position(4)).*figHeight/2)... % bottom
                                                        sideTxtWidth/sideBarWidth... % width
                                                        sideTxtHeight/((hpanLoad.Position(2)-hpanPlay.Position(4)).*figHeight/2)]); % height
                                  
      zsText = annotation(hpanSurveyPoint, 'textbox',...
                                           'LineStyle', '-',...
                                           'String', 'z = ',...
                                           'FontSize', 10,...
                                           'BackgroundColor', GUIColors.Textbox,...
                                           'EdgeColor', GUIColors.TextEdge,...
                                           'Units', 'normalized',...
                                           'HorizontalAlignment','left',...
                                           'VerticalAlignment','middle',...
                                           'Position', [((sideBarWidth-sideTxtWidth)/2)/sideBarWidth... % left
                                                        1-6*(sideTxtOffset+sideTxtHeight)/((hpanLoad.Position(2)-hpanPlay.Position(4)).*figHeight/2)... % bottom
                                                        sideTxtWidth/sideBarWidth... % width
                                                        sideTxtHeight/((hpanLoad.Position(2)-hpanPlay.Position(4)).*figHeight/2)]); % height
       
    %% Set Axes and Slider Positions
    % =============================
    haxes.Position = [plotAxesHorOffset/figWidth,...
                      (plotAxesVertOffset+lowerBarHeight)/figHeight,...
                      0.6,...
                      1-(lowerBarHeight+upperBarHeight+2*plotAxesVertOffset)/figHeight];
                  
    hzoom.Position = [0.6 + (zoomAxesHorOffset+plotAxesHorOffset)/figWidth...
                      0.545...
                      1-(0.6 + (2*zoomAxesHorOffset+plotAxesHorOffset+sideBarWidth)/figWidth)...
                      1-(0.545+(zoomAxesVertOffset+upperBarHeight)/figHeight)];
                  
    hSlider.Position = [0.6 + (zoomAxesHorOffset+plotAxesHorOffset)/figWidth...
                        hzoom.Position(2)-((sliderHeight+sliderOffset)/figHeight)...
                        1-(0.6 + (2*zoomAxesHorOffset+plotAxesHorOffset+sideBarWidth)/figWidth)...
                        sliderHeight/figHeight];

    hfig.Visible = 'on';
        
    
    %% GUI Functions
    % ==============

    function LOADUTC(~, ~)
        
        loadRawBtn.Enable = 'inactive';
        
        [fileNameUTC, pathNameUTC, fileNameLLZ, pathNameLLZ, timeZone, cameraVal, cameraStr] = SelectLoadFiles();
        
        if ~isempty(fileNameUTC)
            
            % Set the time zone to use with the image set
            if strcmp(timeZone, 'Eastern Standard')
                timeZone = '-05:00';
            elseif strcmp(timeZone, 'Eastern Daylight')
                timeZone = '-04:00';
            elseif strcmp(timeZone, 'UTC')
                timeZone = '+00:00';
            end
            
            currentImageSet = ['set_' fileNameUTC(1:end-4)];
            tiffNameTemplate = [pathNameUTC fileNameUTC(1:end-4) '_'];
            
            % has the image set already been loaded?
            loadContinueFlag = 0;
            if ~any(strcmp(fieldnames(points), currentImageSet))
                loadContinueFlag = 1;
            else
                reLoadWarn = questdlg({'This data set has already been loaded.';...
                                           'Reloading will overwrite all selected points for this set'},...
                                           'Reload Data Set?', 'Continue', 'Cancel', 'Cancel'); 
                if strcmp('Continue', reLoadWarn) == 1
                    loadContinueFlag = 1;
                else
                    loadContinueFlag = 0;
                end
            end
            
            % has the camera set already been defined?
            setCameraFlag = 0;
            if loadContinueFlag == 1
                if figdata.CameraSelectVal == 1
                    setCameraFlag = 1;
                elseif cameraVal == figdata.CameraSelectVal
                else
                    camTypeWarn = questdlg({['The camera type is currently set to ' figdata.CameraSelectStr '.'];...
                                            ['Are you sure you want to change the camera type to ' cameraStr '?']},...
                                             'Change camera type?', 'Yes', 'No', 'No');
                    if strcmp('Yes', camTypeWarn)
                        setCameraFlag = 1;
                    else
                        loadContinueFlag = 0;
                    end
                end
            end
            
            % define the camera specific parameters
            if setCameraFlag == 1
                figdata.CameraSelectVal = cameraVal;
                figdata.CameraSelectStr = cameraStr;
                if cameraVal == 2 % Sofradir Atom 1024
                    figdata.ImWidth = 1024;
                    figdata.ImHeight = 768;
                    figdata.XCPDefault = 512;
                    figdata.YCPDefault = 384;
                    figdata.FrameRate = 30;
                    figdata.BitDepth = 14;
                    figdata.CameraType = 'IR';
                elseif cameraVal == 3 % Genie Nano C2590
                    figdata.ImWidth = 2592;
                    figdata.ImHeight = 2048;
                    figdata.XCPDefault = 1296;
                    figdata.YCPDefault = 1024;
                    figdata.FrameRate = 5;
                    figdata.BitDepth = 10;
                    figdata.CameraType = 'EO';
                elseif cameraVal == 4 % Genie Nano C1940
                    figdata.ImWidth = 1920;
                    figdata.ImHeight = 1200;
                    figdata.XCPDefault = 960;
                    figdata.YCPDefault = 600;
                    figdata.FrameRate = 15;
                    figdata.BitDepth = 10;
                    figdata.CameraType = 'EO';
                end
                haxes.XLim = [0 figdata.ImWidth];
                haxes.YLim = [0 figdata.ImHeight];
                haxes.CLim = [0 2^figdata.BitDepth];
                hzoom.CLim = [0 2^figdata.BitDepth];
            end
            
            %Load in the data from the survey and UTC file
            [wholeSecondFrameNum, wholeFrameDateTime, lastFrame] = FindNearestWholeSecondFrame(fileNameUTC, pathNameUTC, timeZone, figdata.FrameRate);
            [latGPS, lonGPS, XGPS, YGPS, ZGPS, dateTimeGPS] = LoadSurvey(fileNameLLZ, pathNameLLZ);
            zerothFrameStr = MakeTiffZerothString(lastFrame);
            
            % time sync the data and put it into the workspace
            if loadContinueFlag == 1
                figdata.CurrentInd = 1;
                figdata.CurrentImageSet = currentImageSet;
                points.(figdata.CurrentImageSet).file{1} = zerothFrameStr;
                points.(figdata.CurrentImageSet).file{2} = tiffNameTemplate;
                
                %           1        2        3       4    5   6  7 8 9    10
                % Points{FrameNum FrameTime XPixel YPixel Lat Lon X Y Z GPSDateTime}
                points.(figdata.CurrentImageSet).data = [];
                points.(figdata.CurrentImageSet).data =...
                        {wholeSecondFrameNum' wholeFrameDateTime NaN(length(wholeSecondFrameNum),1) ...
                        NaN(length(wholeSecondFrameNum),1) NaN(length(wholeSecondFrameNum),1) NaN(length(wholeSecondFrameNum),1) ...
                        NaN(length(wholeSecondFrameNum),1) NaN(length(wholeSecondFrameNum),1) NaN(length(wholeSecondFrameNum),1) ...
                        datetime(NaN(length(wholeSecondFrameNum),1),...
                                 NaN(length(wholeSecondFrameNum),1),...
                                 NaN(length(wholeSecondFrameNum),1),...
                                 'TimeZone', 'UTC')};
                             
                points.(figdata.CurrentImageSet).file{3} = fileNameLLZ;
                            
                dateTimeImage = dateshift(points.(figdata.CurrentImageSet).data{2},'start','second','nearest');
                
                syncInd1 = ismember(dateTimeGPS, dateTimeImage);
                dateTimeGPS = dateTimeGPS(syncInd1);
                latGPS = latGPS(syncInd1);
                lonGPS = lonGPS(syncInd1);
                XGPS = XGPS(syncInd1);
                YGPS = YGPS(syncInd1);
                ZGPS = ZGPS(syncInd1);
                
                syncInd2 = ismember(dateTimeImage, dateTimeGPS);
                points.(figdata.CurrentImageSet).data{10}(syncInd2) = dateTimeGPS;
                points.(figdata.CurrentImageSet).data{10}.TimeZone = points.(figdata.CurrentImageSet).data{2}.TimeZone;
                points.(figdata.CurrentImageSet).data{5}(syncInd2) = latGPS;
                points.(figdata.CurrentImageSet).data{6}(syncInd2) = lonGPS;
                points.(figdata.CurrentImageSet).data{7}(syncInd2) = XGPS;
                points.(figdata.CurrentImageSet).data{8}(syncInd2) = YGPS;
                points.(figdata.CurrentImageSet).data{9}(syncInd2) = ZGPS;
                
                hSyncMsg = msgbox(['Found ' num2str(length(dateTimeGPS)) ' overlapping times.'],'modal');
                uiwait(hSyncMsg)
                
                frameStr = num2str(wholeSecondFrameNum(figdata.CurrentInd));
                
                PlotTiff(frameStr);

                % set up the zooom window
                figdata.XCP = figdata.XCPDefault;
                figdata.YCP = figdata.YCPDefault;
                hSlider.Value = 55;
                PlotZoom()
                        
                SetGUIValues('LOADUTC')
            end
            
        end
        
        loadRawBtn.Enable = 'on';
        
    end

    function [utcFname, utcPname, surveyFname, surveyPname, timeZone, cameraVal, cameraString] = SelectLoadFiles()
        
        hLoadDialog = dialog('Units', 'character',...
                             'Position', [ssW/2-35   ssH/2-15 115 25],...
                             'Name', 'Load Raw Data',...
                             'WindowStyle', 'modal',...
                             'Color', GUIColors.LowerPanel,...
                             'CloseRequestFcn', @CloseDialog);
        
        % Text box and button for UTC file select
        hUtcTxt = annotation(hLoadDialog, 'textbox',...
                             'Units', 'character',...
                             'Position',[4 20 90 1.5],...
                             'BackgroundColor', GUIColors.Textbox,...
                             'HorizontalAlignment', 'center',...
                             'VerticalAlignment', 'middle',...
                             'Interpreter', 'none',...
                             'FontSize', 8,...
                             'String','Select UTC file.');
                        
        hUtcBtn = uicontrol('Parent',hLoadDialog,...
                            'Style','pushbutton',...
                            'Units', 'character',...
                            'Position',[97 20 15 1.5],...
                            'HorizontalAlignment', 'center',...
                            'ForegroundColor', GUIColors.Text,...
                            'BackgroundColor',GUIColors.ButtonColor,...
                            'String','Select File',...
                            'Callback', @SelectUTCFile);
                    
        % text box and button for survey file select
        hSurveyTxt = annotation(hLoadDialog, 'textbox',...
                                'Units', 'character',...
                                'Position',[4 17 90 1.5],...
                                'BackgroundColor', GUIColors.Textbox,...
                                'HorizontalAlignment', 'center',...
                                'VerticalAlignment', 'middle',...
                                'Interpreter', 'none',...
                                'FontSize', 8,...
                                'String','Select survey file.');
                           
        hSurveyBtn = uicontrol('Parent',hLoadDialog,...
                               'Style','pushbutton',...
                               'Units', 'character',...
                               'Position',[97 17 15 1.5],...
                               'HorizontalAlignment', 'center',...
                               'ForegroundColor', GUIColors.Text,...
                               'BackgroundColor',GUIColors.ButtonColor,...
                               'String','Select File',...
                               'Callback', @SelectSurveyFile);
                           
        % title and dropdown for image time zone select
        hUtcTmzTxt = annotation(hLoadDialog, 'textbox',...
                                             'Units', 'character',...
                                             'Position',[27.5 14 60 1.5],...
                                             'BackgroundColor', GUIColors.UpperPanel,...
                                             'LineStyle', 'none',...
                                             'Color', GUIColors.Text,...
                                             'HorizontalAlignment', 'center',...
                                             'VerticalAlignment', 'middle',...
                                             'Interpreter', 'none',...
                                             'String','Select the timezone of the images.');
                           
        hUtcTmz = uicontrol('Parent',hLoadDialog,...
                            'Style','popup',...
                            'Units', 'character',...
                            'Position',[42.5 12 30 1.5],...
                            'BackgroundColor', GUIColors.Figure,...
                            'ForegroundColor', GUIColors.Text,...
                            'String',{'Eastern Standard';'Eastern Daylight';'UTC'},...
                            'Value', 2,...
                            'Callback',@SelectTimezone);
                        
        % title and dropdown for camera type select
        hCamTypeTxt = annotation(hLoadDialog, 'textbox',...
                                              'Units', 'character',...
                                              'Position',[27.5 9 60 1.5],...
                                              'BackgroundColor', GUIColors.UpperPanel,...
                                              'LineStyle', 'none',...
                                              'Color', GUIColors.Text,...
                                              'HorizontalAlignment', 'center',...
                                              'VerticalAlignment', 'middle',...
                                              'Interpreter', 'none',...
                                              'String','Select the type of camera used.');
                                          
        hCamType = uicontrol('Parent',hLoadDialog,...
                             'Style','popup',...
                             'Units', 'character',...
                             'Position',[42.5 7 30 1.5],...
                             'BackgroundColor', GUIColors.Figure,...
                             'ForegroundColor', GUIColors.Text,...
                             'String',{'';'Sofradir Atom 1024';'Genie Nano C2590';'Genie Nano C1940'},...
                             'Value', figdata.CameraSelectVal,...
                             'Callback',@SelectCameraType);
        
        % Buttons to OK or cancel                
        hOKBtn = uicontrol('Parent',hLoadDialog,...
                           'Style','pushbutton',...
                           'Units', 'character',...
                           'Position',[43.5 2.5 12 2],...
                           'HorizontalAlignment', 'center',...
                           'ForegroundColor', GUIColors.Text,...
                           'BackgroundColor',GUIColors.ButtonColor,...
                           'String','OK',...
                           'Enable', 'off',...
                           'Callback', @ReturnDialog);
                       
        hCancelBtn = uicontrol('Parent',hLoadDialog,...
                               'Style','pushbutton',...
                               'Units', 'character',...
                               'Position',[59.5 2.5 12 2],...
                               'HorizontalAlignment', 'center',...
                               'ForegroundColor', GUIColors.Text,...
                               'BackgroundColor',GUIColors.ButtonColor,...
                               'String','Cancel',...
                               'Callback', @CloseDialog);
                        
        utcFname = '';
        utcPname = '';
        surveyFname = '';
        surveyPname = '';
        timeZone = hUtcTmz.String{hUtcTmz.Value};
        cameraVal = hCamType.Value;
        cameraString = hCamType.String{hCamType.Value};
        
        uiwait(hLoadDialog);
                           
        function SelectUTCFile(~, ~)
            
            hUtcBtn.Enable = 'inactive';
            
            [fName, pName, filterIndex] = uigetfile({'*.utc'}, 'Load Image Timing (*.UTC)');
            if filterIndex ~= 0
                if strcmpi('.utc', fName(end-3:end))
                    utcFname = fName;
                    utcPname = pName;
                    hUtcTxt.String = [utcPname utcFname];
                else
                    herror = errordlg('Selected file is not a .UTC File','File Error','modal');
                    uiwait(herror)
                end
            end
            
            if ~isempty(utcFname) && ~isempty(surveyFname) && ~isempty(cameraVal)
                hOKBtn.Enable = 'on'; 
            else
                hOKBtn.Enable = 'off'; 
            end
            
            hUtcBtn.Enable = 'on';
            
        end
        
        function SelectSurveyFile(~, ~)
            
            hSurveyBtn.Enable = 'inactive';
            
            [fName, pName, filterIndex] = uigetfile({'*.llz'}, 'Load Survey File');
                    
            if filterIndex ~= 0
                if strcmpi('.llz', fName(end-3:end))
                    surveyFname = fName;
                    surveyPname = pName;
                    hSurveyTxt.String = [surveyPname surveyFname];
                else
                    hwarn = warndlg('A survey file (.llz) was not selected.','File Error','modal');
                    uiwait(hwarn)
                end
            end
            
            if ~isempty(utcFname) && ~isempty(surveyFname) && ~isempty(cameraVal)
                hOKBtn.Enable = 'on'; 
            else
                hOKBtn.Enable = 'off'; 
            end
            
            hSurveyBtn.Enable = 'on';
            
        end
        
        function SelectTimezone(~, ~)
            hUtcTmz.Enable = 'inactive';
            timeZone = hUtcTmz.String{hUtcTmz.Value};
            hUtcTmz.Enable = 'on';
        end
        
        function SelectCameraType(~, ~)
            hCamType.Enable = 'inactive';
            cameraVal = hCamType.Value;
            cameraString = hCamType.String{hCamType.Value};
            hCamType.Enable = 'on';
            
            if ~isempty(utcFname) && ~isempty(surveyFname) && ~isempty(cameraVal)
                hOKBtn.Enable = 'on'; 
            else
                hOKBtn.Enable = 'off'; 
            end
        end
        
        function CloseDialog(~, ~)
            utcFname = '';
            utcPname = '';
            surveyFname = '';
            surveyPname = '';
            timeZone = '';
            cameraVal = [];
            cameraString = '';
            
            delete(hLoadDialog)
        end
        
        function ReturnDialog(~, ~)
            delete(hLoadDialog)
        end
        
    end

    function LOADMAT(~, ~)
        
        loadMatBtn.Enable = 'inactive';
        
        loadMatContFlag = 0;
        if isempty(fieldnames(points))
            loadMatContFlag = 1;
        else
            reLoadWarn = questdlg('Loading will overwrite the current data.',...
                                  'Load Data Set?', 'Continue', 'Cancel', 'Cancel');
            if strcmp(reLoadWarn, 'Continue')
                loadMatContFlag = 1;
            else
                loadMatContFlag = 0;
            end
        end
        
        if loadMatContFlag == 1;
            [fileNameMAT, pathNameMAT, filterIndex] = uigetfile({'*.ppp'}, 'Load Saved Points');
            if filterIndex ~= 0
                if strcmpi('.ppp', fileNameMAT(end-3:end))
                    loadedData = load([pathNameMAT fileNameMAT], '-mat');
                    points = loadedData.points;
                    rectParams = loadedData.rectParams;
                    figdata = loadedData.figdata;
                
                    %Adjust figdata back to certain default values
                    figdata.CurrentInd = 1;
                    figdata.ChangeFlag = 0;
                    figdata.PauseFlag = 0;
                    figdata.FrameStep = [];
                    figdata.AlreadyRunning = 0;
                    loadedFields = fieldnames(points);
                    figdata.CurrentImageSet = loadedFields{1};
                    frameStr = num2str(points.(figdata.CurrentImageSet).data{1}(figdata.CurrentInd));
                    figdata.SavePath = [];
                    
                    % Set the axes data
                    haxes.XLim = [0 figdata.ImWidth];
                    haxes.YLim = [0 figdata.ImHeight];
                    haxes.CLim = [0 2^figdata.BitDepth];
                    hzoom.CLim = [0 2^figdata.BitDepth];
                
                    PlotTiff(frameStr);
                
                    % setup zoom
                    figdata.XCP = figdata.XCPDefault;
                    figdata.YCP = figdata.YCPDefault;
                    hSlider.Value = 55;
                    PlotZoom()
                
                    SetGUIValues('LOADMAT')
                else
                    herror = errordlg('Selected file is not a .PPP File','File Error','modal');
                    uiwait(herror)
                end
            end
        end
        
        loadMatBtn.Enable = 'on';
    end

    function SAVE(hObject, ~)
        
        if figdata.ChangeFlag == 1 && hObject == hfig
            saveWarn = questdlg({'Changes have been made since your last save.';...
                                   'Would you like to save now?'},...
                                   'Save Data?', 'Yes', 'No', 'Cancel', 'Yes');
            if strcmp(saveWarn, 'No')
                delete(hfig);
            elseif strcmp(saveWarn, 'Yes')
                [fileNameSave, pathNameSave, filterIndex] = uiputfile({'*.ppp'}, 'Select File for Save');
                if filterIndex ~= 0
                    save([pathNameSave fileNameSave], 'figdata', 'points', 'rectParams', '-mat');
                    figdata.ChangeFlag = 0;
                    delete(hfig);
                end
            end
            
        elseif figdata.ChangeFlag == 0 && hObject == hfig
            delete(hfig)
            
        elseif hObject == saveBtn
            saveBtn.Enable = 'inactive';
            if isempty(figdata.SavePath)
                [fileNameSave, pathNameSave, filterIndex] = uiputfile({'*.ppp'}, 'Select File for Save');
                if filterIndex ~= 0
                    save([pathNameSave fileNameSave], 'figdata', 'points', 'rectParams', '-mat');
                    figdata.SavePath = [pathNameSave fileNameSave];
                    figdata.ChangeFlag = 0;
                end
            else
                save(figdata.SavePath, 'figdata', 'points', 'rectParams', '-mat');
                figdata.ChangeFlag = 0;
            end
            saveBtn.Enable = 'on';
            
        elseif hObject == saveasBtn
            saveasBtn.Enable = 'inactive';
            [fileNameSave, pathNameSave, filterIndex] = uiputfile({'*.ppp'}, 'Select File for Save');
            if filterIndex ~= 0
                save([pathNameSave fileNameSave], 'figdata', 'points', 'rectParams', '-mat');
                figdata.SavePath = [pathNameSave fileNameSave];
                figdata.ChangeFlag = 0;
            end
            saveasBtn.Enable = 'on';
            
        end
        
        
    end

    function EXPORT(~, ~)
        
        exportBtn.Enable = 'inactive';
        
        [expFile, expPath, filterIndex] = uiputfile('*.txt', 'Select File for Export');
        if filterIndex ~= 0
            fieldsExport = fieldnames(points);
            FrameNum = [];
            XPix = [];
            YPix = [];
            Lat = [];
            Lon = [];
            XGPS = [];
            YGPS = [];
            ZGPS = [];
            Time = [];
            for i = 1:length(fieldsExport)
                expInd = ~isnan(points.(fieldsExport{i}).data{3});
                FrameNum = [FrameNum; points.(fieldsExport{i}).data{1}(expInd)];
                XPix = [XPix; points.(fieldsExport{i}).data{3}(expInd)];
                YPix = [YPix; points.(fieldsExport{i}).data{4}(expInd)];
                Lat = [Lat; points.(fieldsExport{i}).data{5}(expInd)];
                Lon = [Lon; points.(fieldsExport{i}).data{6}(expInd)];
                XGPS = [XGPS; points.(fieldsExport{i}).data{7}(expInd)];
                YGPS = [YGPS; points.(fieldsExport{i}).data{8}(expInd)];
                ZGPS = [ZGPS; points.(fieldsExport{i}).data{9}(expInd)];
                Time = [Time; datevec(points.(fieldsExport{i}).data{10}(expInd))];
            end
            Year = Time(:,1);
            Month = Time(:,2);
            Day = Time(:,3);
            Hour = Time(:,4);
            Min = Time(:,5);
            Sec = Time(:,6);
            
            expTable = table(FrameNum, XPix, YPix, Lat, Lon, XGPS, YGPS, ZGPS, Year, Month, Day, Hour, Min, Sec);
            
            writetable(expTable, [expPath expFile], 'FileType', 'text');
            
        end
        exportBtn.Enable = 'on';
        
    end

    function SETSELECT(hObject, ~)
        
        hObject.Enable = 'inactive';
        if ~strcmp(figdata.CurrentImageSet, ['set_' setSelect.String{setSelect.Value}])
            figdata.CurrentImageSet = ['set_' setSelect.String{setSelect.Value}];
            figdata.CurrentInd = 1;
        
            frameStr = num2str(points.(figdata.CurrentImageSet).data{1}(figdata.CurrentInd));
            PlotTiff(frameStr);
            PlotZoom()
        
            SetGUIValues('SETSELECT')
        end
        hObject.Enable = 'on';
        
    end

    function REMOVESET(hObject, ~)
        
        hObject.Enable = 'inactive';
        
        removeSetWarn = questdlg(['Are you sure you want to remove data set ' setSelect.String{setSelect.Value}],...
                                      'Remove Data Set?', 'Yes', 'No', 'Cancel', 'Yes');
        if strcmp('Yes', removeSetWarn)
            if length(fieldnames(points)) > 1
                points = rmfield(points, ['set_' setSelect.String{setSelect.Value}]);
                setFieldNames = fieldnames(points);
                figdata.CurrentImageSet = setFieldNames{1};
                figdata.CurrentInd = 1;
                figdata.ChangeFlag = 1;
                
                frameStr = num2str(points.(figdata.CurrentImageSet).data{1}(figdata.CurrentInd));
                PlotTiff(frameStr);
                PlotZoom()
                
                SetGUIValues('REMOVESET_1')
            
            elseif length(fieldnames(points)) == 1
                points = struct();
                figdata.CurrentInd = 1;
                figdata.ChangeFlag = 0;
                figdata.CurrentImageSet = [];
                figdata.SavePath = [];
                
                delete(haxes.Children);
                delete(hzoom.Children);
                
                SetGUIValues('REMOVESET_2')
            end
        end
        hObject.Enable = 'on';
        
    end

    function PLAY(hObject, ~)
        
        if figdata.AlreadyRunning == 0
            
            SetGUIValues('PLAY_Start')
            
            % delete the zoom window while running
            delete(hzoom.Children);
            
            % set the value to frame skip for play, ff, and rw
            if hObject == playBtn
                figdata.FrameStep = 1;
            elseif hObject == ffBtn
                figdata.FrameStep = 4;
            elseif hObject == rwBtn
                figdata.FrameStep = -4;
            end
            
            % step through frames and plot
            while figdata.CurrentInd >= 1 && figdata.CurrentInd <= length(points.(figdata.CurrentImageSet).data{1})
        
                tic
                frameStr = num2str(points.(figdata.CurrentImageSet).data{1}(figdata.CurrentInd));
                PlotTiff(frameStr);
                if figdata.PauseFlag == 1
                    frameStr = num2str(points.(figdata.CurrentImageSet).data{1}(figdata.CurrentInd));
                    PlotTiff(frameStr);
                    break
                elseif figdata.PauseFlag == 0
                    frameStr = num2str(points.(figdata.CurrentImageSet).data{1}(figdata.CurrentInd));
                    PlotTiff(frameStr);
                end
            
                figdata.CurrentInd = figdata.CurrentInd + figdata.FrameStep;
                elapsedTime = toc;
                
                if elapsedTime < 0.1
                    pause(0.1-elapsedTime)
                end
                
            end % end while
            
            if figdata.CurrentInd < 1
                figdata.CurrentInd = 1;
            elseif figdata.CurrentInd > length(points.(figdata.CurrentImageSet).data{1})
                figdata.CurrentInd = length(points.(figdata.CurrentImageSet).data{1});
            end
            
            SetGUIValues('PLAY_End')
            
            % setup zoom window
            PlotZoom()
            
            % Plot a picked point if there
            hold(haxes, 'on')
              PlotPickedPoint()
            hold(haxes, 'off')
            
        else
            if hObject == playBtn
                figdata.FrameStep = 1;
            elseif hObject == ffBtn
                figdata.FrameStep = 4;
            elseif hObject == rwBtn
                figdata.FrameStep = -4;
            end
        end
        
    end

    function PAUSE(~, ~)
        
        figdata.PauseFlag = 1;
        
    end

    function STEP(hObject, ~)
        
        hObject.Enable = 'inactive';
        
        if hObject == startBtn
            figdata.CurrentInd = 1;
        elseif hObject == stepb100Btn
            figdata.CurrentInd = figdata.CurrentInd - 100;
        elseif hObject == stepb10Btn
            figdata.CurrentInd = figdata.CurrentInd - 10;
        elseif hObject == stepb1Btn
            figdata.CurrentInd = figdata.CurrentInd - 1;
        elseif hObject == stepf1Btn
            figdata.CurrentInd = figdata.CurrentInd + 1;
        elseif hObject == stepf10Btn
            figdata.CurrentInd = figdata.CurrentInd + 10;
        elseif hObject == stepf100Btn
            figdata.CurrentInd = figdata.CurrentInd + 100;
        elseif hObject == endBtn
            figdata.CurrentInd = length(points.(figdata.CurrentImageSet).data{1});
        elseif hObject == previousBtn
            allPointsInd = find(isnan(points.(figdata.CurrentImageSet).data{3}) == 0);
            previousInd = find(allPointsInd < figdata.CurrentInd, 1, 'last');
            if isempty(previousInd)
                msgbox('There are no more GCPs that way.', '', 'modal')
            else
                figdata.CurrentInd = allPointsInd(previousInd);
            end
        elseif hObject == nextBtn
            allPointsInd = find(isnan(points.(figdata.CurrentImageSet).data{3}) == 0);
            nextInd = find(allPointsInd > figdata.CurrentInd, 1, 'first');
            if isempty(nextInd)
                msgbox('There are no more GCPs that way.', '', 'modal')
            else
                figdata.CurrentInd = allPointsInd(nextInd);
            end
        end
        
        if figdata.CurrentInd < 1
            figdata.CurrentInd = 1;
        elseif figdata.CurrentInd > length(points.(figdata.CurrentImageSet).data{1})
            figdata.CurrentInd = length(points.(figdata.CurrentImageSet).data{1});
        end
        
        frameStr = num2str(points.(figdata.CurrentImageSet).data{1}(figdata.CurrentInd));
        PlotTiff(frameStr);
        
        PlotZoom()

        SetGUIValues('STEP')
        
        hObject.Enable = 'on';
        
    end

    function ZOOMSLIDER(~, ~)
       
        hzoom.XLim = [figdata.XCP-hSlider.Value figdata.XCP+hSlider.Value];
        hzoom.YLim = [figdata.YCP-hSlider.Value figdata.YCP+hSlider.Value];
        
    end

    function ZOOMCENTER(~, ~)
       
       centerPoint = haxes.CurrentPoint;
       figdata.XCP = round(centerPoint(1,1));
       figdata.YCP = round(centerPoint(1,2));
       
       PlotZoom()
        
    end

    function GETPIXEL(~, ~)
       
       pixelPoint = hzoom.CurrentPoint;
       pixelX = round(pixelPoint(1,1));
       pixelY = round(pixelPoint(1,2));
       
       points.(figdata.CurrentImageSet).data{3}(figdata.CurrentInd) = pixelX;
       points.(figdata.CurrentImageSet).data{4}(figdata.CurrentInd) = pixelY;
       figdata.ChangeFlag = 1;
       
       xText.String = ['x = ' num2str(pixelX)];
       yText.String = ['y = ' num2str(pixelY)];
       
       hRemove.Enable = 'on';
       exportBtn.Enable = 'on';
       hPlotPoints.Enable = 'on';
       hRectify.Enable = 'on';
       previousBtn.Enable = 'on';
       nextBtn.Enable = 'on';
       
       hold(haxes, 'on')
       if isempty(findobj(haxes.Children,'Type','Line'))
           hLineAxes = plot(haxes, pixelX, pixelY, 'og', 'LineWidth', 2, 'MarkerSize', 10);
       else
           delete(findobj(haxes.Children,'Type','Line'));
           hLineAxes = plot(haxes, pixelX, pixelY, 'og', 'LineWidth', 2, 'MarkerSize', 10);
       end
       hold(haxes, 'off')
       hLineAxes.PickableParts = 'none';
       
       hold(hzoom, 'on')
       if isempty(findobj(hzoom.Children,'Type','Line'))
           hLineZoom = plot(hzoom, pixelX, pixelY, 'og', 'LineWidth', 2, 'MarkerSize', 10);
       else
           delete(findobj(hzoom.Children,'Type','Line'));
           hLineZoom = plot(hzoom, pixelX, pixelY, 'og', 'LineWidth', 2, 'MarkerSize', 10);
       end
       hold(hzoom, 'off')
       hLineZoom.PickableParts = 'none';
       
    end

    function REMOVE(hObject, ~)
        
        hObject.Enable = 'inactive';
        
        points.(figdata.CurrentImageSet).data{3}(figdata.CurrentInd) = NaN;
        points.(figdata.CurrentImageSet).data{4}(figdata.CurrentInd) = NaN;
       
        xText.String = 'x = ';
        yText.String = 'y = ';
       
        hObject.Enable = 'off';
        if all(isnan(points.(figdata.CurrentImageSet).data{3}))
             previousBtn.Enable = 'off';
             nextBtn.Enable = 'off';
        else
            previousBtn.Enable = 'on';
            nextBtn.Enable = 'on';
        end
       
        fieldNames = fieldnames(points);
        noExportFlag = zeros(length(fieldNames), 1);
        for i = 1:length(fieldNames)
            if all(isnan(points.(fieldNames{i}).data{3}))
                noExportFlag(i) = 1;
            end
        end
        if all(noExportFlag)
            exportBtn.Enable = 'off';
            hPlotPoints.Enable = 'off';
            hRectify.Enable = 'off'; 
        end
       
        if ~isempty(findobj(haxes.Children,'Type','Line'))
            delete(findobj(haxes.Children,'Type','Line'));
        end
       
        if ~isempty(findobj(hzoom.Children,'Type','Line'))
            delete(findobj(hzoom.Children,'Type','Line'));
        end
        
    end 

    function PLOTPOINTS(hObject, ~)
        
        hObject.Enable = 'inactive';
        
        fieldNamesPoints = fieldnames(points);
        setNumPoints = [];
        frameNumPoints = [];
        xPixelPoints = [];
        yPixelPoints = [];
        latPoints = [];
        lonPoints = [];
        for i = 1:length(fieldNamesPoints)
            fileIndPoints = ~isnan(points.(fieldNamesPoints{i}).data{3});
            frameNumPoints = [frameNumPoints; points.(fieldNamesPoints{i}).data{1}(fileIndPoints)];
            xPixelPoints = [xPixelPoints; points.(fieldNamesPoints{i}).data{3}(fileIndPoints)];
            yPixelPoints = [yPixelPoints; points.(fieldNamesPoints{i}).data{4}(fileIndPoints)];
            latPoints = [latPoints; points.(fieldNamesPoints{i}).data{5}(fileIndPoints)];
            lonPoints = [lonPoints; points.(fieldNamesPoints{i}).data{6}(fileIndPoints)];
            setNumPoints = [setNumPoints; ones(sum(fileIndPoints),1).*i];
        end
        
        tiffFileNamePoints = [points.(fieldNamesPoints{setNumPoints(1)}).file{2} points.(fieldNamesPoints{setNumPoints(1)}).file{1}(1:end-length(num2str(frameNumPoints(1)))) num2str(frameNumPoints(1))];
        
        PlotSelectedPoints(tiffFileNamePoints, frameNumPoints, xPixelPoints, yPixelPoints, latPoints, lonPoints)
        
        hObject.Enable = 'on';
        
    end

    function RECTIFY(hObject, ~)
        
        hObject.Enable = 'inactive';
        RectifyImageGUI()
        hObject.Enable = 'on';
        
    end

    function ADJUSTFIGURE(~,~)
        
        adjustSize = hfig.Position;
        adjustHeight = adjustSize(4).*ssH;
        adjustWidth = adjustSize(3).*ssW;
        
        hpanLoad.Position = [0 ... % left
                            (1-(upperBarHeight/adjustHeight))... % bottom
                            loadPanelWidth... % width
                            (upperBarHeight/adjustHeight)]; % height
          loadRawBtn.Position = [(upperBtnOffset/adjustWidth)/loadPanelWidth... % left
                                ((upperBarHeight-upperBtnHeight)/2)/upperBarHeight... % bottom
                                (upperBtnWidth/adjustWidth)/loadPanelWidth... % width
                                upperBtnHeight/upperBarHeight]; % Height
          loadMatBtn.Position = [loadRawBtn.Position(1)+loadRawBtn.Position(3)+(upperBtnOffset/adjustWidth)/loadPanelWidth... % left
                                ((upperBarHeight-upperBtnHeight)/2)/upperBarHeight... % bottom
                                (upperBtnWidth/adjustWidth)/loadPanelWidth... % width
                                upperBtnHeight/upperBarHeight];... % height
          saveBtn.Position = [loadMatBtn.Position(1)+loadMatBtn.Position(3)+(upperBtnOffset/adjustWidth)/loadPanelWidth... % left
                             ((upperBarHeight-upperBtnHeight)/2)/upperBarHeight... % bottom
                             (upperBtnWidth/adjustWidth)/loadPanelWidth... % width
                             upperBtnHeight/upperBarHeight];... % height
          saveasBtn.Position = [saveBtn.Position(1)+saveBtn.Position(3)+(upperBtnOffset/adjustWidth)/loadPanelWidth... % left
                               ((upperBarHeight-upperBtnHeight)/2)/upperBarHeight... % bottom
                               (upperBtnWidth/adjustWidth)/loadPanelWidth... % width
                               upperBtnHeight/upperBarHeight];... % height
          exportBtn.Position = [saveasBtn.Position(1)+saveasBtn.Position(3)+(upperBtnOffset/adjustWidth)/loadPanelWidth... % left
                               ((upperBarHeight-upperBtnHeight)/2)/upperBarHeight... % bottom
                               (upperBtnWidth/adjustWidth)/loadPanelWidth... % width
                               upperBtnHeight/upperBarHeight];... % height                
        hpanFile.Position = [loadPanelWidth... % left
                            (1-(upperBarHeight/adjustHeight))... % bottom
                            1-loadPanelWidth... % width
                            (upperBarHeight/adjustHeight)];... % Height
          setSelect.Position = [(upperBtnOffset/adjustWidth)/(1-loadPanelWidth)... % left
                               ((upperBarHeight-upperDropdownHeight)/2)/upperBarHeight... % bottom
                               (upperDropdownWidth/adjustWidth)/(1-loadPanelWidth)... % width
                               upperBtnHeight/upperBarHeight]; % height                 
          setSurvey.Position = [setSelect.Position(1)+setSelect.Position(3)+(upperBtnOffset/adjustWidth)/(1-loadPanelWidth)... % left
                               ((upperBarHeight-upperTxtHeight)/2)/upperBarHeight... % bottom
                               (upperTxtWidth/adjustWidth)/(1-loadPanelWidth)... % width
                               upperTxtHeight/upperBarHeight]; % height
          removeSetBtn.Position = [setSurvey.Position(1)+setSurvey.Position(3)+(upperBtnOffset/adjustWidth)/(1-loadPanelWidth)... % left
                                   ((upperBarHeight-upperBtnHeight)/2)/upperBarHeight... % bottom
                                   (upperBtnWidth/adjustWidth)/(1-loadPanelWidth)... % width
                                   upperBtnHeight/upperBarHeight]; % height
        hpanPlay.Position = [0.0... % left
                             0.0... % bottom
                             0.3... % width
                             lowerBarHeight/adjustHeight]; % height 
          playBtn.Position = [0.5-(playBtnOffset/2+playBtnWidth)/0.3/adjustWidth... % left
                             ((lowerBarHeight-playBtnHeight)/2)/lowerBarHeight... % bottom
                             (playBtnWidth/adjustWidth)/0.3... % width
                             playBtnHeight/lowerBarHeight]; % height; old = [0.375 0.1 0.1 0.8]
          pauseBtn.Position = [0.5+(playBtnOffset/2)/0.3/adjustWidth... % left
                              ((lowerBarHeight-playBtnHeight)/2)/lowerBarHeight... % bottom
                              (playBtnWidth/adjustWidth)/0.3... % width
                              playBtnHeight/lowerBarHeight]; % height
          ffBtn.Position = [0.5+(playBtnOffset*3/2+playBtnWidth)/0.3/adjustWidth... % left
                            ((lowerBarHeight-playBtnHeight)/2)/lowerBarHeight... % bottom
                            (playBtnWidth/adjustWidth)/0.3... % width
                            playBtnHeight/lowerBarHeight]; % height                              
          rwBtn.Position = [0.5-(playBtnOffset*3/2+playBtnWidth*2)/0.3/adjustWidth... % left
                            ((lowerBarHeight-playBtnHeight)/2)/lowerBarHeight... % bottom
                            (playBtnWidth/adjustWidth)/0.3... % width
                            playBtnHeight/lowerBarHeight]; % height
        hpanStep.Position = [0.3... % left
                             0.0... % bottom
                             0.7... % width
                             lowerBarHeight/adjustHeight]; % height
          stepb1Btn.Position = [0.5-(stepBtnOffset/2+stepBtnWidth)/0.7/adjustWidth... % left
                                ((lowerBarHeight-stepBtnHeight)/2)/lowerBarHeight... % bottom
                                (stepBtnWidth/adjustWidth)/0.7... % width
                                playBtnHeight/lowerBarHeight]; % height
          stepf1Btn.Position = [0.5+(stepBtnOffset/2)/0.7/adjustWidth... % left
                                ((lowerBarHeight-stepBtnHeight)/2)/lowerBarHeight... % bottom
                                (stepBtnWidth/adjustWidth)/0.7... % width
                                playBtnHeight/lowerBarHeight]; % height
          stepf10Btn.Position = [0.5+(stepBtnOffset*3/2+stepBtnWidth)/0.7/adjustWidth... % left
                                 ((lowerBarHeight-stepBtnHeight)/2)/lowerBarHeight... % bottom
                                 (stepBtnWidth/adjustWidth)/0.7... % width
                                 playBtnHeight/lowerBarHeight]; % height
          stepb10Btn.Position = [0.5-(stepBtnOffset*3/2+2*stepBtnWidth)/0.7/adjustWidth... % left
                                 ((lowerBarHeight-stepBtnHeight)/2)/lowerBarHeight... % bottom
                                 (stepBtnWidth/adjustWidth)/0.7... % width
                                 playBtnHeight/lowerBarHeight]; % height                      
          stepf100Btn.Position = [0.5+(stepBtnOffset*5/2+2*stepBtnWidth)/0.7/adjustWidth... % left
                                 ((lowerBarHeight-stepBtnHeight)/2)/lowerBarHeight... % bottom
                                 (stepBtnWidth/adjustWidth)/0.7... % width
                                 playBtnHeight/lowerBarHeight]; % height
          stepb100Btn.Position = [0.5-(stepBtnOffset*5/2+3*stepBtnWidth)/0.7/adjustWidth... % left
                                  ((lowerBarHeight-stepBtnHeight)/2)/lowerBarHeight... % bottom
                                  (stepBtnWidth/adjustWidth)/0.7... % width
                                  playBtnHeight/lowerBarHeight]; % height
          previousBtn.Position = [0.5-(stepBtnOffset*7/2+4*stepBtnWidth)/0.7/adjustWidth... % left
                                 ((lowerBarHeight-stepBtnHeight)/2)/lowerBarHeight... % bottom
                                 (stepBtnWidth/adjustWidth)/0.7... % width
                                 playBtnHeight/lowerBarHeight]; % height
          nextBtn.Position = [0.5+(stepBtnOffset*7/2+3*stepBtnWidth)/0.7/adjustWidth... % left
                              ((lowerBarHeight-stepBtnHeight)/2)/lowerBarHeight... % bottom
                              (stepBtnWidth/adjustWidth)/0.7... % width
                              playBtnHeight/lowerBarHeight]; % height
          startBtn.Position = [0.5-(stepBtnOffset*9/2+5*stepBtnWidth)/0.7/adjustWidth... % left
                               ((lowerBarHeight-stepBtnHeight)/2)/lowerBarHeight... % bottom
                               (stepBtnWidth/adjustWidth)/0.7... % width
                               playBtnHeight/lowerBarHeight]; % height
          endBtn.Position = [0.5+(stepBtnOffset*9/2+4*stepBtnWidth)/0.7/adjustWidth... % left
                             ((lowerBarHeight-stepBtnHeight)/2)/lowerBarHeight... % bottom
                             (stepBtnWidth/adjustWidth)/0.7... % width
                             playBtnHeight/lowerBarHeight]; % height
        hpanImagePoint.Position = [1-(sideBarWidth/adjustWidth)... % left
                                   ((hpanLoad.Position(2)-hpanPlay.Position(4))/2)+hpanPlay.Position(4)... % bottom
                                   sideBarWidth/adjustWidth... % width
                                   (hpanLoad.Position(2)-hpanPlay.Position(4))/2]; % height
          frameText.Position = [((sideBarWidth-sideTxtWidth)/2)/sideBarWidth... % left
                                1-(sideTxtOffset+sideTxtHeight)/((hpanLoad.Position(2)-hpanPlay.Position(4)).*adjustHeight/2)... % bottom
                                sideTxtWidth/sideBarWidth... % width
                                sideTxtHeight/((hpanLoad.Position(2)-hpanPlay.Position(4)).*adjustHeight/2)]; % height             
          utcTimeText.Position = [((sideBarWidth-sideTxtWidth)/2)/sideBarWidth... % left
                                  1-2*(sideTxtOffset+sideTxtHeight)/((hpanLoad.Position(2)-hpanPlay.Position(4)).*adjustHeight/2)... % bottom
                                  sideTxtWidth/sideBarWidth... % width
                                  sideTxtHeight/((hpanLoad.Position(2)-hpanPlay.Position(4)).*adjustHeight/2)]; % height
          xText.Position = [((sideBarWidth-sideTxtWidth)/2)/sideBarWidth... % left
                            1-3*(sideTxtOffset+sideTxtHeight)/((hpanLoad.Position(2)-hpanPlay.Position(4)).*adjustHeight/2)... % bottom
                            sideTxtWidth/sideBarWidth... % width
                            sideTxtHeight/((hpanLoad.Position(2)-hpanPlay.Position(4)).*adjustHeight/2)]; % height
                                
          yText.Position = [((sideBarWidth-sideTxtWidth)/2)/sideBarWidth... % left
                            1-4*(sideTxtOffset+sideTxtHeight)/((hpanLoad.Position(2)-hpanPlay.Position(4)).*adjustHeight/2)... % bottom
                            sideTxtWidth/sideBarWidth... % width
                            sideTxtHeight/((hpanLoad.Position(2)-hpanPlay.Position(4)).*adjustHeight/2)]; % height
          hRemove.Position = [((sideBarWidth-sideBtnWidth)/2)/sideBarWidth... % left
                              (yText.Position(2)/2)+(sideBtnHeight/2+sideBtnOffset)/((hpanLoad.Position(2)-hpanPlay.Position(4)).*adjustHeight/2)... % bottom
                              sideBtnWidth/sideBarWidth... % width
                              sideBtnHeight/((hpanLoad.Position(2)-hpanPlay.Position(4)).*adjustHeight/2)]; % height
          hPlotPoints.Position = [((sideBarWidth-sideBtnWidth)/2)/sideBarWidth... % left
                                  (yText.Position(2)/2)-(sideBtnHeight/2)/((hpanLoad.Position(2)-hpanPlay.Position(4)).*adjustHeight/2)... % bottom
                                  sideBtnWidth/sideBarWidth... % width
                                  sideBtnHeight/((hpanLoad.Position(2)-hpanPlay.Position(4)).*adjustHeight/2)]; % height                 
          hRectify.Position = [((sideBarWidth-sideBtnWidth)/2)/sideBarWidth... % left
                               (yText.Position(2)/2)-(sideBtnHeight*3/2+sideBtnOffset)/((hpanLoad.Position(2)-hpanPlay.Position(4)).*adjustHeight/2)... % bottom
                                sideBtnWidth/sideBarWidth... % width
                                sideBtnHeight/((hpanLoad.Position(2)-hpanPlay.Position(4)).*adjustHeight/2)]; % height
        hpanSurveyPoint.Position = [1-(sideBarWidth/adjustWidth)... % left
                                    hpanPlay.Position(4)... % bottom
                                    sideBarWidth/adjustWidth... % width
                                    (hpanLoad.Position(2)-hpanPlay.Position(4))/2]; % height
          gpsTimeText.Position = [((sideBarWidth-sideTxtWidth)/2)/sideBarWidth... % left
                                  1-(sideTxtOffset+sideTxtHeight)/((hpanLoad.Position(2)-hpanPlay.Position(4)).*adjustHeight/2)... % bottom
                                  sideTxtWidth/sideBarWidth... % width
                                  sideTxtHeight/((hpanLoad.Position(2)-hpanPlay.Position(4)).*adjustHeight/2)]; % height
          latText.Position = [((sideBarWidth-sideTxtWidth)/2)/sideBarWidth... % left
                              1-2*(sideTxtOffset+sideTxtHeight)/((hpanLoad.Position(2)-hpanPlay.Position(4)).*adjustHeight/2)... % bottom
                              sideTxtWidth/sideBarWidth... % width
                              sideTxtHeight/((hpanLoad.Position(2)-hpanPlay.Position(4)).*adjustHeight/2)]; % height
          lonText.Position = [((sideBarWidth-sideTxtWidth)/2)/sideBarWidth... % left
                              1-3*(sideTxtOffset+sideTxtHeight)/((hpanLoad.Position(2)-hpanPlay.Position(4)).*adjustHeight/2)... % bottom
                              sideTxtWidth/sideBarWidth... % width
                              sideTxtHeight/((hpanLoad.Position(2)-hpanPlay.Position(4)).*adjustHeight/2)]; % height    
          xsText.Position = [((sideBarWidth-sideTxtWidth)/2)/sideBarWidth... % left
                             1-4*(sideTxtOffset+sideTxtHeight)/((hpanLoad.Position(2)-hpanPlay.Position(4)).*adjustHeight/2)... % bottom
                             sideTxtWidth/sideBarWidth... % width
                             sideTxtHeight/((hpanLoad.Position(2)-hpanPlay.Position(4)).*adjustHeight/2)]; % height
          ysText.Position = [((sideBarWidth-sideTxtWidth)/2)/sideBarWidth... % left
                             1-5*(sideTxtOffset+sideTxtHeight)/((hpanLoad.Position(2)-hpanPlay.Position(4)).*adjustHeight/2)... % bottom
                             sideTxtWidth/sideBarWidth... % width
                             sideTxtHeight/((hpanLoad.Position(2)-hpanPlay.Position(4)).*adjustHeight/2)]; % height
          zsText.Position = [((sideBarWidth-sideTxtWidth)/2)/sideBarWidth... % left
                             1-6*(sideTxtOffset+sideTxtHeight)/((hpanLoad.Position(2)-hpanPlay.Position(4)).*adjustHeight/2)... % bottom
                             sideTxtWidth/sideBarWidth... % width
                             sideTxtHeight/((hpanLoad.Position(2)-hpanPlay.Position(4)).*adjustHeight/2)]; % height
        haxes.Position = [plotAxesHorOffset/adjustWidth,...
                          (plotAxesVertOffset+lowerBarHeight)/adjustHeight,...
                          0.6,...
                          1-(lowerBarHeight+upperBarHeight+2*plotAxesVertOffset)/adjustHeight];
        hzoom.Position = [0.6 + (zoomAxesHorOffset+plotAxesHorOffset)/adjustWidth...
                          0.545...
                          1-(0.6 + (2*zoomAxesHorOffset+plotAxesHorOffset+sideBarWidth)/adjustWidth)...
                          1-(0.545+(zoomAxesVertOffset+upperBarHeight)/adjustHeight)];
        hSlider.Position = [0.6 + (zoomAxesHorOffset+plotAxesHorOffset)/adjustWidth...
                            hzoom.Position(2)-((sliderHeight+sliderOffset)/adjustHeight)...
                            1-(0.6 + (2*zoomAxesHorOffset+plotAxesHorOffset+sideBarWidth)/adjustWidth)...
                            sliderHeight/adjustHeight];

    end

    function PlotTiff(frameStr)

        tiffName = [points.(figdata.CurrentImageSet).file{2} points.(figdata.CurrentImageSet).file{1}(1:end-length(frameStr)) frameStr];
        
        errorFlag = 0;
        try
            tiffData = imread(tiffName, 'tif');
            if strcmp(figdata.CameraType, 'IR') == 1
            elseif strcmp(figdata.CameraType, 'EO') == 1
                tiffData = demosaic(tiffData.*2^(16-figdata.BitDepth), 'rggb');
            end
        catch
            errorFlag = 1;
        end
        
        if errorFlag == 0
            delete(haxes.Children)
            hold(haxes, 'on')
              hImage = imagesc(haxes, tiffData);
              PlotPickedPoint()
            hold(haxes, 'off')
            hImage.PickableParts = 'none';
            drawnow;
        else
            delete(haxes.Children)
            delete(hzoom.Children)
            text(haxes, 400, 384, {'Image Missing';['Frame ' num2str(points.(figdata.CurrentImageSet).data{1}(figdata.CurrentInd))]},'Color', 'red', 'FontSize', 16)
            pause(0.5)
        end
        
        haxes.HitTest = 'on';

    end

    function PlotPickedPoint()
        
        if ~isnan(points.(figdata.CurrentImageSet).data{3}(figdata.CurrentInd)) && figdata.AlreadyRunning == 0
            hPoint = plot(haxes, points.(figdata.CurrentImageSet).data{3}(figdata.CurrentInd),...
                                 points.(figdata.CurrentImageSet).data{4}(figdata.CurrentInd), 'og', 'LineWidth', 2, 'MarkerSize', 10);
            hPoint.PickableParts = 'none';
            hPoint.HitTest = 'off';
        end
        
    end

    function PlotZoom()
        
        if isempty(findobj(haxes.Children,'Type','Text'))
            if ~isnan(points.(figdata.CurrentImageSet).data{5}(figdata.CurrentInd))
                hzoom.XLim = [figdata.XCP-hSlider.Value figdata.XCP+hSlider.Value];
                hzoom.YLim = [figdata.YCP-hSlider.Value figdata.YCP+hSlider.Value];
       
                delete(hzoom.Children)
                hZoomIm = copyobj(findobj(haxes.Children,'Type','Image'), hzoom);
                hZoomIm.PickableParts = 'none';
                if ~isempty(findobj(haxes.Children,'Type','Line'))
                    hZoomLine = copyobj(findobj(haxes.Children,'Type','Line'), hzoom);
                    hZoomLine.PickableParts = 'none';
                    hZoomLine.HitTest = 'off';
                end
                if ~isnan(points.(figdata.CurrentImageSet).data{3}(figdata.CurrentInd))
                    figdata.XCP = points.(figdata.CurrentImageSet).data{3}(figdata.CurrentInd);
                    figdata.YCP = points.(figdata.CurrentImageSet).data{4}(figdata.CurrentInd);
                    hzoom.XLim = [figdata.XCP-hSlider.Value figdata.XCP+hSlider.Value];
                    hzoom.YLim = [figdata.YCP-hSlider.Value figdata.YCP+hSlider.Value];
                end
                hzoom.HitTest = 'on';
            else
                hzoom.XLim = [figdata.XCP-hSlider.Value figdata.XCP+hSlider.Value];
                hzoom.YLim = [figdata.YCP-hSlider.Value figdata.YCP+hSlider.Value];
       
                delete(hzoom.Children)
                hZoomIm = copyobj(findobj(haxes.Children,'Type','Image'), hzoom);
                hold(hzoom, 'on')
                  plot(hzoom, [figdata.XCP-hSlider.Max figdata.XCP+hSlider.Max],[figdata.YCP-hSlider.Max figdata.YCP+hSlider.Max],'-r','LineWidth',2)
                  plot(hzoom, [figdata.XCP-hSlider.Max figdata.XCP+hSlider.Max],[figdata.YCP+hSlider.Max figdata.YCP-hSlider.Max],'-r','LineWidth',2)
                hold(hzoom, 'off')
                hZoomIm.PickableParts = 'none';
                hzoom.HitTest = 'off';
            end
            
        else
            delete(hzoom.Children)
        end
        
    end

    function [wholeSecFrameNumbers, wholeFrameDateTime, lastFrame] = FindNearestWholeSecondFrame(fName, pName, tmz, fr)

        % load and read the .utc file
        fid = fopen([pName fName],'r');
        fgetl(fid);
        frameUTC = fscanf(fid,'%d) %d/%d/%d %d:%d:%d:%d:%d\n',[9 Inf])';
        fclose(fid);
    
        frameNumber = frameUTC(:,1);
        secs = frameUTC(:,7) + frameUTC(:,8).*(10^-3) + frameUTC(:,9).*(10^-6);

        % Get index of frames closest to the whole second
        wholeSecs = round(secs);
        minWholeSecs = abs(secs-wholeSecs);
        remainder = mod(length(minWholeSecs),fr);
        minWholeSecs = minWholeSecs(1:end-remainder); % only keep a multipe of the frame rate to make reshape work
        tempReshape = reshape(minWholeSecs,[fr,length(minWholeSecs)/fr]);
        [~, ind] = min(tempReshape,[],1);
        [~, col] = size(tempReshape);
        offSet = (0:col-1).*fr;
        wholeSecFrameNumbers = (ind-1) + offSet;
    
        wFYear = frameUTC(wholeSecFrameNumbers+1,4);
        wFMonth = frameUTC(wholeSecFrameNumbers+1,2);
        wFDay = frameUTC(wholeSecFrameNumbers+1,3);
        wFHour = frameUTC(wholeSecFrameNumbers+1,5);
        wFMin = frameUTC(wholeSecFrameNumbers+1,6);
        wFSec = secs(wholeSecFrameNumbers+1);
        wholeFrameDateTime = datetime(wFYear, wFMonth, wFDay, wFHour, wFMin, wFSec, 'TimeZone', tmz);
    
        lastFrame = frameNumber(end);
    
    end

    function [latGPS, lonGPS, XGPS, YGPS, ZGPS, dateTimeGPS] = LoadSurvey(fName, pName)

        fid = fopen([pName fName],'r');

        surveyData = textscan(fid,'%f %f %f %f %f %f %f %f %f %f %f',...
                                  'Delimiter', ' ', 'HeaderLines', 1)';
        fclose(fid);

        yearGPS = surveyData{1};
        monthGPS = surveyData{2};
        dayGPS = surveyData{3};
        hourGPS = surveyData{4};
        minGPS = surveyData{5};
        secGPS = surveyData{6};
        latGPS = surveyData{7};
        lonGPS = surveyData{8};
        XGPS = surveyData{9};
        YGPS = surveyData{10};
        ZGPS = surveyData{11};
        dateGPS = yearGPS.*10^10 + monthGPS.*10^8 + dayGPS.*10^6 + hourGPS.*10^4 + minGPS.*10^2 + secGPS;
        
        [~, sortInd]= sort(dateGPS, 'ascend');
    
        latGPS = latGPS(sortInd);
        lonGPS = lonGPS(sortInd);
        XGPS = XGPS(sortInd);
        YGPS = YGPS(sortInd);
        ZGPS = ZGPS(sortInd);
    
        yearGPS = yearGPS(sortInd);
        monthGPS = monthGPS(sortInd);
        dayGPS = dayGPS(sortInd);
        hourGPS = hourGPS(sortInd);
        minGPS = minGPS(sortInd);
        secGPS = secGPS(sortInd);
        dateTimeGPS = datetime(yearGPS, monthGPS, dayGPS, hourGPS, minGPS, secGPS, 'TimeZone','UTC');

    end

    function zerothFrameStr = MakeTiffZerothString(lastFrameNum)
    
        zerothFrameStr = [];
        frameStrLen = length(num2str(lastFrameNum));
        for i = 1:frameStrLen
            zerothFrameStr = ['0' zerothFrameStr];
        end
    
    end

    function SetGUIValues(flag)
        
        if strcmp(flag, 'LOADUTC') % values to set for sucessful UTC load
            figdata.XCP = figdata.XCPDefault;
            figdata.YCP = figdata.YCPDefault;
            figdata.CurrentInd = 1;
            
            saveBtn.Enable = 'on';
            saveasBtn.Enable = 'on';
            playBtn.Enable = 'on';
            pauseBtn.Enable = 'off';
            ffBtn.Enable = 'on';
            rwBtn.Enable = 'on';
            stepb1Btn.Enable = 'on';
            stepf1Btn.Enable = 'on';
            stepf10Btn.Enable = 'on';
            stepb10Btn.Enable = 'on';
            stepf100Btn.Enable = 'on';
            stepb100Btn.Enable = 'on';
            previousBtn.Enable = 'off';
            nextBtn.Enable = 'off';
            startBtn.Enable = 'on';
            endBtn.Enable = 'on';
            setSelect.Enable = 'on';
            removeSetBtn.Enable = 'on';
            
            hSlider.Enable = 'on';
            hSlider.Value = 55;
            if isempty(findobj(haxes.Children, 'Type','Text'))
                haxes.HitTest = 'on';
                hzoom.HitTest = 'on';
            else
                haxes.HitTest = 'off';
                hzoom.HitTest = 'off';
            end
            if isnan(points.(figdata.CurrentImageSet).data{5}(figdata.CurrentInd))
                hzoom.HitTest = 'off';
                haxes.HitTest = 'off';
            end
            
            xText.String = 'x = ';
            yText.String = 'y = ';
            frameText.String = ['Frame ' num2str(points.(figdata.CurrentImageSet).data{1}(figdata.CurrentInd))];
            if ~isnat(points.(figdata.CurrentImageSet).data{10}(figdata.CurrentInd))
                gpsTimeText.String = datestr(points.(figdata.CurrentImageSet).data{10}(figdata.CurrentInd), 'HH:MM:SS.FFF');
            else
                gpsTimeText.String = [];
            end
            utcTimeText.String = datestr(points.(figdata.CurrentImageSet).data{2}(figdata.CurrentInd), 'HH:MM:SS.FFF');
            if ~isnan(points.(figdata.CurrentImageSet).data{5}(figdata.CurrentInd))
                latText.String = ['lat = ' num2str(points.(figdata.CurrentImageSet).data{5}(figdata.CurrentInd))];
                lonText.String = ['lon = ' num2str(points.(figdata.CurrentImageSet).data{6}(figdata.CurrentInd))];
                xsText.String = ['x = ' num2str(points.(figdata.CurrentImageSet).data{7}(figdata.CurrentInd))];
                ysText.String = ['y = ' num2str(points.(figdata.CurrentImageSet).data{8}(figdata.CurrentInd))];
                zsText.String = ['z = ' num2str(points.(figdata.CurrentImageSet).data{9}(figdata.CurrentInd))];
            else
                latText.String = 'lat = ';
                lonText.String = 'lon = ';
                xsText.String = 'x = ';
                ysText.String = 'y = ';
                zsText.String = 'z = ';
            end
            
            if exist('points', 'var')
                setSelect.String = cellfun(@(str) str(5:end), fieldnames(points), 'UniformOutput', 0);
                setSelect.Value = find(strcmp(setSelect.String, figdata.CurrentImageSet(5:end)));
                setSurvey.String = points.(figdata.CurrentImageSet).file{3};
            end
            
            fieldNames = fieldnames(points);
            noExportFlag = zeros(length(fieldNames),1);
            for i = 1:length(fieldNames)
                if all(isnan(points.(fieldNames{i}).data{3}))
                    noExportFlag(i) = 1;
                end
            end
            if all(noExportFlag)
                exportBtn.Enable = 'off';
                hPlotPoints.Enable = 'off';
                hRectify.Enable = 'off';
            else
                exportBtn.Enable = 'on';
                hPlotPoints.Enable = 'on';
                hRectify.Enable = 'on';
            end

        elseif strcmp(flag, 'LOADMAT')
            figdata.XCP = figdata.XCPDefault;
            figdata.YCP = figdata.YCPDefault;
            figdata.CurrentInd = 1;
            
            saveBtn.Enable = 'on';
            saveasBtn.Enable = 'on';
            playBtn.Enable = 'on';
            pauseBtn.Enable = 'off';
            ffBtn.Enable = 'on';
            rwBtn.Enable = 'on';
            stepb1Btn.Enable = 'on';
            stepf1Btn.Enable = 'on';
            stepf10Btn.Enable = 'on';
            stepb10Btn.Enable = 'on';
            stepf100Btn.Enable = 'on';
            stepb100Btn.Enable = 'on';
            if all(isnan(points.(figdata.CurrentImageSet).data{3}))
                previousBtn.Enable = 'off';
                nextBtn.Enable = 'off';
            else
                previousBtn.Enable = 'on';
                nextBtn.Enable = 'on';
            end
            startBtn.Enable = 'on';
            endBtn.Enable = 'on';
            setSelect.Enable = 'on';
            removeSetBtn.Enable = 'on';
            
            hSlider.Enable = 'on';
            hSlider.Value = 55;
            if isempty(findobj(haxes.Children, 'Type','Text'))
                haxes.HitTest = 'on';
                hzoom.HitTest = 'on';
            else
                haxes.HitTest = 'off';
                hzoom.HitTest = 'off';
            end
            if isnan(points.(figdata.CurrentImageSet).data{5}(figdata.CurrentInd))
                hzoom.HitTest = 'off';
                haxes.HitTest = 'off';
            end
            
            if isnan(points.(figdata.CurrentImageSet).data{3}(figdata.CurrentInd))
                xText.String = 'x = ';
                yText.String = 'y = ';
                hRemove.Enable = 'off';
            else
                xText.String = ['x = ' num2str(points.(figdata.CurrentImageSet).data{3}(figdata.CurrentInd))];
                yText.String = ['y = ' num2str(points.(figdata.CurrentImageSet).data{4}(figdata.CurrentInd))];
                hRemove.Enable = 'on';
            end
            frameText.String = ['Frame ' num2str(points.(figdata.CurrentImageSet).data{1}(figdata.CurrentInd))];
            if ~isnat(points.(figdata.CurrentImageSet).data{10}(figdata.CurrentInd))
                gpsTimeText.String = datestr(points.(figdata.CurrentImageSet).data{10}(figdata.CurrentInd), 'HH:MM:SS.FFF');
            else
                gpsTimeText.String = [];
            end
            utcTimeText.String = datestr(points.(figdata.CurrentImageSet).data{2}(figdata.CurrentInd), 'HH:MM:SS.FFF');
            if ~isnan(points.(figdata.CurrentImageSet).data{5}(figdata.CurrentInd))
                latText.String = ['lat = ' num2str(points.(figdata.CurrentImageSet).data{5}(figdata.CurrentInd))];
                lonText.String = ['lon = ' num2str(points.(figdata.CurrentImageSet).data{6}(figdata.CurrentInd))];
                xsText.String = ['x = ' num2str(points.(figdata.CurrentImageSet).data{7}(figdata.CurrentInd))];
                ysText.String = ['y = ' num2str(points.(figdata.CurrentImageSet).data{8}(figdata.CurrentInd))];
                zsText.String = ['z = ' num2str(points.(figdata.CurrentImageSet).data{9}(figdata.CurrentInd))];
            else
                latText.String = 'lat = ';
                lonText.String = 'lon = ';
                xsText.String = 'x = ';
                ysText.String = 'y = ';
                zsText.String = 'z = ';
            end
            
            if exist('points', 'var')
                setSelect.String = cellfun(@(str) str(5:end), fieldnames(points), 'UniformOutput', 0);
                setSelect.Value = find(strcmp(setSelect.String, figdata.CurrentImageSet(5:end)));
                setSurvey.String = points.(figdata.CurrentImageSet).file{3};
            end
            
            fieldNames = fieldnames(points);
            noExportFlag = zeros(length(fieldNames), 1);
            for i = 1:length(fieldNames)
                if all(isnan(points.(fieldNames{i}).data{3}))
                    noExportFlag(i) = 1;
                end
            end
            if all(noExportFlag)
                exportBtn.Enable = 'off';
                hPlotPoints.Enable = 'off';
                hRectify.Enable = 'off';
            else
                exportBtn.Enable = 'on';
                hPlotPoints.Enable = 'on';
                hRectify.Enable = 'on';
            end
             
        elseif strcmp(flag, 'SETSELECT')
            figdata.XCP = figdata.XCPDefault;
            figdata.YCP = figdata.YCPDefault;
            figdata.CurrentInd = 1;
            
            playBtn.Enable = 'on';
            pauseBtn.Enable = 'off';
            ffBtn.Enable = 'on';
            rwBtn.Enable = 'on';
            stepb1Btn.Enable = 'on';
            stepf1Btn.Enable = 'on';
            stepf10Btn.Enable = 'on';
            stepb10Btn.Enable = 'on';
            stepf100Btn.Enable = 'on';
            stepb100Btn.Enable = 'on';
            if all(isnan(points.(figdata.CurrentImageSet).data{3}))
                previousBtn.Enable = 'off';
                nextBtn.Enable = 'off';
            else
                previousBtn.Enable = 'on';
                nextBtn.Enable = 'on';
            end
            startBtn.Enable = 'on';
            endBtn.Enable = 'on';
            setSelect.Enable = 'on';
            
            hSlider.Enable = 'on';
            hSlider.Value = 55;
            if isempty(findobj(haxes.Children, 'Type','Text'))
                haxes.HitTest = 'on';
                hzoom.HitTest = 'on';
            else
                haxes.HitTest = 'off';
                hzoom.HitTest = 'off';
            end
            if isnan(points.(figdata.CurrentImageSet).data{5}(figdata.CurrentInd))
                hzoom.HitTest = 'off';
                haxes.HitTest = 'off';
            end
            
            if isnan(points.(figdata.CurrentImageSet).data{3}(figdata.CurrentInd))
                xText.String = 'x = ';
                yText.String = 'y = ';
                hRemove.Enable = 'off';
            else
                xText.String = ['x = ' num2str(points.(figdata.CurrentImageSet).data{3}(figdata.CurrentInd))];
                yText.String = ['y = ' num2str(points.(figdata.CurrentImageSet).data{4}(figdata.CurrentInd))];
                hRemove.Enable = 'on';
            end
            frameText.String = ['Frame ' num2str(points.(figdata.CurrentImageSet).data{1}(figdata.CurrentInd))];
            if ~isnat(points.(figdata.CurrentImageSet).data{10}(figdata.CurrentInd))
                gpsTimeText.String = datestr(points.(figdata.CurrentImageSet).data{10}(figdata.CurrentInd), 'HH:MM:SS.FFF');
            else
                gpsTimeText.String = [];
            end
            utcTimeText.String = datestr(points.(figdata.CurrentImageSet).data{2}(figdata.CurrentInd), 'HH:MM:SS.FFF');
            if ~isnan(points.(figdata.CurrentImageSet).data{5}(figdata.CurrentInd))
                latText.String = ['lat = ' num2str(points.(figdata.CurrentImageSet).data{5}(figdata.CurrentInd))];
                lonText.String = ['lon = ' num2str(points.(figdata.CurrentImageSet).data{6}(figdata.CurrentInd))];
                xsText.String = ['x = ' num2str(points.(figdata.CurrentImageSet).data{7}(figdata.CurrentInd))];
                ysText.String = ['y = ' num2str(points.(figdata.CurrentImageSet).data{8}(figdata.CurrentInd))];
                zsText.String = ['z = ' num2str(points.(figdata.CurrentImageSet).data{9}(figdata.CurrentInd))];
            else
                latText.String = 'lat = ';
                lonText.String = 'lon = ';
                xsText.String = 'x = ';
                ysText.String = 'y = ';
                zsText.String = 'z = ';
            end
            
            fieldNames = fieldnames(points);
            noExportFlag = zeros(length(fieldNames), 1);
            for i = 1:length(fieldNames)
                if all(isnan(points.(fieldNames{i}).data{3}))
                    noExportFlag(i) = 1;
                end
            end
            if all(noExportFlag)
                exportBtn.Enable = 'off';
                hPlotPoints.Enable = 'off';
                hRectify.Enable = 'off';
            else
                exportBtn.Enable = 'on';
                hPlotPoints.Enable = 'on';
                hRectify.Enable = 'on';
            end
            
            setSurvey.String = points.(figdata.CurrentImageSet).file{3};
            
        elseif strcmp(flag, 'REMOVESET_1')
            figdata.XCP = figdata.XCPDefault;
            figdata.YCP = figdata.YCPDefault;
            figdata.CurrentInd = 1;
            
            playBtn.Enable = 'on';
            pauseBtn.Enable = 'off';
            ffBtn.Enable = 'on';
            rwBtn.Enable = 'on';
            stepb1Btn.Enable = 'on';
            stepf1Btn.Enable = 'on';
            stepf10Btn.Enable = 'on';
            stepb10Btn.Enable = 'on';
            stepf100Btn.Enable = 'on';
            stepb100Btn.Enable = 'on';
            if all(isnan(points.(figdata.CurrentImageSet).data{3}))
                previousBtn.Enable = 'off';
                nextBtn.Enable = 'off';
            else
                previousBtn.Enable = 'on';
                nextBtn.Enable = 'on';
            end
            startBtn.Enable = 'on';
            endBtn.Enable = 'on';
            setSelect.Enable = 'on';
            
            hSlider.Enable = 'on';
            hSlider.Value = 55;
            if isempty(findobj(haxes.Children, 'Type','Text'))
                haxes.HitTest = 'on';
                hzoom.HitTest = 'on';
            else
                haxes.HitTest = 'off';
                hzoom.HitTest = 'off';
            end
            if isnan(points.(figdata.CurrentImageSet).data{5}(figdata.CurrentInd))
                hzoom.HitTest = 'off';
                haxes.HitTest = 'off';
            end
            
            if isnan(points.(figdata.CurrentImageSet).data{3}(figdata.CurrentInd))
                xText.String = 'x = ';
                yText.String = 'y = ';
                hRemove.Enable = 'off';
            else
                xText.String = ['x = ' num2str(points.(figdata.CurrentImageSet).data{3}(figdata.CurrentInd))];
                yText.String = ['y = ' num2str(points.(figdata.CurrentImageSet).data{4}(figdata.CurrentInd))];
                hRemove.Enable = 'on';
            end
            frameText.String = ['Frame ' num2str(points.(figdata.CurrentImageSet).data{1}(figdata.CurrentInd))];
            if ~isnat(points.(figdata.CurrentImageSet).data{10}(figdata.CurrentInd))
                gpsTimeText.String = datestr(points.(figdata.CurrentImageSet).data{10}(figdata.CurrentInd), 'HH:MM:SS.FFF');
            else
                gpsTimeText.String = [];
            end
            utcTimeText.String = datestr(points.(figdata.CurrentImageSet).data{2}(figdata.CurrentInd), 'HH:MM:SS.FFF');
            if ~isnan(points.(figdata.CurrentImageSet).data{5}(figdata.CurrentInd))
                latText.String = ['lat = ' num2str(points.(figdata.CurrentImageSet).data{5}(figdata.CurrentInd))];
                lonText.String = ['lon = ' num2str(points.(figdata.CurrentImageSet).data{6}(figdata.CurrentInd))];
                xsText.String = ['x = ' num2str(points.(figdata.CurrentImageSet).data{7}(figdata.CurrentInd))];
                ysText.String = ['y = ' num2str(points.(figdata.CurrentImageSet).data{8}(figdata.CurrentInd))];
                zsText.String = ['z = ' num2str(points.(figdata.CurrentImageSet).data{9}(figdata.CurrentInd))];
            else
                latText.String = 'lat = ';
                lonText.String = 'lon = ';
                xsText.String = 'x = ';
                ysText.String = 'y = ';
                zsText.String = 'z = ';
            end
            
            if exist('points', 'var')
                setSelect.String = cellfun(@(str) str(5:end), fieldnames(points), 'UniformOutput', 0);
                setSelect.Value = find(strcmp(setSelect.String, figdata.CurrentImageSet(5:end)));
                setSurvey.String = points.(figdata.CurrentImageSet).file{3};
            end
            
            fieldNames = fieldnames(points);
            noExportFlag = zeros(length(fieldNames), 1);
            for i = 1:length(fieldNames)
                if all(isnan(points.(fieldNames{i}).data{3}))
                    noExportFlag(i) = 1;
                end
            end
            if all(noExportFlag)
                exportBtn.Enable = 'off';
                hPlotPoints.Enable = 'off';
                hRectify.Enable = 'off';
            else
                exportBtn.Enable = 'on';
                hPlotPoints.Enable = 'on';
                hRectify.Enable = 'on';
            end
            
            setSurvey.String = points.(figdata.CurrentImageSet).file{3};
            
        elseif strcmp(flag, 'REMOVESET_2')
            figdata.XCPDefault = 512;
            figdata.XCPDefault = 384;
            figdata.XCP = figdata.XCPDefault;
            figdata.YCP = figdata.YCPDefault;
            figdata.ImWidth = 1024;
            figdata.ImHeight = 768;
            figdata.CameraSelectVal = 1;
            figdata.CameraSelectStr = '';
            figdata.FrameRate = 30;
            figdata.BitDepth = 14;
            figdata.CurrentInd = 1;
            figdata.CameraType = 'IR';
            
            saveBtn.Enable = 'off';
            saveasBtn.Enable = 'off';
            playBtn.Enable = 'off';
            pauseBtn.Enable = 'off';
            ffBtn.Enable = 'off';
            rwBtn.Enable = 'off';
            stepb1Btn.Enable = 'off';
            stepf1Btn.Enable = 'off';
            stepf10Btn.Enable = 'off';
            stepb10Btn.Enable = 'off';
            stepf100Btn.Enable = 'off';
            stepb100Btn.Enable = 'off';
            previousBtn.Enable = 'off';
            nextBtn.Enable = 'off';
            startBtn.Enable = 'off';
            endBtn.Enable = 'off';
            setSelect.Value = 1;
            setSelect.String =  ' ';
            setSelect.Enable = 'off';
            removeSetBtn.Enable = 'off';
            
            hSlider.Enable = 'off';
            hSlider.Value = 55;
            
            haxes.HitTest = 'off';
            hzoom.HitTest = 'off';
            
            xText.String = 'x = ';
            yText.String = 'y = ';
            hRemove.Enable = 'off';

            frameText.String = [];
            gpsTimeText.String = [];
            
            utcTimeText.String = [];
            latText.String = 'lat = ';
            lonText.String = 'lon = ';
            xsText.String = 'x = ';
            ysText.String = 'y = ';
            zsText.String = 'z = ';
            
            setSurvey.String = [];
            
            exportBtn.Enable = 'off';
            hPlotPoints.Enable = 'off';
            hRectify.Enable = 'off';
                
        elseif strcmp(flag, 'PLAY_Start')
            figdata.AlreadyRunning = 1;
            figdata.XCP = figdata.XCPDefault;
            figdata.YCP = figdata.YCPDefault;
            
            saveBtn.Enable = 'off';
            saveasBtn.Enable = 'off';
            exportBtn.Enable = 'off';
            hPlotPoints.Enable = 'off';
            hRectify.Enable = 'off';
            loadRawBtn.Enable = 'off';
            loadMatBtn.Enable = 'off';
            pauseBtn.Enable = 'on';
            stepb1Btn.Enable = 'off';
            stepf1Btn.Enable = 'off';
            stepf10Btn.Enable = 'off';
            stepb10Btn.Enable = 'off';
            stepf100Btn.Enable = 'off';
            stepb100Btn.Enable = 'off';
            previousBtn.Enable = 'off';
            nextBtn.Enable = 'off';
            startBtn.Enable = 'off';
            endBtn.Enable = 'off';
            setSelect.Enable = 'off';
            removeSetBtn.Enable = 'off';
            
            hSlider.Value = 55;
            haxes.HitTest = 'off';
            hzoom.HitTest = 'off';
            
            xText.String = 'x = ';
            yText.String = 'y = ';
            latText.String = 'lat = ';
            lonText.String = 'lon = ';
            xsText.String = 'x = ';
            ysText.String = 'y = ';
            zsText.String = 'z = ';
            frameText.String = 'Frame ...';
            gpsTimeText.String = '';
            utcTimeText.String = '';
        elseif strcmp(flag, 'PLAY_End')
            figdata.PauseFlag = 0;
            figdata.AlreadyRunning = 0;
            
            saveBtn.Enable = 'on';
            saveasBtn.Enable = 'on';
            loadRawBtn.Enable = 'on';
            loadMatBtn.Enable = 'on';
            pauseBtn.Enable = 'off';
            stepb1Btn.Enable = 'on';
            stepf1Btn.Enable = 'on';
            stepf10Btn.Enable = 'on';
            stepb10Btn.Enable = 'on';
            stepf100Btn.Enable = 'on';
            stepb100Btn.Enable = 'on';
            if all(isnan(points.(figdata.CurrentImageSet).data{3}))
                previousBtn.Enable = 'off';
                nextBtn.Enable = 'off';
            else
                previousBtn.Enable = 'on';
                nextBtn.Enable = 'on';
            end
            startBtn.Enable = 'on';
            endBtn.Enable = 'on';
            setSelect.Enable = 'on';
            removeSetBtn.Enable = 'on';
            
            if isempty(findobj(haxes.Children, 'Type','Text'))
                haxes.HitTest = 'on';
                hzoom.HitTest = 'on';
            else
                haxes.HitTest = 'off';
                hzoom.HitTest = 'off';
            end
            if isnan(points.(figdata.CurrentImageSet).data{5}(figdata.CurrentInd))
                hzoom.HitTest = 'off';
                haxes.HitTest = 'off';
            end
            
            frameText.String = ['Frame ' num2str(points.(figdata.CurrentImageSet).data{1}(figdata.CurrentInd))];
            if ~isnat(points.(figdata.CurrentImageSet).data{10}(figdata.CurrentInd))
                gpsTimeText.String = datestr(points.(figdata.CurrentImageSet).data{10}(figdata.CurrentInd), 'HH:MM:SS.FFF');
            else
                gpsTimeText.String = [];
            end
            utcTimeText.String = datestr(points.(figdata.CurrentImageSet).data{2}(figdata.CurrentInd), 'HH:MM:SS.FFF');
            if isnan(points.(figdata.CurrentImageSet).data{3}(figdata.CurrentInd))
                xText.String = 'x = ';
                yText.String = 'y = ';
                hRemove.Enable = 'off';
            else
                xText.String = ['x = ' num2str(points.(figdata.CurrentImageSet).data{3}(figdata.CurrentInd))];
                yText.String = ['y = ' num2str(points.(figdata.CurrentImageSet).data{4}(figdata.CurrentInd))];
                hRemove.Enable = 'on';
            end
            if ~isnan(points.(figdata.CurrentImageSet).data{5}(figdata.CurrentInd))
                latText.String = ['lat = ' num2str(points.(figdata.CurrentImageSet).data{5}(figdata.CurrentInd))];
                lonText.String = ['lon = ' num2str(points.(figdata.CurrentImageSet).data{6}(figdata.CurrentInd))];
                xsText.String = ['x = ' num2str(points.(figdata.CurrentImageSet).data{7}(figdata.CurrentInd))];
                ysText.String = ['y = ' num2str(points.(figdata.CurrentImageSet).data{8}(figdata.CurrentInd))];
                zsText.String = ['z = ' num2str(points.(figdata.CurrentImageSet).data{9}(figdata.CurrentInd))];
            else
                latText.String = 'lat = ';
                lonText.String = 'lon = ';
                xsText.String = 'x = ';
                ysText.String = 'y = ';
                zsText.String = 'z = ';
            end
            
            fieldNames = fieldnames(points);
            noExportFlag = zeros(length(fieldNames), 1);
            for i = 1:length(fieldNames)
                if all(isnan(points.(fieldNames{i}).data{3}))
                    noExportFlag(i) = 1;
                end
            end
            if all(noExportFlag)
                exportBtn.Enable = 'off';
                hPlotPoints.Enable = 'off';
                hRectify.Enable = 'off';
            else
                exportBtn.Enable = 'on';
                hPlotPoints.Enable = 'on';
                hRectify.Enable = 'on';
            end
            
        elseif strcmp(flag, 'STEP')
            
            if isempty(findobj(haxes.Children, 'Type','Text'))
                haxes.HitTest = 'on';
                hzoom.HitTest = 'on';
            else
                haxes.HitTest = 'off';
                hzoom.HitTest = 'off';
            end
            if isnan(points.(figdata.CurrentImageSet).data{5}(figdata.CurrentInd))
                hzoom.HitTest = 'off';
                haxes.HitTest = 'off';
            end
            
            frameText.String = ['Frame ' num2str(points.(figdata.CurrentImageSet).data{1}(figdata.CurrentInd))];
            if ~isnat(points.(figdata.CurrentImageSet).data{10}(figdata.CurrentInd))
                gpsTimeText.String = datestr(points.(figdata.CurrentImageSet).data{10}(figdata.CurrentInd), 'HH:MM:SS.FFF');
            else
                gpsTimeText.String = [];
            end
            utcTimeText.String = datestr(points.(figdata.CurrentImageSet).data{2}(figdata.CurrentInd), 'HH:MM:SS.FFF');
            if isnan(points.(figdata.CurrentImageSet).data{3}(figdata.CurrentInd))
                xText.String = 'x = ';
                yText.String = 'y = ';
                hRemove.Enable = 'off';
            else
                xText.String = ['x = ' num2str(points.(figdata.CurrentImageSet).data{3}(figdata.CurrentInd))];
                yText.String = ['y = ' num2str(points.(figdata.CurrentImageSet).data{4}(figdata.CurrentInd))];
                hRemove.Enable = 'on';
            end
            if ~isnan(points.(figdata.CurrentImageSet).data{5}(figdata.CurrentInd))
                latText.String = ['lat = ' num2str(points.(figdata.CurrentImageSet).data{5}(figdata.CurrentInd))];
                lonText.String = ['lon = ' num2str(points.(figdata.CurrentImageSet).data{6}(figdata.CurrentInd))];
                xsText.String = ['x = ' num2str(points.(figdata.CurrentImageSet).data{7}(figdata.CurrentInd))];
                ysText.String = ['y = ' num2str(points.(figdata.CurrentImageSet).data{8}(figdata.CurrentInd))];
                zsText.String = ['z = ' num2str(points.(figdata.CurrentImageSet).data{9}(figdata.CurrentInd))];
            else
                latText.String = 'lat = ';
                lonText.String = 'lon = ';
                xsText.String = 'x = ';
                ysText.String = 'y = ';
                zsText.String = 'z = ';
            end
            
            fieldNames = fieldnames(points);
            noExportFlag = zeros(length(fieldNames), 1);
            for i = 1:length(fieldNames)
                if all(isnan(points.(fieldNames{i}).data{3}))
                    noExportFlag(i) = 1;
                end
            end
            if all(noExportFlag)
                exportBtn.Enable = 'off';
                hPlotPoints.Enable = 'off';
                hRectify.Enable = 'off';
            else
                exportBtn.Enable = 'on';
                hPlotPoints.Enable = 'on';
                hRectify.Enable = 'on';
            end
        end
        
    end % end function SetGUIValues(flag)

    function PlotSelectedPoints(tiffFileName, frameNum, xPixel, yPixel, lat, lon)

        apiKey = 'AIzaSyC3i9XCFhezhOoUDPEIyRuwRvHKbK2N47A';

        hfig1 = figure('Units', 'normalized',...
                       'OuterPosition', [0.025 0.1 0.95 0.85],...
                       'DockControls', 'off',...
                       'WindowStyle', 'modal',...
                       'MenuBar', 'none',...
                       'ToolBar', 'none',...
                       'NumberTitle', 'off',...
                       'Name', 'Point Picker 1.0',...
                       'Color', GUIColors.Figure);
    
        haxes1 = axes('Parent', hfig1,...
                      'Units', 'normalized',...
                      'Position', [0.01 0.1 0.48 0.8],...
                      'Color',GUIColors.Axes,...
                      'XColorMode', 'manual',...
                      'XColor', GUIColors.Figure,...
                      'XTickMode', 'manual',...
                      'XTick', [],...
                      'XLim',[0 figdata.ImWidth],...
                      'YColorMode', 'manual',...
                      'YColor', GUIColors.Figure,...
                      'YTickMode', 'manual',...
                      'YTick', [],...
                      'YDir','reverse',...
                      'YLim',[0 figdata.ImHeight],...
                      'CLimMode','Manual',...
                      'CLim',[0 2^figdata.BitDepth],...
                      'NextPlot', 'replacechildren',...
                      'HitTest','off');
        haxes1.Title.String = 'Camera View';
        haxes1.Title.Color = GUIColors.Text;
        colormap(haxes1,bone(256));
              
        haxes2 = axes('Parent', hfig1,...
                      'Units', 'normalized',...
                      'Position', [0.51 0.1 0.48 0.8],...
                      'Color',GUIColors.Axes,...
                      'XColorMode', 'manual',...
                      'XColor', GUIColors.Figure,...
                      'XTickMode', 'manual',...
                      'XTick', [],...
                      'XLim',[0 figdata.ImWidth],...
                      'YColorMode', 'manual',...
                      'YColor', GUIColors.Figure,...
                      'YTickMode', 'manual',...
                      'YTick', [],...
                      'YLim',[0 figdata.ImHeight],...
                      'HitTest','off');
        haxes2.Title.String = 'Earth View';
        haxes2.Title.Color = GUIColors.Text;
    
        PlotCameraView()
    
        PlotEarthView()
        
        uiwait(hfig1)
    
        function PlotCameraView()
            errorFlag = 0;
            try
                tiffData = imread(tiffFileName, 'tif');
                if strcmp(figdata.CameraType, 'IR') == 1
                elseif strcmp(figdata.CameraType, 'EO') == 1
                    tiffData = demosaic(tiffData.*2^(16-figdata.BitDepth), 'rggb');
                end
            catch
                errorFlag = 1;
            end
    
            if errorFlag == 0
                imagesc(haxes1, tiffData);
                hold(haxes1, 'on')
                    plot(haxes1, xPixel, yPixel, 'sg', 'LineWidth', 2, 'MarkerFaceColor', 'g')
                hold(haxes1, 'off')
            else
                text(haxes1, 400, 384, {'Image Missing';['Frame ' num2str(frameNum(1))]},'Color', 'red', 'FontSize', 16)
            end
        
        end

        function PlotEarthView()
        
            if length(lat) >= 2
            
                text(haxes2, 200, 384, 'Loading Google Map ...','Color', 'green', 'FontSize', 16)
            
                height = 640;
                width = 640;
                scale = 2;
                mapType = 'satellite';
        
                preamble = 'http://maps.googleapis.com/maps/api/staticmap?';
                scale = ['&scale=' num2str(scale)];
                size = ['&size=' num2str(width) 'x' num2str(height)];
                maptype = ['&maptype=' mapType ];
                markers = '&markers=icon:https://maps.google.com/mapfiles/kml/paddle/grn-blank-lv.png%7C';
                for idx = 1:length(lat)
                    if idx < length(lat)
                        markers = [markers num2str(lat(idx),10) ',' num2str(lon(idx),10) '%7C'];
                    else
                        markers = [markers num2str(lat(idx),10) ',' num2str(lon(idx),10)];
                    end
                end
                format = '&format=png';
                key = ['&key=' apiKey];
                sensor = '&sensor=false';
                url = [preamble size scale maptype format markers sensor key];
       
                [M, Mcolor] = webread(url);
       
                imshow(M, Mcolor, 'Parent', haxes2)
                haxes2.Title.String = 'Earth View';
                haxes2.Title.Color = GUIColors.Text;
            else
                text(haxes2, 200, 384, 'Need 2 or more points to plot in earth view.','Color', 'red', 'FontSize', 16)
            end
        
        end

    end

    function RectifyImageGUI
        
        
        %% Set up data to be used in GUI
        
        fieldNames = fieldnames(points);
        setNum = [];
        frameNum = [];
        xPixel = [];
        yPixel = [];
        XGPS = [];
        YGPS = [];
        ZGPS = [];
        for i = 1:length(fieldNames)
            fileInd = ~isnan(points.(fieldNames{i}).data{3});
            frameNum = [frameNum; points.(fieldNames{i}).data{1}(fileInd)];
            xPixel = [xPixel; points.(fieldNames{i}).data{3}(fileInd)];
            yPixel = [yPixel; points.(fieldNames{i}).data{4}(fileInd)];
            XGPS = [XGPS; points.(fieldNames{i}).data{7}(fileInd)];
            YGPS = [YGPS; points.(fieldNames{i}).data{8}(fileInd)];
            ZGPS = [ZGPS; points.(fieldNames{i}).data{9}(fileInd)];
            setNum = [setNum; ones(sum(fileInd),1).*i];
        end
        
        % convert GCPs to pixel loactions if a pose was computed
        xPixGPS = nan(length(XGPS),1);
        yPixGPS = nan(length(XGPS),1);
        if ~isempty(rectParams.XPose) && ~isempty(rectParams.YPose) && ~isempty(rectParams.ZPose) && ~isempty(rectParams.PitchPose) && ~isempty(rectParams.RollPose) && ~isempty(rectParams.AzimuthPose) 
            [xPixGPS, yPixGPS] = XYZ2UV(XGPS, YGPS, ZGPS, rectParams);
        end
        
        % convert pixel loactions to X,Y if a pose was computed
        xGPSPix = nan(length(xPixel),1);
        yGPSPix = nan(length(yPixel),1);
        if ~isempty(rectParams.XPose) && ~isempty(rectParams.YPose) && ~isempty(rectParams.ZPose) && ~isempty(rectParams.PitchPose) && ~isempty(rectParams.RollPose) && ~isempty(rectParams.AzimuthPose) 
            [xGPSPix, yGPSPix, ~] = UV2XYZ(xPixel, yPixel, ZGPS, rectParams);
        end
        
        deleteInd = [];
        %deleteMarker = 1;
        deleteMarker = [];
        deleteStack = cell(0,0);
        
        checkParams = zeros(1,16);
    
        tiffFileName = [points.(fieldNames{setNum(1)}).file{2} points.(fieldNames{setNum(1)}).file{1}(1:end-length(num2str(frameNum(1)))) num2str(frameNum(1))];
        errorFlag = 0;
        try
            tiffData = imread(tiffFileName, 'tif');
        catch
            errorFlag = 1;
        end
        
        GUIHandles = struct('input', [], 'check', []);

        %% Set Figure and Axes
        % ====================
        hfig2 = figure('Units', 'normalized',...
                       'OuterPosition', [0.025 0.1 0.95 0.85],...
                       'DockControls', 'off',...
                       'MenuBar', 'none',...
                       'ToolBar', 'none',...
                       'NumberTitle', 'off',...
                       'Name', 'Point Picker 1.0',...
                       'WindowStyle', 'normal',...
                       'Color', GUIColors.Figure,...
                       'Visible', 'off',...
                       'SizeChangedFcn', @ADJUSTFIGURE2,...
                       'DeleteFcn', @REMOVEPOINTSFROMMAIN);
                   
        % Dimensions
        rectSize = hfig2.Position;
        rectWidth = rectSize(3).*ssW;
        rectHeight = rectSize(4).*ssH;
        axesHorOffset = 4;
        axesBottomOffset = 2;
        axesTopOffset = 4;
        loadRectHeight = 2.75;
        loadRectBtnHeight = 2;
        loadRectBtnWidth = 24;
        loadRectBtnOffset = 3;
        editHeight = 1.75;
        editWidth = 20;
        txtWidth = 10;
        endWidth = 5;
        startOffset = 1.5;
        vertOffset = 0.75;
        horOffset1 = 1;
        horOffset2 = 5;
        dispValWidth = 25;
                                            
        haxes3 = axes('Parent', hfig2,...
                      'Units', 'normalized',...
                      'Position', [axesHorOffset/rectWidth...
                                   axesBottomOffset/rectHeight...
                                   (1-(3*axesHorOffset+editWidth+txtWidth+endWidth)/(rectWidth))/2.0...
                                   1-(axesTopOffset+axesBottomOffset+loadRectHeight)/rectHeight],...
                      'Color',GUIColors.Axes,...
                      'XColorMode', 'manual',...
                      'XColor', GUIColors.Figure,...
                      'XTickMode', 'manual',...
                      'XTick', [],...
                      'XLim',[0 figdata.ImWidth],...
                      'YColorMode', 'manual',...
                      'YColor', GUIColors.Figure,...
                      'YTickMode', 'manual',...
                      'YTick', [],...
                      'YDir','reverse',...
                      'YLim',[0 figdata.ImHeight],...
                      'CLimMode','Manual',...
                      'CLim',[0 2^figdata.BitDepth],...
                      'NextPlot', 'replacechildren',...
                      'HitTest','off');
        haxes3.Title.String = {'Unrectified';' '};
        haxes3.Title.Color = GUIColors.Text;
        haxes3.Title.FontSize = 10;
                  
        haxes4 = axes('Parent', hfig2,...
                      'Units', 'normalized',...
                      'Position', [2*axesHorOffset/rectWidth+haxes3.Position(3)...
                                   axesBottomOffset/rectHeight...
                                   (1-(3*axesHorOffset+editWidth+txtWidth+endWidth)/(rectWidth))/2.0...
                                   1-(axesTopOffset+axesBottomOffset+loadRectHeight)/rectHeight],...
                      'Color',GUIColors.Axes,...
                      'XColorMode', 'manual',...
                      'XColor', GUIColors.Figure,...
                      'XTickMode', 'manual',...
                      'XTick', [],...
                      'YColorMode', 'manual',...
                      'YColor', GUIColors.Figure,...
                      'YTickMode', 'manual',...
                      'YTick', [],...
                      'YDir', 'normal',...
                      'CLimMode','Manual',...
                      'CLim',[0 2^figdata.BitDepth],...
                      'NextPlot', 'replacechildren',...
                      'HitTest','off');
                  
        haxes4.Title.String = {'Rectified';' '};
        haxes4.Title.Color = GUIColors.Text;
        haxes4.Title.FontSize = 10;
                  
        colormap(haxes3, bone(256));
        colormap(haxes4, bone(256));
        
        %% Set Top Panel
        % ==============
        
        % Load, Save, and Rectify
        % =======================
        hpanLoadRect = uipanel(hfig2, 'Position', [0 ... % left
                                                   (1-(loadRectHeight/rectHeight))... % bottom
                                                   1-(2*horOffset1+txtWidth+editWidth+endWidth)/rectWidth... % width
                                                   (loadRectHeight/rectHeight)],... % height; old = [0 0.95 0.6 0.05]
                                      'BackgroundColor', GUIColors.LowerPanel,...
                                      'BorderWidth', 1,...
                                      'HighlightColor', GUIColors.LowerHighlight,...
                                      'ShadowColor', GUIColors.LowerShadow);
                 
          loadCamCalBtn = uicontrol(hpanLoadRect, 'Style', 'pushbutton',...
                                      'String', 'Load Calibration',...
                                      'Units', 'normalized',...
                                      'Position', [(loadRectBtnOffset/(hpanLoadRect.Position(3).*rectWidth))... % left
                                                   ((loadRectHeight-loadRectBtnHeight)/2)/loadRectHeight... % bottom
                                                   (loadRectBtnWidth/(hpanLoadRect.Position(3).*rectWidth))... % width
                                                   loadRectBtnHeight/loadRectHeight],... % height;
                                      'FontWeight', 'bold',...
                                      'BackgroundColor', GUIColors.ButtonColor,...
                                      'ForegroundColor', GUIColors.Text,...
                                      'Callback', @LOADCALIBRATION);
                                   
          loadPoseBtn = uicontrol(hpanLoadRect, 'Style', 'pushbutton',...
                                   'String', 'Load Extrinsics',...
                                   'Units', 'normalized',...
                                   'Position', [loadCamCalBtn.Position(1)+loadCamCalBtn.Position(3)+(loadRectBtnOffset/(hpanLoadRect.Position(3).*rectWidth))... % left
                                                ((loadRectHeight-loadRectBtnHeight)/2)/loadRectHeight... % bottom
                                                (loadRectBtnWidth/(hpanLoadRect.Position(3).*rectWidth))... % width
                                                loadRectBtnHeight/loadRectHeight],... % height; 
                                   'FontWeight', 'bold',...
                                   'BackgroundColor', GUIColors.ButtonColor,...
                                   'ForegroundColor', GUIColors.Text,...
                                   'Callback', @LOADCAMERAPOSE);
                               
         saveRectBtn = uicontrol(hpanLoadRect, 'Style', 'pushbutton',...
                                   'String', 'Save Rectification',...
                                   'Units', 'normalized',...
                                   'Position', [loadPoseBtn.Position(1)+loadPoseBtn.Position(3)+(loadRectBtnOffset/(hpanLoadRect.Position(3).*rectWidth))... % left
                                                ((loadRectHeight-loadRectBtnHeight)/2)/loadRectHeight... % bottom
                                                (loadRectBtnWidth/(hpanLoadRect.Position(3).*rectWidth))... % width
                                                loadRectBtnHeight/loadRectHeight],... % height; 
                                   'FontWeight', 'bold',...
                                   'BackgroundColor', GUIColors.ButtonColor,...
                                   'ForegroundColor', GUIColors.Text,...
                                   'Enable', 'off',...
                                   'Callback', @SAVERECTIFY);
                                
         computePoseBtn = uicontrol(hpanLoadRect, 'Style', 'pushbutton',...
                               'String', 'Compute Extrinsics',...
                               'Units', 'normalized',...
                               'Position', [saveRectBtn.Position(1)+saveRectBtn.Position(3)+(loadRectBtnOffset/(hpanLoadRect.Position(3).*rectWidth))... % left
                                            ((loadRectHeight-loadRectBtnHeight)/2)/loadRectHeight... % bottom
                                            (loadRectBtnWidth/(hpanLoadRect.Position(3).*rectWidth))... % width
                                            loadRectBtnHeight/loadRectHeight],... % height; 
                               'FontWeight', 'bold',...
                               'BackgroundColor', GUIColors.ButtonColor,...
                               'ForegroundColor', GUIColors.Text,...
                               'Enable', 'off',...
                               'Callback', @COMPUTEPOSE);
                           
        plotRectBtn = uicontrol(hpanLoadRect, 'Style', 'pushbutton',...
                               'String', 'Plot Rectifiy',...
                               'Units', 'normalized',...
                               'Position', [computePoseBtn.Position(1)+computePoseBtn.Position(3)+(loadRectBtnOffset/(hpanLoadRect.Position(3).*rectWidth))... % left
                                            ((loadRectHeight-loadRectBtnHeight)/2)/loadRectHeight... % bottom
                                            (loadRectBtnWidth/(hpanLoadRect.Position(3).*rectWidth))... % width
                                            loadRectBtnHeight/loadRectHeight],... % height; 
                               'FontWeight', 'bold',...
                               'BackgroundColor', GUIColors.ButtonColor,...
                               'ForegroundColor', GUIColors.Text,...
                               'Enable', 'off',...
                               'Callback', @PLOTRECTIFY);
                           
        deleteGCPBtn = uicontrol(hpanLoadRect, 'Style', 'pushbutton',...
                                 'String', 'Delete GCP',...
                                 'Units', 'normalized',...
                                 'Position', [1-((2*loadRectBtnOffset+2*loadRectBtnWidth)/(hpanLoadRect.Position(3).*rectWidth))... % left
                                              ((loadRectHeight-loadRectBtnHeight)/2)/loadRectHeight... % bottom
                                              (loadRectBtnWidth/(hpanLoadRect.Position(3).*rectWidth))... % width
                                              loadRectBtnHeight/loadRectHeight],... % height; old = [0.02 0.1 0.176 0.8]
                                 'FontWeight', 'bold',...
                                 'BackgroundColor', GUIColors.ButtonColor,...
                                 'ForegroundColor', GUIColors.Text,...
                                 'Enable', 'off',...
                                 'Callback', @DELETE);
                             
        undoGCPBtn = uicontrol(hpanLoadRect, 'Style', 'pushbutton',...
                                 'String', 'Undo Delete',...
                                 'Units', 'normalized',...
                                 'Position', [1-((loadRectBtnOffset+loadRectBtnWidth)/(hpanLoadRect.Position(3).*rectWidth))... % left
                                              ((loadRectHeight-loadRectBtnHeight)/2)/loadRectHeight... % bottom
                                              (loadRectBtnWidth/(hpanLoadRect.Position(3).*rectWidth))... % width
                                              loadRectBtnHeight/loadRectHeight],... % height; old = [0.02 0.1 0.176 0.8]
                                 'FontWeight', 'bold',...
                                 'BackgroundColor', GUIColors.ButtonColor,...
                                 'ForegroundColor', GUIColors.Text,...
                                 'Enable', 'off',...
                                 'Callback', @UNDO);
       
                           
        %% Set Side Panel
        %================
        
        % Camera Extrinsic parameter panel          
        % ================================
        hpanCamEx = uipanel(hfig2, 'Position', [1-(2*horOffset1+txtWidth+editWidth+endWidth)/rectWidth...
                                                1-(6*editHeight+6*vertOffset+startOffset)/rectHeight...
                                                (2*horOffset1+txtWidth+editWidth+endWidth)/rectWidth...
                                                (6*editHeight+6*vertOffset+startOffset)/rectHeight],...
                                  'Title', 'Estimated Extrinsic Parameters',...
                                  'FontWeight', 'bold',...
                                  'BackgroundColor', GUIColors.UpperPanel,...
                                  'BorderWidth', 1,...
                                  'HighlightColor', GUIColors.UpperHighlight,...
                                  'ShadowColor', GUIColors.UpperShadow);
        
        % Camera X Input
        % ==============
        GUIHandles.input.hXIn = uicontrol(hpanCamEx, 'Style', 'edit',...
                                        'String', num2str(rectParams.X, '%.6g'),...
                                        'Units', 'normalized',...
                                        'Position', [(horOffset1+txtWidth)/(2*horOffset1+txtWidth+editWidth+endWidth)...
                                                     (5*editHeight+6*vertOffset)/(6*editHeight+6*vertOffset+startOffset)...
                                                     editWidth/(2*horOffset1+txtWidth+editWidth+endWidth)...
                                                     editHeight/(6*editHeight+6*vertOffset+startOffset)],...
                                        'FontWeight', 'bold',...
                                        'BackgroundColor', GUIColors.ButtonColor,...
                                        'ForegroundColor', GUIColors.Text,...
                                        'Enable', 'on',...
                                        'Callback', @SETINPUTCALLBACK);
                                
        hXText = annotation(hpanCamEx, 'textbox',...
                                         'LineStyle', 'none',...
                                         'String', 'X = ',...
                                         'BackgroundColor', GUIColors.UpperPanel,...
                                         'Units', 'normalized',...
                                         'HorizontalAlignment','right',...
                                         'VerticalAlignment','middle',...
                                         'Position', [horOffset1/(2*horOffset1+txtWidth+editWidth+endWidth)...
                                                      (5*editHeight+6*vertOffset)/(6*editHeight+6*vertOffset+startOffset)...
                                                      txtWidth/(2*horOffset1+txtWidth+editWidth+endWidth)...
                                                      editHeight/(6*editHeight+6*vertOffset+startOffset)]);
      
        % Camera Y Input
        % ==============
        GUIHandles.input.hYIn = uicontrol(hpanCamEx, 'Style', 'edit',...
                                        'String', num2str(rectParams.Y, '%.6g'),...
                                        'Units', 'normalized',...
                                        'Position', [(horOffset1+txtWidth)/(2*horOffset1+txtWidth+editWidth+endWidth)...
                                                     (4*editHeight+5*vertOffset)/(6*editHeight+6*vertOffset+startOffset)...
                                                     editWidth/(2*horOffset1+txtWidth+editWidth+endWidth)...
                                                     editHeight/(6*editHeight+6*vertOffset+startOffset)],...
                                        'FontWeight', 'bold',...
                                        'BackgroundColor', GUIColors.ButtonColor,...
                                        'ForegroundColor', GUIColors.Text,...
                                        'Enable', 'on',...
                                        'Callback', @SETINPUTCALLBACK);
                                
        hYText = annotation(hpanCamEx, 'textbox',...
                                         'LineStyle', 'none',...
                                         'String', 'Y = ',...
                                         'BackgroundColor', GUIColors.UpperPanel,...
                                         'Units', 'normalized',...
                                         'HorizontalAlignment','right',...
                                         'VerticalAlignment','middle',...
                                         'Position', [horOffset1/(2*horOffset1+txtWidth+editWidth+endWidth)...
                                                      (4*editHeight+5*vertOffset)/(6*editHeight+6*vertOffset+startOffset)...
                                                      txtWidth/(2*horOffset1+txtWidth+editWidth+endWidth)...
                                                      editHeight/(6*editHeight+6*vertOffset+startOffset)]);
                                    
        % Camera Z Input
        % ==============                              
        GUIHandles.input.hZIn = uicontrol(hpanCamEx, 'Style', 'edit',...
                                        'String', num2str(rectParams.Z, '%.5g'),...
                                        'Units', 'normalized',...
                                        'Position', [(horOffset1+txtWidth)/(2*horOffset1+txtWidth+editWidth+endWidth)...
                                                     (3*editHeight+4*vertOffset)/(6*editHeight+6*vertOffset+startOffset)...
                                                     editWidth/(2*horOffset1+txtWidth+editWidth+endWidth)...
                                                     editHeight/(6*editHeight+6*vertOffset+startOffset)],...
                                        'FontWeight', 'bold',...
                                        'BackgroundColor', GUIColors.ButtonColor,...
                                        'ForegroundColor', GUIColors.Text,...
                                        'Enable', 'on',...
                                        'Callback', @SETINPUTCALLBACK);
                                
        hZText = annotation(hpanCamEx, 'textbox',...
                                         'LineStyle', 'none',...
                                         'String', 'Z = ',...
                                         'BackgroundColor', GUIColors.UpperPanel,...
                                         'Units', 'normalized',...
                                         'HorizontalAlignment','right',...
                                         'VerticalAlignment','middle',...
                                         'Position', [horOffset1/(2*horOffset1+txtWidth+editWidth+endWidth)...
                                                      (3*editHeight+4*vertOffset)/(6*editHeight+6*vertOffset+startOffset)...
                                                      txtWidth/(2*horOffset1+txtWidth+editWidth+endWidth)...
                                                      editHeight/(6*editHeight+6*vertOffset+startOffset)]);
                                
                            
        % Camera Pitch Angle Input
        % ========================
        GUIHandles.input.hPitchIn = uicontrol(hpanCamEx, 'Style', 'edit',...
                                        'String', num2str(rectParams.Pitch, '%.3g'),...
                                        'Units', 'normalized',...
                                        'Position', [(horOffset1+txtWidth)/(2*horOffset1+txtWidth+editWidth+endWidth)...
                                                     (2*editHeight+3*vertOffset)/(6*editHeight+6*vertOffset+startOffset)...
                                                     editWidth/(2*horOffset1+txtWidth+editWidth+endWidth)...
                                                     editHeight/(6*editHeight+6*vertOffset+startOffset)],...
                                        'FontWeight', 'bold',...
                                        'BackgroundColor', GUIColors.ButtonColor,...
                                        'ForegroundColor', GUIColors.Text,...
                                        'Enable', 'on',...
                                        'Callback', @SETINPUTCALLBACK);
                                
        hPitchText = annotation(hpanCamEx, 'textbox',...
                                         'LineStyle', 'none',...
                                         'String', '\lambda = ',...
                                         'BackgroundColor', GUIColors.UpperPanel,...
                                         'Units', 'normalized',...
                                         'HorizontalAlignment','right',...
                                         'VerticalAlignment','middle',...
                                         'Position', [horOffset1/(2*horOffset1+txtWidth+editWidth+endWidth)...
                                                      (2*editHeight+3*vertOffset)/(6*editHeight+6*vertOffset+startOffset)...
                                                      txtWidth/(2*horOffset1+txtWidth+editWidth+endWidth)...
                                                      editHeight/(6*editHeight+6*vertOffset+startOffset)]);

       
        % Camera Roll Angle Input
        % =======================
        GUIHandles.input.hRollIn = uicontrol(hpanCamEx, 'Style', 'edit',...
                                         'String', num2str(rectParams.Roll, '%.3g'),...
                                         'Units', 'normalized',...
                                         'Position', [(horOffset1+txtWidth)/(2*horOffset1+txtWidth+editWidth+endWidth)...
                                                      (1*editHeight+2*vertOffset)/(6*editHeight+6*vertOffset+startOffset)...
                                                      editWidth/(2*horOffset1+txtWidth+editWidth+endWidth)...
                                                      editHeight/(6*editHeight+6*vertOffset+startOffset)],...
                                         'FontWeight', 'bold',...
                                         'BackgroundColor', GUIColors.ButtonColor,...
                                         'ForegroundColor', GUIColors.Text,...
                                         'Enable', 'on',...
                                         'Callback', @SETINPUTCALLBACK);
                                 
        hRollText = annotation(hpanCamEx, 'textbox',...
                                          'LineStyle', 'none',...
                                          'String', '\phi = ',...
                                          'BackgroundColor', GUIColors.UpperPanel,...
                                          'Units', 'normalized',...
                                          'HorizontalAlignment','right',...
                                          'VerticalAlignment','middle',...
                                          'Position', [horOffset1/(2*horOffset1+txtWidth+editWidth+endWidth)...
                                                       (1*editHeight+2*vertOffset)/(6*editHeight+6*vertOffset+startOffset)...
                                                       txtWidth/(2*horOffset1+txtWidth+editWidth+endWidth)...
                                                       editHeight/(6*editHeight+6*vertOffset+startOffset)]);

     
        % Camera Azimuth Input
        % ====================
        GUIHandles.input.hAzimuthIn = uicontrol(hpanCamEx, 'Style', 'edit',...
                                         'String', num2str(rectParams.Azimuth, '%.4g'),...
                                         'Units', 'normalized',...
                                         'Position', [(horOffset1+txtWidth)/(2*horOffset1+txtWidth+editWidth+endWidth)...
                                                      (0*editHeight+1*vertOffset)/(6*editHeight+6*vertOffset+startOffset)...
                                                      editWidth/(2*horOffset1+txtWidth+editWidth+endWidth)...
                                                      editHeight/(6*editHeight+6*vertOffset+startOffset)],...
                                         'FontWeight', 'bold',...
                                         'BackgroundColor', GUIColors.ButtonColor,...
                                         'ForegroundColor', GUIColors.Text,...
                                         'Enable', 'on',...
                                         'Callback', @SETINPUTCALLBACK);
                                 
        hAzimuthText = annotation(hpanCamEx, 'textbox',...
                                          'LineStyle', 'none',...
                                          'String', '\theta = ',...
                                          'BackgroundColor', GUIColors.UpperPanel,...
                                          'Units', 'normalized',...
                                          'HorizontalAlignment','right',...
                                          'VerticalAlignment','middle',...
                                          'Position', [horOffset1/(2*horOffset1+txtWidth+editWidth+endWidth)...
                                                       (0*editHeight+1*vertOffset)/(6*editHeight+6*vertOffset+startOffset)...
                                                       txtWidth/(2*horOffset1+txtWidth+editWidth+endWidth)...
                                                       editHeight/(6*editHeight+6*vertOffset+startOffset)]);

                                
        % Camera Intrinsic Parameters          
        % ===========================
        hpanCamIn = uipanel(hfig2, 'Position', [1-(2*horOffset1+txtWidth+editWidth+endWidth)/rectWidth...
                                                1-(10*editHeight+10*vertOffset+2*startOffset)/rectHeight...
                                                (2*horOffset1+txtWidth+editWidth+endWidth)/rectWidth...
                                                (4*editHeight+4*vertOffset+startOffset)/rectHeight],...
                                   'Title', 'Camera Intrinsic Parameters',...
                                   'FontWeight', 'bold',...
                                   'BackgroundColor', GUIColors.UpperPanel,...
                                   'BorderWidth', 1,...
                                   'HighlightColor', GUIColors.UpperHighlight,...
                                   'ShadowColor', GUIColors.UpperShadow);
                               
        % Focal length in images X direction
        % ==================================
        GUIHandles.input.hXFocIn = uicontrol(hpanCamIn, 'Style', 'edit',...
                                         'String', num2str(rectParams.Fx, '%.8g'),...
                                         'Units', 'normalized',...
                                         'Position', [(horOffset1+txtWidth)/(2*horOffset1+txtWidth+editWidth+endWidth)...
                                                      (3*editHeight+4*vertOffset)/(4*editHeight+4*vertOffset+startOffset)...
                                                      editWidth/(2*horOffset1+txtWidth+editWidth+endWidth)...
                                                      editHeight/(4*editHeight+4*vertOffset+startOffset)],...
                                         'FontWeight', 'bold',...
                                         'BackgroundColor', GUIColors.ButtonColor,...
                                         'ForegroundColor', GUIColors.Text,...
                                         'Enable', 'on',...
                                         'Callback', @SETINPUTCALLBACK);
                                 
        hXFocText = annotation(hpanCamIn, 'textbox',...
                                          'LineStyle', 'none',...
                                          'String', 'f_x = ',...
                                          'BackgroundColor', GUIColors.UpperPanel,...
                                          'Units', 'normalized',...
                                          'HorizontalAlignment','right',...
                                          'VerticalAlignment','middle',...
                                          'Position', [horOffset1/(2*horOffset1+txtWidth+editWidth+endWidth)...
                                                       (3*editHeight+4*vertOffset)/(4*editHeight+4*vertOffset+startOffset)...
                                                       txtWidth/(2*horOffset1+txtWidth+editWidth+endWidth)...
                                                       editHeight/(4*editHeight+4*vertOffset+startOffset)]);
                                                   
        % Focal length in images Y direction
        % ==================================
        GUIHandles.input.hYFocIn = uicontrol(hpanCamIn, 'Style', 'edit',...
                                         'String', num2str(rectParams.Fy, '%.8g'),...
                                         'Units', 'normalized',...
                                         'Position', [(horOffset1+txtWidth)/(2*horOffset1+txtWidth+editWidth+endWidth)...
                                                      (2*editHeight+3*vertOffset)/(4*editHeight+4*vertOffset+startOffset)...
                                                      editWidth/(2*horOffset1+txtWidth+editWidth+endWidth)...
                                                      editHeight/(4*editHeight+4*vertOffset+startOffset)],...
                                         'FontWeight', 'bold',...
                                         'BackgroundColor', GUIColors.ButtonColor,...
                                         'ForegroundColor', GUIColors.Text,...
                                         'Enable', 'on',...
                                         'Callback', @SETINPUTCALLBACK);
                                 
        hYFocText = annotation(hpanCamIn, 'textbox',...
                                          'LineStyle', 'none',...
                                          'String', 'f_y = ',...
                                          'BackgroundColor', GUIColors.UpperPanel,...
                                          'Units', 'normalized',...
                                          'HorizontalAlignment','right',...
                                          'VerticalAlignment','middle',...
                                          'Position', [horOffset1/(2*horOffset1+txtWidth+editWidth+endWidth)...
                                                       (2*editHeight+3*vertOffset)/(4*editHeight+4*vertOffset+startOffset)...
                                                       txtWidth/(2*horOffset1+txtWidth+editWidth+endWidth)...
                                                       editHeight/(4*editHeight+4*vertOffset+startOffset)]);
                                                   
      
        % x Principle point offset
        % ========================
        GUIHandles.input.hXPPOIn = uicontrol(hpanCamIn, 'Style', 'edit',...
                                         'String', num2str(rectParams.Xp, '%.6g'),...
                                         'Units', 'normalized',...
                                         'Position', [(horOffset1+txtWidth)/(2*horOffset1+txtWidth+editWidth+endWidth)...
                                                      (1*editHeight+2*vertOffset)/(4*editHeight+4*vertOffset+startOffset)...
                                                      editWidth/(2*horOffset1+txtWidth+editWidth+endWidth)...
                                                      editHeight/(4*editHeight+4*vertOffset+startOffset)],...
                                         'FontWeight', 'bold',...
                                         'BackgroundColor', GUIColors.ButtonColor,...
                                         'ForegroundColor', GUIColors.Text,...
                                         'Enable', 'on',...
                                         'Callback', @SETINPUTCALLBACK);
                                 
        hXPPOText = annotation(hpanCamIn, 'textbox',...
                                          'LineStyle', 'none',...
                                          'String', 'x_p = ',...
                                          'BackgroundColor', GUIColors.UpperPanel,...
                                          'Units', 'normalized',...
                                          'HorizontalAlignment','right',...
                                          'VerticalAlignment','middle',...
                                          'Position', [horOffset1/(2*horOffset1+txtWidth+editWidth+endWidth)...
                                                       (1*editHeight+2*vertOffset)/(4*editHeight+4*vertOffset+startOffset)...
                                                       txtWidth/(2*horOffset1+txtWidth+editWidth+endWidth)...
                                                       editHeight/(4*editHeight+4*vertOffset+startOffset)]);
                                   
                                     
        % y Principle point offset
        % ========================
        GUIHandles.input.hYPPOIn = uicontrol(hpanCamIn, 'Style', 'edit',...
                                       'String', num2str(rectParams.Yp, '%.6g'),...
                                       'Units', 'normalized',...
                                       'Position', [(horOffset1+txtWidth)/(2*horOffset1+txtWidth+editWidth+endWidth)...
                                                    (0*editHeight+1*vertOffset)/(4*editHeight+4*vertOffset+startOffset)...
                                                    editWidth/(2*horOffset1+txtWidth+editWidth+endWidth)...
                                                    editHeight/(4*editHeight+4*vertOffset+startOffset)],...
                                       'FontWeight', 'bold',...
                                       'BackgroundColor', GUIColors.ButtonColor,...
                                       'ForegroundColor', GUIColors.Text,...
                                       'Enable', 'on',...
                                       'Callback', @SETINPUTCALLBACK);
                                 
        hYPPOText = annotation(hpanCamIn, 'textbox',...
                                          'LineStyle', 'none',...
                                          'String', 'y_p = ',...
                                          'BackgroundColor', GUIColors.UpperPanel,...
                                          'Units', 'normalized',...
                                          'HorizontalAlignment','right',...
                                          'VerticalAlignment','middle',...
                                          'Position', [horOffset1/(2*horOffset1+txtWidth+editWidth+endWidth)...
                                                       (0*editHeight+1*vertOffset)/(4*editHeight+4*vertOffset+startOffset)...
                                                       txtWidth/(2*horOffset1+txtWidth+editWidth+endWidth)...
                                                       editHeight/(4*editHeight+4*vertOffset+startOffset)]);

                          
        % Camera distortion parameter input          
        % =================================
        hpanDistortIn = uipanel(hfig2, 'Position', [1-(2*horOffset1+txtWidth+editWidth+endWidth)/rectWidth...
                                                      1-(16*editHeight+16*vertOffset+3*startOffset)/rectHeight...
                                                      (2*horOffset1+txtWidth+editWidth+endWidth)/rectWidth...
                                                      (6*editHeight+6*vertOffset+startOffset)/rectHeight],...
                                         'Title', 'Distortion Parameters',...
                                         'FontWeight', 'bold',...
                                         'BackgroundColor', GUIColors.UpperPanel,...
                                         'BorderWidth', 1,...
                                         'HighlightColor', GUIColors.UpperHighlight,...
                                         'ShadowColor', GUIColors.UpperShadow);
                                     
        % Radial Distortion Parameter 1
        % =============================
        GUIHandles.input.hD1In = uicontrol(hpanDistortIn, 'Style', 'edit',...
                                               'String', num2str(rectParams.D1, '%.6g'),...
                                               'Units', 'normalized',...
                                               'Position', [(horOffset1+txtWidth)/(2*horOffset1+txtWidth+editWidth+endWidth)...
                                                            (5*editHeight+6*vertOffset)/(6*editHeight+6*vertOffset+startOffset)...
                                                            editWidth/(2*horOffset1+txtWidth+editWidth+endWidth)...
                                                            editHeight/(6*editHeight+6*vertOffset+startOffset)],...
                                               'FontWeight', 'bold',...
                                               'BackgroundColor', GUIColors.ButtonColor,...
                                               'ForegroundColor', GUIColors.Text,...
                                               'Enable', 'on',...
                                               'Callback', @SETINPUTCALLBACK);
                                 
        hD1Text = annotation(hpanDistortIn, 'textbox',...
                                                'LineStyle', 'none',...
                                                'String', 'd_1 = ',...
                                                'BackgroundColor', GUIColors.UpperPanel,...
                                                'Units', 'normalized',...
                                                'HorizontalAlignment','right',...
                                                'VerticalAlignment','middle',...
                                                'Position', [horOffset1/(2*horOffset1+txtWidth+editWidth+endWidth)...
                                                             (5*editHeight+6*vertOffset)/(6*editHeight+6*vertOffset+startOffset)...
                                                             txtWidth/(2*horOffset1+txtWidth+editWidth+endWidth)...
                                                             editHeight/(6*editHeight+6*vertOffset+startOffset)]);
                                
        % Radial Distortion Parameter 2
        % =============================
        GUIHandles.input.hD2In = uicontrol(hpanDistortIn, 'Style', 'edit',...
                                               'String', num2str(rectParams.D2, '%.6g'),...
                                               'Units', 'normalized',...
                                               'Position', [(horOffset1+txtWidth)/(2*horOffset1+txtWidth+editWidth+endWidth)...
                                                            (4*editHeight+5*vertOffset)/(6*editHeight+6*vertOffset+startOffset)...
                                                            editWidth/(2*horOffset1+txtWidth+editWidth+endWidth)...
                                                            editHeight/(6*editHeight+6*vertOffset+startOffset)],...
                                               'FontWeight', 'bold',...
                                               'BackgroundColor', GUIColors.ButtonColor,...
                                               'ForegroundColor', GUIColors.Text,...
                                               'Enable', 'on',...
                                               'Callback', @SETINPUTCALLBACK);
                                 
        hD2Text = annotation(hpanDistortIn, 'textbox',...
                                                'LineStyle', 'none',...
                                                'String', 'd_2 = ',...
                                                'BackgroundColor', GUIColors.UpperPanel,...
                                                'Units', 'normalized',...
                                                'HorizontalAlignment','right',...
                                                'VerticalAlignment','middle',...
                                                'Position', [horOffset1/(2*horOffset1+txtWidth+editWidth+endWidth)...
                                                             (4*editHeight+5*vertOffset)/(6*editHeight+6*vertOffset+startOffset)...
                                                             txtWidth/(2*horOffset1+txtWidth+editWidth+endWidth)...
                                                             editHeight/(6*editHeight+6*vertOffset+startOffset)]);

                                           
        % Radial Distortion Parameter 3
        % =============================
        GUIHandles.input.hD3In = uicontrol(hpanDistortIn, 'Style', 'edit',...
                                                'String', num2str(rectParams.D3, '%.6g'),...
                                                'Units', 'normalized',...
                                                'Position', [(horOffset1+txtWidth)/(2*horOffset1+txtWidth+editWidth+endWidth)...
                                                             (3*editHeight+4*vertOffset)/(6*editHeight+6*vertOffset+startOffset)...
                                                             editWidth/(2*horOffset1+txtWidth+editWidth+endWidth)...
                                                             editHeight/(6*editHeight+6*vertOffset+startOffset)],...
                                                'FontWeight', 'bold',...
                                                'BackgroundColor', GUIColors.ButtonColor,...
                                                'ForegroundColor', GUIColors.Text,...
                                                'Enable', 'on',...
                                                'Callback', @SETINPUTCALLBACK);
                                 
        hD3Text = annotation(hpanDistortIn, 'textbox',...
                                                 'LineStyle', 'none',...
                                                 'String', 'd_3 = ',...
                                                 'BackgroundColor', GUIColors.UpperPanel,...
                                                 'Units', 'normalized',...
                                                 'HorizontalAlignment','right',...
                                                 'VerticalAlignment','middle',...
                                                 'Position', [horOffset1/(2*horOffset1+txtWidth+editWidth+endWidth)...
                                                              (3*editHeight+4*vertOffset)/(6*editHeight+6*vertOffset+startOffset)...
                                                              txtWidth/(2*horOffset1+txtWidth+editWidth+endWidth)...
                                                              editHeight/(6*editHeight+6*vertOffset+startOffset)]);

                                            
        % Tangential Distortion Parameter 1
        % =================================
        GUIHandles.input.hT1In = uicontrol(hpanDistortIn, 'Style', 'edit',...
                                                'String', num2str(rectParams.T1, '%.6g'),...
                                                'Units', 'normalized',...
                                                'Position', [(horOffset1+txtWidth)/(2*horOffset1+txtWidth+editWidth+endWidth)...
                                                             (2*editHeight+3*vertOffset)/(6*editHeight+6*vertOffset+startOffset)...
                                                             editWidth/(2*horOffset1+txtWidth+editWidth+endWidth)...
                                                             editHeight/(6*editHeight+6*vertOffset+startOffset)],...
                                                'FontWeight', 'bold',...
                                                'BackgroundColor', GUIColors.ButtonColor,...
                                                'ForegroundColor', GUIColors.Text,...
                                                'Enable', 'on',...
                                                'Callback', @SETINPUTCALLBACK);
                                 
        hT1Text = annotation(hpanDistortIn, 'textbox',...
                                                'LineStyle', 'none',...
                                                'String', 't_1 = ',...
                                                'BackgroundColor', GUIColors.UpperPanel,...
                                                'Units', 'normalized',...
                                                'HorizontalAlignment','right',...
                                                'VerticalAlignment','middle',...
                                                'Position', [horOffset1/(2*horOffset1+txtWidth+editWidth+endWidth)...
                                                             (2*editHeight+3*vertOffset)/(6*editHeight+6*vertOffset+startOffset)...
                                                             txtWidth/(2*horOffset1+txtWidth+editWidth+endWidth)...
                                                             editHeight/(6*editHeight+6*vertOffset+startOffset)]);

                                            
        % Tangential Distortion Parameter 2
        % =================================
        GUIHandles.input.hT2In = uicontrol(hpanDistortIn, 'Style', 'edit',...
                                                'String', num2str(rectParams.T2, '%.6g'),...
                                                'Units', 'normalized',...
                                                'Position', [(horOffset1+txtWidth)/(2*horOffset1+txtWidth+editWidth+endWidth)...
                                                             (editHeight+2*vertOffset)/(6*editHeight+6*vertOffset+startOffset)...
                                                             editWidth/(2*horOffset1+txtWidth+editWidth+endWidth)...
                                                             editHeight/(6*editHeight+6*vertOffset+startOffset)],...
                                                'FontWeight', 'bold',...
                                                'BackgroundColor', GUIColors.ButtonColor,...
                                                'ForegroundColor', GUIColors.Text,...
                                                'Enable', 'on',...
                                                'Callback', @SETINPUTCALLBACK);
                                 
        hT2Text = annotation(hpanDistortIn, 'textbox',...
                                                 'LineStyle', 'none',...
                                                 'String', 't_2 = ',...
                                                 'BackgroundColor', GUIColors.UpperPanel,...
                                                 'Units', 'normalized',...
                                                 'HorizontalAlignment','right',...
                                                 'VerticalAlignment','middle',...
                                                 'Position', [horOffset1/(2*horOffset1+txtWidth+editWidth+endWidth)...
                                                              (editHeight+2*vertOffset)/(6*editHeight+6*vertOffset+startOffset)...
                                                              txtWidth/(2*horOffset1+txtWidth+editWidth+endWidth)...
                                                              editHeight/(6*editHeight+6*vertOffset+startOffset)]);

                                            
        % Camera Skewness
        % ===============
        GUIHandles.input.hSkewIn = uicontrol(hpanDistortIn, 'Style', 'edit',...
                                                'String', num2str(rectParams.Alpha, '%.6g'),...
                                                'Units', 'normalized',...
                                                'Position', [(horOffset1+txtWidth)/(2*horOffset1+txtWidth+editWidth+endWidth)...
                                                             vertOffset/(6*editHeight+6*vertOffset+startOffset)...
                                                             editWidth/(2*horOffset1+txtWidth+editWidth+endWidth)...
                                                             editHeight/(6*editHeight+6*vertOffset+startOffset)],...
                                                'FontWeight', 'bold',...
                                                'BackgroundColor', GUIColors.ButtonColor,...
                                                'ForegroundColor', GUIColors.Text,...
                                                'Enable', 'on',...
                                                'Callback', @SETINPUTCALLBACK);
                                 
        hSkewText = annotation(hpanDistortIn, 'textbox',...
                                                 'LineStyle', 'none',...
                                                 'String', '\alpha = ',...
                                                 'BackgroundColor', GUIColors.UpperPanel,...
                                                 'Units', 'normalized',...
                                                 'HorizontalAlignment','right',...
                                                 'VerticalAlignment','middle',...
                                                 'Position', [horOffset1/(2*horOffset1+txtWidth+editWidth+endWidth)...
                                                              vertOffset/(6*editHeight+6*vertOffset+startOffset)...
                                                              txtWidth/(2*horOffset1+txtWidth+editWidth+endWidth)...
                                                              editHeight/(6*editHeight+6*vertOffset+startOffset)]);
                                   
                                        
        % Values of the computed camera pose from GCPs          
        % ============================================
        hpanComputedPose = uipanel(hfig2, 'Position', [1-(2*horOffset1+txtWidth+editWidth+endWidth)/rectWidth...
                                                       1-(22*editHeight+22*vertOffset+4*startOffset)/rectHeight...
                                                       (2*horOffset1+txtWidth+editWidth+endWidth)/rectWidth...
                                                       (6*editHeight+6*vertOffset+startOffset)/rectHeight],...
                                  'Title', 'Computed Extrinsic Parameters',...
                                  'FontWeight', 'bold',...
                                  'BackgroundColor', GUIColors.UpperPanel,...
                                  'BorderWidth', 1,...
                                  'HighlightColor', GUIColors.UpperHighlight,...
                                  'ShadowColor', GUIColors.UpperShadow);
                              
        hXPoseText = annotation(hpanComputedPose, 'textbox',...
                                                  'LineStyle', '-',...
                                                  'LineWidth', 1,...
                                                  'String', ['X = ' num2str(rectParams.XPose, '%.5g')],...
                                                  'EdgeColor', GUIColors.UpperHighlight,...
                                                  'BackgroundColor', GUIColors.ButtonColor,...
                                                  'Color', GUIColors.Text,...
                                                  'Units', 'normalized',...
                                                  'HorizontalAlignment','Left',...
                                                  'VerticalAlignment','middle',...
                                                  'Position', [horOffset2/(2*horOffset1+txtWidth+editWidth+endWidth)...
                                                               (5*editHeight+6*vertOffset)/(6*editHeight+6*vertOffset+startOffset)...
                                                               dispValWidth/(2*horOffset1+txtWidth+editWidth+endWidth)...
                                                               editHeight/(6*editHeight+6*vertOffset+startOffset)]);
                                                           
        hYPoseText = annotation(hpanComputedPose, 'textbox',...
                                                  'LineStyle', '-',...
                                                  'LineWidth', 1,...
                                                  'String', ['Y = ' num2str(rectParams.YPose, '%.5g')],...
                                                  'EdgeColor', GUIColors.UpperHighlight,...
                                                  'BackgroundColor', GUIColors.ButtonColor,...
                                                  'Color', GUIColors.Text,...
                                                  'Units', 'normalized',...
                                                  'HorizontalAlignment','Left',...
                                                  'VerticalAlignment','middle',...
                                                  'Position', [horOffset2/(2*horOffset1+txtWidth+editWidth+endWidth)...
                                                               (4*editHeight+5*vertOffset)/(6*editHeight+6*vertOffset+startOffset)...
                                                               dispValWidth/(2*horOffset1+txtWidth+editWidth+endWidth)...
                                                               editHeight/(6*editHeight+6*vertOffset+startOffset)]);
                                                           
        hZPoseText = annotation(hpanComputedPose, 'textbox',...
                                                  'LineStyle', '-',...
                                                  'LineWidth', 1,...
                                                  'String', ['Z = ' num2str(rectParams.ZPose, '%.5g')],...
                                                  'EdgeColor', GUIColors.UpperHighlight,...
                                                  'BackgroundColor', GUIColors.ButtonColor,...
                                                  'Color', GUIColors.Text,...
                                                  'Units', 'normalized',...
                                                  'HorizontalAlignment','Left',...
                                                  'VerticalAlignment','middle',...
                                                  'Position', [horOffset2/(2*horOffset1+txtWidth+editWidth+endWidth)...
                                                               (3*editHeight+4*vertOffset)/(6*editHeight+6*vertOffset+startOffset)...
                                                               dispValWidth/(2*horOffset1+txtWidth+editWidth+endWidth)...
                                                               editHeight/(6*editHeight+6*vertOffset+startOffset)]);
                                                           
        hPitchPoseText = annotation(hpanComputedPose, 'textbox',...
                                                  'LineStyle', '-',...
                                                  'LineWidth', 1,...
                                                  'String', ['\lambda = ' num2str(rectParams.PitchPose, '%.4g')],...
                                                  'EdgeColor', GUIColors.UpperHighlight,...
                                                  'BackgroundColor', GUIColors.ButtonColor,...
                                                  'Color', GUIColors.Text,...
                                                  'Units', 'normalized',...
                                                  'HorizontalAlignment','Left',...
                                                  'VerticalAlignment','middle',...
                                                  'Position', [horOffset2/(2*horOffset1+txtWidth+editWidth+endWidth)...
                                                               (2*editHeight+3*vertOffset)/(6*editHeight+6*vertOffset+startOffset)...
                                                               dispValWidth/(2*horOffset1+txtWidth+editWidth+endWidth)...
                                                               editHeight/(6*editHeight+6*vertOffset+startOffset)]);
                                                           
        hRollPoseText = annotation(hpanComputedPose, 'textbox',...
                                                  'LineStyle', '-',...
                                                  'LineWidth', 1,...
                                                  'String', ['\phi = ' num2str(rectParams.RollPose, '%.4g')],...
                                                  'EdgeColor', GUIColors.UpperHighlight,...
                                                  'BackgroundColor', GUIColors.ButtonColor,...
                                                  'Color', GUIColors.Text,...
                                                  'Units', 'normalized',...
                                                  'HorizontalAlignment','Left',...
                                                  'VerticalAlignment','middle',...
                                                  'Position', [horOffset2/(2*horOffset1+txtWidth+editWidth+endWidth)...
                                                               (1*editHeight+2*vertOffset)/(6*editHeight+6*vertOffset+startOffset)...
                                                               dispValWidth/(2*horOffset1+txtWidth+editWidth+endWidth)...
                                                               editHeight/(6*editHeight+6*vertOffset+startOffset)]);
                                                           
        hAzimuthPoseText = annotation(hpanComputedPose, 'textbox',...
                                                  'LineStyle', '-',...
                                                  'LineWidth', 1,...
                                                  'String', ['\theta = ' num2str(rectParams.AzimuthPose, '%.5g')],...
                                                  'EdgeColor', GUIColors.UpperHighlight,...
                                                  'BackgroundColor', GUIColors.ButtonColor,...
                                                  'Color', GUIColors.Text,...
                                                  'Units', 'normalized',...
                                                  'HorizontalAlignment','Left',...
                                                  'VerticalAlignment','middle',...
                                                  'Position', [horOffset2/(2*horOffset1+txtWidth+editWidth+endWidth)...
                                                               (0*editHeight+1*vertOffset)/(6*editHeight+6*vertOffset+startOffset)...
                                                               dispValWidth/(2*horOffset1+txtWidth+editWidth+endWidth)...
                                                               editHeight/(6*editHeight+6*vertOffset+startOffset)]);
        
        
        % the rest of the space
        hpanFiller = uipanel(hfig2, 'Position', [1-(2*horOffset1+txtWidth+editWidth+endWidth)/rectWidth...
                                                 0.0...
                                                 (2*horOffset1+txtWidth+editWidth+endWidth)/rectWidth...
                                                 1-(22*editHeight+22*vertOffset+4*startOffset)/rectHeight],...
                                  'FontWeight', 'bold',...
                                  'BackgroundColor', GUIColors.UpperPanel,...
                                  'BorderWidth', 1,...
                                  'HighlightColor', GUIColors.UpperHighlight,...
                                  'ShadowColor', GUIColors.UpperShadow);
                              
        %% Finish setting up GUI
        % ======================
     
        % Check to see which input paremters are set
        paramsTemp = fieldnames(rectParams);
        for i = 1:length(paramsTemp)
            if any(strcmp(paramsTemp{i},{'XPose';'YPose';'ZPose';'PitchPose';'RollPose';'AzimuthPose'}))
            else
                CheckInputParams(paramsTemp{i});
            end
        end
        
        PlotCameraUnrectified()
        
        if ~isempty(rectParams.XPose) && ~isempty(rectParams.YPose) && ~isempty(rectParams.ZPose) && ~isempty(rectParams.PitchPose) && ~isempty(rectParams.RollPose) && ~isempty(rectParams.AzimuthPose) 
            plotRectBtn.Enable = 'on';
            saveRectBtn.Enable = 'on';
        end
        
        if ~isempty(rectParams.XRect)
            PlotRectified(rectParams.XRect, rectParams.YRect, rectParams.ImRect)
        end
        
        hfig2.Visible = 'on';
        
        if sum(checkParams) ==  length(checkParams);
            computePoseBtn.Enable = 'on';
        else
            computePoseBtn.Enable = 'off';
        end
        
        %% Rectification GUI Functions
        % ============================
        function SETINPUTCALLBACK(hObject, ~)
            
            inputStr = hObject.String;
            inputNum = str2double(inputStr);
            if isnan(inputNum) == 1
                validParam = 0;
            else
                validParam = 1;
            end
        
            if validParam == 1
                if hObject == GUIHandles.input.hXIn
                    rectParams.X = inputNum;
                    checkParams(1) = 1;
                elseif hObject == GUIHandles.input.hYIn
                    rectParams.Y = inputNum;
                    checkParams(2) = 1;
                elseif hObject == GUIHandles.input.hZIn
                    rectParams.Z = inputNum;
                    checkParams(3) = 1;
                elseif hObject == GUIHandles.input.hPitchIn
                    rectParams.Pitch = inputNum;
                    checkParams(4) = 1;
                elseif hObject == GUIHandles.input.hRollIn
                    rectParams.Roll = inputNum;
                    checkParams(5) = 1;
                elseif hObject == GUIHandles.input.hAzimuthIn
                    rectParams.Azimuth = inputNum;
                    checkParams(6) = 1;
                elseif hObject == GUIHandles.input.hXFocIn
                    rectParams.Fx = inputNum;
                    checkParams(7) = 1;
                elseif hObject == GUIHandles.input.hYFocIn
                    rectParams.Fy = inputNum;
                    checkParams(8) = 1;
                elseif hObject == GUIHandles.input.hXPPOIn
                    rectParams.Xp = inputNum;
                    checkParams(9) = 1;
                elseif hObject == GUIHandles.input.hYPPOIn
                    rectParams.Yp = inputNum;
                    checkParams(10) = 1;
                elseif hObject == GUIHandles.input.hD1In
                    rectParams.D1 = inputNum;
                    checkParams(11) = 1;
                elseif hObject == GUIHandles.input.hD2In
                    rectParams.D2 = inputNum;
                    checkParams(12) = 1;
                elseif hObject == GUIHandles.input.hD3In
                    rectParams.D3 = inputNum;
                    checkParams(13) = 1;
                elseif hObject == GUIHandles.input.hT1In
                    rectParams.T1 = inputNum;
                    checkParams(14) = 1;
                elseif hObject == GUIHandles.input.hT2In
                    rectParams.T2 = inputNum;
                    checkParams(15) = 1;
                elseif hObject == GUIHandles.input.hSkewIn
                    rectParams.Alpha = inputNum;
                    checkParams(16) = 1;
                end
            elseif validParam == 0
                hObject.String = '';
                if hObject == GUIHandles.input.hXIn
                    rectParams.X = [];
                    checkParams(1) = 0;
                elseif hObject == GUIHandles.input.hYIn
                    rectParams.Y = [];
                    checkParams(2) = 0;
                elseif hObject == GUIHandles.input.hZIn
                    rectParams.Z = [];
                    checkParams(3) = 0;
                elseif hObject == GUIHandles.input.hPitchIn
                    rectParams.Pitch = [];
                    checkParams(4) = 0;
                elseif hObject == GUIHandles.input.hRollIn
                    rectParams.Roll = [];
                    checkParams(5) = 0;
                elseif hObject == GUIHandles.input.hAzimuthIn
                    rectParams.Azimuth = [];
                    checkParams(6) = 0;
                elseif hObject == GUIHandles.input.hXFocIn
                    rectParams.Fx = [];
                    checkParams(7) = 0;
                elseif hObject == GUIHandles.input.hYFocIn
                    rectParams.Fy = [];
                    checkParams(8) = 0;
                elseif hObject == GUIHandles.input.hXPPOIn
                    rectParams.Xp = [];
                    checkParams(9) = 0;
                elseif hObject == GUIHandles.input.hYPPOIn
                    rectParams.Yp = [];
                    checkParams(10) = 0;
                elseif hObject == GUIHandles.input.hD1In
                    rectParams.D1 = [];
                    checkParams(11) = 0;
                elseif hObject == GUIHandles.input.hD2In
                    rectParams.D2 = [];
                    checkParams(12) = 0;
                elseif hObject == GUIHandles.input.hD3In
                    rectParams.D3 = [];
                    checkParams(13) = 0;
                elseif hObject == GUIHandles.input.hT1In
                    rectParams.T1 = [];
                    checkParams(14) = 0;
                elseif hObject == GUIHandles.input.hT2In
                    rectParams.T2 = [];
                    checkParams(15) = 0;
                elseif hObject == GUIHandles.input.hSkewIn
                    rectParams.Alpha = [];
                    checkParams(16) = 0;
                end
                
            end
            
%             PlotHorizon()
            
            if sum(checkParams) ==  length(checkParams);
                computePoseBtn.Enable = 'on';
            else
                computePoseBtn.Enable = 'off';
            end
        
        end
        
        function LOADCAMERAPOSE(hObject, ~)
            
            hObject.Enable = 'inactive';
            
            if ~isempty(rectParams.X)
                reLoadWarn = questdlg({'An Extrinsics file has already been loaded';...
                                       'Are you sure you want to load a new Extyrinsics file?'},...
                                       'Load New Extrinsics?', 'Continue', 'Cancel', 'Cancel'); 
                if strcmp('Cancel', reLoadWarn) == 1
                    return
                end
            end
            
            [fileNameExt, pathNameExt, filterIndex] = uigetfile({'*.dat'}, 'Load Camera Extrinsics File (*.DAT)');
        
            if filterIndex ~= 0 % if a file was selected
            
                if strcmpi('.dat', fileNameExt(end-3:end)) % if file is a .text file
                    
                    fidExt = fopen([pathNameExt fileNameExt], 'r');

                    error2Display = {'X0 missing';'Y0 missing';'Z0 missing';'Pitch missing';'Roll missing';'Azimuth missing'};
                    error2DisplayVal = [1 1 1 1 1 1];
                    while 1

                        paramLine = fgetl(fidExt);
                        if paramLine == -1
                            break
                        end

                        if regexp(paramLine, '^\s*X0\s*=\s*')
                            matchStr = regexp(paramLine, '(?<=^\s*X0\s*=\s*)[-+]?\d+[.]?\d*', 'match');
                            rectParams.X = str2double(matchStr);
                            GUIHandles.input.hXIn.String = matchStr;
                            error2DisplayVal(1) = 0;
                            
                        elseif regexp(paramLine, '^\s*Y0\s*=\s*')
                            matchStr = regexp(paramLine, '(?<=^\s*Y0\s*=\s*)[-+]?\d+[.]?\d*', 'match');
                            rectParams.Y = str2double(matchStr);
                            GUIHandles.input.hYIn.String = matchStr;
                            error2DisplayVal(2) = 0;
                            
                        elseif regexp(paramLine, '^\s*Z0\s*=\s*')
                            matchStr = regexp(paramLine, '(?<=^\s*Z0\s*=\s*)[-+]?\d+[.]?\d*', 'match');
                            rectParams.Z = str2double(matchStr);
                            GUIHandles.input.hZIn.String = matchStr;
                            error2DisplayVal(3) = 0;

                        elseif regexp(paramLine, '^\s*Pitch\s*=\s*')
                            matchStr = regexp(paramLine, '(?<=^\s*Pitch\s*=\s*)[-+]?\d+[.]?\d*', 'match');
                            rectParams.Pitch = str2double(matchStr);
                            GUIHandles.input.hPitchIn.String = matchStr;
                            error2DisplayVal(4) = 0;
                            
                        elseif regexp(paramLine, '^\s*Roll\s*=\s*')
                            matchStr = regexp(paramLine, '(?<=^\s*Roll\s*=\s*)[-+]?\d+[.]?\d*', 'match');
                            rectParams.Roll = str2double(matchStr);
                            GUIHandles.input.hRollIn.String = matchStr;
                            error2DisplayVal(5) = 0;
                            
                        elseif regexp(paramLine, '^\s*Azimuth\s*=\s*')
                            matchStr = regexp(paramLine, '(?<=^\s*Azimuth\s*=\s*)[-+]?\d+[.]?\d*', 'match');
                            rectParams.Azimuth = str2double(matchStr);
                            GUIHandles.input.hAzimuthIn.String = matchStr;
                            error2DisplayVal(6) = 0;

                        end
                        
                    end

                    fclose(fidExt);

                    % Set missing values to empty
                    if error2DisplayVal(1) == 1
                        rectParams.X = [];
                        GUIHandles.input.hXIn.String = '';
                    end
                    if error2DisplayVal(2) == 1
                        rectParams.Y = [];
                        GUIHandles.input.hYIn.String = '';
                    end
                    if error2DisplayVal(3) == 1
                        rectParams.Z = [];
                        GUIHandles.input.hZIn.String = '';
                    end
                    if error2DisplayVal(4) == 1
                        rectParams.Pitch = [];
                        GUIHandles.input.hPitchIn.String = '';
                    end
                    if error2DisplayVal(5) == 1
                        rectParams.Roll = [];
                        GUIHandles.input.hRollIn.String = '';
                    end
                    if error2DisplayVal(6) == 1
                        rectParams.Azimuth = [];
                        GUIHandles.input.hAzimuthIn.String = '';
                    end

                    % display an error if any values are missing
                    if sum(error2DisplayVal) > 0
                        errordlg(error2Display(logical(error2DisplayVal)),'Input Error', 'modal')
                    end
                    
                    % Something was loaded, so flag to resave data
                    
                    if sum(error2DisplayVal) ~= 6
                        figdata.ChangeFlag = 1;
                    end

                    % Check to see which input paremters are set
                    paramsTemp = fieldnames(rectParams);
                    for i = 1:length(paramsTemp)
                        if any(strcmp(paramsTemp{i},{'XPose';'YPose';'ZPose';'PitchPose';'RollPose';'AzimuthPose'}))
                        else
                            CheckInputParams(paramsTemp{i});
                        end
                    end
                    
                    if sum(checkParams) ==  length(checkParams)
                        computePoseBtn.Enable = 'on';
                    else
                        computePoseBtn.Enable = 'off';
                    end
                
                else
                
                    herror = errordlg('Selected file is not a .DAT File','File Error','modal');
                    uiwait(herror)
                
                end % if strcmpi('.dat', fileNameExt(end-3:end))
            
            end % end if filterIndex ~= 0
            
            hObject.Enable = 'on';
            
        end
        
        function LOADCALIBRATION(hObject, ~)
            
            hObject.Enable = 'inactive';
            
            % get the file name for the mat file mad by the Cal Tech Toolbox
            [fileNameCal, pathNameCal, filterIndex] = uigetfile({'*.mat'}, 'Load Camera Parameters File (*.MAT)');
            
            if filterIndex ~= 0 % if a file was selected
                
                if strcmpi('.mat', fileNameCal(end-3:end)) % if file is a .mat file
                
                    calMatFile = [pathNameCal fileNameCal];
                
                    % get the names of the variables in the mat file
                    calVars = whos('-file', calMatFile);
                    calVarNames = extractfield(calVars, 'name');
                
                    % make sure that the required variables are in the mat file
                    errString = {};
                    errCount = 1;
                    if ~any(strcmp(calVarNames, 'fc'))
                        errString{errCount} = 'Focal Length Not Found';
                        errCount = errCount + 1;
                    end
                    if ~any(strcmp(calVarNames, 'cc'))
                        errString{errCount} = 'Principal Point Not Found';
                        errCount = errCount + 1;
                    end
                    if ~any(strcmp(calVarNames, 'alpha_c'))
                        errString{errCount} = 'Skewness Coefficinet Not Found';
                        errCount = errCount + 1;
                    end
                    if ~any(strcmp(calVarNames, 'kc'))
                        errString{errCount} = 'Distortion Coefficinets Not Found';
                        errCount = errCount + 1;
                    end
                    if ~any(strcmp(calVarNames, 'nx')) || ~any(strcmp(calVarNames, 'ny'))
                        errString{errCount} = 'Image Size Is Missing';
                        errCount = errCount + 1;
                    end
                    
                    if ~isempty(errString)
                        herror = errordlg(errString,'File Error','modal');
                        uiwait(herror)
                        return
                    end
                    
                    % has a cal file already been loaded?
                    if ~isempty(rectParams.Fx)
                        reLoadWarn = questdlg({'A calibration file has already been loaded';...
                                           'Are you sure you want to load a new calibration file?'},...
                                           'Load New Calibration?', 'Continue', 'Cancel', 'Cancel'); 
                        if strcmp('Cancel', reLoadWarn) == 1
                            return
                        end
                    end
                    
                    % load in the calibration data
                    calDat = load(calMatFile, 'fc', 'cc', 'alpha_c', 'kc', 'nx', 'ny');
                    
                    rectParams.Nx  = calDat.nx;
                    rectParams.Ny  = calDat.ny;
                    rectParams.Xp = calDat.cc(1);
                    rectParams.Yp = calDat.cc(2);
                    rectParams.Fx  = calDat.fc(1);
                    rectParams.Fy  = calDat.fc(2);
                    rectParams.D1  = calDat.kc(1);
                    rectParams.D2  = calDat.kc(2);
                    rectParams.D3  = calDat.kc(5);
                    rectParams.T1  = calDat.kc(3);
                    rectParams.T2  = calDat.kc(4);
                    rectParams.Alpha  = calDat.alpha_c;
                    
                    % Display the values
                    GUIHandles.input.hXPPOIn.String = rectParams.Xp;
                    GUIHandles.input.hYPPOIn.String = rectParams.Yp;
                    GUIHandles.input.hXFocIn.String = rectParams.Fx;
                    GUIHandles.input.hYFocIn.String = rectParams.Fy;
                    GUIHandles.input.hD1In.String = rectParams.D1;
                    GUIHandles.input.hD2In.String = rectParams.D2;
                    GUIHandles.input.hD3In.String = rectParams.D3;
                    GUIHandles.input.hT1In.String = rectParams.T1;
                    GUIHandles.input.hT2In.String = rectParams.T2;
                    GUIHandles.input.hSkewIn.String = rectParams.Alpha;
                    
                    % Check to see which input paremters are set
                    paramsTemp = fieldnames(rectParams);
                    for i = 1:length(paramsTemp)
                        if any(strcmp(paramsTemp{i},{'XPose';'YPose';'ZPose';'PitchPose';'RollPose';'AzimuthPose'}))
                        else
                            CheckInputParams(paramsTemp{i});
                        end
                    end
                    
                    if sum(checkParams) ==  length(checkParams);
                        computePoseBtn.Enable = 'on';
                    else
                        computePoseBtn.Enable = 'off';
                    end
                    
                    figdata.ChangeFlag = 1;
                
                else
                
                    herror = errordlg('Selected file is not a .MAT File','File Error','modal');
                    uiwait(herror)
                
                end % end if strcmpi('.mat', fileNameParam(end-3:end))
            
            end % end if filterIndex ~= 0
            
            hObject.Enable = 'on';
            
        end
        
        function COMPUTEPOSE(hObject, ~)
            
            hObject.Enable = 'inactive';
            
            [xNew, yNew, zNew, pitchNew, rollNew, azimuthNew] = computeCameraPoseFromGCPs(XGPS, YGPS, ZGPS, xPixel, yPixel, rectParams);
            
            rectParams.XPose = xNew;
            rectParams.YPose = yNew;
            rectParams.ZPose = zNew;
            rectParams.PitchPose = pitchNew;
            rectParams.RollPose = rollNew;
            rectParams.AzimuthPose = azimuthNew;
            
            hXPoseText.String = ['X = ' num2str(rectParams.XPose, '%.5g')];
            hYPoseText.String = ['Y = ' num2str(rectParams.YPose, '%.5g')];
            hZPoseText.String = ['Z = ' num2str(rectParams.ZPose, '%.5g')];
            hPitchPoseText.String = ['\lambda = ' num2str(rectParams.PitchPose, '%.4g')];
            hRollPoseText.String = ['\phi = ' num2str(rectParams.RollPose, '%.4g')];
            hAzimuthPoseText.String = ['\theta = ' num2str(rectParams.AzimuthPose, '%.5g')];
            
            [xPixGPS, yPixGPS] = XYZ2UV(XGPS, YGPS, ZGPS, rectParams);
            [xGPSPix, yGPSPix, ~] = UV2XYZ(xPixel, yPixel, ZGPS, rectParams);
            % convert pixel loactions to X,Y if a pose was computed
            delete(findobj(haxes3.Children, 'Tag', 'GCPUn'))
            hold(haxes3, 'on')
                plot(haxes3, xPixel, yPixel, 'sg', 'LineWidth', 2, 'MarkerFaceColor', 'g', 'Tag', 'GCPUn', 'ButtonDownFcn', @SELECTGCP)
                plot(haxes3, xPixGPS, yPixGPS, '+r', 'LineWidth', 2, 'Tag', 'GCPUn', 'PickableParts', 'none')
            hold(haxes3, 'off')
            
            plotRectBtn.Enable = 'on';
            saveRectBtn.Enable = 'on';
            
            figdata.ChangeFlag = 1;
            
            hObject.Enable = 'on';
            
        end
        
        function PLOTRECTIFY(hObject, ~)
            
            hObject.Enable = 'inactive';
            
            if errorFlag == 0
                xRectLims = rectParams.XRectLims;
                yRectLims = rectParams.YRectLims;
                zRectLims = rectParams.ZRectLims;
            
                [xRectLims, yRectLims, zRectLims] = GetRectGridValues(xRectLims, yRectLims, zRectLims);
            
                if ~isempty(xRectLims)
                    rectParams.XRectLims = xRectLims;
                    rectParams.YRectLims = yRectLims;
                    rectParams.ZRectLims = zRectLims;
                
                    [xRect, yRect, imRect] = MakeRectGrid(tiffData, rectParams);
                    rectParams.XRect = xRect;
                    rectParams.YRect = yRect;
                    rectParams.ImRect = imRect;
                
                    PlotRectified(rectParams.XRect, rectParams.YRect, rectParams.ImRect)
                    
                    figdata.ChangeFlag = 1;
                    
                end
            
            end
            
            hObject.Enable = 'on';
            
        end
        
        function SAVERECTIFY(hObject, ~)
            
            hObject.Enable = 'inactive';
            
            [fileNameSaveRect, pathNameSaveRect, filterIndex] = uiputfile({'*.mat'}, 'Select File for Rectificaiton Save');

            if filterIndex ~= 0
                
                [U, V] = meshgrid(1:rectParams.Nx, 1:rectParams.Ny);
                
                [X, Y, ~] = UV2XYZ(U, V, rectParams.ZRectLims,rectParams);
                
                Z = rectParams.ZRectLims;
                
                cameraExt = struct('x0', rectParams.XPose, 'y0', rectParams.YPose, 'z0', rectParams.ZPose,...
                                   'pitch', rectParams.PitchPose, 'roll', rectParams.RollPose, 'azimuth', rectParams.AzimuthPose);
                cameraInt = struct('nx', rectParams.Nx, 'ny', rectParams.Ny, 'fx', rectParams.Fx, 'fy', rectParams.Fy,...
                                    'xp', rectParams.Xp, 'yp', rectParams.Yp);
                cameraDis = struct('d1', rectParams.D1, 'd2', rectParams.D2, 'd3', rectParams.D3,...
                                    't1', rectParams.T1, 't2', rectParams.T2, 'alpha', rectParams.Alpha);
                       
                iNan = ~isnan(XGPS);
                xGCP = XGPS(iNan);
                yGCP = YGPS(iNan);
                zGCP = ZGPS(iNan);
                GCPS = struct('x', xGCP, 'y', yGCP, 'z', zGCP);
                
                xIm = rectParams.XRect(1, 1:end);
                yIm = rectParams.YRect(1:end, 1);
                datIm = rectParams.ImRect;
                rectIm = struct('x', xIm, 'y', yIm, 'dat', datIm);

                save([pathNameSaveRect fileNameSaveRect], 'U', 'V', 'X', 'Y', 'Z', 'cameraExt', 'cameraInt', 'GCPS', 'rectIm', '-mat');
                
%                 [m,n] = size(LON);
%                 LONReshape = reshape(LON,m*n, 1);
%                 LATReshape = reshape(LAT,m*n, 1);
%                 xpReshape = reshape(xp,m*n, 1);
%                 ypReshape = reshape(yp,m*n, 1);
%                 rectData = [xpReshape ypReshape LONReshape LATReshape];
%                 ind = isnan(rectData);
%                 rectData(ind) = -999;
%                 fid = fopen([pathNameSaveRect fileNameSaveRect(1:end-4) '.txt'], 'w');
%                   fprintf(fid, '# Altitude = %3.4f, hfov = %3.4f, Dip Angle = %3.4f, Tilt Angle = %3.4f, View Angle = %3.4f\n', altitude, hfov, dip, tilt, heading);
%                   fprintf(fid, '%d\t%d\t%f\t%f\n', rectData');
%                 fclose(fid);
                
            end
       
            hObject.Enable = 'on';
        end
        
        function DELETE(~, ~)
            
            hObject.Enable = 'inactive';
            
            deleteStack{end+1} = [deleteInd' xPixel(deleteInd) yPixel(deleteInd) XGPS(deleteInd) YGPS(deleteInd) ZGPS(deleteInd) xPixGPS(deleteInd) yPixGPS(deleteInd) xGPSPix(deleteInd) yGPSPix(deleteInd)];
            
            xPixel(deleteInd) = nan;
            yPixel(deleteInd) = nan;
            XGPS(deleteInd) = nan;
            YGPS(deleteInd) = nan;
            ZGPS(deleteInd) = nan;
            xPixGPS(deleteInd) = nan;
            yPixGPS(deleteInd) = nan;
            xGPSPix(deleteInd) = nan;
            yGPSPix(deleteInd) = nan;
            
            deleteInd = [];
            deleteMarker = [];
            %deleteMarker = 1;
            
            delete(findobj(haxes3.Children, 'Tag', 'GCPSelect'))
            delete(findobj(haxes4.Children, 'Tag', 'GCPSelect'))
            delete(findobj(haxes3.Children, 'Tag', 'GCPUn'))
            delete(findobj(haxes4.Children, 'Tag', 'GCPR'))
            
            hold(haxes3, 'on')
                plot(haxes3, xPixel, yPixel, 'sg', 'LineWidth', 2, 'MarkerFaceColor', 'g', 'Tag', 'GCPUn', 'ButtonDownFcn', @SELECTGCP)
                plot(haxes3, xPixGPS, yPixGPS, '+r', 'LineWidth', 2, 'Tag', 'GCPUn', 'PickableParts', 'none')
            hold(haxes3, 'off')

            hold(haxes4, 'on')
                plot(haxes4, XGPS, YGPS, 'og', 'LineWidth', 2, 'Tag', 'GCPR', 'ButtonDownFcn', @SELECTGCP)
                plot(haxes4, xGPSPix, yGPSPix, '+r', 'LineWidth', 2, 'Tag', 'GCPR', 'PickableParts', 'none')
            hold(haxes4, 'off')
            
            undoGCPBtn.Enable = 'on';
            deleteGCPBtn.Enable = 'off';
            
        end
        
        function UNDO(hObject, ~)
            
            hObject.Enable = 'inactive';
            
            gcp2Undo = deleteStack{end};
            xPixel(gcp2Undo(:,1)) = gcp2Undo(:,2);
            yPixel(gcp2Undo(:,1)) = gcp2Undo(:,3);
            XGPS(gcp2Undo(:,1)) = gcp2Undo(:,4);
            YGPS(gcp2Undo(:,1)) = gcp2Undo(:,5);
            ZGPS(gcp2Undo(:,1)) = gcp2Undo(:,6);
            xPixGPS(gcp2Undo(:,1)) = gcp2Undo(:,7);
            yPixGPS(gcp2Undo(:,1)) = gcp2Undo(:,8);
            xGPSPix(gcp2Undo(:,1)) = gcp2Undo(:,9);
            yGPSPix(gcp2Undo(:,1)) = gcp2Undo(:,10);
            
            deleteStack(end) = [];
            
            delete(findobj(haxes3.Children, 'Tag', 'GCPSelect'))
            delete(findobj(haxes4.Children, 'Tag', 'GCPSelect'))
            delete(findobj(haxes3.Children, 'Tag', 'GCPUn'))
            delete(findobj(haxes4.Children, 'Tag', 'GCPR'))
            
            hold(haxes3, 'on')
                plot(haxes3, xPixel, yPixel, 'sg', 'LineWidth', 2, 'MarkerFaceColor', 'g', 'Tag', 'GCPUn', 'ButtonDownFcn', @SELECTGCP)
                plot(haxes3, xPixGPS, yPixGPS, '+r', 'LineWidth', 2, 'Tag', 'GCPUn', 'PickableParts', 'none')
            hold(haxes3, 'off')
            
            hold(haxes4, 'on')
                plot(haxes4, XGPS, YGPS, 'og', 'LineWidth', 2, 'Tag', 'GCPR', 'ButtonDownFcn', @SELECTGCP)
                plot(haxes4, xGPSPix, yGPSPix, '+r', 'LineWidth', 2, 'Tag', 'GCPR', 'PickableParts', 'none')
            hold(haxes4, 'off')
            
            if isempty(deleteStack)
                undoGCPBtn.Enable = 'off';
            else
                undoGCPBtn.Enable = 'on';
            end
           
        end
        
        function SELECTGCP(hObject, ~)
            
            deleteGCPBtn.Enable = 'on';
            
            if strcmp(hObject.Tag, 'GCPUn')
                centerPoint = haxes3.CurrentPoint;
                [~, ind] = min(sqrt((centerPoint(1,1)-xPixel).^2 + (centerPoint(1,2)-yPixel).^2));
                
                deleteMarker = ind;
                
                hold(haxes3, 'on')
                    plot(haxes3, xPixel(ind), yPixel(ind), 'sm', 'LineWidth', 2, 'MarkerFaceColor', 'm', 'Tag', 'GCPSelect', 'UserData', deleteMarker, 'ButtonDownFcn', @UNSELECTGCP)
                    plot(haxes3, xPixGPS(ind), yPixGPS(ind), '+m', 'LineWidth', 2, 'Tag', 'GCPSelect', 'UserData', deleteMarker, 'ButtonDownFcn', @UNSELECTGCP)
                hold(haxes3, 'off')
                if any( strcmp( get(haxes4.Children, 'Type'), 'line' ) )
                    hold(haxes4, 'on')
                        plot(haxes4, XGPS(ind), YGPS(ind), 'om', 'LineWidth', 2, 'Tag', 'GCPSelect', 'UserData', deleteMarker, 'ButtonDownFcn', @UNSELECTGCP)
                        plot(haxes4, xGPSPix(ind), yGPSPix(ind), '+m', 'LineWidth', 2, 'Tag', 'GCPSelect', 'UserData', deleteMarker, 'ButtonDownFcn', @UNSELECTGCP)
                    hold(haxes4, 'off')
                end
                deleteInd(end+1) = ind;
                %deleteMarker = deleteMarker+1;
                
            elseif strcmp(hObject.Tag, 'GCPR')
                centerPoint = haxes4.CurrentPoint;
                [~, ind] = min(sqrt((centerPoint(1,1)-XGPS).^2 + (centerPoint(1,2)-YGPS).^2));
                
                deleteMarker = ind;
                
                hold(haxes3, 'on')
                hold(haxes4, 'on')
                    plot(haxes3, xPixel(ind), yPixel(ind), 'sm', 'LineWidth', 2, 'MarkerFaceColor', 'm', 'Tag', 'GCPSelect', 'UserData', deleteMarker, 'ButtonDownFcn', @UNSELECTGCP)
                    plot(haxes3, xPixGPS(ind), yPixGPS(ind), '+m', 'LineWidth', 2, 'Tag', 'GCPSelect', 'UserData', deleteMarker, 'ButtonDownFcn', @UNSELECTGCP)
                    plot(haxes4, XGPS(ind), YGPS(ind), 'om', 'LineWidth', 2, 'Tag', 'GCPSelect', 'UserData', deleteMarker, 'ButtonDownFcn', @UNSELECTGCP)
                    plot(haxes4, xGPSPix(ind), yGPSPix(ind), '+m', 'LineWidth', 2, 'Tag', 'GCPSelect', 'UserData', deleteMarker, 'ButtonDownFcn', @UNSELECTGCP)
                hold(haxes3, 'off')
                hold(haxes4, 'off')
                deleteInd(end+1) = ind;
                %deleteMarker = deleteMarker+1;
                
            end
            
        end
        
        function UNSELECTGCP(hObject, ~)
            
            if hObject.Parent == haxes3

                centerPoint = haxes3.CurrentPoint;
                [~, ind] = min(sqrt((centerPoint(1,1)-xPixel).^2 + (centerPoint(1,2)-yPixel).^2));
                deleteInd(deleteInd == ind) = [];
                
                if any( strcmp( get(haxes4.Children, 'Type'), 'line' ) )
                    delete(findobj(haxes4.Children, 'UserData', hObject.UserData))
                end
                delete(findobj(haxes3.Children, 'UserData', hObject.UserData))
                
            elseif hObject.Parent == haxes4
                
                centerPoint = haxes4.CurrentPoint;
                [~, ind] = min(sqrt((centerPoint(1,1)-XGPS).^2 + (centerPoint(1,2)-YGPS).^2));
                deleteInd(deleteInd == ind) = [];
                
                delete(findobj(haxes3.Children, 'UserData', hObject.UserData));
                delete(findobj(haxes4.Children, 'UserData', hObject.UserData));
                
            end
            
            if isempty(deleteInd)
                deleteGCPBtn.Enable = 'off';
            else
                deleteGCPBtn.Enable = 'on';
            end
            
        end
        
        function REMOVEPOINTSFROMMAIN(~, ~) % No Edits Needed %
            
            if ~isempty(deleteStack)
                deleteQuestion = questdlg({'You Deleted Points During Rectification.';...
                                           'Would you like to permanently remove those points?'},...
                                           'Remove Points?', 'Yes', 'No', 'No');
                            
                setNumDelete = [];
                frameNumDelete = [];
                for j = 1:length(deleteStack)
                    setNumDelete = [setNumDelete; setNum(deleteStack{j}(:,1))];
                    frameNumDelete = [frameNumDelete; frameNum(deleteStack{j}(:,1))];
                end
                                       
                if strcmp(deleteQuestion, 'Yes')
                    for ind = 1:length(setNumDelete)
                        ind2 = find(points.(fieldNames{setNumDelete(ind)}).data{1} == frameNumDelete(ind));
                        points.(fieldNames{setNumDelete(ind)}).data{3}(ind2) = nan;
                        points.(fieldNames{setNumDelete(ind)}).data{4}(ind2) = nan;
                        figdata.ChangeFlag = 1;
                    end
                    
                end
                
            end
            
        end
        
        function [xRectLimsOut, yRectLimsOut, zRectLimsOut] = GetRectGridValues(xRectLimsIn, yRectLimsIn, zRectLimsIn)
            
            limsOK = zeros(1,7);
        
            if isempty(xRectLimsIn)
                xLower = [];
                xLowerStr = '';
                xUpper = [];
                xUpperStr = '';
                xStep = [];
                xStepStr = '';
            else
                xLower = xRectLimsIn(1);
                xLowerStr = num2str(xLower);
                xUpper = xRectLimsIn(3);
                xUpperStr = num2str(xUpper);
                xStep = xRectLimsIn(2);
                xStepStr = num2str(xStep);
                limsOK(1:3) = 1;
            end
            
            if isempty(yRectLimsIn)
                yLower = [];
                yLowerStr = '';
                yUpper = [];
                yUpperStr = '';
                yStep = [];
                yStepStr = '';
            else
                yLower = yRectLimsIn(1);
                yLowerStr = num2str(yLower);
                yUpper = yRectLimsIn(3);
                yUpperStr = num2str(yUpper);
                yStep = yRectLimsIn(2);
                yStepStr = num2str(yStep);
                limsOK(4:6) = 1;
            end
            
            if isempty(zRectLimsIn)
                zVal = [];
                zValStr = '';
            else
                zVal = zRectLimsIn;
                zValStr = num2str(zVal);
                limsOK(7) = 1;
            end
            
            hLoadDialog = dialog('Units', 'character',...
                                 'Position', [ssW/2-35   ssH/2-15 90 20],...
                                 'Name', 'Load Raw Data',...
                                 'WindowStyle', 'modal',...
                                 'Color', GUIColors.LowerPanel,...
                                 'CloseRequestFcn', @CloseDialog);
        
            % Text box and button for X limit selects
            hXLimsTxt = annotation(hLoadDialog, 'textbox',...
                                'LineStyle', 'none',...
                                'Units', 'character',...
                                'Position',[4 15 10 1.5],...
                                'BackgroundColor', GUIColors.LowerPanel,...
                                'Color', GUIColors.TextEdge,...
                                'HorizontalAlignment', 'right',...
                                'VerticalAlignment', 'middle',...
                                'Interpreter', 'none',...
                                'FontSize', 10,...
                                'FontWeight', 'bold',...
                                'String','X =');
                        
            hXLimLowerTxt = annotation(hLoadDialog, 'textbox',...
                             'LineStyle', 'none',...
                             'Units', 'character',...
                             'Position',[16 17 20 1.5],...
                             'BackgroundColor', GUIColors.LowerPanel,...
                             'Color', GUIColors.TextEdge,...
                             'HorizontalAlignment', 'center',...
                             'VerticalAlignment', 'middle',...
                             'Interpreter', 'none',...
                             'FontSize', 10,...
                             'FontWeight', 'bold',...
                             'String','Lower Limit');
                         
            hXLowerLimIn = uicontrol(hLoadDialog, 'Style', 'edit',...
                                            'String', xLowerStr,...
                                            'Units', 'character',...
                                            'Position', [16 15 20 1.5],...
                                            'FontWeight', 'bold',...
                                            'BackgroundColor', GUIColors.ButtonColor,...
                                            'ForegroundColor', GUIColors.Text,...
                                            'Callback', @SETLIMS,...
                                            'Enable', 'on');
                                        
            hXStepTxt = annotation(hLoadDialog, 'textbox',...
                             'LineStyle', 'none',...
                             'Units', 'character',...
                             'Position',[38 17 15 1.5],...
                             'BackgroundColor', GUIColors.LowerPanel,...
                             'Color', GUIColors.TextEdge,...
                             'HorizontalAlignment', 'center',...
                             'VerticalAlignment', 'middle',...
                             'Interpreter', 'none',...
                             'FontSize', 10,...
                             'FontWeight', 'bold',...
                             'String','Step Size');
                         
            hXStepIn = uicontrol(hLoadDialog, 'Style', 'edit',...
                                            'String', xStepStr,...
                                            'Units', 'character',...
                                            'Position', [38 15 15 1.5],...
                                            'FontWeight', 'bold',...
                                            'BackgroundColor', GUIColors.ButtonColor,...
                                            'ForegroundColor', GUIColors.Text,...
                                            'Callback', @SETLIMS,...
                                            'Enable', 'on');
                                        
            hXUpperLimTxt = annotation(hLoadDialog, 'textbox',...
                             'LineStyle', 'none',...
                             'Units', 'character',...
                             'Position',[55 17 20 1.5],...
                             'BackgroundColor', GUIColors.LowerPanel,...
                             'Color', GUIColors.TextEdge,...
                             'HorizontalAlignment', 'center',...
                             'VerticalAlignment', 'middle',...
                             'Interpreter', 'none',...
                             'FontSize', 10,...
                             'FontWeight', 'bold',...
                             'String','Upper Limit');
                         
            hXUpperLimIn = uicontrol(hLoadDialog, 'Style', 'edit',...
                                            'String', xUpperStr,...
                                            'Units', 'character',...
                                            'Position', [55 15 20 1.5],...
                                            'FontWeight', 'bold',...
                                            'BackgroundColor', GUIColors.ButtonColor,...
                                            'ForegroundColor', GUIColors.Text,...
                                            'Callback', @SETLIMS,...
                                            'Enable', 'on');
                                        
            % Text box and button for Y limit selects
            hYLimsTxt = annotation(hLoadDialog, 'textbox',...
                                'LineStyle', 'none',...
                                'Units', 'character',...
                                'Position',[4 9 10 1.5],...
                                'BackgroundColor', GUIColors.LowerPanel,...
                                'Color', GUIColors.TextEdge,...
                                'HorizontalAlignment', 'right',...
                                'VerticalAlignment', 'middle',...
                                'Interpreter', 'none',...
                                'FontSize', 10,...
                                'FontWeight', 'bold',...
                                'String','Y =');
                        
            hYLimLowerTxt = annotation(hLoadDialog, 'textbox',...
                             'LineStyle', 'none',...
                             'Units', 'character',...
                             'Position',[16 11 20 1.5],...
                             'BackgroundColor', GUIColors.LowerPanel,...
                             'Color', GUIColors.TextEdge,...
                             'HorizontalAlignment', 'center',...
                             'VerticalAlignment', 'middle',...
                             'Interpreter', 'none',...
                             'FontSize', 10,...
                             'FontWeight', 'bold',...
                             'String','Lower Limit');
                         
            hYLowerLimIn = uicontrol(hLoadDialog, 'Style', 'edit',...
                                            'String', yLowerStr,...
                                            'Units', 'character',...
                                            'Position', [16 9 20 1.5],...
                                            'FontWeight', 'bold',...
                                            'BackgroundColor', GUIColors.ButtonColor,...
                                            'ForegroundColor', GUIColors.Text,...
                                            'Callback', @SETLIMS,...
                                            'Enable', 'on');
                                        
            hYStepTxt = annotation(hLoadDialog, 'textbox',...
                             'LineStyle', 'none',...
                             'Units', 'character',...
                             'Position',[38 11 15 1.5],...
                             'BackgroundColor', GUIColors.LowerPanel,...
                             'Color', GUIColors.TextEdge,...
                             'HorizontalAlignment', 'center',...
                             'VerticalAlignment', 'middle',...
                             'Interpreter', 'none',...
                             'FontSize', 10,...
                             'FontWeight', 'bold',...
                             'String','Step Size');
                         
            hYStepIn = uicontrol(hLoadDialog, 'Style', 'edit',...
                                            'String', yStepStr,...
                                            'Units', 'character',...
                                            'Position', [38 9 15 1.5],...
                                            'FontWeight', 'bold',...
                                            'BackgroundColor', GUIColors.ButtonColor,...
                                            'ForegroundColor', GUIColors.Text,...
                                            'Callback', @SETLIMS,...
                                            'Enable', 'on');
                                        
            hYUpperLimTxt = annotation(hLoadDialog, 'textbox',...
                             'LineStyle', 'none',...
                             'Units', 'character',...
                             'Position',[55 11 20 1.5],...
                             'BackgroundColor', GUIColors.LowerPanel,...
                             'Color', GUIColors.TextEdge,...
                             'HorizontalAlignment', 'center',...
                             'VerticalAlignment', 'middle',...
                             'Interpreter', 'none',...
                             'FontSize', 10,...
                             'FontWeight', 'bold',...
                             'String','Upper Limit');
                         
            hYUpperLimIn = uicontrol(hLoadDialog, 'Style', 'edit',...
                                            'String', yUpperStr,...
                                            'Units', 'character',...
                                            'Position', [55 9 20 1.5],...
                                            'FontWeight', 'bold',...
                                            'BackgroundColor', GUIColors.ButtonColor,...
                                            'ForegroundColor', GUIColors.Text,...
                                            'Callback', @SETLIMS,...
                                            'Enable', 'on');
                                        
            % Text box and button for Y limit selects
            hZLimsTxt = annotation(hLoadDialog, 'textbox',...
                                'LineStyle', 'none',...
                                'Units', 'character',...
                                'Position',[4 5 10 1.5],...
                                'BackgroundColor', GUIColors.LowerPanel,...
                                'Color', GUIColors.TextEdge,...
                                'HorizontalAlignment', 'right',...
                                'VerticalAlignment', 'middle',...
                                'Interpreter', 'none',...
                                'FontSize', 10,...
                                'FontWeight', 'bold',...
                                'String','Z =');
                         
            hZLimIn = uicontrol(hLoadDialog, 'Style', 'edit',...
                                            'String', zValStr,...
                                            'Units', 'character',...
                                            'Position', [16 5 20 1.5],...
                                            'FontWeight', 'bold',...
                                            'BackgroundColor', GUIColors.ButtonColor,...
                                            'ForegroundColor', GUIColors.Text,...
                                            'Callback', @SETLIMS,...
                                            'Enable', 'on');
                                        
            % Buttons to OK or cancel                
            hOKBtn = uicontrol('Parent',hLoadDialog,...
                           'Style','pushbutton',...
                           'Units', 'character',...
                           'Position',[32 1 12 2],...
                           'HorizontalAlignment', 'center',...
                           'ForegroundColor', GUIColors.Text,...
                           'BackgroundColor',GUIColors.ButtonColor,...
                           'String','OK',...
                           'Enable', 'off',...
                           'Callback', @ReturnDialog);
                       
            hCancelBtn = uicontrol('Parent',hLoadDialog,...
                               'Style','pushbutton',...
                               'Units', 'character',...
                               'Position',[46 1 12 2],...
                               'HorizontalAlignment', 'center',...
                               'ForegroundColor', GUIColors.Text,...
                               'BackgroundColor',GUIColors.ButtonColor,...
                               'String','Cancel',...
                               'Callback', @CloseDialog);
                           
            xRectLimsOut = [];
            yRectLimsOut = [];
            zRectLimsOut = [];
            
            if sum(limsOK) == 7
                hOKBtn.Enable = 'on';
            end
            
            uiwait(hLoadDialog);
                        
        
            function SETLIMS(hObject, ~)
                
                inputLim = str2double(hObject.String);
                
                if isnan(inputLim) == 1
                    if hObject == hXLowerLimIn
                        xLower = [];
                        hXLowerLimIn.String = '';
                        limsOK(1) = 0;
                    elseif hObject == hXStepIn
                        xStep = [];
                        hXStepIn.String = '';
                        limsOK(2) = 0;
                    elseif hObject == hXUpperLimIn
                        xUpper = [];
                        hXUpperLimIn.String = '';
                        limsOK(3) = 0;
                    elseif hObject == hYLowerLimIn
                        yLower = [];
                        hYLowerLimIn.String = '';
                        limsOK(4) = 0;
                    elseif hObject == hYStepIn
                        yStep = [];
                        hYStepIn.String = '';
                        limsOK(5) = 0;
                    elseif hObject == hYUpperLimIn
                        yUpper = [];
                        hYUpperLimIn.String = '';
                        limsOK(6) = 0;
                    elseif hObject == hZLimIn
                        zVal = [];
                        hZLimIn.String = '';
                        limsOK(7) = 0;
                    end
                else
                    if hObject == hXLowerLimIn
                        xLower = inputLim;
                        limsOK(1) = 1;
                    elseif hObject == hXStepIn
                        xStep = inputLim;
                        limsOK(2) = 1;
                    elseif hObject == hXUpperLimIn
                        xUpper = inputLim;
                        limsOK(3) = 1;
                    elseif hObject == hYLowerLimIn
                        yLower = inputLim;
                        limsOK(4) = 1;
                    elseif hObject == hYStepIn
                        yStep = inputLim;
                        limsOK(5) = 1;
                    elseif hObject == hYUpperLimIn
                        yUpper = inputLim;
                        limsOK(6) = 1;
                    elseif hObject == hZLimIn
                        zVal = inputLim;
                        limsOK(7) = 1;
                    end
                end
                
                if sum(limsOK) == 7
                    hOKBtn.Enable = 'on';
                end
                
            end
            
            function CloseDialog(~, ~)
            
                xRectLimsOut = [];
                yRectLimsOut = [];
                zRectLimsOut = [];
                delete(hLoadDialog)
            
            end
        
            function ReturnDialog(~, ~)
                
                errFlag = CheckGridValues();
            
                if errFlag == 1
                    errordlg('Limits must be increasing and Step Size must be greater than zero.', 'Limits Error', 'modal');
                else
                    xRectLimsOut = [xLower xStep xUpper];
                    yRectLimsOut = [yLower yStep yUpper];
                    zRectLimsOut = zVal;
                    delete(hLoadDialog)
                end
            
            end
            
            function [flag] = CheckGridValues()
                
                flag = 0;
                if xLower >= xUpper || yLower >= yUpper || xStep <= 0 || yStep <= 0
                    flag = 1;
                end
                
            end
        
    end
        
        function CheckInputParams(inputVar) % Edits Done %
            
            if isempty(rectParams.(inputVar))
                if strcmp(inputVar, 'X')
                    checkParams(1) = 0;
                elseif strcmp(inputVar, 'Y')
                    checkParams(2) = 0;
                elseif strcmp(inputVar, 'Z')
                    checkParams(3) = 0;
                elseif strcmp(inputVar, 'Pitch')
                    checkParams(4) = 0;
                elseif strcmp(inputVar, 'Roll')
                    checkParams(5) = 0;
                elseif strcmp(inputVar, 'Azimuth')
                    checkParams(6) = 0;
                elseif strcmp(inputVar, 'Fx')
                    checkParams(7) = 0;
                elseif strcmp(inputVar, 'Fy')
                    checkParams(8) = 0;
                elseif strcmp(inputVar, 'Xp')
                    checkParams(9) = 0;
                elseif strcmp(inputVar, 'Yp')
                    checkParams(10) = 0;
                elseif strcmp(inputVar, 'D1')
                    checkParams(11) = 0;
                elseif strcmp(inputVar, 'D2')
                    checkParams(12) = 0;
                elseif strcmp(inputVar, 'D3')
                    checkParams(13) = 0;
                elseif strcmp(inputVar, 'T1')
                    checkParams(14) = 0;
                elseif strcmp(inputVar, 'T2')
                    checkParams(15) = 0;
                elseif strcmp(inputVar, 'Alpha')
                    checkParams(16) = 0;
                end
            else
                if strcmp(inputVar, 'X')
                    checkParams(1) = 1;
                elseif strcmp(inputVar, 'Y')
                    checkParams(2) = 1;
                elseif strcmp(inputVar, 'Z')
                    checkParams(3) = 1;
                elseif strcmp(inputVar, 'Pitch')
                    checkParams(4) = 1;
                elseif strcmp(inputVar, 'Roll')
                    checkParams(5) = 1;
                elseif strcmp(inputVar, 'Azimuth')
                    checkParams(6) = 1;
                elseif strcmp(inputVar, 'Fx')
                    checkParams(7) = 1;
                elseif strcmp(inputVar, 'Fy')
                    checkParams(8) = 1;
                elseif strcmp(inputVar, 'Xp')
                    checkParams(9) = 1;
                elseif strcmp(inputVar, 'Yp')
                    checkParams(10) = 1;
                elseif strcmp(inputVar, 'D1')
                    checkParams(11) = 1;
                elseif strcmp(inputVar, 'D2')
                    checkParams(12) = 1;
                elseif strcmp(inputVar, 'D3')
                    checkParams(13) = 1;
                elseif strcmp(inputVar, 'T1')
                    checkParams(14) = 1;
                elseif strcmp(inputVar, 'T2')
                    checkParams(15) = 1;
                elseif strcmp(inputVar, 'Alpha')
                    checkParams(16) = 1;
                end
            end
            

            
        end

        function PlotCameraUnrectified
    
            if errorFlag == 0
                if strcmp(figdata.CameraType, 'IR') == 1
                elseif strcmp(figdata.CameraType, 'EO') == 1
                    tiffData = demosaic(tiffData.*2^(16-figdata.BitDepth), 'rggb');
                end
                imagesc(haxes3, tiffData);
                hold(haxes3, 'on')
                    plot(haxes3, xPixel, yPixel, 'sg', 'LineWidth', 2, 'MarkerFaceColor', 'g', 'Tag', 'GCPUn', 'ButtonDownFcn', @SELECTGCP)
                    plot(haxes3, xPixGPS, yPixGPS, '+r', 'LineWidth', 2, 'Tag', 'GCPUn', 'PickableParts', 'none')
                hold(haxes3, 'off')
            else
                text(haxes3, 400, 384, {'Image Missing';['Frame ' num2str(frameNum(1))]},'Color', 'red', 'FontSize', 16)
            end
        
        end
        
        function PlotHorizon
            
            if sum(checkParams([4 5 6 7])) == 4;
                if errorFlag == 0;
                    delete(findobj(haxes3.Children,'Tag','horizon'))
                    yPix = 1:figdata.ImHeight;
                    xPixLeft = ones(1,length(yPix));
                    xPixRight = ones(1,length(yPix)).*figdata.ImWidth;
                    [x_hor1, y_hor1] = get_horizon(figdata.ImWidth, figdata.ImHeight, xPixLeft, yPix,...
                                        rectParams.xppo, rectParams.yppo, rectParams.hfov,...
                                        rectParams.dip, rectParams.tilt, rectParams.head);
                    [x_hor2, y_hor2] = get_horizon(figdata.ImWidth, figdata.ImHeight, xPixRight, yPix,...
                                        rectParams.xppo, rectParams.yppo, rectParams.hfov,...
                                        rectParams.dip, rectParams.tilt, rectParams.head);
                    hold(haxes3, 'on')
                        plot(haxes3, [x_hor1 x_hor2], [y_hor1 y_hor2], 'm', 'LineWidth', 2, 'Tag', 'horizon')
                    hold(haxes3, 'off')
                    text(haxes3, x_hor1+10, y_hor1+2, 'Horizon Estimate', 'VerticalAlignment', 'bottom', 'Color', 'm', 'Tag', 'horizon')
                    
                end
            else
                delete(findobj(haxes3.Children,'Tag','horizon'))
            end
                
        end
        
        function PlotRectified(xPlot, yPlot, imDatPlot)
            
            if errorFlag == 0
                 
                delete(haxes4.Children) % Start fresh

                X0 = rectParams.XPose;
                Y0 = rectParams.YPose;
            
                imagesc(haxes4, xPlot(1, 1:end), yPlot(1:end, 1), imDatPlot);
                
                hold(haxes4, 'on')
                
                    plot(haxes4, XGPS, YGPS, 'og', 'LineWidth', 2, 'Tag', 'GCPR', 'ButtonDownFcn', @SELECTGCP) % GCP X/Y location from GPS
                    plot(haxes4, xGPSPix, yGPSPix, '+r', 'LineWidth', 2, 'Tag', 'GCPR', 'PickableParts', 'none')
                    plot(haxes4, X0, Y0, 'oy', 'LineWidth', 3, 'MarkerSize', 10)
                    
                    % plot selected points if there are any
                    if any( strcmp( get(haxes3.Children, 'Tag'), 'GCPSelect') )
                        selectedInd = get(haxes3.Children, 'UserData');
                        for plotInd = 1:length(selectedInd)
                            j = selectedInd{plotInd};
                            if ~isempty(j)
                                if plotInd == 1
                                    plot(haxes4, XGPS(j), YGPS(j), 'om', 'LineWidth', 2, 'Tag', 'GCPSelect', 'UserData', j, 'ButtonDownFcn', @UNSELECTGCP)
                                    plot(haxes4, xGPSPix(j), yGPSPix(j), '+r', 'LineWidth', 2, 'Tag', 'GCPR', 'UserData', j, 'ButtonDownFcn', @UNSELECTGCP)
                                else
                                    if j ~= selectedInd{plotInd-1}
                                        plot(haxes4, XGPS(j), YGPS(j), 'om', 'LineWidth', 2, 'Tag', 'GCPSelect', 'UserData', j, 'ButtonDownFcn', @UNSELECTGCP)
                                        plot(haxes4, xGPSPix(j), yGPSPix(j), '+r', 'LineWidth', 2, 'Tag', 'GCPR', 'UserData', j, 'ButtonDownFcn', @UNSELECTGCP)
                                    end
                                end
                            end
                        end
                    end
                    
                hold(haxes4, 'off')
                
                %nanInd = ~isnan(imDatPlot);
                nanInd = imDatPlot(:,:,1) ~= 0;
                haxes4.XLim = [ min( [min(xPlot(nanInd)) X0 nanmin(xGPSPix)] ) max( [max(xPlot(nanInd)) X0 nanmax(xGPSPix)] ) ];
                haxes4.YLim = [ min( [min(yPlot(nanInd)) Y0 nanmin(yGPSPix)] ) max( [max(yPlot(nanInd)) Y0 nanmax(yGPSPix)] ) ];
                haxes4.XTick = [];
                haxes4.YTick = [];
                haxes4.YDir = 'normal';
                haxes4.XTickLabel = '';
                haxes4.YTickLabel = '';
                haxes4.Color = GUIColors.Axes;

%                 rectTitle = {'Rectified';['alt = ' num2str(rectParams.altRect) ', hfov = ' num2str(rectParams.hfovRect)...
%                             ', \lambda = ' num2str(rectParams.dipRect) ', \phi = ' num2str(rectParams.tiltRect)...
%                             ', \theta = ' num2str(rectParams.headRect)]};
%                 if isempty(rectParams.errPolyRect)
%                     rectTitle{2} = [rectTitle{2} ', RMS Error = ' num2str(rectParams.errGeoRect)];
%                 else
%                     rectTitle{2} = [rectTitle{2} ', RMS Error = ' num2str(rectParams.errPolyRect)];
%                 end

                haxes4.Title.String = {'Rectified';' '};
                haxes4.Title.Color = GUIColors.Text;
                haxes4.Title.FontSize = 10;
            end
            
        end
        
        function ADJUSTFIGURE2(~,~)
        
            adjustSizeRect = hfig2.Position;
            adjustHeightRect = adjustSizeRect(4).*ssH;
            adjustWidthRect = adjustSizeRect(3).*ssW;
            
            haxes3.Position = [axesHorOffset/adjustWidthRect...
                               axesBottomOffset/adjustHeightRect...
                               (1-(3*axesHorOffset+editWidth+txtWidth+endWidth)/(adjustWidthRect))/2.0...
                               1-(axesTopOffset+axesBottomOffset+loadRectHeight)/adjustHeightRect];
            
            haxes4.Position = [2*axesHorOffset/adjustWidthRect+haxes3.Position(3)...
                               axesBottomOffset/adjustHeightRect...
                               (1-(3*axesHorOffset+editWidth+txtWidth+endWidth)/(adjustWidthRect))/2.0...
                               1-(axesTopOffset+axesBottomOffset+loadRectHeight)/adjustHeightRect];
            
            hpanLoadRect.Position = [0 ... % left
                                     (1-(loadRectHeight/adjustHeightRect))... % bottom
                                     1-(2*horOffset1+txtWidth+editWidth+endWidth)/adjustWidthRect... % width
                                     (loadRectHeight/adjustHeightRect)]; % height
                                 
            loadCamCalBtn.Position = [(loadRectBtnOffset/(hpanLoadRect.Position(3).*adjustWidthRect))... % left
                                       ((loadRectHeight-loadRectBtnHeight)/2)/loadRectHeight... % bottom
                                       (loadRectBtnWidth/(hpanLoadRect.Position(3).*adjustWidthRect))... % width
                                       loadRectBtnHeight/loadRectHeight]; % height
                                   
            loadPoseBtn.Position = [loadCamCalBtn.Position(1)+loadCamCalBtn.Position(3)+(loadRectBtnOffset/(hpanLoadRect.Position(3).*adjustWidthRect))... % left
                                   ((loadRectHeight-loadRectBtnHeight)/2)/loadRectHeight... % bottom
                                   (loadRectBtnWidth/(hpanLoadRect.Position(3).*adjustWidthRect))... % width
                                   loadRectBtnHeight/loadRectHeight]; % Height
                               
            saveRectBtn.Position = [loadPoseBtn.Position(1)+loadPoseBtn.Position(3)+(loadRectBtnOffset/(hpanLoadRect.Position(3).*adjustWidthRect))... % left
                                   ((loadRectHeight-loadRectBtnHeight)/2)/loadRectHeight... % bottom
                                   (loadRectBtnWidth/(hpanLoadRect.Position(3).*adjustWidthRect))... % width
                                   loadRectBtnHeight/loadRectHeight]; % Height
                                
            computePoseBtn.Position = [saveRectBtn.Position(1)+saveRectBtn.Position(3)+(loadRectBtnOffset/(hpanLoadRect.Position(3).*adjustWidthRect))... % left
                                    ((loadRectHeight-loadRectBtnHeight)/2)/loadRectHeight... % bottom
                                    (loadRectBtnWidth/(hpanLoadRect.Position(3).*adjustWidthRect))... % width
                                    loadRectBtnHeight/loadRectHeight]; % Height
                                
            deleteGCPBtn.Position = [1-((2*loadRectBtnOffset+2*loadRectBtnWidth)/(hpanLoadRect.Position(3).*adjustWidthRect))... % left
                                     ((loadRectHeight-loadRectBtnHeight)/2)/loadRectHeight... % bottom
                                     (loadRectBtnWidth/(hpanLoadRect.Position(3).*adjustWidthRect))... % width
                                     loadRectBtnHeight/loadRectHeight]; % height
                                          
            undoGCPBtn.Position = [1-((loadRectBtnOffset+loadRectBtnWidth)/(hpanLoadRect.Position(3).*adjustWidthRect))... % left
                                  ((loadRectHeight-loadRectBtnHeight)/2)/loadRectHeight... % bottom
                                  (loadRectBtnWidth/(hpanLoadRect.Position(3).*adjustWidthRect))... % width
                                   loadRectBtnHeight/loadRectHeight]; % height
            
            hpanCamEx.Position = [1-(2*horOffset1+txtWidth+editWidth+endWidth)/adjustWidthRect...
                                  1-(6*editHeight+6*vertOffset+startOffset)/adjustHeightRect...
                                 (2*horOffset1+txtWidth+editWidth+endWidth)/adjustWidthRect...
                                 (6*editHeight+6*vertOffset+startOffset)/adjustHeightRect];
                             
            hpanCamIn.Position = [1-(2*horOffset1+txtWidth+editWidth+endWidth)/adjustWidthRect...
                                  1-(10*editHeight+10*vertOffset+2*startOffset)/adjustHeightRect...
                                 (2*horOffset1+txtWidth+editWidth+endWidth)/adjustWidthRect...
                                 (4*editHeight+4*vertOffset+startOffset)/adjustHeightRect];
                             
            hpanDistortIn.Position = [1-(2*horOffset1+txtWidth+editWidth+endWidth)/adjustWidthRect...
                                        1-(16*editHeight+16*vertOffset+3*startOffset)/adjustHeightRect...
                                        (2*horOffset1+txtWidth+editWidth+endWidth)/adjustWidthRect...
                                        (6*editHeight+6*vertOffset+startOffset)/adjustHeightRect];
                                              
            hpanComputedPose.Position = [1-(2*horOffset1+txtWidth+editWidth+endWidth)/adjustWidthRect...
                                         1-(22*editHeight+22*vertOffset+4*startOffset)/adjustHeightRect...
                                        (2*horOffset1+txtWidth+editWidth+endWidth)/adjustWidthRect...
                                        (6*editHeight+6*vertOffset+startOffset)/adjustHeightRect];
                                        
            hpanFiller.Position = [1-(2*horOffset1+txtWidth+editWidth+endWidth)/adjustWidthRect...
                                   0.0...
                                   (2*horOffset1+txtWidth+editWidth+endWidth)/adjustWidthRect...
                                   1-(22*editHeight+22*vertOffset+4*startOffset)/adjustHeightRect];

        end

    end

end


%% Rectification Functions
function  [xNew, yNew, zNew, pitchNew, rollNew, azimuthNew] = computeCameraPoseFromGCPs(xGCP, yGCP, zGCP, uGCP, vGCP, params)

    xyzGCP = [xGCP(:) yGCP(:) zGCP(:)];
    
    uvGCP = [uGCP(:) vGCP(:)];
    
    icp.NU  = params.Nx;
    icp.NV  = params.Ny;
    icp.c0U = params.Xp;
    icp.c0V = params.Yp;
    icp.fx  = params.Fx;
    icp.fy  = params.Fy;
    icp.d1  = params.D1;
    icp.d2  = params.D2;
    icp.d3  = params.D3;
    icp.t1  = params.T1;
    icp.t2  = params.T2;
    icp.ac  = params.Alpha;
    icp = makeRadialDistortion(icp);
    icp = makeTangentialDistortion(icp);
    
    beta0 = [params.X params.Y params.Z params.Pitch params.Roll params.Azimuth];
    
    betaNew = constructCameraPose(xyzGCP, uvGCP, icp, beta0);
    
    xNew = betaNew(1);
    yNew = betaNew(2);
    zNew = betaNew(3);
    pitchNew = betaNew(4);
    rollNew = betaNew(5);
    azimuthNew = betaNew(6);

end

function [U, V] = XYZ2UV(xGCP, yGCP, zGCP, params)

    icp.NU  = params.Nx;
    icp.NV  = params.Ny;
    icp.c0U = params.Xp;
    icp.c0V = params.Yp;
    icp.fx  = params.Fx;
    icp.fy  = params.Fy;
    icp.d1  = params.D1;
    icp.d2  = params.D2;
    icp.d3  = params.D3;
    icp.t1  = params.T1;
    icp.t2  = params.T2;
    icp.ac  = params.Alpha;
    icp = makeRadialDistortion(icp);
    icp = makeTangentialDistortion(icp);
    
    beta0 = [params.XPose params.YPose params.ZPose params.PitchPose params.RollPose params.AzimuthPose];

    [U, V] = getUVfromXYZ(xGCP, yGCP, zGCP, icp, beta0);
    
end

function [X, Y, Z] = UV2XYZ(U, V, zGPS,params)

    icp.NU  = params.Nx;
    icp.NV  = params.Ny;
    icp.c0U = params.Xp;
    icp.c0V = params.Yp;
    icp.fx  = params.Fx;
    icp.fy  = params.Fy;
    icp.d1  = params.D1;
    icp.d2  = params.D2;
    icp.d3  = params.D3;
    icp.t1  = params.T1;
    icp.t2  = params.T2;
    icp.ac  = params.Alpha;
    icp = makeRadialDistortion(icp);
    icp = makeTangentialDistortion(icp);
    
    beta0 = [params.XPose params.YPose params.ZPose params.PitchPose params.RollPose params.AzimuthPose];

    [X, Y, Z] = getXYZfromUV(U, V, icp, beta0, zGPS, '-z');
    
end

function [xRectGrid, yRectGrid, imRectGrid] = MakeRectGrid(imDat, params)

    xRectLims = params.XRectLims;
    yRectLims = params.YRectLims;
    zRectLims = params.ZRectLims;
    
    xRectVect = xRectLims(1):xRectLims(2):xRectLims(3);
    yRectVect = yRectLims(1):yRectLims(2):yRectLims(3);

    [xRectGrid, yRectGrid] = meshgrid(xRectVect, yRectVect);
    zRectGrid = ones(size(xRectGrid)).*zRectLims;

    [uRectGrid, vRectGrid] = XYZ2UV(xRectGrid, yRectGrid, zRectGrid, params);
    
    % find points actually in the image
    iIn = find(uRectGrid >= 1 & uRectGrid <= params.Nx & vRectGrid >= 1 & vRectGrid <= params.Ny);
    Uin = uRectGrid(iIn);
    Vin = vRectGrid(iIn);

    % get the image values at those new, computed pixel locations
    [Uorig, Vorig] = meshgrid(1:params.Nx, 1:params.Ny);

    if size(imDat,3) == 3 % image is color
        imDatInterpR = interp2(Uorig, Vorig, double(imDat(:,:,1)), Uin, Vin);
        imDatInterpG = interp2(Uorig, Vorig, double(imDat(:,:,2)), Uin, Vin);
        imDatInterpB = interp2(Uorig, Vorig, double(imDat(:,:,3)), Uin, Vin);
        dimSize = 3;
    else
        imDatInterp = interp2(Uorig, Vorig, double(imDat), Uin, Vin);
        dimSize = 1;
    end

    % drop the intesnities into the pixels
    if dimSize == 3
        imRectGrid = NaN([size(xRectGrid), 3]);
        
        imRectGridR = NaN([size(xRectGrid), 1]);
        imRectGridR(iIn) = imDatInterpR;
        imRectGrid(:,:,1) = imRectGridR;
        
        imRectGridG = NaN([size(xRectGrid), 1]);
        imRectGridG(iIn) = imDatInterpG;
        imRectGrid(:,:,2) = imRectGridG;
        
        imRectGridB = NaN([size(xRectGrid), 1]);
        imRectGridB(iIn) = imDatInterpB;
        imRectGrid(:,:,3) = imRectGridB;
        
    else
        imRectGrid = NaN([size(xRectGrid), 1]);
        imRectGrid(iIn) = imDatInterp;
    end
    
    imRectGrid = uint16(imRectGrid);

end

function betaNew = constructCameraPose(xyzGCP, uvGCP, icp, beta0)

    % betaNew = constructCameraPose(xyzGCP, icp, beta0)
    % ===============================================================
    % Do a nonlinear least squares regression to find the best parameters for
    % the camera's extrinisc parameters (beta = [x y z pitch roll azimuth]).
    % The model for the least squares fit in the function findUVFrom6DOF.m
    % 
    % This program is simple for now, but is being left for future expansion.
    % ===============================================================

    UV = [uvGCP(:,1); uvGCP(:,2)];

    [betaNew, R, J, CovB, MSE, ErrInfo] = nlinfit(xyzGCP, UV, @(beta0, xyzGCP)findUVFrom6DOF(beta0, icp, xyzGCP),beta0);

end

function UV = findUVFrom6DOF(beta0, icp, xyz)

    % UV = findUVFrom6DOF(beta0, icp, xyz)
    % =====================================================
    % Converts a set of real world x, y, and zs into the corresponding image
    % coordinates U, and V.  The convertion uses camera intrinsic and 
    % distortion parameters, defined in icp, and extrinsic parameters, defined
    % in beta0.  This program is to be used as the model function for nlinfit.m
    % to find the best extrinsic camera parameters given a set of GCPs
    % 
    % Inputs:
    %     beta0 = The camera extrinsic parameters defined as a row vector with
    %             elements [x y z pitch roll azimuth].
    %     icp = structure made from the camera parameter structure produced by
    %           makeIntrinsicStructureFromCalTechCal.m
    %     xyz = An array of real world points.  Each column is a column vector
    %           containing all the x, y, or z values.  So the size of the array
    %           should by Nx3, where N is the number of real world points to 
    %           convert 
    % 
    % Outputs:
    %     UV = A single column vector containing all the distorted image
    %          cooordinates, set up as [U;V].  This is used by nlinfit.m to
    %          find the optimum beta0 vector given a set of GCPs.
    % =====================================================

    % make the P matrix
    K = makeCameraMatrix(icp);
    R = makeCameraRotationMatrix(beta0(4), beta0(5), beta0(6));
    IC = [eye(3) -beta0(1:3)'];
 
    P = K*R*IC;

    % Convet x, y, z to undistorted U, V.
    UVZc = P*[xyz'; ones(1,size(xyz,1))];
    UV = UVZc./repmat(UVZc(3,:),3,1); % Normalize each column of UV by the bottom element (so the bottom row is now all ones)

    % Distort the computed pixel coordinates
    [U,V] = distortUV(UV(1,:)',UV(2,:)',icp); 

    UV = [U(:); V(:)];

end

function icp = makeRadialDistortion(icp)

    %   lcp = makeRadDist(lcp)
    %
    %  computes the radial stretch factor for lens distortion as a function of
    %  normalized radius, for any lens calibration profile

    % This is taken from an Adobe lcp file found on the web.  

    % updated from previous version to reflect that this need only be computed
    % once for any lcp, so should be stored in the lcp.

    % copied by Levi Gorrell to keep codes compartmentalized

    r = 0: 0.001: 2;   % max tan alpha likely to see.
    r2 = r.*r;
    fr = 1 + icp.d1*r2 + icp.d2*r2.*r2 + icp.d3*r2.*r2.*r2;

    % limit to increasing r-distorted (no folding back)
    rd = r.*fr;
    good = diff(rd)>0;      
    icp.r = r(good);
    icp.fr = fr(good);

    %
    %   Copyright (C) 2017  Coastal Imaging Research Network
    %                       and Oregon State University

    %    This program is free software: you can redistribute it and/or  
    %    modify it under the terms of the GNU General Public License as 
    %    published by the Free Software Foundation, version 3 of the 
    %    License.

    %    This program is distributed in the hope that it will be useful,
    %    but WITHOUT ANY WARRANTY; without even the implied warranty of
    %    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    %    GNU General Public License for more details.

    %    You should have received a copy of the GNU General Public License
    %    along with this program.  If not, see
    %                                <http://www.gnu.org/licenses/>.

    % CIRN: https://coastal-imaging-research-network.github.io/
    % CIL:  http://cil-www.coas.oregonstate.edu
    %
    %key UAVProcessingToolbox
    %

end

function icp = makeTangentialDistortion(icp)

    %   lcp = makefr(lcpIn)
    %
    %  computes the tangential distortion over an expected domain x and y
    %  in tan(alpha) coords that can be used for an interp2 for any required
    %  set of x,y values

    % copied by Levi Gorrell to keep codes compartmentalized

    % This is taken from the Caltech cam cal docs.  
    xmax = 1.5;     % no idea if this is good
    dx = 0.1;
    ymax = 1.3;
    dy = 0.1;

    icp.x = -xmax: dx: xmax;
    icp.y = -ymax: dy: ymax;
    [X,Y] = meshgrid(icp.x,icp.y);
    X = X(:); Y = Y(:);
    r2 = X.*X + Y.*Y;
    icp.dx = reshape(2*icp.t1*X.*Y + icp.t2*(r2+2*X.*X),[],length(icp.x));
    icp.dy = reshape(icp.t1*(r2+2*Y.*Y) + 2*icp.t2*X.*Y,[],length(icp.x));


    %
    %   Copyright (C) 2017  Coastal Imaging Research Network
    %                       and Oregon State University

    %    This program is free software: you can redistribute it and/or  
    %    modify it under the terms of the GNU General Public License as 
    %    published by the Free Software Foundation, version 3 of the 
    %    License.

    %    This program is distributed in the hope that it will be useful,
    %    but WITHOUT ANY WARRANTY; without even the implied warranty of
    %    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    %    GNU General Public License for more details.

    %    You should have received a copy of the GNU General Public License
    %    along with this program.  If not, see
    %                                <http://www.gnu.org/licenses/>.

    % CIRN: https://coastal-imaging-research-network.github.io/
    % CIL:  http://cil-www.coas.oregonstate.edu
    %
    %key UAVProcessingToolbox
    %

end

function [Ud, Vd] = distortUV(Uu, Vu, icp)

    % [Ud, Vd] = distortUV(Uu, Vu, icp)
    % =================================================
    % Converts pixels from undistorted to distorted image coordinates.  This
    % program is based off distortCaltech.m from the CIRN UAV-toolbox and is
    % based on equations from the Cal Tech calibration toolbox manual.
    % 
    % Inputs:
    %     Uu = U pixel poistion, in image coordinates, to be distorted.  Uu may
    %          be a 1D vector or a 2D array.
    %     Vu = V pixel poistion, in image coordinates, to be distorted.  Vu may
    %          be a 1D vector or a 2D array.
    %     icp = structure made from the camera parameter structure produced by
    %           makeIntrinsicStructureFromCalTechCal.m
    % 
    % Outputs:
    %     Ud = distorted U pixel position in image coordinates.  Is the same
    %          size as Uu.
    %     Vd = distorted V pixel position in image coordinates.  Is the same
    %          size as Vu.
    % =================================================

    [rowU, colU] = size(Uu);
    [rowV, colV] = size(Vu);
    if rowU ~= rowV || colU ~= colV
        error('Input Uu and Vu must be the same size')
    end

    % convert Uu and Vu into normalized camera coordinates
    x = (Uu(:)-icp.c0U)/icp.fx;
    y = (Vu(:)-icp.c0V)/icp.fy;

    % distortion based on distance from image center
    r2 = x.*x + y.*y;
    r = sqrt(r2);
    rOut = r > 2;

    % Find the radial distortion factor 
    fr = 1 + icp.d1*r2 + icp.d2*r2.*r2 + icp.d3*r2.*r2.*r2;

    % Find the tangential distortion factor 
    dx = 2*icp.t1*x.*y + icp.t2*(r2+2*x.*x);
    dy = icp.t1*(r2+2*y.*y) + 2*icp.t2*x.*y;

    % distort locations in camera coordinates
    x2 = x.*fr + dx;
    y2 = y.*fr + dy;

    % get rid of values with large r. These may distort back into the image
    % space
    x2(rOut) = NaN;
    y2(rOut) = NaN;

    % convert from camera coordinates back to image coordinates
    ud = (x2+icp.ac.*y2).*icp.fx + icp.c0U;       % accounts for skewness
    vd = y2.*icp.fy + icp.c0V;

    % convert undistorted pixels into same aray size as inputs
    Ud = reshape(ud, rowU, colU);
    Vd = reshape(vd, rowV, colV);

end

function [Uu, Vu] = undistortUV(Ud, Vd, icp)

    % [Uu, Vu] = undistortUV(Ud, Vd, icp)
    % =================================================
    % Converts pixels from distorted to undistorted image coordinates.  This
    % program is based off undistortCaltech.m from the CIRN UAV-toolbox and 
    % comp_distortion_oulu.m from the Cal Tech toolbox. The equations come from
    % the Cal Tech calibration toolbox manual.
    % 
    % Inputs:
    %     Ud = U pixel poistion, in image coordinates, to be undistorted.  Ud 
    %          may be a 1D vector or a 2D array.
    %     Vd = V pixel poistion, in image coordinates, to be undistorted.  Vd 
    %          may be a 1D vector or a 2D array.
    %     icp = structure made from the camera parameter structure produced by
    %           makeIntrinsicStructureFromCalTechCal.m
    % 
    % Outputs:
    %     Uu = undistorted U pixel position in image coordinates.  Is the same
    %          size as Ud.
    %     Vu = undistorted V pixel position in image coordinates.  Is the same
    %          size as Vd.
    % =================================================

    [rowU, colU] = size(Ud);
    [rowV, colV] = size(Vd);
    if rowU ~= rowV || colU ~= colV
        error('Input Ud and Vd must be the same size')
    end

    % convert from image coordinates to normalized camera coordinates.
    yd = (Vd(:)-icp.c0V)/icp.fy;
    xd = ((Ud(:)-icp.c0U)/icp.fx)-(icp.ac*yd);

    % compute radial distance
    r2 = xd.*xd + yd.*yd;
    r = sqrt(r2);   % radius in distorted pixels

    if r~=0
    
        x = xd;
        y = yd;
        % iterate through to compute undistorted pixles.  This is done because
        % fr, dx, and dy depend on the undistorted radius.  r2 is computed
        % above as a distorted radius. So the progarm undistorts the pixels and
        % then computes fr, dx, and dy again to get the true, undistoprted
        % pixel locations.
        for i = 1:20
            fr = 1 + icp.d1.*r2 + icp.d2.*r2.*r2 + icp.d3.*r2.*r2.*r2;
            dx = 2*icp.t1.*x.*y + icp.t2.*(r2+2.*x.*x);
            dy = icp.t1.*(r2+2.*y.*y) + 2*icp.t2.*x.*y;
            x = (xd - dx)./fr;
            y = (yd - dy)./fr;
            r2 = x.*x + y.*y;
        end
        x2 = x;
        y2 = y;
    
        % convert back to image coordinates
        Uu = x2*icp.fx + icp.c0U;
        Vu = y2*icp.fy + icp.c0V;
    else
        Uu = Ud;     % camera center pixel is unchanged by distortion
        Vu = Vd;
    end

    % convert undistorted pixels into same aray size as inputs
    Uu = reshape(Uu, rowU, colU);
    Vu = reshape(Vu, rowV, colV);

end

function [U, V] = getUVfromXYZ(X, Y, Z, icp, beta0)

    % [U, V] = getUVfromXYZ(X, Y, Z, icp)
    % ================================================================
    % Returns the image coordinates of a set of real world, rectangular
    % coordinates.  
    % 
    % Inputs:
    %     X = The real world, rectangular, X coordinate.  X should be posotive
    %         to the east. May be scalar, 1D vector, or 2D array.
    %     Y = The real world, rectangular, Y coordinate.  Y should be posotive
    %         to the north. May be scalar, 1D vector, or 2D array.
    %     Z = The real world, rectangual, Z coordinate.  Z should be posotive
    %         up. May be scalar, 1D vector, or 2D array.
    %     icp = The structure containing the camera's intrinsic and calibration
    %           parameters.  Strucutre created with
    %           makeInstrinsicStructFromCalTechCal.m
    %     beta0 = The camera extrinsic parameters defined as a row vector with
    %             elements [x y z pitch roll azimuth].
    % 
    % Outputs:
    %     U = The U image coordinate corresponding to the X, Y, Z real world
    %         coordinate. Will be the same size as X, Y, Z.
    %     V = The V image coordinate corresponding to the X, Y, Z real world
    %         coordinate. Will be the same size as X, Y, Z.
    % ================================================================

    [rowX, colX] = size(X);
    [rowY, colY] = size(Y);
    [rowZ, colZ] = size(Z);
    if rowX ~= rowY || colX ~= colY || rowX ~= rowZ || colX ~= colZ
        error('Input X, Y, and Z must be the same size')
    end

    % convet x, y, and z into one matrix for matrix multiplication
    XYZ = [X(:)'; Y(:)'; Z(:)'; ones(1,length(X(:)))];

    % make the P matrix
    K = makeCameraMatrix(icp);
    R = makeCameraRotationMatrix(beta0(4), beta0(5), beta0(6));
    IC = [eye(3) -beta0(1:3)'];
 
    P = K*R*IC;

    % Convet x, y, z to undistorted U, V.
    UVZc = P*XYZ;
    UV = UVZc./repmat(UVZc(3,:),3,1); % Normalize each column of UVZc by the bottom element, which is Zc (so the bottom row is now all ones).
    U = UV(1,:);
    V = UV(2,:);

    % Distort the computed pixel coordinates
    [U,V] = distortUV(UV(1,:)',UV(2,:)',icp);

    % reshape back into original input size
    U = reshape(U, rowX, colX);
    V = reshape(V, rowX, colX);

end

function [X, Y, Z] = getXYZfromUV(U, V, icp, beta0, val, flag)

    % [X, Y, Z] = getXYZfromUV(U, V, icp, beta0, val, flag)
    % ================================================================
    % Returns the real world, rectangular coordinates X, Y, Z given an input 
    % image coordinate U, V given a camera structure and pose.  since the 
    % solution to go from U, V to X, Y, Z is underdetermined, one of the
    % coordinates, X, Y, or Z must be specified.  This is usually Z, but may be
    % X or Y as well.
    % 
    % Inputs:
    %     U = The U image coordinate.  May be scalar, a 1D vector, or a 2D
    %         array
    %     V = The V image coordinate.    May be scalar, a 1D vector, or a 2D
    %         array
    %     icp = The structure containing the camera's intrinsic and calibration
    %           parameters.  Strucutre created with
    %           makeInstrinsicStructFromCalTechCal.m
    %     beta0 = The camera extrinsic parameters defined as a row vector with
    %             elements [x y z pitch roll azimuth].
    %     val = the value of the know X, Y, or Z quantity.  If val is scalar
    %           then that value is used for all points. If val is not scalar
    %           then it must be the same size as U and V.
    %     flag = A string that states which X, Y, or Z value is specified.
    %            Flag is '-x', '-y', or '-z'
    % 
    % Outputs:
    %     X = The real world, rectangular, X coordinate.  is the same size as U
    %         and V.
    %     Y = The real world, rectangular, Y coordinate.  is the same size as U
    %         and V.
    %     Z = The real world, rectangual, Z coordinate.  is the same size as U
    %         and V.
    % ================================================================

    % Which value is defined; x, y, or z
    if strcmpi(flag, '-x')
        flagNum = 1;
    elseif strcmpi(flag, '-y')
        flagNum = 2;
    elseif strcmpi(flag, '-z')
        flagNum = 3;
    else
        error('Invalid flag for the known variable.')
    end

    if ~isscalar(val) && length(val(:)) ~= length(U(:))
        error('If input val is not a scalar then it should be the same size as U and V')
    end

    [rowU, colU] = size(U);
    [rowV, colV] = size(V);
    if rowU ~= rowV || colU ~= colV
        error('Input U and V must be the same size')
    end

    % undistort pixels
    [U, V] = undistortUV(U,V, icp);

    % convert U and V into one matrix for matrix multiplication
    UV = [U(:)'; V(:)'; ones(1,length(U(:)))];

    % get the transformation matricies
    K = makeCameraMatrix(icp);
    R = makeCameraRotationMatrix(beta0(4), beta0(5), beta0(6));
    IC = [eye(3) beta0(1:3)']; % opposite sign from x, y, z to U, V;

    % apply the camera matrix and rotaion to go from U, V to untranslated
    % coordinated space divided by Zc. [Xt/Zc; Yt/Zc; Zt/Zc]
    XYZtilZc = R^-1*K^-1*UV;

    % Normalize by the Zt/Zc value to get rid of the Zc dependency
    tilXYZNorm = XYZtilZc./repmat(XYZtilZc(flagNum,:),3,1);

    % % =============== %
    %   X = tilXYZNorm(1,:);
    %   Y = tilXYZNorm(2,:);
    %   Z = tilXYZNorm(3,:);
    %   X = reshape(X, rowU, colU); 
    %   Y = reshape(Y, rowU, colU);
    %   Z = reshape(Z, rowU, colU);
    %   return
    % % =============== %

    % Find Y values greater than or equal to zero. These are points on or above
    % the horrizon and should be masked out
%     iHor = find(tilXYZNorm(2,:) >= 0);
%     tilXYZNorm(:,iHor) = nan;

    % find the translated value of the known
    valTil = val(:)'-IC(flagNum,4);

    % multiply by the known to get into regular, untranslated space
    XYZtil = tilXYZNorm.*valTil;

    % translate into world coordinates
    XYZtil = [XYZtil;ones(1,length(U(:)))];
    XYZ = IC*XYZtil;

    X = reshape(XYZ(1,:), rowU, colU);
    Y = reshape(XYZ(2,:), rowU, colU);
    Z = reshape(XYZ(3,:), rowU, colU);

end




%% Old Rectification Functions
function errGeoFit = g_error_geofit(cv,imgWidth,imgHeight,xp,yp,ic,jc,...
                                   hfov,lambda,phi,H,theta,...
                                   hfov0,lambda0,phi0,H0,theta0,...
                                   hfovGuess,lambdaGuess,phiGuess,HGuess,thetaGuess,...
                                   dhfov,dlambda,dphi,dH,dtheta,...
                                   LON0,LAT0,...
                                   i_gcp,j_gcp,lon_gcp,lat_gcp,...
                                   theOrder,field)

                               
    for i=1:length(theOrder)
        if theOrder(i) == 1; hfov   = cv(i); end
        if theOrder(i) == 2; lambda = cv(i); end
        if theOrder(i) == 3; phi    = cv(i); end
        if theOrder(i) == 4; H      = cv(i); end
        if theOrder(i) == 5; theta  = cv(i); end
    end

    % Perform the geometrical transformation
    [LON, LAT] = g_pix2ll(xp,yp,imgWidth,imgHeight,ic,jc,...
                          hfov,lambda,phi,theta,H,LON0,LAT0,field);


    % Calculate the error between ground control points (GCPs) 
    % and image control points once georectified. 
    %
    % This error (errGeoFit) is the error associated with the geometrical fit,
    % as opposed to the error associated with a polynomial fit that can be 
    % calculated if requested by the user. 
    %

    % Determine the number of CGP
    ngcp = length(i_gcp);

    ngcpFinite = 0;
    errGeoFit  = 0.0;

    for k = 1:ngcp

        % Calculate the distance (i.e. error) between GCP and rectificed ICPs.
        distance = g_dist(lon_gcp(k),lat_gcp(k),LON(k),LAT(k),field);
  
        % Check if the distance is finite. The distance may be NaN for some
        % GCPs that may temporarily be above the horizon. Those points are 
        % blanked out in the function g_pix2ll.
        if isfinite(distance) == 1 
            errGeoFit = errGeoFit + distance^2;
            ngcpFinite = ngcpFinite + 1;
        else
            errGeoFit = Inf;
        end
  
    end

    % rms distance
    errGeoFit = sqrt(errGeoFit/ngcpFinite);

    % Check if the parameters are within the specified uncertainties.
    % If not set the error to infinity.
    if abs(hfov - hfovGuess)     > dhfov;   errGeoFit = inf; end
    if abs(lambda - lambdaGuess) > dlambda; errGeoFit = inf; end
    if abs(phi - phiGuess)       > dphi;    errGeoFit = inf; end
    if abs(H - HGuess)           > dH;      errGeoFit = inf; end
    if abs(theta - thetaGuess)   > dtheta;  errGeoFit = inf; end

end

function [LON,LAT] = g_pix2ll(xp,yp,imgWidth,imgHeight,ic,jc,...
                              hfov,lambda,phi,theta,H,LON0,LAT0,field)
    % G_PIX2LL Converts pixel to ground coordinates
    %
    % input: 
    %        xp, yp:     The image coordinate
    %        imgWidth:   Number of horizontal pixel of the image
    %        imgHeight:  Number of vertical pixel of the image
    %        ic, jc:     The number of pixel off center for the principal point
    %                    (generally both set to 0)
    %        hfov:       Horizontal field of view
    %        lambda:     Dip angle below horizontal (straight down = 90, horizontal = 0)
    %        phi:        Tilt angle clockwise around the principal axis
    %        theta:      View angle clockwise from North (e.g. East = 90)
    %        H:          Camera altitude (m) above surface of interest.
    %        LON0, LAT0: Camera longitude and latitude position
    %
    % output: LAT,LON: Ground coordinates
    %
    % Authors:
    %
    % R. Pawlowicz 2002, University of British Columbia
    %   Reference: Pawlowicz, R. (2003) Quantitative visualization of 
    %                 geophysical flows using low-cost oblique digital 
    %                 time-lapse imaging, IEEE Journal of Oceanic Engineering
    %                 28 (4), 699-710.
    %
    % D. Bourgault 2012 - Naming convention slightly modified to match naming
    %                     convention used in other part of the g_rect package.
    %
    %
    
    % Earth's radius (m)
    Re   = 6378135.0;

    % Transformation factors for local cartesian coordinate
    meterPerDegLat = 1852*60.0;
    meterPerDegLon = meterPerDegLat*cosd(LAT0);

    % Image aspect ratio.
    aspectRatio = imgWidth/imgHeight;

    % Construct the image coordinate given the width and height of the image. 
    %xp = repmat([1:imgWidth]',1,imgHeight);
    %yp = repmat([1:imgHeight],imgWidth,1);

    [n,m] = size(xp);

    % Image origin
    x_c = imgWidth/2;
    y_c = imgHeight/2;

    % Compute the vertical angle of view (vfov) given the horizontal angle 
    % of view (hfov) and the image aspect ratio. Then calculate the focal 
    % length (fx, fy).
    % In principle, the horizontal and vertical focal lengths are identical.
    % However these may slighty differ from cameras. The calculation done here
    % provides identical focal length.

    vfov = 2*atand(tand(hfov/2)/aspectRatio);
    fx   = (imgWidth/2)/tand(hfov/2);
    fy   = (imgHeight/2)/tand(vfov/2);


    % Subtract the principal point
    x_p = xp - x_c + (jc);
    y_p = yp - y_c + (ic);

    % Divide by the focal length
    xd = x_p./fx;
    yd = y_p./fy;

    x = xd;
    y = yd;
    
    % The rotations are performed clockwise, first around the z-axis (rot), 
    % then around the already once rotated x-axis (dip) and finally around the 
    % twice rotated y-axis (tilt);

    % Tilt angle
    R_phi =  [ cosd(-phi), -sind(-phi), 0;
               sind(-phi),  cosd(-phi), 0;
                       0,            0, 1];

    % Dip angle
    R_lambda = [ 1,          0,        0;
                 0, cosd(-lambda), -sind(-lambda);
                 0, sind(-lambda),  cosd(-lambda)];

    % View from North
    R_theta = [ cosd(-theta), 0, -sind(-theta);
                           0, 1,           0;
                sind(-theta), 0,  cosd(-theta)];
          
    z = ones(size(x));

    % Apply tilt and dip corrections

    p = R_lambda*R_phi*[(x(:))';(y(:))';(z(:))'];

    % Rotate towards true direction
    M = R_theta*p;

    % Project forward onto ground plane (flat-earth distance)
    alpha = H./M(2,:);
    alpha(M(2,:) < 0) = NaN; % Blanks out vectors pointing above horizon

    % Need distance away and across field-of-view for auto-scaling
    xx = alpha.*p(1,:);
    zz = alpha.*p(3,:);

    x_w = reshape(alpha.*M(1,:),n,m);
    z_w = reshape(alpha.*M(3,:),n,m);

    % Spherical earth corrections
    Dfl2    = (x_w.^2 + z_w.^2);
    Dhoriz2 = (2*H*Re);  % Distance to spherical horizon

    fac             = (4*Dfl2/Dhoriz2);
    fac(fac >= 1.0) = NaN;     % Points past horizon
    s2f             = 2*(1 - sqrt( 1 - fac )) ./ fac;

    x_w = x_w.*s2f;
    z_w = z_w.*s2f;

    % Convert coordinates to lat/lon using locally cartesian assumption
    if field
        LON = x_w/meterPerDegLon + LON0;
        LAT = z_w/meterPerDegLat + LAT0;
    else
        LON = x_w + LON0;
        LAT = z_w + LAT0;
    end
end

function distance = g_dist(lon1,lat1,lon2,lat2,field)

    % This function computes the distance (m) between two points on a
    % Cartesian Earth given their lat-lon coordinate.
    %
    % If field = false then simple cartesian transformation
    %
    %

    dlon = lon2 - lon1;
    dlat = lat2 - lat1;

    if field
    
        meterPerDegLat = 1852*60.0;
        meterPerDegLon = meterPerDegLat * cosd(lat1);
        dx = dlon*meterPerDegLon;
        dy = dlat*meterPerDegLat;
    
    else
    
        dx = dlon;
        dy = dlat;
    
    end

    distance = sqrt(dx^2 + dy^2);

end

function [LONpc, LATpc, err_polyfit] = g_poly(LON,LAT,LON0,LAT0,i_gcp,j_gcp,lon_gcp,lat_gcp,p_order,field)

    ngcp=length(i_gcp);

    % LON0 and LAT0 are removed to facilitate the fiminsearch algorithm
    for k = 1:ngcp
        
        lonlon(k) =  LON(i_gcp(k), j_gcp(k))-LON0;
        latlat(k) =  LAT(i_gcp(k),j_gcp(k))-LAT0;
        err_lon(k) = lonlon(k)-(lon_gcp(k)-LON0);
        err_lat(k) = latlat(k)-(lat_gcp(k)-LAT0);  
  
        Delta_lon = LON(i_gcp(k)+1,j_gcp(k)) - LON(i_gcp(k),j_gcp(k));
        Delta_lat = LAT(i_gcp(k)+1,j_gcp(k)) - LAT(i_gcp(k),j_gcp(k));
  
        if (abs(err_lon) - Delta_lon) < 0
            err_lon(k) = 0.0;
        end
        if (abs(err_lat) - Delta_lat) < 0
            err_lat(k) = 0.0;
        end
  
    end
    LON = LON-LON0; LAT = LAT-LAT0;

    options = optimset('MaxFunEvals',1000000,'MaxIter',1000000,'TolFun',1.d-12,'TolX',1.d-12);

    % The fminsearch is done twice for more accuracy. Otherwise, sometime it is 
    % not the true minimum that is found in the first pass.

    if p_order == 1
  
        a(1:3) = 0.0;
        b(1:3) = 0.0;
        a = fminsearch(@g_error_polyfit,a,options,lonlon,latlat,err_lon,p_order);
        a = fminsearch(@g_error_polyfit,a,options,lonlon,latlat,err_lon,p_order);
        b = fminsearch(@g_error_polyfit,b,options,lonlon,latlat,err_lat,p_order);
        b = fminsearch(@g_error_polyfit,b,options,lonlon,latlat,err_lat,p_order);
    
        LONpc = LON-(a(1)*LON+a(2)*LAT+a(3));
        LATpc = LAT-(b(1)*LON+b(2)*LAT+b(3));
  
    elseif p_order == 2
  
        % First pass - 1st order
        a(1:3) = 0.0;
        b(1:3) = 0.0;
        a = fminsearch(@g_error_polyfit,a,options,lonlon,latlat,err_lon,1);
        a = fminsearch(@g_error_polyfit,a,options,lonlon,latlat,err_lon,1);
        b = fminsearch(@g_error_polyfit,b,options,lonlon,latlat,err_lat,1);
        b = fminsearch(@g_error_polyfit,b,options,lonlon,latlat,err_lat,1);
    
        LONpc = LON-(a(1)*LON+a(2)*LAT+a(3));
        LATpc = LAT-(b(1)*LON+b(2)*LAT+b(3));

        LON = LONpc + LON0;
        LAT = LATpc + LAT0;

        % Second pass - 2nd order
        for k = 1:ngcp
            lonlon(k) =  LON(i_gcp(k),j_gcp(k))-LON0;
            latlat(k) =  LAT(i_gcp(k),j_gcp(k))-LAT0;
            err_lon(k) = lonlon(k)-(lon_gcp(k)-LON0);
            err_lat(k) = latlat(k)-(lat_gcp(k)-LAT0);  
        end
        LON = LON-LON0; LAT = LAT-LAT0;

        a(1:6) = 0.0;
        b(1:6) = 0.0;
        a = fminsearch(@g_error_polyfit,a,options,lonlon,latlat,err_lon,2);
        a = fminsearch(@g_error_polyfit,a,options,lonlon,latlat,err_lon,2);
        b = fminsearch(@g_error_polyfit,b,options,lonlon,latlat,err_lat,2);
        b = fminsearch(@g_error_polyfit,b,options,lonlon,latlat,err_lat,2);
        LONpc=LON-(a(1)*LON.^2+a(2)*LAT.^2+a(3)*LON.*LAT+a(4)*LON+a(5)*LAT+a(6));
        LATpc=LAT-(b(1)*LON.^2+b(2)*LAT.^2+b(3)*LON.*LAT+b(4)*LON+b(5)*LAT+b(6));
  
    end

    % Add the LON0 and LAT0
    LONpc = LONpc + LON0;
    LATpc = LATpc + LAT0;

    % Recalculate the error after correction.
    err_polyfit=0;
    for k = 1:ngcp
    
        DX = g_dist(LONpc(i_gcp(k),j_gcp(k)),LATpc(i_gcp(k),j_gcp(k)),lon_gcp(k),lat_gcp(k),field);
        err_polyfit = err_polyfit + DX^2;

    end
    err_polyfit = sqrt(err_polyfit/ngcp);

end

function err=g_error_polyfit(cv,lonlon,latlat,err_ll,order)
    %function err=g_error_polyfit(cv,lonlon,latlat,err_ll,order);

    n_gcp=length(err_ll);
    err=0;

    for k=1:n_gcp

        if order == 1
      
            efit = cv(1)*lonlon(k)+cv(2)*latlat(k)+cv(3);  
    
        elseif order == 2
      
            efit = cv(1)*lonlon(k)^2+cv(2)*latlat(k)^2+cv(3)*lonlon(k)*latlat(k)+cv(4)*lonlon(k)+cv(5)*latlat(k)+cv(6);
    
        end
  
        err = err + (efit-err_ll(k))^2;

    end
end

function [x_hor, y_hor] = get_horizon(imgWidth, imgHeight, xp, yp, jc, ic, hfov, lambda, phi, theta)
    % Image aspect ratio.
    aspectRatio = imgWidth/imgHeight;

    % Image origin
    x_c = imgWidth/2;
    y_c = imgHeight/2;

    % Compute the vertical angle of view (vfov) given the horizontal angle 
    % of view (hfov) and the image aspect ratio. Then calculate the focal 
    % length (fx, fy).
    % In principle, the horizontal and vertical focal lengths are identical.
    % However these may slighty differ from cameras. The calculation done here
    % provides identical focal length.

    vfov = 2*atand(tand(hfov/2)/aspectRatio);
    fx   = (imgWidth/2)/tand(hfov/2);
    fy   = (imgHeight/2)/tand(vfov/2);


    % Subtract the principal point
    x_p = xp - x_c + (jc);
    y_p = yp - y_c + (ic);

    % Divide by the focal length
    xd = x_p./fx;
    yd = y_p./fy;

    x = xd;
    y = yd;
    
    % The rotations are performed clockwise, first around the z-axis (rot), 
    % then around the already once rotated x-axis (dip) and finally around the 
    % twice rotated y-axis (tilt);

    % Tilt angle
    R_phi =  [ cosd(-phi), -sind(-phi), 0;
               sind(-phi),  cosd(-phi), 0;
                       0,            0, 1];

    % Dip angle
    R_lambda = [ 1,          0,        0;
                 0, cosd(-lambda), -sind(-lambda);
                 0, sind(-lambda),  cosd(-lambda)];

    % View from North
    R_theta = [ cosd(-theta), 0, -sind(-theta);
                           0, 1,           0;
                sind(-theta), 0,  cosd(-theta)];
          
    z = ones(size(x));

    % Apply tilt and dip corrections

    p = R_lambda*R_phi*[(x(:))';(y(:))';(z(:))'];

    % Rotate towards true direction
    M = R_theta*p;
    
    i = find(abs(M(2,:)) == min(abs(M(2,:))));
    x_hor = xp(i);
    y_hor = yp(i);
end


