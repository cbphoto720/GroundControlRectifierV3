% PickControlPointsV2()
% =========================================================================
% Version 2, 10/08/2017
% 
% NOTE: This version has been superseded by version 3
% 
% This program was designed to aid in the selection of ground control
% points from video imagry of a moving, GPS equipped vessel. Image data
% must be GPS time stamped.
% 
% Once ground control points are selected, camera extrinsic parameters can
% be computed using the function g_rect.
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
% =========================================================================

function PickControlPointsV2()
    
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
    rectParams = struct('lat', [], 'lon', [], 'alt', [], 'hfov', [],...
                        'dip', [], 'tilt', [], 'head', [], 'xppo', [], ...
                        'yppo', [], 'altUn', [], 'hfovUn', [], 'dipUn', [], ...
                        'tiltUn', [], 'headUn', [], 'order', [],...
                        'rectLON', [], 'rectLAT', [], 'altRect', [], 'hfovRect', [],...
                        'dipRect', [], 'tiltRect', [], 'headRect', [], 'errGeoRect', [],...
                        'errPolyRect', []);

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
                if figdata.PauseFlag == 0
                    frameStr = num2str(points.(figdata.CurrentImageSet).data{1}(figdata.CurrentInd));
                    PlotTiff(frameStr);
                elseif figdata.PauseFlag == 1
                    break
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

    function choice = timezoneDialog()

        d = dialog('Position', [300 300 250 150], 'Name', 'Timezone', 'WindowStyle', 'modal');
        txt = uicontrol('Parent',d,...
                        'Style','text',...
                        'Position',[0 80 250 40],...
                        'String','Select the timezone of the image times.');
       
        popup = uicontrol('Parent',d,...
                          'Style','popup',...
                          'Position',[50 70 150 25],...
                          'String',{'Eastern Standard';'Eastern Daylight';'UTC'},...
                          'Callback',@popup_callback);
       
        btn = uicontrol('Parent',d,...
                        'Position',[89 20 70 25],...
                        'String','ok',...
                        'Callback',@btn_callback);
                    
        popup.String
       
        choice = 'none';
       
        % Wait for d to close before running to completion
        uiwait(d);
   
        function popup_callback(popup,~)
            idx = popup.Value;
            choice = popup.String{idx};
        end
       
        function btn_callback(btn, ~)
            delete(btn.Parent);
        end
    end

    function RectifyImageGUI
        
        fieldNames = fieldnames(points);
        setNum = [];
        frameNum = [];
        xPixel = [];
        yPixel = [];
        lat = [];
        lon = [];
        for i = 1:length(fieldNames)
            fileInd = ~isnan(points.(fieldNames{i}).data{3});
            frameNum = [frameNum; points.(fieldNames{i}).data{1}(fileInd)];
            xPixel = [xPixel; points.(fieldNames{i}).data{3}(fileInd)];
            yPixel = [yPixel; points.(fieldNames{i}).data{4}(fileInd)];
            lat = [lat; points.(fieldNames{i}).data{5}(fileInd)];
            lon = [lon; points.(fieldNames{i}).data{6}(fileInd)];
            setNum = [setNum; ones(sum(fileInd),1).*i];
        end
        
        deleteInd = [];
        deleteMarker = 1;
        deleteStack = cell(0,0);
        
        checkParams = zeros(1,15);
    
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
                       'WindowStyle', 'modal',...
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
        pollyHeight = 2.5;
        editWidth = 20;
        txtWidth = 10;
        checkWidth = 10;
        startOffset = 1.5;
        vertOffset = 0.75;
        horOffset = 0.5;
                                            
        haxes3 = axes('Parent', hfig2,...
                      'Units', 'normalized',...
                      'Position', [axesHorOffset/rectWidth...
                                   axesBottomOffset/rectHeight...
                                   (1-(3*axesHorOffset+editWidth+txtWidth+checkWidth)/(rectWidth))/2.0...
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
                                   (1-(3*axesHorOffset+editWidth+txtWidth+checkWidth)/(rectWidth))/2.0...
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
                                                   1-(2*horOffset+txtWidth+editWidth+checkWidth)/rectWidth... % width
                                                   (loadRectHeight/rectHeight)],... % height; old = [0 0.95 0.6 0.05]
                                      'BackgroundColor', GUIColors.LowerPanel,...
                                      'BorderWidth', 1,...
                                      'HighlightColor', GUIColors.LowerHighlight,...
                                      'ShadowColor', GUIColors.LowerShadow);
                 
          loadRectParams = uicontrol(hpanLoadRect, 'Style', 'pushbutton',...
                                      'String', 'Load Parameters',...
                                      'Units', 'normalized',...
                                      'Position', [(loadRectBtnOffset/(hpanLoadRect.Position(3).*rectWidth))... % left
                                                   ((loadRectHeight-loadRectBtnHeight)/2)/loadRectHeight... % bottom
                                                   (loadRectBtnWidth/(hpanLoadRect.Position(3).*rectWidth))... % width
                                                   loadRectBtnHeight/loadRectHeight],... % height; old = [0.02 0.1 0.176 0.8]
                                      'FontWeight', 'bold',...
                                      'BackgroundColor', GUIColors.ButtonColor,...
                                      'ForegroundColor', GUIColors.Text,...
                                      'Callback', @LOADPARAMETERS);
                                   
          rectifyBtn = uicontrol(hpanLoadRect, 'Style', 'pushbutton',...
                                   'String', 'Rectify',...
                                   'Units', 'normalized',...
                                   'Position', [loadRectParams.Position(1)+loadRectParams.Position(3)+(loadRectBtnOffset/(hpanLoadRect.Position(3).*rectWidth))... % left
                                                ((loadRectHeight-loadRectBtnHeight)/2)/loadRectHeight... % bottom
                                                (loadRectBtnWidth/(hpanLoadRect.Position(3).*rectWidth))... % width
                                                loadRectBtnHeight/loadRectHeight],... % height; old = [0.216 0.1 0.176 0.8]
                                   'FontWeight', 'bold',...
                                   'BackgroundColor', GUIColors.ButtonColor,...
                                   'ForegroundColor', GUIColors.Text,...
                                   'Enable', 'off',...
                                   'Callback', @COMPUTERECTIFICATION);
                                
         saveRectBtn = uicontrol(hpanLoadRect, 'Style', 'pushbutton',...
                               'String', 'Save Rectify',...
                               'Units', 'normalized',...
                               'Position', [rectifyBtn.Position(1)+rectifyBtn.Position(3)+(loadRectBtnOffset/(hpanLoadRect.Position(3).*rectWidth))... % left
                                            ((loadRectHeight-loadRectBtnHeight)/2)/loadRectHeight... % bottom
                                            (loadRectBtnWidth/(hpanLoadRect.Position(3).*rectWidth))... % width
                                            loadRectBtnHeight/loadRectHeight],... % height; old = [0.412 0.1 0.176 0.8]
                               'FontWeight', 'bold',...
                               'BackgroundColor', GUIColors.ButtonColor,...
                               'ForegroundColor', GUIColors.Text,...
                               'Enable', 'off',...
                               'Callback', @SAVERECTIFY);
                           
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
        
        % Camera Input parameter panel          
        % ============================
        hpanCamIn = uipanel(hfig2, 'Position', [1-(2*horOffset+txtWidth+editWidth+checkWidth)/rectWidth...
                                                1-(7*editHeight+7*vertOffset+startOffset)/rectHeight...
                                                (2*horOffset+txtWidth+editWidth+checkWidth)/rectWidth...
                                                (7*editHeight+7*vertOffset+startOffset)/rectHeight],...
                                  'Title', 'Camera Parameters',...
                                  'FontWeight', 'bold',...
                                  'BackgroundColor', GUIColors.UpperPanel,...
                                  'BorderWidth', 1,...
                                  'HighlightColor', GUIColors.UpperHighlight,...
                                  'ShadowColor', GUIColors.UpperShadow);
        
        % Camera Latitude Input
        % =====================
        GUIHandles.input.hLatIn = uicontrol(hpanCamIn, 'Style', 'edit',...
                                        'String', num2str(rectParams.lat, '%.15g'),...
                                        'Units', 'normalized',...
                                        'Position', [(horOffset+txtWidth)/(2*horOffset+txtWidth+editWidth+checkWidth)...
                                                     (6*editHeight+7*vertOffset)/(7*editHeight+7*vertOffset+startOffset)...
                                                     editWidth/(2*horOffset+txtWidth+editWidth+checkWidth)...
                                                     editHeight/(7*editHeight+7*vertOffset+startOffset)],...
                                        'FontWeight', 'bold',...
                                        'BackgroundColor', GUIColors.ButtonColor,...
                                        'ForegroundColor', GUIColors.Text,...
                                        'Enable', 'on',...
                                        'Callback', @CHECKINPUTCALLBACK);
                                
        hLatText = annotation(hpanCamIn, 'textbox',...
                                         'LineStyle', 'none',...
                                         'String', 'lat = ',...
                                         'BackgroundColor', GUIColors.UpperPanel,...
                                         'Units', 'normalized',...
                                         'HorizontalAlignment','right',...
                                         'VerticalAlignment','middle',...
                                         'Position', [horOffset/(2*horOffset+txtWidth+editWidth+checkWidth)...
                                                      (6*editHeight+7*vertOffset)/(7*editHeight+7*vertOffset+startOffset)...
                                                      txtWidth/(2*horOffset+txtWidth+editWidth+checkWidth)...
                                                      editHeight/(7*editHeight+7*vertOffset+startOffset)]);
                                   
        GUIHandles.check.hLatCheck = annotation(hpanCamIn, 'textbox',...
                                           'LineStyle', 'none',...
                                            'String', ' X ',...
                                            'BackgroundColor', GUIColors.UpperPanel,...
                                            'Color', 'r',...
                                            'FontWeight', 'Bold',...
                                            'Units', 'normalized',...
                                            'HorizontalAlignment','Left',...
                                            'VerticalAlignment','middle',...
                                            'Position', [(horOffset+txtWidth+editWidth)/(2*horOffset+txtWidth+editWidth+checkWidth)...
                                                         (6*editHeight+7*vertOffset)/(7*editHeight+7*vertOffset+startOffset)...
                                                         checkWidth/(2*horOffset+txtWidth+editWidth+checkWidth)...
                                                         editHeight/(7*editHeight+7*vertOffset+startOffset)]);
      
        % Camera Longitude Input
        % ======================
        GUIHandles.input.hLonIn = uicontrol(hpanCamIn, 'Style', 'edit',...
                                        'String', num2str(rectParams.lon, '%.15g'),...
                                        'Units', 'normalized',...
                                        'Position', [(horOffset+txtWidth)/(2*horOffset+txtWidth+editWidth+checkWidth)...
                                                     (5*editHeight+6*vertOffset)/(7*editHeight+7*vertOffset+startOffset)...
                                                     editWidth/(2*horOffset+txtWidth+editWidth+checkWidth)...
                                                     editHeight/(7*editHeight+7*vertOffset+startOffset)],...
                                        'FontWeight', 'bold',...
                                        'BackgroundColor', GUIColors.ButtonColor,...
                                        'ForegroundColor', GUIColors.Text,...
                                        'Enable', 'on',...
                                        'Callback', @CHECKINPUTCALLBACK);
                                
        hLonText = annotation(hpanCamIn, 'textbox',...
                                         'LineStyle', 'none',...
                                         'String', 'lon = ',...
                                         'BackgroundColor', GUIColors.UpperPanel,...
                                         'Units', 'normalized',...
                                         'HorizontalAlignment','right',...
                                         'VerticalAlignment','middle',...
                                         'Position', [horOffset/(2*horOffset+txtWidth+editWidth+checkWidth)...
                                                      (5*editHeight+6*vertOffset)/(7*editHeight+7*vertOffset+startOffset)...
                                                      txtWidth/(2*horOffset+txtWidth+editWidth+checkWidth)...
                                                      editHeight/(7*editHeight+7*vertOffset+startOffset)]);
                                   
        GUIHandles.check.hLonCheck = annotation(hpanCamIn, 'textbox',...
                                            'LineStyle', 'none',...
                                            'String', ' X ',...
                                            'BackgroundColor', GUIColors.UpperPanel,...
                                            'Color', 'r',...
                                            'FontWeight', 'Bold',...
                                            'Units', 'normalized',...
                                            'HorizontalAlignment','Left',...
                                            'VerticalAlignment','middle',...
                                            'Position', [(horOffset+txtWidth+editWidth)/(2*horOffset+txtWidth+editWidth+checkWidth)...
                                                         (5*editHeight+6*vertOffset)/(7*editHeight+7*vertOffset+startOffset)...
                                                         checkWidth/(2*horOffset+txtWidth+editWidth+checkWidth)...
                                                         editHeight/(7*editHeight+7*vertOffset+startOffset)]);
                                    
        % Camera Altitude Input
        % =====================                              
        GUIHandles.input.hAltIn = uicontrol(hpanCamIn, 'Style', 'edit',...
                                        'String', num2str(rectParams.alt, '%.5g'),...
                                        'Units', 'normalized',...
                                        'Position', [(horOffset+txtWidth)/(2*horOffset+txtWidth+editWidth+checkWidth)...
                                                     (4*editHeight+5*vertOffset)/(7*editHeight+7*vertOffset+startOffset)...
                                                     editWidth/(2*horOffset+txtWidth+editWidth+checkWidth)...
                                                     editHeight/(7*editHeight+7*vertOffset+startOffset)],...
                                        'FontWeight', 'bold',...
                                        'BackgroundColor', GUIColors.ButtonColor,...
                                        'ForegroundColor', GUIColors.Text,...
                                        'Enable', 'on',...
                                        'Callback', @CHECKINPUTCALLBACK);
                                
        hAltText = annotation(hpanCamIn, 'textbox',...
                                         'LineStyle', 'none',...
                                         'String', 'alt = ',...
                                         'BackgroundColor', GUIColors.UpperPanel,...
                                         'Units', 'normalized',...
                                         'HorizontalAlignment','right',...
                                         'VerticalAlignment','middle',...
                                         'Position', [horOffset/(2*horOffset+txtWidth+editWidth+checkWidth)...
                                                      (4*editHeight+5*vertOffset)/(7*editHeight+7*vertOffset+startOffset)...
                                                      txtWidth/(2*horOffset+txtWidth+editWidth+checkWidth)...
                                                      editHeight/(7*editHeight+7*vertOffset+startOffset)]);
                                   
        GUIHandles.check.hAltCheck = annotation(hpanCamIn, 'textbox',...
                                            'LineStyle', 'none',...
                                            'String', ' X ',...
                                            'BackgroundColor', GUIColors.UpperPanel,...
                                            'Color', 'r',...
                                            'FontWeight', 'Bold',...
                                            'Units', 'normalized',...
                                            'HorizontalAlignment','Left',...
                                            'VerticalAlignment','middle',...
                                            'Position', [(horOffset+txtWidth+editWidth)/(2*horOffset+txtWidth+editWidth+checkWidth)...
                                                         (4*editHeight+5*vertOffset)/(7*editHeight+7*vertOffset+startOffset)...
                                                         checkWidth/(2*horOffset+txtWidth+editWidth+checkWidth)...
                                                         editHeight/(7*editHeight+7*vertOffset+startOffset)]);
                                
        % Camera Horizontal Field of View Angle Input
        % ===========================================
        GUIHandles.input.hHfovIn = uicontrol(hpanCamIn, 'Style', 'edit',...
                                         'String', num2str(rectParams.hfov, '%.5g'),...
                                         'Units', 'normalized',...
                                         'Position', [(horOffset+txtWidth)/(2*horOffset+txtWidth+editWidth+checkWidth)...
                                                      (3*editHeight+4*vertOffset)/(7*editHeight+7*vertOffset+startOffset)...
                                                      editWidth/(2*horOffset+txtWidth+editWidth+checkWidth)...
                                                      editHeight/(7*editHeight+7*vertOffset+startOffset)],...
                                         'FontWeight', 'bold',...
                                         'BackgroundColor', GUIColors.ButtonColor,...
                                         'ForegroundColor', GUIColors.Text,...
                                         'Enable', 'on',...
                                         'Callback', @CHECKINPUTCALLBACK);
                                 
        hHfovText = annotation(hpanCamIn, 'textbox',...
                                          'LineStyle', 'none',...
                                          'String', 'hfov = ',...
                                          'BackgroundColor', GUIColors.UpperPanel,...
                                          'Units', 'normalized',...
                                          'HorizontalAlignment','right',...
                                          'VerticalAlignment','middle',...
                                          'Position', [horOffset/(2*horOffset+txtWidth+editWidth+checkWidth)...
                                                       (3*editHeight+4*vertOffset)/(7*editHeight+7*vertOffset+startOffset)...
                                                       txtWidth/(2*horOffset+txtWidth+editWidth+checkWidth)...
                                                       editHeight/(7*editHeight+7*vertOffset+startOffset)]);
                                   
        GUIHandles.check.hHfovCheck = annotation(hpanCamIn, 'textbox',...
                                             'LineStyle', 'none',...
                                             'String', ' X ',...
                                             'BackgroundColor', GUIColors.UpperPanel,...
                                             'Color', 'r',...
                                             'FontWeight', 'Bold',...
                                             'Units', 'normalized',...
                                             'HorizontalAlignment','Left',...
                                             'VerticalAlignment','middle',...
                                             'Position', [(horOffset+txtWidth+editWidth)/(2*horOffset+txtWidth+editWidth+checkWidth)...
                                                          (3*editHeight+4*vertOffset)/(7*editHeight+7*vertOffset+startOffset)...
                                                          checkWidth/(2*horOffset+txtWidth+editWidth+checkWidth)...
                                                          editHeight/(7*editHeight+7*vertOffset+startOffset)]);
                                 
        % Camera Dip Angle Input
        % ======================
        GUIHandles.input.hDipIn = uicontrol(hpanCamIn, 'Style', 'edit',...
                                        'String', num2str(rectParams.dip, '%.5g'),...
                                        'Units', 'normalized',...
                                        'Position', [(horOffset+txtWidth)/(2*horOffset+txtWidth+editWidth+checkWidth)...
                                                     (2*editHeight+3*vertOffset)/(7*editHeight+7*vertOffset+startOffset)...
                                                     editWidth/(2*horOffset+txtWidth+editWidth+checkWidth)...
                                                     editHeight/(7*editHeight+7*vertOffset+startOffset)],...
                                        'FontWeight', 'bold',...
                                        'BackgroundColor', GUIColors.ButtonColor,...
                                        'ForegroundColor', GUIColors.Text,...
                                        'Enable', 'on',...
                                        'Callback', @CHECKINPUTCALLBACK);
                                
        hDipText = annotation(hpanCamIn, 'textbox',...
                                         'LineStyle', 'none',...
                                         'String', '\lambda = ',...
                                         'BackgroundColor', GUIColors.UpperPanel,...
                                         'Units', 'normalized',...
                                         'HorizontalAlignment','right',...
                                         'VerticalAlignment','middle',...
                                         'Position', [horOffset/(2*horOffset+txtWidth+editWidth+checkWidth)...
                                                      (2*editHeight+3*vertOffset)/(7*editHeight+7*vertOffset+startOffset)...
                                                      txtWidth/(2*horOffset+txtWidth+editWidth+checkWidth)...
                                                      editHeight/(7*editHeight+7*vertOffset+startOffset)]);
                                   
        GUIHandles.check.hDipCheck = annotation(hpanCamIn, 'textbox',...
                                            'LineStyle', 'none',...
                                            'String', ' X ',...
                                            'BackgroundColor', GUIColors.UpperPanel,...
                                            'Color', 'r',...
                                            'FontWeight', 'Bold',...
                                            'Units', 'normalized',...
                                            'HorizontalAlignment','Left',...
                                            'VerticalAlignment','middle',...
                                            'Position', [(horOffset+txtWidth+editWidth)/(2*horOffset+txtWidth+editWidth+checkWidth)...
                                                         (2*editHeight+3*vertOffset)/(7*editHeight+7*vertOffset+startOffset)...
                                                         checkWidth/(2*horOffset+txtWidth+editWidth+checkWidth)...
                                                         editHeight/(7*editHeight+7*vertOffset+startOffset)]);
       
        % Camera Tilt Angle Input
        % =======================
        GUIHandles.input.hTiltIn = uicontrol(hpanCamIn, 'Style', 'edit',...
                                         'String', num2str(rectParams.tilt, '%.5g'),...
                                         'Units', 'normalized',...
                                         'Position', [(horOffset+txtWidth)/(2*horOffset+txtWidth+editWidth+checkWidth)...
                                                      (editHeight+2*vertOffset)/(7*editHeight+7*vertOffset+startOffset)...
                                                      editWidth/(2*horOffset+txtWidth+editWidth+checkWidth)...
                                                      editHeight/(7*editHeight+7*vertOffset+startOffset)],...
                                         'FontWeight', 'bold',...
                                         'BackgroundColor', GUIColors.ButtonColor,...
                                         'ForegroundColor', GUIColors.Text,...
                                         'Enable', 'on',...
                                         'Callback', @CHECKINPUTCALLBACK);
                                 
        hTiltText = annotation(hpanCamIn, 'textbox',...
                                          'LineStyle', 'none',...
                                          'String', '\phi = ',...
                                          'BackgroundColor', GUIColors.UpperPanel,...
                                          'Units', 'normalized',...
                                          'HorizontalAlignment','right',...
                                          'VerticalAlignment','middle',...
                                          'Position', [horOffset/(2*horOffset+txtWidth+editWidth+checkWidth)...
                                                       (editHeight+2*vertOffset)/(7*editHeight+7*vertOffset+startOffset)...
                                                       txtWidth/(2*horOffset+txtWidth+editWidth+checkWidth)...
                                                       editHeight/(7*editHeight+7*vertOffset+startOffset)]);
                                   
        GUIHandles.check.hTiltCheck = annotation(hpanCamIn, 'textbox',...
                                             'LineStyle', 'none',...
                                             'String', ' X ',...
                                             'BackgroundColor', GUIColors.UpperPanel,...
                                             'Color', 'r',...
                                             'FontWeight', 'Bold',...
                                             'Units', 'normalized',...
                                             'HorizontalAlignment','Left',...
                                             'VerticalAlignment','middle',...
                                             'Position', [(horOffset+txtWidth+editWidth)/(2*horOffset+txtWidth+editWidth+checkWidth)...
                                                          (editHeight+2*vertOffset)/(7*editHeight+7*vertOffset+startOffset)...
                                                          checkWidth/(2*horOffset+txtWidth+editWidth+checkWidth)...
                                                          editHeight/(7*editHeight+7*vertOffset+startOffset)]);
     
        % Camera Heading Input
        % =====================
        GUIHandles.input.hHeadIn = uicontrol(hpanCamIn, 'Style', 'edit',...
                                         'String', num2str(rectParams.head, '%.5g'),...
                                         'Units', 'normalized',...
                                         'Position', [(horOffset+txtWidth)/(2*horOffset+txtWidth+editWidth+checkWidth)...
                                                      vertOffset/(7*editHeight+7*vertOffset+startOffset)...
                                                      editWidth/(2*horOffset+txtWidth+editWidth+checkWidth)...
                                                      editHeight/(7*editHeight+7*vertOffset+startOffset)],...
                                         'FontWeight', 'bold',...
                                         'BackgroundColor', GUIColors.ButtonColor,...
                                         'ForegroundColor', GUIColors.Text,...
                                         'Enable', 'on',...
                                         'Callback', @CHECKINPUTCALLBACK);
                                 
        hHeadText = annotation(hpanCamIn, 'textbox',...
                                          'LineStyle', 'none',...
                                          'String', '\theta = ',...
                                          'BackgroundColor', GUIColors.UpperPanel,...
                                          'Units', 'normalized',...
                                          'HorizontalAlignment','right',...
                                          'VerticalAlignment','middle',...
                                          'Position', [horOffset/(2*horOffset+txtWidth+editWidth+checkWidth)...
                                                       vertOffset/(7*editHeight+7*vertOffset+startOffset)...
                                                       txtWidth/(2*horOffset+txtWidth+editWidth+checkWidth)...
                                                       editHeight/(7*editHeight+7*vertOffset+startOffset)]);
                                   
        GUIHandles.check.hHeadCheck = annotation(hpanCamIn, 'textbox',...
                                             'LineStyle', 'none',...
                                             'String', ' X ',...
                                             'BackgroundColor', GUIColors.UpperPanel,...
                                             'Color', 'r',...
                                             'FontWeight', 'Bold',...
                                             'Units', 'normalized',...
                                             'HorizontalAlignment','Left',...
                                             'VerticalAlignment','middle',...
                                             'Position', [(horOffset+txtWidth+editWidth)/(2*horOffset+txtWidth+editWidth+checkWidth)...
                                                          vertOffset/(7*editHeight+7*vertOffset+startOffset)...
                                                          checkWidth/(2*horOffset+txtWidth+editWidth+checkWidth)...
                                                          editHeight/(7*editHeight+7*vertOffset+startOffset)]);
                                
        % Principle Point Offset          
        % ======================
        hpanPPOIn = uipanel(hfig2, 'Position', [1-(2*horOffset+txtWidth+editWidth+checkWidth)/rectWidth...
                                                1-(9*editHeight+9*vertOffset+2*startOffset)/rectHeight...
                                                (2*horOffset+txtWidth+editWidth+checkWidth)/rectWidth...
                                                (2*editHeight+2*vertOffset+startOffset)/rectHeight],...
                                   'Title', 'Principle Point Offset',...
                                   'FontWeight', 'bold',...
                                   'BackgroundColor', GUIColors.UpperPanel,...
                                   'BorderWidth', 1,...
                                   'HighlightColor', GUIColors.UpperHighlight,...
                                   'ShadowColor', GUIColors.UpperShadow);
      
        % x Principle point offset
        % ========================
        GUIHandles.input.hXPPOIn = uicontrol(hpanPPOIn, 'Style', 'edit',...
                                         'String', num2str(rectParams.xppo, '%.5g'),...
                                         'Units', 'normalized',...
                                         'Position', [(horOffset+txtWidth)/(2*horOffset+txtWidth+editWidth+checkWidth)...
                                                      (editHeight+2*vertOffset)/(2*editHeight+2*vertOffset+startOffset)...
                                                      editWidth/(2*horOffset+txtWidth+editWidth+checkWidth)...
                                                      editHeight/(2*editHeight+2*vertOffset+startOffset)],...
                                         'FontWeight', 'bold',...
                                         'BackgroundColor', GUIColors.ButtonColor,...
                                         'ForegroundColor', GUIColors.Text,...
                                         'Enable', 'on',...
                                         'Callback', @CHECKINPUTCALLBACK);
                                 
        hXPPOText = annotation(hpanPPOIn, 'textbox',...
                                          'LineStyle', 'none',...
                                          'String', 'X = ',...
                                          'BackgroundColor', GUIColors.UpperPanel,...
                                          'Units', 'normalized',...
                                          'HorizontalAlignment','right',...
                                          'VerticalAlignment','middle',...
                                          'Position', [horOffset/(2*horOffset+txtWidth+editWidth+checkWidth)...
                                                       (editHeight+2*vertOffset)/(2*editHeight+2*vertOffset+startOffset)...
                                                       txtWidth/(2*horOffset+txtWidth+editWidth+checkWidth)...
                                                       editHeight/(2*editHeight+2*vertOffset+startOffset)]);
                                   
        GUIHandles.check.hXPPOCheck = annotation(hpanPPOIn, 'textbox',...
                                             'LineStyle', 'none',...
                                             'String', ' X ',...
                                             'BackgroundColor', GUIColors.UpperPanel,...
                                             'Color', 'r',...
                                             'FontWeight', 'Bold',...
                                             'Units', 'normalized',...
                                             'HorizontalAlignment','Left',...
                                             'VerticalAlignment','middle',...
                                             'Position', [(horOffset+txtWidth+editWidth)/(2*horOffset+txtWidth+editWidth+checkWidth)...
                                                          (editHeight+2*vertOffset)/(2*editHeight+2*vertOffset+startOffset)...
                                                          checkWidth/(2*horOffset+txtWidth+editWidth+checkWidth)...
                                                          editHeight/(2*editHeight+2*vertOffset+startOffset)]);
                                     
        % y Principle point offset
        % ========================
        GUIHandles.input.hYPPOIn = uicontrol(hpanPPOIn, 'Style', 'edit',...
                                       'String', num2str(rectParams.yppo, '%.5g'),...
                                       'Units', 'normalized',...
                                       'Position', [(horOffset+txtWidth)/(2*horOffset+txtWidth+editWidth+checkWidth)...
                                                    vertOffset/(2*editHeight+2*vertOffset+startOffset)...
                                                    editWidth/(2*horOffset+txtWidth+editWidth+checkWidth)...
                                                    editHeight/(2*editHeight+2*vertOffset+startOffset)],...
                                       'FontWeight', 'bold',...
                                       'BackgroundColor', GUIColors.ButtonColor,...
                                       'ForegroundColor', GUIColors.Text,...
                                       'Enable', 'on',...
                                       'Callback', @CHECKINPUTCALLBACK);
                                 
        hYPPOText = annotation(hpanPPOIn, 'textbox',...
                                          'LineStyle', 'none',...
                                          'String', 'Y = ',...
                                          'BackgroundColor', GUIColors.UpperPanel,...
                                          'Units', 'normalized',...
                                          'HorizontalAlignment','right',...
                                          'VerticalAlignment','middle',...
                                          'Position', [horOffset/(2*horOffset+txtWidth+editWidth+checkWidth)...
                                                       vertOffset/(2*editHeight+2*vertOffset+startOffset)...
                                                       txtWidth/(2*horOffset+txtWidth+editWidth+checkWidth)...
                                                       editHeight/(2*editHeight+2*vertOffset+startOffset)]);
                                   
        GUIHandles.check.hYPPOCheck = annotation(hpanPPOIn, 'textbox',...
                                             'LineStyle', 'none',...
                                             'String', ' X ',...
                                             'BackgroundColor', GUIColors.UpperPanel,...
                                             'Color', 'r',...
                                             'FontWeight', 'Bold',...
                                             'Units', 'normalized',...
                                             'HorizontalAlignment','Left',...
                                             'VerticalAlignment','middle',...
                                             'Position', [(horOffset+txtWidth+editWidth)/(2*horOffset+txtWidth+editWidth+checkWidth)...
                                                          vertOffset/(2*editHeight+2*vertOffset+startOffset)...
                                                          checkWidth/(2*horOffset+txtWidth+editWidth+checkWidth)...
                                                          editHeight/(2*editHeight+2*vertOffset+startOffset)]);
                          
        % Parameter Uncertainty Input          
        % ============================
        hpanUncertainIn = uipanel(hfig2, 'Position', [1-(2*horOffset+txtWidth+editWidth+checkWidth)/rectWidth...
                                                      1-(14*editHeight+14*vertOffset+3*startOffset)/rectHeight...
                                                      (2*horOffset+txtWidth+editWidth+checkWidth)/rectWidth...
                                                      (5*editHeight+5*vertOffset+startOffset)/rectHeight],...
                                         'Title', 'Uncertainties',...
                                         'FontWeight', 'bold',...
                                         'BackgroundColor', GUIColors.UpperPanel,...
                                         'BorderWidth', 1,...
                                         'HighlightColor', GUIColors.UpperHighlight,...
                                         'ShadowColor', GUIColors.UpperShadow);
                                
        % Altitude Uncertianty
        % ====================
        GUIHandles.input.hAltUIn = uicontrol(hpanUncertainIn, 'Style', 'edit',...
                                               'String', num2str(rectParams.altUn, '%.5g'),...
                                               'Units', 'normalized',...
                                               'Position', [(horOffset+txtWidth)/(2*horOffset+txtWidth+editWidth+checkWidth)...
                                                            (4*editHeight+5*vertOffset)/(5*editHeight+5*vertOffset+startOffset)...
                                                            editWidth/(2*horOffset+txtWidth+editWidth+checkWidth)...
                                                            editHeight/(5*editHeight+5*vertOffset+startOffset)],...
                                               'FontWeight', 'bold',...
                                               'BackgroundColor', GUIColors.ButtonColor,...
                                               'ForegroundColor', GUIColors.Text,...
                                               'Enable', 'on',...
                                               'Callback', @CHECKINPUTCALLBACK);
                                 
        hAltUText = annotation(hpanUncertainIn, 'textbox',...
                                                'LineStyle', 'none',...
                                                'String', 'alt = ',...
                                                'BackgroundColor', GUIColors.UpperPanel,...
                                                'Units', 'normalized',...
                                                'HorizontalAlignment','right',...
                                                'VerticalAlignment','middle',...
                                                'Position', [horOffset/(2*horOffset+txtWidth+editWidth+checkWidth)...
                                                             (4*editHeight+5*vertOffset)/(5*editHeight+5*vertOffset+startOffset)...
                                                             txtWidth/(2*horOffset+txtWidth+editWidth+checkWidth)...
                                                             editHeight/(5*editHeight+5*vertOffset+startOffset)]);
                                   
        GUIHandles.check.hAltUCheck = annotation(hpanUncertainIn, 'textbox',...
                                                   'LineStyle', 'none',...
                                                   'String', ' X ',...
                                                   'BackgroundColor', GUIColors.UpperPanel,...
                                                   'Color', 'r',...
                                                   'FontWeight', 'Bold',...
                                                   'Units', 'normalized',...
                                                   'HorizontalAlignment','Left',...
                                                   'VerticalAlignment','middle',...
                                                   'Position', [(horOffset+txtWidth+editWidth)/(2*horOffset+txtWidth+editWidth+checkWidth)...
                                                                (4*editHeight+5*vertOffset)/(5*editHeight+5*vertOffset+startOffset)...
                                                                checkWidth/(2*horOffset+txtWidth+editWidth+checkWidth)...
                                                                editHeight/(5*editHeight+5*vertOffset+startOffset)]);
                                           
        % Horizontal field of view angle Uncertianty
        % ==========================================
        GUIHandles.input.hHfovUIn = uicontrol(hpanUncertainIn, 'Style', 'edit',...
                                                'String', num2str(rectParams.hfovUn, '%.5g'),...
                                                'Units', 'normalized',...
                                                'Position', [(horOffset+txtWidth)/(2*horOffset+txtWidth+editWidth+checkWidth)...
                                                             (3*editHeight+4*vertOffset)/(5*editHeight+5*vertOffset+startOffset)...
                                                             editWidth/(2*horOffset+txtWidth+editWidth+checkWidth)...
                                                             editHeight/(5*editHeight+5*vertOffset+startOffset)],...
                                                'FontWeight', 'bold',...
                                                'BackgroundColor', GUIColors.ButtonColor,...
                                                'ForegroundColor', GUIColors.Text,...
                                                'Enable', 'on',...
                                                'Callback', @CHECKINPUTCALLBACK);
                                 
        hHfovUText = annotation(hpanUncertainIn, 'textbox',...
                                                 'LineStyle', 'none',...
                                                 'String', 'hfov = ',...
                                                 'BackgroundColor', GUIColors.UpperPanel,...
                                                 'Units', 'normalized',...
                                                 'HorizontalAlignment','right',...
                                                 'VerticalAlignment','middle',...
                                                 'Position', [horOffset/(2*horOffset+txtWidth+editWidth+checkWidth)...
                                                              (3*editHeight+4*vertOffset)/(5*editHeight+5*vertOffset+startOffset)...
                                                              txtWidth/(2*horOffset+txtWidth+editWidth+checkWidth)...
                                                              editHeight/(5*editHeight+5*vertOffset+startOffset)]);
                                   
        GUIHandles.check.hHfovUCheck = annotation(hpanUncertainIn, 'textbox',...
                                                    'LineStyle', 'none',...
                                                    'String', ' X ',...
                                                    'BackgroundColor', GUIColors.UpperPanel,...
                                                    'Color', 'r',...
                                                    'FontWeight', 'Bold',...
                                                    'Units', 'normalized',...
                                                    'HorizontalAlignment','Left',...
                                                    'VerticalAlignment','middle',...
                                                    'Position', [(horOffset+txtWidth+editWidth)/(2*horOffset+txtWidth+editWidth+checkWidth)...
                                                                 (3*editHeight+4*vertOffset)/(5*editHeight+5*vertOffset+startOffset)...
                                                                 checkWidth/(2*horOffset+txtWidth+editWidth+checkWidth)...
                                                                 editHeight/(5*editHeight+5*vertOffset+startOffset)]);
                                            
        % Dip angle Uncertianty
        % =====================
        GUIHandles.input.hDipUIn = uicontrol(hpanUncertainIn, 'Style', 'edit',...
                                                'String', num2str(rectParams.dipUn),...
                                                'Units', 'normalized',...
                                                'Position', [(horOffset+txtWidth)/(2*horOffset+txtWidth+editWidth+checkWidth)...
                                                             (2*editHeight+3*vertOffset)/(5*editHeight+5*vertOffset+startOffset)...
                                                             editWidth/(2*horOffset+txtWidth+editWidth+checkWidth)...
                                                             editHeight/(5*editHeight+5*vertOffset+startOffset)],...
                                                'FontWeight', 'bold',...
                                                'BackgroundColor', GUIColors.ButtonColor,...
                                                'ForegroundColor', GUIColors.Text,...
                                                'Enable', 'on',...
                                                'Callback', @CHECKINPUTCALLBACK);
                                 
        hDipUText = annotation(hpanUncertainIn, 'textbox',...
                                                'LineStyle', 'none',...
                                                'String', '\lambda = ',...
                                                'BackgroundColor', GUIColors.UpperPanel,...
                                                'Units', 'normalized',...
                                                'HorizontalAlignment','right',...
                                                'VerticalAlignment','middle',...
                                                'Position', [horOffset/(2*horOffset+txtWidth+editWidth+checkWidth)...
                                                             (2*editHeight+3*vertOffset)/(5*editHeight+5*vertOffset+startOffset)...
                                                             txtWidth/(2*horOffset+txtWidth+editWidth+checkWidth)...
                                                             editHeight/(5*editHeight+5*vertOffset+startOffset)]);
                                   
        GUIHandles.check.hDipUCheck = annotation(hpanUncertainIn, 'textbox',...
                                                    'LineStyle', 'none',...
                                                    'String', ' X ',...
                                                    'BackgroundColor', GUIColors.UpperPanel,...
                                                    'Color', 'r',...
                                                    'FontWeight', 'Bold',...
                                                    'Units', 'normalized',...
                                                    'HorizontalAlignment','Left',...
                                                    'VerticalAlignment','middle',...
                                                    'Position', [(horOffset+txtWidth+editWidth)/(2*horOffset+txtWidth+editWidth+checkWidth)...
                                                                 (2*editHeight+3*vertOffset)/(5*editHeight+5*vertOffset+startOffset)...
                                                                 checkWidth/(2*horOffset+txtWidth+editWidth+checkWidth)...
                                                                 editHeight/(5*editHeight+5*vertOffset+startOffset)]);
                                            
        % Tilt angle Uncertianty
        % ======================
        GUIHandles.input.hTiltUIn = uicontrol(hpanUncertainIn, 'Style', 'edit',...
                                                'String', num2str(rectParams.tiltUn, '%.5g'),...
                                                'Units', 'normalized',...
                                                'Position', [(horOffset+txtWidth)/(2*horOffset+txtWidth+editWidth+checkWidth)...
                                                             (editHeight+2*vertOffset)/(5*editHeight+5*vertOffset+startOffset)...
                                                             editWidth/(2*horOffset+txtWidth+editWidth+checkWidth)...
                                                             editHeight/(5*editHeight+5*vertOffset+startOffset)],...
                                                'FontWeight', 'bold',...
                                                'BackgroundColor', GUIColors.ButtonColor,...
                                                'ForegroundColor', GUIColors.Text,...
                                                'Enable', 'on',...
                                                'Callback', @CHECKINPUTCALLBACK);
                                 
        hTiltUText = annotation(hpanUncertainIn, 'textbox',...
                                                 'LineStyle', 'none',...
                                                 'String', '\phi = ',...
                                                 'BackgroundColor', GUIColors.UpperPanel,...
                                                 'Units', 'normalized',...
                                                 'HorizontalAlignment','right',...
                                                 'VerticalAlignment','middle',...
                                                 'Position', [horOffset/(2*horOffset+txtWidth+editWidth+checkWidth)...
                                                              (editHeight+2*vertOffset)/(5*editHeight+5*vertOffset+startOffset)...
                                                              txtWidth/(2*horOffset+txtWidth+editWidth+checkWidth)...
                                                              editHeight/(5*editHeight+5*vertOffset+startOffset)]);
                                   
        GUIHandles.check.hTiltUCheck = annotation(hpanUncertainIn, 'textbox',...
                                                    'LineStyle', 'none',...
                                                    'String', ' X ',...
                                                    'BackgroundColor', GUIColors.UpperPanel,...
                                                    'Color', 'r',...
                                                    'FontWeight', 'Bold',...
                                                    'Units', 'normalized',...
                                                    'HorizontalAlignment','Left',...
                                                    'VerticalAlignment','middle',...
                                                    'Position', [(horOffset+txtWidth+editWidth)/(2*horOffset+txtWidth+editWidth+checkWidth)...
                                                                 (editHeight+2*vertOffset)/(5*editHeight+5*vertOffset+startOffset)...
                                                                 checkWidth/(2*horOffset+txtWidth+editWidth+checkWidth)...
                                                                 editHeight/(5*editHeight+5*vertOffset+startOffset)]);
                                            
        % heading angle Uncertianty
        % ==========================
        GUIHandles.input.hHeadUIn = uicontrol(hpanUncertainIn, 'Style', 'edit',...
                                                'String', num2str(rectParams.headUn, '%.5g'),...
                                                'Units', 'normalized',...
                                                'Position', [(horOffset+txtWidth)/(2*horOffset+txtWidth+editWidth+checkWidth)...
                                                             vertOffset/(5*editHeight+5*vertOffset+startOffset)...
                                                             editWidth/(2*horOffset+txtWidth+editWidth+checkWidth)...
                                                             editHeight/(5*editHeight+5*vertOffset+startOffset)],...
                                                'FontWeight', 'bold',...
                                                'BackgroundColor', GUIColors.ButtonColor,...
                                                'ForegroundColor', GUIColors.Text,...
                                                'Enable', 'on',...
                                                'Callback', @CHECKINPUTCALLBACK);
                                 
        hHeadUText = annotation(hpanUncertainIn, 'textbox',...
                                                 'LineStyle', 'none',...
                                                 'String', '\theta = ',...
                                                 'BackgroundColor', GUIColors.UpperPanel,...
                                                 'Units', 'normalized',...
                                                 'HorizontalAlignment','right',...
                                                 'VerticalAlignment','middle',...
                                                 'Position', [horOffset/(2*horOffset+txtWidth+editWidth+checkWidth)...
                                                              vertOffset/(5*editHeight+5*vertOffset+startOffset)...
                                                              txtWidth/(2*horOffset+txtWidth+editWidth+checkWidth)...
                                                              editHeight/(5*editHeight+5*vertOffset+startOffset)]);
                                   
        GUIHandles.check.hHeadUCheck = annotation(hpanUncertainIn, 'textbox',...
                                                    'LineStyle', 'none',...
                                                    'String', ' X ',...
                                                    'BackgroundColor', GUIColors.UpperPanel,...
                                                    'Color', 'r',...
                                                    'FontWeight', 'Bold',...
                                                    'Units', 'normalized',...
                                                    'HorizontalAlignment','Left',...
                                                    'VerticalAlignment','middle',...
                                                    'Position', [(horOffset+txtWidth+editWidth)/(2*horOffset+txtWidth+editWidth+checkWidth)...
                                                                 vertOffset/(5*editHeight+5*vertOffset+startOffset)...
                                                                 checkWidth/(2*horOffset+txtWidth+editWidth+checkWidth)...
                                                                 editHeight/(5*editHeight+5*vertOffset+startOffset)]);
                         
        % Fitting Polynomial Order          
        % ============================
        hpanPollyIn = uipanel(hfig2, 'Position', [1-(2*horOffset+txtWidth+editWidth+checkWidth)/rectWidth...
                                                  1-(15*editHeight+15*vertOffset+4*startOffset)/rectHeight...
                                                  (2*horOffset+txtWidth+editWidth+checkWidth)/rectWidth...
                                                  (1*editHeight+1*vertOffset+1*startOffset)/rectHeight],...
                                     'Title', 'Polynomial Order',...
                                     'FontWeight', 'bold',...
                                     'BackgroundColor', GUIColors.UpperPanel,...
                                     'BorderWidth', 1,...
                                     'HighlightColor', GUIColors.UpperHighlight,...
                                     'ShadowColor', GUIColors.UpperShadow);
                            
        % Order of fiting polynomial
        % ==========================
        GUIHandles.input.hOrderIn = uicontrol(hpanPollyIn, 'Style', 'edit',...
                                            'String', num2str(rectParams.order, '%.5g'),...
                                            'Units', 'normalized',...
                                            'Position', [(horOffset+txtWidth)/(2*horOffset+txtWidth+editWidth+checkWidth)...
                                                         vertOffset/(editHeight+vertOffset+startOffset)...
                                                         editWidth/(2*horOffset+txtWidth+editWidth+checkWidth)...
                                                         pollyHeight/(editHeight+vertOffset+startOffset)],...
                                            'FontWeight', 'bold',...
                                            'BackgroundColor', GUIColors.ButtonColor,...
                                            'ForegroundColor', GUIColors.Text,...
                                            'Enable', 'on',...
                                            'Callback', @CHECKINPUTCALLBACK);
                                 
        hOrderText = annotation(hpanPollyIn, 'textbox',...
                                             'LineStyle', 'none',...
                                             'String', 'Ord = ',...
                                             'BackgroundColor', GUIColors.UpperPanel,...
                                             'Units', 'normalized',...
                                             'HorizontalAlignment','right',...
                                             'VerticalAlignment','middle',...
                                             'Position', [horOffset/(2*horOffset+txtWidth+editWidth+checkWidth)...
                                                          vertOffset/(editHeight+vertOffset+startOffset)...
                                                          txtWidth/(2*horOffset+txtWidth+editWidth+checkWidth)...
                                                          pollyHeight/(editHeight+vertOffset+startOffset)]);
                                   
        GUIHandles.check.hOrderCheck = annotation(hpanPollyIn, 'textbox',...
                                                'LineStyle', 'none',...
                                                'String', ' X ',...
                                                'BackgroundColor', GUIColors.UpperPanel,...
                                                'Color', 'r',...
                                                'FontWeight', 'Bold',...
                                                'Units', 'normalized',...
                                                'HorizontalAlignment','Left',...
                                                'VerticalAlignment','middle',...
                                                'Position', [(horOffset+txtWidth+editWidth)/(2*horOffset+txtWidth+editWidth+checkWidth)...
                                                             vertOffset/(editHeight+vertOffset+startOffset)...
                                                             checkWidth/(2*horOffset+txtWidth+editWidth+checkWidth)...
                                                             pollyHeight/(editHeight+vertOffset+startOffset)]);
                                        
        % Action Buttons          
        % ========================
        hpanBtns = uipanel(hfig2, 'Position', [1-(2*horOffset+txtWidth+editWidth+checkWidth)/rectWidth...
                                               0.0...
                                               (2*horOffset+txtWidth+editWidth+checkWidth)/rectWidth...
                                               1-(15*editHeight+15*vertOffset+4*startOffset)/rectHeight],...
                                  'FontWeight', 'bold',...
                                  'BackgroundColor', GUIColors.UpperPanel,...
                                  'BorderWidth', 1,...
                                  'HighlightColor', GUIColors.UpperHighlight,...
                                  'ShadowColor', GUIColors.UpperShadow);
        %% Finish setting up GUI
        % ======================
     
        % Check that input parameters are OK
        paramsTemp = fieldnames(rectParams);
        error2Display = cell(0,0);
        for i = 1:length(paramsTemp)
            if any(strcmp(paramsTemp{i},{'rectLON';'rectLAT';'altRect';'hfovRect';'dipRect';'tiltRect';'headRect';'errGeoRect';'errPolyRect'}))
            else
                errorTemp = CheckValidParams(paramsTemp{i});
                if ~isempty(errorTemp)
                	[error2Display] = [error2Display; errorTemp];
                end
            end
        end
        
        PlotCameraUnrectified()
        
        PlotHorizon()
        
        if ~isempty(rectParams.rectLON)
            PlotRectified(rectParams.rectLON, rectParams.rectLAT)
            saveRectBtn.Enable = 'on';
        end
        
        hfig2.Visible = 'on';
        
        if ~isempty(error2Display)
            errordlg(error2Display,'Input Error', 'modal')
        end
        
        if sum(checkParams) ==  length(checkParams);
            rectifyBtn.Enable = 'on';
        else
            rectifyBtn.Enable = 'off';
        end
        
        %% Rectification GUI Functions
        % ============================
        function CHECKINPUTCALLBACK(hObject, ~)
        
            inputStr = hObject.String;
        
            if hObject == GUIHandles.input.hLatIn || hObject == GUIHandles.input.hLonIn
                if regexp(inputStr, '^\s*[-+]?\d+[.]?\d*\s*$')
                    if hObject == GUIHandles.input.hLatIn
                        if str2double(inputStr)>= -90 && str2double(inputStr)<= 90
                            GUIHandles.check.hLatCheck.String = ' OK ';
                            GUIHandles.check.hLatCheck.Color = 'g';
                            rectParams.lat = str2double(inputStr);
                            checkParams(1) = 1;
                        else
                            errordlg('Latitude must be between +/- 90 degrees.','Input Error', 'modal')
                            GUIHandles.check.hLatCheck.String = ' X ';
                            GUIHandles.check.hLatCheck.Color = 'r';
                            GUIHandles.input.hLatIn.String = '';
                            rectParams.lat = [];
                            checkParams(1) = 0;
                        end
                    elseif hObject == GUIHandles.input.hLonIn
                        if str2double(inputStr)>= -180 && str2double(inputStr)<= 180
                            GUIHandles.check.hLonCheck.String = ' OK ';
                            GUIHandles.check.hLonCheck.Color = 'g';
                            rectParams.lon = str2double(inputStr);
                            checkParams(2) = 1;
                        else
                            errordlg('Longitude must be between +/- 180 degrees.','Input Error', 'modal')
                            GUIHandles.check.hLonCheck.String = ' X ';
                            GUIHandles.check.hLonCheck.Color = 'r';
                            GUIHandles.input.hLonIn.String = '';
                            rectParams.lon = [];
                            checkParams(2) = 0;
                        end;
                    end
                else
                    if hObject == GUIHandles.input.hLatIn
                        GUIHandles.check.hLatCheck.String = ' X ';
                        GUIHandles.check.hLatCheck.Color = 'r';
                        GUIHandles.input.hLatIn.String = '';
                        rectParams.lat = [];
                        checkParams(1) = 0;
                    elseif hObject == GUIHandles.input.hLonIn
                        GUIHandles.check.hLonCheck.String = ' X ';
                        GUIHandles.check.hLonCheck.Color = 'r';
                        GUIHandles.input.hLatIn.String = '';
                        rectParams.lon = [];
                        checkParams(2) = 0;
                    end
                end
            
            elseif hObject == GUIHandles.input.hAltIn
                if regexp(inputStr, '^\s*[-+]?\d+[.]?\d*\s*$')
                    if str2double(inputStr)>= 0
                        GUIHandles.check.hAltCheck.String = ' OK ';
                        GUIHandles.check.hAltCheck.Color = 'g';
                        rectParams.alt = str2double(inputStr);
                        checkParams(3) = 1;
                    else
                        errordlg('Altitude must be positive.','Input Error', 'modal')
                        GUIHandles.check.hAltCheck.String = ' X ';
                        GUIHandles.check.hAltCheck.Color = 'r';
                        GUIHandles.input.hAltIn.String = '';
                        rectParams.alt = [];
                        checkParams(3) = 0;
                    end
                else
                    GUIHandles.check.hAltCheck.String = ' X ';
                    GUIHandles.check.hAltCheck.Color = 'r';
                    GUIHandles.input.hAltIn.String = '';
                    rectParams.alt = [];
                    checkParams(3) = 0;
                end
            
            elseif hObject == GUIHandles.input.hHfovIn
                if regexp(inputStr, '^\s*[-+]?\d+[.]?\d*\s*$')
                    if str2double(inputStr)>= 0 && str2double(inputStr)<= 180
                        GUIHandles.check.hHfovCheck.String = ' OK ';
                        GUIHandles.check.hHfovCheck.Color = 'g';
                        rectParams.hfov = str2double(inputStr);
                        checkParams(4) = 1;
                    else
                        errordlg('The angle of the horizontal field of view must be between 0 and 180 degrees.','Input Error', 'modal')
                        GUIHandles.check.hHfovCheck.String = ' X ';
                        GUIHandles.hHfovCheck.Color = 'r';
                        GUIHandles.input.hHfovIn.String = '';
                        rectParams.hfov = [];
                        checkParams(4) = 0;
                    end
                else
                    GUIHandles.check.hHfovCheck.String = ' X ';
                    GUIHandles.check.hHfovCheck.Color = 'r';
                    GUIHandles.input.hHfovIn.String = '';
                    rectParams.hfov = [];
                    checkParams(4) = 0;
                end
            
            elseif hObject == GUIHandles.input.hDipIn
                if regexp(inputStr, '^\s*[-+]?\d+[.]?\d*\s*$')
                    if str2double(inputStr)>= 0 && str2double(inputStr)<= 90
                        GUIHandles.check.hDipCheck.String = ' OK ';
                        GUIHandles.check.hDipCheck.Color = 'g';
                        rectParams.dip = str2double(inputStr);
                        checkParams(5) = 1;
                    else
                        errordlg({'The Dip Angle must be between 0 and 90.';'horizontal = 0 and straight down = 90'},'Input Error', 'modal')
                        GUIHandles.check.hDipCheck.String = ' X ';
                        GUIHandles.check.hDipCheck.Color = 'r';
                        GUIHandles.input.hDipIn.String = '';
                        rectParams.dip = [];
                        checkParams(5) = 0;
                    end
                else
                    GUIHandles.check.hDipCheck.String = ' X ';
                    GUIHandles.check.hDipCheck.Color = 'r';
                    GUIHandles.input.hDipIn.String = '';
                    rectParams.dip = [];
                    checkParams(5) = 0;
                end
            
            elseif hObject == GUIHandles.input.hTiltIn
                if regexp(inputStr, '^\s*[-+]?\d+[.]?\d*\s*$')
                    if str2double(inputStr)>= -90 && str2double(inputStr)<= 90
                        GUIHandles.check.hTiltCheck.String = ' OK ';
                        GUIHandles.check.hTiltCheck.Color = 'g';
                        rectParams.tilt = str2double(inputStr);
                        checkParams(6) = 1;
                    else
                        errordlg({'The tilt angle must be between +/- 90 degrees, with positive clockwise from horizontal.';'This will usually be close to 0.'},'Input Error', 'modal')
                        GUIHandles.check.hTiltCheck.String = ' X ';
                        GUIHandles.check.hTiltCheck.Color = 'r';
                        GUIHandles.input.hTiltIn.String = '';
                        rectParams.tilt = [];
                        checkParams(6) = 0;
                    end
                else
                    GUIHandles.check.hTiltCheck.String = ' X ';
                    GUIHandles.check.hTiltCheck.Color = 'r';
                    GUIHandles.input.hTiltIn.String = '';
                    rectParams.tilt = [];
                    checkParams(6) = 0;
                end
            
            elseif hObject == GUIHandles.input.hHeadIn
                if regexp(inputStr, '^\s*[-+]?\d+[.]?\d*\s*$')
                    if str2double(inputStr)>= 0 && str2double(inputStr)< 360
                        GUIHandles.check.hHeadCheck.String = ' OK ';
                        GUIHandles.check.hHeadCheck.Color = 'g';
                        rectParams.head = str2double(inputStr);
                        checkParams(7) = 1;
                    else
                        errordlg( {'The view angle of the camera must be between 0 and 360 degrees.';'View angle is clockwise from North.'}, 'Input Error', 'modal')
                        GUIHandles.check.hHeadCheck.String = ' X ';
                        GUIHandles.check.hHeadCheck.Color = 'r';
                        GUIHandles.input.hHeadIn.String = '';
                        rectParams.head = [];
                        checkParams(7) = 0;
                    end
                else
                    GUIHandles.check.hHeadCheck.String = ' X ';
                    GUIHandles.check.hHeadCheck.Color = 'r';
                    GUIHandles.input.hHeadIn.String = '';
                    rectParams.head = [];
                    checkParams(7) = 0;
                end
            
            elseif hObject == GUIHandles.input.hXPPOIn
                if regexp(inputStr, '^\s*[-+]?\d+[.]?\d*\s*$')
                    if mod(str2double(inputStr),1) == 0
                        GUIHandles.check.hXPPOCheck.String = ' OK ';
                        GUIHandles.check.hXPPOCheck.Color = 'g';
                        rectParams.xppo = str2double(inputStr);
                        checkParams(8) = 1;
                    else
                        errordlg( {'The principle point offset must be an integer number of pixels';'This offset is generally zero.'},'Input Error', 'modal')
                        GUIHandles.check.hXPPOCheck.String = ' X ';
                        GUIHandles.check.hXPPOCheck.Color = 'r';
                        GUIHandles.input.hXPPOIn.String = '';
                        rectParams.xppo = [];
                        checkParams(8) = 0;
                    end
                else
                    GUIHandles.check.hXPPOCheck.String = ' X ';
                    GUIHandles.check.hXPPOCheck.Color = 'r';
                    GUIHandles.input.hXPPOIn.String = '';
                    rectParams.xppo = [];
                    checkParams(8) = 0;
                end
            
            elseif hObject == GUIHandles.input.hYPPOIn
                if regexp(inputStr, '^\s*[-+]?\d+[.]?\d*\s*$')
                    if mod(str2double(inputStr),1) == 0
                        GUIHandles.check.hYPPOCheck.String = ' OK ';
                        GUIHandles.check.hYPPOCheck.Color = 'g';
                        rectParams.yppo = str2double(inputStr);
                        checkParams(9) = 1;
                    else
                        errordlg( {'The principle point offset must be an integer number of pixels';'This offset is generally zero.'},'Input Error', 'modal')
                        GUIHandles.check.hYPPOCheck.String = ' X ';
                        GUIHandles.check.hYPPOCheck.Color = 'r';
                        GUIHandles.input.hYPPOIn.String = '';
                        rectParams.yppo = [];
                        checkParams(9) = 0;
                    end
                else
                    GUIHandles.check.hYPPOCheck.String = ' X ';
                    GUIHandles.check.hYPPOCheck.Color = 'r';
                    GUIHandles.input.hYPPOIn.String = '';
                    rectParams.yppo = [];
                    checkParams(9) = 0;
                end
            
            elseif hObject == GUIHandles.input.hAltUIn
                if regexp(inputStr, '^\s*[-+]?\d+[.]?\d*\s*$')
                    if str2double(inputStr) >= 0
                        GUIHandles.check.hAltUCheck.String = ' OK ';
                        GUIHandles.check.hAltUCheck.Color = 'g';
                        rectParams.altUn = str2double(inputStr);
                        checkParams(10) = 1;
                    else
                        errordlg( 'Uncertainties must be greater than or equal to zero.','Input Error', 'modal')
                        GUIHandles.check.hAltUCheck.String = ' X ';
                        GUIHandles.check.hAltUCheck.Color = 'r';
                        GUIHandles.input.hAltUIn.String = '';
                        rectParams.altUn = [];
                        checkParams(10) = 0;
                    end
                else
                    GUIHandles.check.hAltUCheck.String = ' X ';
                    GUIHandles.check.hAltUCheck.Color = 'r';
                    GUIHandles.input.hAltUIn.String = '';
                    rectParams.altUn = [];
                    checkParams(10) = 0;
                end
            
            elseif hObject == GUIHandles.input.hHfovUIn
                if regexp(inputStr, '^\s*[-+]?\d+[.]?\d*\s*$')
                    if str2double(inputStr) >= 0
                        GUIHandles.check.hHfovUCheck.String = ' OK ';
                        GUIHandles.check.hHfovUCheck.Color = 'g';
                        rectParams.hfovUn = str2double(inputStr);
                        checkParams(11) = 1;
                    else
                        errordlg( 'Uncertainties must be greater than or equal to zero.','Input Error', 'modal')
                        GUIHandles.check.hHfovUCheck.String = ' X ';
                        GUIHandles.check.hHfovUCheck.Color = 'r';
                        GUIHandles.input.hHfovUIn.String = '';
                        rectParams.hfovUn = [];
                        checkParams(11) = 0;
                    end
                else
                    GUIHandles.check.hHfovUCheck.String = ' X ';
                    GUIHandles.check.hHfovUCheck.Color = 'r';
                    GUIHandles.input.hHfovUIn.String = '';
                    rectParams.hfovUn = [];
                    checkParams(11) = 0;
                end
            
            elseif hObject == GUIHandles.input.hDipUIn
                if regexp(inputStr, '^\s*[-+]?\d+[.]?\d*\s*$')
                    if str2double(inputStr) >= 0
                        GUIHandles.check.hDipUCheck.String = ' OK ';
                        GUIHandles.check.hDipUCheck.Color = 'g';
                        rectParams.dipUn = str2double(inputStr);
                        checkParams(12) = 1;
                    else
                        errordlg( 'Uncertainties must be greater than or equal to zero.','Input Error', 'modal')
                        GUIHandles.check.hDipUCheck.String = ' X ';
                        GUIHandles.check.hDipUCheck.Color = 'r';
                        GUIHandles.input.hDipUIn.String = '';
                        rectParams.dipUn = [];
                        checkParams(12) = 0;
                    end
                else
                    GUIHandles.check.hDipUCheck.String = ' X ';
                    GUIHandles.check.hDipUCheck.Color = 'r';
                    GUIHandles.input.hDipUIn.String = '';
                    rectParams.dipUn = [];
                    checkParams(12) = 0;
                end
            
            elseif hObject == GUIHandles.input.hTiltUIn
                if regexp(inputStr, '^\s*[-+]?\d+[.]?\d*\s*$')
                    if str2double(inputStr) >= 0
                        GUIHandles.check.hTiltUCheck.String = ' OK ';
                        GUIHandles.check.hTiltUCheck.Color = 'g';
                    	rectParams.tiltUn = str2double(inputStr);
                        checkParams(13) = 1;
                    else
                        errordlg( 'Uncertainties must be greater than or equal to zero.','Input Error', 'modal')
                        GUIHandles.check.hTiltUCheck.String = ' X ';
                        GUIHandles.check.hTiltUCheck.Color = 'r';
                        GUIHandles.input.hTiltUIn.String = '';
                        rectParams.tiltUn = [];
                        checkParams(13) = 0;
                    end
                else
                    GUIHandles.check.hTiltUCheck.String = ' X ';
                    GUIHandles.check.hTiltUCheck.Color = 'r';
                    GUIHandles.input.hTiltUIn.String = '';
                    rectParams.tiltUn = [];
                    checkParams(13) = 0;
                end
            
            elseif hObject == GUIHandles.input.hHeadUIn
                if regexp(inputStr, '^\s*[-+]?\d+[.]?\d*\s*$')
                    if str2double(inputStr) >= 0
                        GUIHandles.check.hHeadUCheck.String = ' OK ';
                        GUIHandles.check.hHeadUCheck.Color = 'g';
                        rectParams.headUn = str2double(inputStr);
                        checkParams(14) = 1;
                    else
                        errordlg( 'Uncertainties must be greater than or equal to zero.','Input Error', 'modal')
                        GUIHandles.check.hHeadUCheck.String = ' X ';
                        GUIHandles.check.hHeadUCheck.Color = 'r';
                        GUIHandles.input.hHeadUIn.String = '';
                        rectParams.headUn = [];
                        checkParams(14) = 0;
                    end
                else
                    GUIHandles.check.hHeadUCheck.String = ' X ';
                    GUIHandles.check.hHeadUCheck.Color = 'r';
                    GUIHandles.input.hHeadUIn.String = '';
                    rectParams.headUn = [];
                    checkParams(14) = 0;
                end
            
            elseif hObject == GUIHandles.input.hOrderIn
                if regexp(inputStr, '^\s*[-+]?\d+[.]?\d*\s*$')
                    if str2double(inputStr) == 0 || str2double(inputStr) == 1 || str2double(inputStr) == 2
                        GUIHandles.check.hOrderCheck.String = ' OK ';
                        GUIHandles.check.hOrderCheck.Color = 'g';
                        rectParams.order = str2double(inputStr);
                        checkParams(15) = 1;
                    else
                        errordlg( 'The polynomial order should be 0, 1, or 2.','Input Error', 'modal')
                        GUIHandles.check.hOrderCheck.String = ' X ';
                        GUIHandles.check.hOrderCheck.Color = 'r';
                        GUIHandles.input.hOrderIn.String = '';
                        rectParams.order = [];
                        checkParams(15) = 0;
                    end
                else
                    GUIHandles.check.hOrderCheck.String = ' X ';
                    GUIHandles.check.hOrderCheck.Color = 'r';
                    GUIHandles.input.hOrderIn.String = '';
                    rectParams.order = [];
                    checkParams(15) = 0;
                end
            
            end
            
            PlotHorizon()
            
            if sum(checkParams) ==  length(checkParams);
                rectifyBtn.Enable = 'on';
            else
                rectifyBtn.Enable = 'off';
            end
        
        end
        
        function LOADPARAMETERS(hObject, ~)
            
            hObject.Enable = 'inactive';
            
            [fileNameParam, pathNameParam, filterIndex] = uigetfile({'*.dat'}, 'Load Camera Parameters File (*.DAT)');
        
            if filterIndex ~= 0 % if a file was selected
            
                if strcmpi('.dat', fileNameParam(end-3:end)) % if file is a .text file
                    
                    fidParam = fopen([pathNameParam fileNameParam], 'r');
                    while 1
                        paramLine = fgetl(fidParam);
                        if paramLine == -1;
                            break
                        end
                        if regexp(paramLine, '^\s*LON0\s*=\s*')
                            matchStr = regexp(paramLine, '(?<=^\s*LON0\s*=\s*)[-+]?\d+[.]?\d*', 'match');
                            rectParams.lon = str2double(matchStr);
                            GUIHandles.input.hLonIn.String = matchStr;
                            
                        elseif regexp(paramLine, '^\s*LAT0\s*=\s*')
                            matchStr = regexp(paramLine, '(?<=^\s*LAT0\s*=\s*)[-+]?\d+[.]?\d*', 'match');
                            rectParams.lat = str2double(matchStr);
                            GUIHandles.input.hLatIn.String = matchStr;
                            
                        elseif regexp(paramLine, '^\s*H\s*=\s*')
                            matchStr = regexp(paramLine, '(?<=^\s*H\s*=\s*)[-+]?\d+[.]?\d*', 'match');
                            rectParams.alt = str2double(matchStr);
                            GUIHandles.input.hAltIn.String = matchStr;
                            
                        elseif regexp(paramLine, '^\s*hfov\s*=\s*')
                            matchStr = regexp(paramLine, '(?<=^\s*hfov\s*=\s*)[-+]?\d+[.]?\d*', 'match');
                            rectParams.hfov = str2double(matchStr);
                            GUIHandles.input.hHfovIn.String = matchStr;
                            
                        elseif regexp(paramLine, '^\s*lambda\s*=\s*')
                            matchStr = regexp(paramLine, '(?<=^\s*lambda\s*=\s*)[-+]?\d+[.]?\d*', 'match');
                            rectParams.dip = str2double(matchStr);
                            GUIHandles.input.hDipIn.String = matchStr;
                            
                        elseif regexp(paramLine, '^\s*phi\s*=\s*')
                            matchStr = regexp(paramLine, '(?<=^\s*phi\s*=\s*)[-+]?\d+[.]?\d*', 'match');
                            rectParams.tilt = str2double(matchStr);
                            GUIHandles.input.hTiltIn.String = matchStr;
                            
                        elseif regexp(paramLine, '^\s*theta\s*=\s*')
                            matchStr = regexp(paramLine, '(?<=^\s*theta\s*=\s*)[-+]?\d+[.]?\d*', 'match');
                            rectParams.head = str2double(matchStr);
                            GUIHandles.input.hHeadIn.String = matchStr;
                            
                        elseif regexp(paramLine, '^\s*ic\s*=\s*')
                            matchStr = regexp(paramLine, '(?<=^\s*ic\s*=\s*)[-+]?\d+[.]?\d*', 'match');
                            rectParams.xppo = str2double(matchStr);
                            GUIHandles.input.hXPPOIn.String = matchStr;
                            
                        elseif regexp(paramLine, '^\s*jc\s*=\s*')
                            matchStr = regexp(paramLine, '(?<=^\s*jc\s*=\s*)[-+]?\d+[.]?\d*', 'match');
                            rectParams.yppo = str2double(matchStr);
                            GUIHandles.input.hYPPOIn.String = matchStr;
                            
                         elseif regexp(paramLine, '^\s*dH\s*=\s*')
                            matchStr = regexp(paramLine, '(?<=^\s*dH\s*=\s*)[-+]?\d+[.]?\d*', 'match');
                            rectParams.altUn = str2double(matchStr);
                            GUIHandles.input.hAltUIn.String = matchStr;
                            
                        elseif regexp(paramLine, '^\s*dhfov\s*=\s*')
                            matchStr = regexp(paramLine, '(?<=^\s*dhfov\s*=\s*)[-+]?\d+[.]?\d*', 'match');
                            rectParams.hfovUn = str2double(matchStr);
                            GUIHandles.input.hHfovUIn.String = matchStr;
                            
                        elseif regexp(paramLine, '^\s*dlambda\s*=\s*')
                            matchStr = regexp(paramLine, '(?<=^\s*dlambda\s*=\s*)[-+]?\d+[.]?\d*', 'match');
                            rectParams.dipUn = str2double(matchStr);
                            GUIHandles.input.hDipUIn.String = matchStr;
                            
                        elseif regexp(paramLine, '^\s*dphi\s*=\s*')
                            matchStr = regexp(paramLine, '(?<=^\s*dphi\s*=\s*)[-+]?\d+[.]?\d*', 'match');
                            rectParams.tiltUn = str2double(matchStr);
                            GUIHandles.input.hTiltUIn.String = matchStr;
                            
                        elseif regexp(paramLine, '^\s*dtheta\s*=\s*')
                            matchStr = regexp(paramLine, '(?<=^\s*dtheta\s*=\s*)[-+]?\d+[.]?\d*', 'match');
                            rectParams.headUn = str2double(matchStr);
                            GUIHandles.input.hHeadUIn.String = matchStr;
                            
                        elseif regexp(paramLine, '^\s*polyOrder\s*=\s*')
                            matchStr = regexp(paramLine, '(?<=^\s*polyOrder\s*=\s*)[-+]?\d+[.]?\d*', 'match');
                            rectParams.order = str2double(matchStr);
                            GUIHandles.input.hOrderIn.String = matchStr;
                            
                        end
                        
                    end
                    fclose(fidParam);
                    
                    paramsTempLoad = fieldnames(rectParams);
                    error2DisplayLoad = cell(0,0);
                    for ind = 1:length(paramsTempLoad)
                        if any(strcmp(paramsTempLoad{i},{'rectLON';'rectLAT';'atlRect';'hfovRect';'dipRect';'tiltRect';'HeadRect';'errGeoRect';'errPolyRect'}))
                        else
                            errorTempLoad = CheckValidParams(paramsTempLoad{i});
                            if ~isempty(errorTempLoad)
                                [error2DisplayLoad] = [error2DisplayLoad; errorTempLoad];
                            end
                        end
                    end
                    
                    PlotHorizon()
                    
                    if ~isempty(error2Display)
                        errordlg(error2Display,'Input Error', 'modal')
                    end
                    
                    if sum(checkParams) ==  length(checkParams);
                        rectifyBtn.Enable = 'on';
                    else
                        rectifyBtn.Enable = 'off';
                    end
                
                else
                
                    herror = errordlg('Selected file is not a .DAT File','File Error','modal');
                    uiwait(herror)
                
                end % end if strcmpi('.utc', utcFName(end-3:end))
            
            end % end if filterIndex ~= 0
            
            hObject.Enable = 'on';
            
        end
        
        function COMPUTERECTIFICATION(hObject, ~)
            
            hObject.Enable = 'inactive';
            
            loadRectParams.Enable = 'off';
            undoGCPBtn.Enable = 'off';
            
            nMinimize = figdata.RectificationIteration;
            
            % check for correct number of GCPS to unknowns
            nUnknown = 0;
            if rectParams.hfovUn   > 0.0
                nUnknown = nUnknown+1;
            end
            if rectParams.dipUn > 0.0
                nUnknown = nUnknown+1; 
            end
            if rectParams.tiltUn    > 0.0
                nUnknown = nUnknown+1; 
            end
            if rectParams.altUn      > 0.0
                nUnknown = nUnknown+1;
            end
            if rectParams.headUn  > 0.0
                nUnknown = nUnknown+1; 
            end

            if nUnknown > length(xPixel)
                hErr = errordlg('The number of GCPs must be greater than the number of unknowns.','Input Error', 'modal');
                uiwait(hErr)
                return
            end
            
            % Check for consistencies between number of GCPs and order of the polynomial 
            % correction
            ngcp = length(xPixel);
            if ngcp < 3*rectParams.order
                hWarn = warndlg({'The number of GCPs is inconsistent with the order of the polynomial correction.';'number of GCPs should be >= 3*polynomial order.';'Polynomial correction will not be applied.'},'Input Error', 'modal');
                polyCorrection = 0;
                uiwait(hWarn) 
            else
                polyCorrection = 1;
            end
            if rectParams.order == 0
                polyCorrection = 0;
            end
            
            % This is the main section for the minimization algorithm
            % =======================================================
            % Author: Daniel Bourgault
            %         Institut des sciences de la mer de Rimouski
            % email: daniel_bourgault@uqar.ca 
            % Website: http://demeter.uqar.ca/g_rect/
            % February 2013
            %========================================================

            if nUnknown > 0
    
                % Options for the fminsearch function. May be needed for some particular
                % problems but in general the default values should work fine.  
                options=optimset('Display','off');
                %options=optimset('MaxFunEvals',100000,'MaxIter',100000,'TolX',1.d-12,'TolFun',1.d-12);
                %options = [];
  
    
                % Only feed the minimization algorithm with the GCPs. xp and yp are the
                % image coordinate of these GCPs.
                xp = xPixel(~isnan(xPixel));
                yp = yPixel(~isnan(yPixel));
                lonp = lon(~isnan(lon));
                latp = lat(~isnan(lat));

                % This is the call to the minimization
                bestErrGeoFit = Inf;
                cvBest = [];
                
                % set the camera parameters
                imgWidth = figdata.ImWidth;
                imgHeight = figdata.ImHeight;
                LON0 = rectParams.lon;
                LAT0 = rectParams.lat;
                hfov   = rectParams.hfov;
                lambda = rectParams.dip;
                phi    = rectParams.tilt;
                H      = rectParams.alt;
                theta  = rectParams.head;
                ic = rectParams.yppo;
                jc = rectParams.xppo;
  
                % Save inital guesses in new variables. 
                hfovGuess   = rectParams.hfov;
                lambdaGuess = rectParams.dip;
                phiGuess    = rectParams.tilt;
                HGuess      = rectParams.alt;
                thetaGuess  = rectParams.head;
                
                % set uncertainties
                dhfov = rectParams.hfovUn;
                dlambda = rectParams.dipUn;
                dphi = rectParams.tiltUn;
                dH = rectParams.altUn;
                dtheta = rectParams.headUn;
                
                hWait = waitbar(0, 'Applying Geometric Rectification...');
  
                for iMinimize = 1:nMinimize
      
                    % First guesses for the minimization
                    if iMinimize == 1
                        hfov0   = rectParams.hfov; 
                        lambda0 = rectParams.dip; 
                        phi0    = rectParams.tilt; 
                        H0      = rectParams.alt;
                        theta0  = rectParams.head;
                    else
                        % Select randomly new initial guesses within the specified
                        % uncertainties.
                        hfov0   = (hfovGuess - dhfov)     + 2*dhfov*rand(1); 
                        lambda0 = (lambdaGuess - dlambda) + 2*dlambda*rand(1); 
                        phi0    = (phiGuess - dphi)       + 2*dphi*rand(1); 
                        H0      = (HGuess - dH)           + 2*dH*rand(1);
                        theta0  = (thetaGuess - dtheta)   + 2*dtheta*rand(1);
                    end
  
                    % Cretae vector cv0 for the initial guesses. 
                    guessInd = 0;
                    if dhfov > 0.0
                        guessInd = guessInd+1;
                        cv0(guessInd) = hfov0;
                        theOrder(guessInd) = 1;
                    end
                    if dlambda > 0.0
                        guessInd = guessInd + 1;
                        cv0(guessInd) = lambda0;
                        theOrder(guessInd) = 2;
                    end
                    if dphi > 0.0
                        guessInd = guessInd + 1;
                        cv0(guessInd) = phi0;
                        theOrder(guessInd) = 3;
                    end
                    if dH > 0.0
                        guessInd = guessInd + 1;
                        cv0(guessInd) = H0;
                        theOrder(guessInd) = 4;
                    end
                    if dtheta > 0.0
                        guessInd = guessInd + 1;
                        cv0(guessInd) = theta0;
                        theOrder(guessInd) = 5;
                    end

                    [cv, errGeoFit] = fminsearch(@g_error_geofit,cv0,options, ...
                                            imgWidth,imgHeight,xp,yp,ic,jc,...
                                            hfov,lambda,phi,H,theta,...
                                            hfov0,lambda0,phi0,H0,theta0,...
                                            hfovGuess,lambdaGuess,phiGuess,HGuess,thetaGuess,...
                                            dhfov,dlambda,dphi,dH,dtheta,...
                                            LON0,LAT0,...
                                            xp,yp,lonp,latp,...
                                            theOrder, 1);
                              
                    if errGeoFit < bestErrGeoFit
                        bestErrGeoFit = errGeoFit;
                        cvBest = cv;
                    end
                    
                    waitbar(iMinimize/nMinimize, hWait)
                
                end
                close(hWait);
                
                if ~isempty(cvBest)
                    for j = 1:length(theOrder)
                        if theOrder(j) == 1; hfov   = cvBest(j); end
                        if theOrder(j) == 2; lambda = cvBest(j); end
                        if theOrder(j) == 3; phi    = cvBest(j); end
                        if theOrder(j) == 4; H      = cvBest(j); end
                        if theOrder(j) == 5; theta  = cvBest(j); end
                    end
                end
                
                if isinf(bestErrGeoFit)
                    msgbox({'Could not find a solution.';...
                            'Error between GCPs and their projection was infinity.';...
                            'Image will not be rectified.'}, ' ', 'modal')
                    loadRectParams.Enable = 'on';
                    return
                end
                
                % Now construct the matrices LON and LAT for the entire image using the 
                % camera parameters found by minimization just above.

                % Camera coordinate of all pixels
                xpAll = repmat(1:imgWidth,imgHeight,1);
                ypAll = repmat((1:imgHeight)',1,imgWidth);
                
                % Transform camera coordinate to ground coordinate.
                [LON, LAT] = g_pix2ll(xpAll,ypAll,imgWidth,imgHeight,ic,jc,...
                                    hfov,lambda,phi,theta,H,LON0,LAT0,1);
                                
                % Apply polynomial correction if requested.
                if polyCorrection == true
                    [LON, LAT, errPolyFit] = g_poly(LON,LAT,LON0,LAT0,yp,xp,lonp,latp,rectParams.order,1);
                    createStruct.Interpreter = 'Tex';
                    createStruct.WindowStyle = 'modal';
                    msgbox({'PARAMETERS AFTER GEOMETRICAL RECTIFICATION';...
                            ['   Field of view (hfov):           ' num2str(hfov)];...
                            ['   Dip andle (\lambda):            ' num2str(lambda)];...
                            ['   Tilt angle (\phi):              ' num2str(phi)];...
                            ['   Camera altitude (alt):          ' num2str(H)];...
                            ['   View angle from North (\theta):  ' num2str(theta)];...
                            '';...
                            ['The rms error after geometrical correction (m): ' num2str(bestErrGeoFit)];...
                            ['The rms error after polynomial stretching (m): ' num2str(errPolyFit)]},...
                            createStruct)
                else
                    errPolyFit = [];
                    createStruct.Interpreter = 'Tex';
                    createStruct.WindowStyle = 'modal';
                    msgbox({'PARAMETERS AFTER GEOMETRICAL RECTIFICATION';...
                            ['   Field of view (hfov):           ' num2str(hfov)];...
                            ['   Dip andle (\lambda):            ' num2str(lambda)];...
                            ['   Tilt angle (\phi):              ' num2str(phi)];...
                            ['   Camera altitude (alt):          ' num2str(H)];...
                            ['   View angle from North (\theta):  ' num2str(theta)];...
                            '';...
                            ['The rms error after geometrical correction (m): ' num2str(bestErrGeoFit)]},...
                            createStruct)
                end
                
                % plot the rectified image
                rectParams.rectLON = LON;
                rectParams.rectLAT = LAT;
                rectParams.altRect = H;
                rectParams.hfovRect = hfov;
                rectParams.dipRect = lambda;
                rectParams.tiltRect = phi;
                rectParams.headRect = theta;
                rectParams.errGeoRect = bestErrGeoFit;
                rectParams.errPolyRect = errPolyFit;
                PlotRectified(LON, LAT)
  
            end
            
            loadRectParams.Enable = 'on';
            saveRectBtn.Enable = 'on';
            if isempty(deleteStack)
                undoGCPBtn.Enable = 'off';
            else
                undoGCPBtn.Enable = 'on';
            end
            
            hObject.Enable = 'on';
        end
        
        function SAVERECTIFY(hObject, ~)
            
            hObject.Enable = 'inactive';
            
            [fileNameSaveRect, pathNameSaveRect, filterIndex] = uiputfile({'*.mat'}, 'Select File for Rectificaiton Save');
            if filterIndex ~= 0
                LON = rectParams.rectLON;
                LAT = rectParams.rectLAT;
                altitude = rectParams.altRect;
                hfov = rectParams.hfovRect;
                dip = rectParams.dipRect;
                tilt = rectParams.tiltRect;
                heading = rectParams.headRect;
                xp = repmat(1:figdata.ImWidth,figdata.ImHeight,1);
                yp = repmat((1:figdata.ImHeight)',1,figdata.ImWidth);
                
                save([pathNameSaveRect fileNameSaveRect], 'LON', 'LAT', 'altitude', 'hfov', 'dip', 'tilt', 'heading', '-mat');
                
                [m,n] = size(LON);
                LONReshape = reshape(LON,m*n, 1);
                LATReshape = reshape(LAT,m*n, 1);
                xpReshape = reshape(xp,m*n, 1);
                ypReshape = reshape(yp,m*n, 1);
                rectData = [xpReshape ypReshape LONReshape LATReshape];
                ind = isnan(rectData);
                rectData(ind) = -999;
                fid = fopen([pathNameSaveRect fileNameSaveRect(1:end-4) '.txt'], 'w');
                  fprintf(fid, '# Altitude = %3.4f, hfov = %3.4f, Dip Angle = %3.4f, Tilt Angle = %3.4f, View Angle = %3.4f\n', altitude, hfov, dip, tilt, heading);
                  fprintf(fid, '%d\t%d\t%f\t%f\n', rectData');
                fclose(fid);
                
            end
       
            hObject.Enable = 'on';
        end
        
        function DELETE(~, ~)
            
            deleteStack{end+1} = [deleteInd' xPixel(deleteInd) yPixel(deleteInd) lat(deleteInd) lon(deleteInd)];
            
            xPixel(deleteInd) = nan;
            yPixel(deleteInd) = nan;
            lat(deleteInd) = nan;
            lon(deleteInd) = nan;
            
            deleteInd = [];
            deleteMarker = 1;
            
            delete(findobj(haxes3.Children, 'Tag', 'GCPSelect'))
            delete(findobj(haxes4.Children, 'Tag', 'GCPSelect'))
            delete(findobj(haxes3.Children, 'Tag', 'GCPUn'))
            delete(findobj(haxes4.Children, 'Tag', 'GCPR'))
            
            hold(haxes3, 'on')
                plot(haxes3, xPixel, yPixel, 'sg', 'LineWidth', 2, 'MarkerFaceColor', 'g', 'Tag', 'GCPUn', 'ButtonDownFcn', @SELECTGCP)
            hold(haxes3, 'off')
            
            if ~isempty(rectParams.rectLON)
                lonRect = [];
                latRect = [];
                for ind = 1:length(xPixel)
                    if ~isnan(xPixel(ind))
                        lonRect = [lonRect; rectParams.rectLON(yPixel(ind), xPixel(ind))];
                        latRect = [latRect; rectParams.rectLAT(yPixel(ind), xPixel(ind))];
                    end
                end
                hold(haxes4, 'on')
                    plot(haxes4, lon, lat, 'og', 'LineWidth', 2, 'Tag', 'GCPR', 'ButtonDownFcn', @SELECTGCP)
                    plot(haxes4, lonRect, latRect, '+r', 'LineWidth', 2, 'Tag', 'GCPR', 'PickableParts', 'none')
                hold(haxes4, 'off')
            end
            
            undoGCPBtn.Enable = 'on';
            rectifyBtn.Enable = 'on';
            deleteGCPBtn.Enable = 'off';
            
        end
        
        function UNDO(hObject, ~)
            
            hObject.Enable = 'inactive';
            
            gcp2Undo = deleteStack{end};
            xPixel(gcp2Undo(:,1)) = gcp2Undo(:,2);
            yPixel(gcp2Undo(:,1)) = gcp2Undo(:,3);
            lat(gcp2Undo(:,1)) = gcp2Undo(:,4);
            lon(gcp2Undo(:,1)) = gcp2Undo(:,5);
            
            deleteStack(end) = [];
            
            delete(findobj(haxes3.Children, 'Tag', 'GCPSelect'))
            delete(findobj(haxes4.Children, 'Tag', 'GCPSelect'))
            delete(findobj(haxes3.Children, 'Tag', 'GCPUn'))
            delete(findobj(haxes4.Children, 'Tag', 'GCPR'))
            
            hold(haxes3, 'on')
                plot(haxes3, xPixel, yPixel, 'sg', 'LineWidth', 2, 'MarkerFaceColor', 'g', 'Tag', 'GCPUn', 'ButtonDownFcn', @SELECTGCP)
            hold(haxes3, 'off')
            
            lonRect = [];
            latRect = [];
            for ind = 1:length(xPixel)
                if ~isnan(xPixel(ind))
                    lonRect = [lonRect; rectParams.rectLON(yPixel(ind), xPixel(ind))];
                    latRect = [latRect; rectParams.rectLAT(yPixel(ind), xPixel(ind))];
                end
            end
            if ~isempty(rectParams.rectLON)
                hold(haxes4, 'on')
                    plot(haxes4, lon, lat, 'og', 'LineWidth', 2, 'Tag', 'GCPR', 'ButtonDownFcn', @SELECTGCP)
                    plot(haxes4, lonRect, latRect, '+r', 'LineWidth', 2, 'Tag', 'GCPR', 'PickableParts', 'none')
                hold(haxes4, 'off')
            end
            
            if isempty(deleteStack)
                undoGCPBtn.Enable = 'off';
            else
                undoGCPBtn.Enable = 'on';
            end
           
        end
        
        function SELECTGCP(hObject, ~)
            
            deleteGCPBtn.Enable = 'on';
            rectifyBtn.Enable = 'off';
            
            if strcmp(hObject.Tag, 'GCPUn')
                centerPoint = haxes3.CurrentPoint;
                [~, ind] = min(sqrt((centerPoint(1,1)-xPixel).^2 + (centerPoint(1,2)-yPixel).^2));
                hold(haxes3, 'on')
                    plot(haxes3, xPixel(ind), yPixel(ind), 'sy', 'LineWidth', 2, 'MarkerFaceColor', 'y', 'Tag', 'GCPSelect', 'UserData', deleteMarker, 'ButtonDownFcn', @UNSELECTGCP)
                hold(haxes3, 'off')
                if ~isempty(rectParams.rectLON)
                    hold(haxes4, 'on')
                        plot(haxes4, lon(ind), lat(ind), 'oy', 'LineWidth', 2, 'Tag', 'GCPSelect', 'UserData', deleteMarker, 'ButtonDownFcn', @UNSELECTGCP)
                    hold(haxes4, 'off')
                end
                deleteInd(end+1) = ind;
                deleteMarker = deleteMarker+1;
                
            elseif strcmp(hObject.Tag, 'GCPR')
                centerPoint = haxes4.CurrentPoint;
                [~, ind] = min(sqrt((centerPoint(1,1)-lon).^2 + (centerPoint(1,2)-lat).^2));
                hold(haxes3, 'on')
                hold(haxes4, 'on')
                    plot(haxes3, xPixel(ind), yPixel(ind), 'sy', 'LineWidth', 2, 'MarkerFaceColor', 'y', 'Tag', 'GCPSelect', 'UserData', deleteMarker, 'ButtonDownFcn', @UNSELECTGCP)
                    plot(haxes4, lon(ind), lat(ind), 'oy', 'LineWidth', 2, 'Tag', 'GCPSelect', 'UserData', deleteMarker, 'ButtonDownFcn', @UNSELECTGCP)
                hold(haxes3, 'off')
                hold(haxes4, 'off')
                deleteInd(end+1) = ind;
                deleteMarker = deleteMarker+1;
                
            end
            
        end
        
        function UNSELECTGCP(hObject, ~)
            
            if hObject.Parent == haxes3

                centerPoint = haxes3.CurrentPoint;
                [~, ind] = min(sqrt((centerPoint(1,1)-xPixel).^2 + (centerPoint(1,2)-yPixel).^2));
                deleteInd(deleteInd == ind) = [];
                
                delete(findobj(haxes4.Children, 'UserData', hObject.UserData));
                delete(hObject);
                
            elseif hObject.Parent == haxes4
                
                centerPoint = haxes4.CurrentPoint;
                [~, ind] = min(sqrt((centerPoint(1,1)-lon).^2 + (centerPoint(1,2)-lat).^2));
                deleteInd(deleteInd == ind) = [];
                
                delete(findobj(haxes3.Children, 'UserData', hObject.UserData));
                delete(hObject);
                
            end
            
            if isempty(deleteInd)
                deleteGCPBtn.Enable = 'off';
                rectifyBtn.Enable = 'on';
            else
                deleteGCPBtn.Enable = 'on';
                rectifyBtn.Enable = 'off';
            end
            
        end
        
        function REMOVEPOINTSFROMMAIN(~, ~)
            
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
        
        function [errorStr] = CheckValidParams(inputVar)
            
            if strcmp(inputVar, 'lat')
                if ~isempty(rectParams.(inputVar))
                    if rectParams.(inputVar)>= -90 && rectParams.(inputVar)<= 90
                        GUIHandles.check.hLatCheck.String = ' OK ';
                        GUIHandles.check.hLatCheck.Color = 'g';
                        checkParams(1) = 1;
                        errorStr = '';
                    else
                        GUIHandles.check.hLatCheck.String = ' X ';
                        GUIHandles.check.hLatCheck.Color = 'r';
                        checkParams(1) = 0;
                        errorStr = 'Latitude must be between +/- 90 degrees.';
                    end
                else
                    GUIHandles.check.hLatCheck.String = ' X ';
                    GUIHandles.check.hLatCheck.Color = 'r';
                    checkParams(1) = 0;
                    errorStr = '';
                end
                
            elseif strcmp(inputVar, 'lon')
                if ~isempty(rectParams.(inputVar))
                    if rectParams.(inputVar)>= -180 && rectParams.(inputVar)<= 180
                        GUIHandles.check.hLonCheck.String = ' OK ';
                        GUIHandles.check.hLonCheck.Color = 'g';
                        checkParams(2) = 1;
                        errorStr = '';
                    else
                        GUIHandles.check.hLonCheck.String = ' X ';
                        GUIHandles.check.hLonCheck.Color = 'r';
                        checkParams(2) = 0;
                        errorStr = 'Longitude must be between +/- 180 degrees.';
                    end
                else
                    GUIHandles.check.hLonCheck.String = ' X ';
                    GUIHandles.check.hLonCheck.Color = 'r';
                    checkParams(2) = 0;
                    errorStr = '';
                end
                
            elseif strcmp(inputVar, 'alt')
                if ~isempty(rectParams.(inputVar))
                    if rectParams.(inputVar)>= 0
                        GUIHandles.check.hAltCheck.String = ' OK ';
                        GUIHandles.check.hAltCheck.Color = 'g';
                        checkParams(3) = 1;
                        errorStr = '';
                    else
                        GUIHandles.check.hAltCheck.String = ' X ';
                        GUIHandles.check.hAltCheck.Color = 'r';
                        checkParams(3) = 0;
                        errorStr = 'Altitude must be positive.';
                    end
                else
                    GUIHandles.check.hAltCheck.String = ' X ';
                    GUIHandles.check.hAltCheck.Color = 'r';
                    checkParams(3) = 0;
                    errorStr = '';
                end
                
            elseif strcmp(inputVar, 'hfov')
                if ~isempty(rectParams.(inputVar))
                    if rectParams.(inputVar)>= 0 && rectParams.(inputVar)<= 180
                        GUIHandles.check.hHfovCheck.String = ' OK ';
                        GUIHandles.check.hHfovCheck.Color = 'g';
                        checkParams(4) = 1;
                        errorStr = '';
                    else
                        GUIHandles.check.hHfovCheck.String = ' X ';
                        GUIHandles.check.hHfovCheck.Color = 'r';
                        checkParams(4) = 0;
                        errorStr = 'The angle of the horizontal field of view must be between 0 and 180 degrees.';
                    end
                else
                    GUIHandles.check.hHfovCheck.String = ' X ';
                    GUIHandles.check.hHfovCheck.Color = 'r';
                    checkParams(4) = 0;
                    errorStr = '';
                end
                
            elseif strcmp(inputVar, 'dip')
                if ~isempty(rectParams.(inputVar))
                    if rectParams.(inputVar)>= 0 && rectParams.(inputVar)<= 90
                        GUIHandles.check.hDipCheck.String = ' OK ';
                        GUIHandles.check.hDipCheck.Color = 'g';
                        checkParams(5) = 1;
                        errorStr = '';
                    else
                        GUIHandles.check.hDipCheck.String = ' X ';
                        GUIHandles.check.hDipCheck.Color = 'r';
                        checkParams(5) = 0;
                        errorStr = 'The Dip Angle must be between 0 and 90.  horizontal = 0 and straight down = 90';
                    end
                else
                    GUIHandles.check.hDipCheck.String = ' X ';
                    GUIHandles.check.hDipCheck.Color = 'r';
                    checkParams(5) = 0;
                    errorStr = '';
                end
                
            elseif strcmp(inputVar, 'tilt')
                if ~isempty(rectParams.(inputVar))
                    if rectParams.(inputVar)>= -90 && rectParams.(inputVar)<= 90
                        GUIHandles.check.hTiltCheck.String = ' OK ';
                        GUIHandles.check.hTiltCheck.Color = 'g';
                        checkParams(6) = 1;
                        errorStr = '';
                    else
                        GUIHandles.check.hTiltCheck.String = ' X ';
                        GUIHandles.check.hTiltCheck.Color = 'r';
                        checkParams(6) = 0;
                        errorStr = 'The tilt angle must be between +/- 90 degrees, with positive clockwise from horizontal. This will usually be close to 0.';
                    end
                else
                    GUIHandles.check.hTiltCheck.String = ' X ';
                    GUIHandles.check.hTiltCheck.Color = 'r';
                    checkParams(6) = 0;
                    errorStr = '';
                end
                
            elseif strcmp(inputVar, 'head')
                if ~isempty(rectParams.(inputVar))
                    if rectParams.(inputVar)>= 0 && rectParams.(inputVar) < 360
                        GUIHandles.check.hHeadCheck.String = ' OK ';
                        GUIHandles.check.hHeadCheck.Color = 'g';
                        checkParams(7) = 1;
                        errorStr = '';
                    else
                        GUIHandles.check.hHeadCheck.String = ' X ';
                        GUIHandles.check.hHeadCheck.Color = 'r';
                        checkParams(7) = 0;
                        errorStr = 'The view angle of the camera must be between 0 and 360 degrees.  View angle is clockwise from North.';
                    end
                else
                    GUIHandles.check.hHeadCheck.String = ' X ';
                    GUIHandles.check.hHeadCheck.Color = 'r';
                    checkParams(7) = 0;
                    errorStr = '';
                end
                
            elseif strcmp(inputVar, 'xppo')
                if ~isempty(rectParams.(inputVar))
                    if mod(rectParams.(inputVar), 1) == 0
                        GUIHandles.check.hXPPOCheck.String = ' OK ';
                        GUIHandles.check.hXPPOCheck.Color = 'g';
                        checkParams(8) = 1;
                        errorStr = '';
                    else
                        GUIHandles.check.hXPPOCheck.String = ' X ';
                        GUIHandles.check.hXPPOCheck.Color = 'r';
                        checkParams(8) = 0;
                        errorStr = 'The X principle point offset must be an integer number of pixels.  This offset is generally zero.';
                    end
                else
                    GUIHandles.check.hXPPOCheck.String = ' X ';
                    GUIHandles.check.hXPPOCheck.Color = 'r';
                    checkParams(8) = 0;
                    errorStr = '';
                end
                
            elseif strcmp(inputVar, 'yppo')
                if ~isempty(rectParams.(inputVar))
                    if mod(rectParams.(inputVar), 1) == 0
                        GUIHandles.check.hYPPOCheck.String = ' OK ';
                        GUIHandles.check.hYPPOCheck.Color = 'g';
                        checkParams(9) = 1;
                        errorStr = '';
                    else
                        GUIHandles.check.hYPPOCheck.String = ' X ';
                        GUIHandles.check.hYPPOCheck.Color = 'r';
                        checkParams(9) = 0;
                        errorStr = 'The Y principle point offset must be an integer number of pixels.  This offset is generally zero.';
                    end
                else
                    GUIHandles.check.hYPPOCheck.String = ' X ';
                    GUIHandles.check.hYPPOCheck.Color = 'r';
                    checkParams(9) = 0;
                    errorStr = '';
                end
                
            elseif strcmp(inputVar, 'altUn')
                if ~isempty(rectParams.(inputVar))
                    if rectParams.(inputVar)>= 0
                        GUIHandles.check.hAltUCheck.String = ' OK ';
                        GUIHandles.check.hAltUCheck.Color = 'g';
                        checkParams(10) = 1;
                        errorStr = '';
                    else
                        GUIHandles.check.hAltUCheck.String = ' X ';
                        GUIHandles.check.hAltUCheck.Color = 'r';
                        checkParams(10) = 0;
                        errorStr = 'The altitude uncertainty must be greater than or equal to zero.';
                    end
                else
                    GUIHandles.check.hAltUCheck.String = ' X ';
                    GUIHandles.check.hAltUCheck.Color = 'r';
                    checkParams(10) = 0;
                    errorStr = '';
                end
                
            elseif strcmp(inputVar, 'hfovUn')
                if ~isempty(rectParams.(inputVar))
                    if rectParams.(inputVar)>= 0
                        GUIHandles.check.hHfovUCheck.String = ' OK ';
                        GUIHandles.check.hHfovUCheck.Color = 'g';
                        checkParams(11) = 1;
                        errorStr = '';
                    else
                        GUIHandles.check.hHfovUCheck.String = ' X ';
                        GUIHandles.check.hHfovUCheck.Color = 'r';
                        checkParams(11) = 0;
                        errorStr = 'The field of view angle uncertainty must be greater than or equal to zero.';
                    end
                else
                    GUIHandles.check.hHfovUCheck.String = ' X ';
                    GUIHandles.check.hHfovUCheck.Color = 'r';
                    checkParams(11) = 0;
                    errorStr = '';
                end
                
            elseif strcmp(inputVar, 'dipUn')
                if ~isempty(rectParams.(inputVar))
                    if rectParams.(inputVar)>= 0
                        GUIHandles.check.hDipUCheck.String = ' OK ';
                        GUIHandles.check.hDipUCheck.Color = 'g';
                        checkParams(12) = 1;
                        errorStr = '';
                    else
                        GUIHandles.check.hDipUCheck.String = ' X ';
                        GUIHandles.check.hDipUCheck.Color = 'r';
                        checkParams(12) = 0;
                        errorStr = 'The dip angle uncertainty must be greater than or equal to zero.';
                    end
                else
                    GUIHandles.check.hDipUCheck.String = ' X ';
                    GUIHandles.check.hDipUCheck.Color = 'r';
                    checkParams(12) = 0;
                    errorStr = '';
                end
                
            elseif strcmp(inputVar, 'tiltUn')
                if ~isempty(rectParams.(inputVar))
                    if rectParams.(inputVar)>= 0
                        GUIHandles.check.hTiltUCheck.String = ' OK ';
                        GUIHandles.check.hTiltUCheck.Color = 'g';
                        checkParams(13) = 1;
                        errorStr = '';
                    else
                        GUIHandles.check.hTiltUCheck.String = ' X ';
                        GUIHandles.check.hTiltUCheck.Color = 'r';
                        checkParams(13) = 0;
                        errorStr = 'The tilt angle uncertainty must be greater than or equal to zero.';
                    end
                else
                    GUIHandles.check.hTiltUCheck.String = ' X ';
                    GUIHandles.check.hTiltUCheck.Color = 'r';
                    checkParams(13) = 0;
                    errorStr = '';
                end
                
            elseif strcmp(inputVar, 'headUn')
                if ~isempty(rectParams.(inputVar))
                    if rectParams.(inputVar)>= 0
                        GUIHandles.check.hHeadUCheck.String = ' OK ';
                        GUIHandles.check.hHeadUCheck.Color = 'g';
                        checkParams(14) = 1;
                        errorStr = '';
                    else
                        GUIHandles.check.hHeadUCheck.String = ' X ';
                        GUIHandles.check.hHeadUCheck.Color = 'r';
                        checkParams(14) = 0;
                        errorStr = 'The view angle uncertainty must be greater than or equal to zero.';
                    end
                else
                    GUIHandles.check.hHeadUCheck.String = ' X ';
                    GUIHandles.check.hHeadUCheck.Color = 'r';
                    checkParams(14) = 0;
                    errorStr = '';
                end
                
            elseif strcmp(inputVar, 'order')
                if ~isempty(rectParams.(inputVar))
                    if rectParams.(inputVar)== 0 || rectParams.(inputVar)== 1 || rectParams.(inputVar)== 2
                        GUIHandles.check.hOrderCheck.String = ' OK ';
                        GUIHandles.check.hOrderCheck.Color = 'g';
                        checkParams(15) = 1;
                        errorStr = '';
                    else
                        GUIHandles.check.hOrderCheck.String = ' X ';
                        GUIHandles.check.hOrderCheck.Color = 'r';
                        checkParams(15) = 0;
                        errorStr = 'The polynomial order should be 0, 1, or 2.';
                    end
                else
                    GUIHandles.check.hOrderCheck.String = ' X ';
                    GUIHandles.check.hOrderCheck.Color = 'r';
                    checkParams(15) = 0;
                    errorStr = '';
                end
                
            end
            
        end

        function PlotCameraUnrectified
    
            if errorFlag == 0
                imagesc(haxes3, tiffData);
                hold(haxes3, 'on')
                    plot(haxes3, xPixel, yPixel, 'sg', 'LineWidth', 2, 'MarkerFaceColor', 'g', 'Tag', 'GCPUn', 'ButtonDownFcn', @SELECTGCP)
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
        
        function PlotRectified(LON, LAT)
            
            if errorFlag == 0;
                delete(haxes4.Children)
                lonRect = [];
                latRect = [];
                for ind = 1:length(xPixel)
                    if ~isnan(xPixel(ind))
                        lonRect = [lonRect; LON(yPixel(ind), xPixel(ind))];
                        latRect = [latRect; LAT(yPixel(ind), xPixel(ind))];
                    end
                end
                LON0 = rectParams.lon;
                LAT0 = rectParams.lat;
            
                pcolor(haxes4, LON, LAT, tiffData);
                hold(haxes4, 'on')
                    plot(haxes4, lon, lat, 'og', 'LineWidth', 2, 'Tag', 'GCPR', 'ButtonDownFcn', @SELECTGCP)
                    plot(haxes4, lonRect, latRect, '+r', 'LineWidth', 2, 'Tag', 'GCPR', 'PickableParts', 'none')
                    plot(haxes4, LON0, LAT0, 'oy', 'LineWidth', 2, 'MarkerSize', 10)
                hold(haxes4, 'off')
                haxes4.XLim = [min([lon; lonRect; LON0]) max([lon; lonRect; LON0])];
                haxes4.YLim = [min([lat; latRect; LAT0]) max([lat; latRect; LAT0])];
                haxes4.XTick = [];
                haxes4.YTick = [];
                haxes4.XTickLabel = '';
                haxes4.YTickLabel = '';
                haxes4.Color = GUIColors.Axes;
                shading(haxes4, 'flat')
                rectTitle = {'Rectified';['alt = ' num2str(rectParams.altRect) ', hfov = ' num2str(rectParams.hfovRect)...
                            ', \lambda = ' num2str(rectParams.dipRect) ', \phi = ' num2str(rectParams.tiltRect)...
                            ', \theta = ' num2str(rectParams.headRect)]};
                if isempty(rectParams.errPolyRect)
                    rectTitle{2} = [rectTitle{2} ', RMS Error = ' num2str(rectParams.errGeoRect)];
                else
                    rectTitle{2} = [rectTitle{2} ', RMS Error = ' num2str(rectParams.errPolyRect)];
                end
                haxes4.Title.String = rectTitle;
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
                               (1-(3*axesHorOffset+editWidth+txtWidth+checkWidth)/(adjustWidthRect))/2.0...
                               1-(axesTopOffset+axesBottomOffset+loadRectHeight)/adjustHeightRect];
            
            haxes4.Position = [2*axesHorOffset/adjustWidthRect+haxes3.Position(3)...
                               axesBottomOffset/adjustHeightRect...
                               (1-(3*axesHorOffset+editWidth+txtWidth+checkWidth)/(adjustWidthRect))/2.0...
                               1-(axesTopOffset+axesBottomOffset+loadRectHeight)/adjustHeightRect];
            
            hpanLoadRect.Position = [0 ... % left
                                     (1-(loadRectHeight/adjustHeightRect))... % bottom
                                     1-(2*horOffset+txtWidth+editWidth+checkWidth)/adjustWidthRect... % width
                                     (loadRectHeight/adjustHeightRect)]; % height
                                 
            loadRectParams.Position = [(loadRectBtnOffset/(hpanLoadRect.Position(3).*adjustWidthRect))... % left
                                       ((loadRectHeight-loadRectBtnHeight)/2)/loadRectHeight... % bottom
                                       (loadRectBtnWidth/(hpanLoadRect.Position(3).*adjustWidthRect))... % width
                                       loadRectBtnHeight/loadRectHeight]; % height
                                   
            rectifyBtn.Position = [loadRectParams.Position(1)+loadRectParams.Position(3)+(loadRectBtnOffset/(hpanLoadRect.Position(3).*adjustWidthRect))... % left
                                   ((loadRectHeight-loadRectBtnHeight)/2)/loadRectHeight... % bottom
                                   (loadRectBtnWidth/(hpanLoadRect.Position(3).*adjustWidthRect))... % width
                                   loadRectBtnHeight/loadRectHeight]; % Height
                                
            saveRectBtn.Position = [rectifyBtn.Position(1)+rectifyBtn.Position(3)+(loadRectBtnOffset/(hpanLoadRect.Position(3).*adjustWidthRect))... % left
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
            
            hpanCamIn.Position = [1-(2*horOffset+txtWidth+editWidth+checkWidth)/adjustWidthRect...
                                  1-(7*editHeight+7*vertOffset+startOffset)/adjustHeightRect...
                                 (2*horOffset+txtWidth+editWidth+checkWidth)/adjustWidthRect...
                                 (7*editHeight+7*vertOffset+startOffset)/adjustHeightRect];
                             
            hpanPPOIn.Position = [1-(2*horOffset+txtWidth+editWidth+checkWidth)/adjustWidthRect...
                                  1-(9*editHeight+9*vertOffset+2*startOffset)/adjustHeightRect...
                                 (2*horOffset+txtWidth+editWidth+checkWidth)/adjustWidthRect...
                                 (2*editHeight+2*vertOffset+startOffset)/adjustHeightRect];
                             
            hpanUncertainIn.Position = [1-(2*horOffset+txtWidth+editWidth+checkWidth)/adjustWidthRect...
                                        1-(14*editHeight+14*vertOffset+3*startOffset)/adjustHeightRect...
                                        (2*horOffset+txtWidth+editWidth+checkWidth)/adjustWidthRect...
                                        (5*editHeight+5*vertOffset+startOffset)/adjustHeightRect];
                                    
            hpanPollyIn.Position = [1-(2*horOffset+txtWidth+editWidth+checkWidth)/adjustWidthRect...
                                    1-(15*editHeight+15*vertOffset+4*startOffset)/adjustHeightRect...
                                    (2*horOffset+txtWidth+editWidth+checkWidth)/adjustWidthRect...
                                    (1*editHeight+1*vertOffset+1*startOffset)/adjustHeightRect];
                                              
            hpanBtns.Position = [1-(2*horOffset+txtWidth+editWidth+checkWidth)/adjustWidthRect...
                                 0.0...
                                 (2*horOffset+txtWidth+editWidth+checkWidth)/adjustWidthRect...
                                 1-(15*editHeight+15*vertOffset+4*startOffset)/adjustHeightRect];

        end

    end

end


%% Rectification Functions
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


