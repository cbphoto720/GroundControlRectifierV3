function PvlabSurvey2PCP(fnameIn, fnameOut)

% PvlabSurvey2PCP(fnameIn, fnameOut)
% =========================================================================
% Current verison = Version 1, 10/13/2017
% 
% This program takes one of my processed .llzt survey files and converts it
% to a file that can be inputted to PickControlPoints.  Lat and lon are
% converted to FRF X and FRF Y before before being written to the output
% file.
% 
% Inputs:
%     fnameIn = A string with the name of the name and path of the .LLZT
%               survey file. Data should be at 1Hz.
%     fnameOut = A string with the name and path of the output file that
%                can be loaded into PickControlPoints 
% 
% Outputs:
%     Output is a text file with the survey data in a format that can be
%     loaded into PickControlPoints.m
% 
% Version History:
%     1) 10/13/2017: Original
% =========================================================================

    surveyIn = load(fnameIn);
    
    % pull out values from the loaded data
    lat = surveyIn(:,1);
    lon = surveyIn(:,2);
    z = surveyIn(:,3);
    dateNum = surveyIn(:,4);
    
    % pull apart the date number
    year = floor(dateNum./10^6);
    month = floor( (dateNum-(year.*10^6))./10^4 );
    day = floor( (dateNum-(year.*10^6+month.*10^4))./10^2 );
    decHour = dateNum-(year.*10^6+month.*10^4+day.*10^2);
    hour = floor(decHour);
    decMin = (decHour-hour).*60;
    min = floor(decMin);
    decSec = (decMin-min).*60;
    gpsTime = datetime(year, month, day, hour, min, decSec, 'timezone', 'UTC');
    gpsTime = dateshift(gpsTime,'start','second','nearest');
    
    [year, month, day, hour, min, sec] = datevec(gpsTime);
    
    % convert lat and lon to FRFX and FRFY
    % FRF lat origin = 36.177597325
    % FRF lon origin = -75.749685725
    % pier heading = 71.8609
    [x, y] = lltoxy_survey(lat, lon, 36.177597484, -75.749685973, 72.29326);
    
    % print data to survey out
    surveyOut = [year, month, day, hour, min, sec, lat, lon, x, y, z];
    fid = fopen(fnameOut, 'w');
    fprintf(fid, 'Year\tMonth\tDay\tHour\tMin\tSec\tLat\t\tLon\t\tX\t\tY\t\tZ\r\n');
    fprintf(fid, '%4d\t%02d\t%02d\t%02d\t%02d\t%02d\t%2.10f\t%2.10f\t%4.3f\t\t%4.3f\t\t%3.3f\r\n', surveyOut');
    fclose(fid);

end