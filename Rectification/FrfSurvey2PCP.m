function FrfSurvey2PCP(fnameIn, fnameOut)

% FrfSurvey2PCP(fnameIn, fnameOut)
% =========================================================================
% Current verison = Version 1, 10/14/2017
% 
% Gets the FRF X, FRF Y, and Z from a processed FRF .CSV survey file.
% Survey points are outputted to a file that can be loaded into
% PickCOntrolPoints.m. 
% 
% Because the processed FRF survey files tend to correct for the GPS 
% antenna height, it is better to work with the .RAW survey files and use
% FRFRawSurvey2PCP.m
% 
% Inputs:
%     dirIn = A string a processed FRF .CSV survey file.
%     fnameOut = A string with the name of the output file that can then go
%                to PickControlPoints.m
% 
% Outputs:
%     A file with the name of input fnameOut that can be used with
%     PickControlPoints.m
% 
% Version History:
%     1) 10/14/2017: Original
%  ========================================================================

    fid = fopen(fnameIn);
    surveyIn = textscan(fid,'%*s %*d %*d %f %f %*f %*f %f %f %*f %*f %f %f %f %f %*d %*f %*f %*f %f %*f', 'Delimiter', ',', 'HeaderLines', 1)';
    
    % pull out values from the loaded data
    lat = surveyIn{1};
    lon = surveyIn{2};
    x = surveyIn{3};
    y = surveyIn{4};
    dateNum = surveyIn{5};
    hour = surveyIn{6};
    min = surveyIn{7};
    sec = surveyIn{8};
    z = surveyIn{9};
    
    % pull apart the date number
    year = floor(dateNum./10^4);
    month = floor( (dateNum-(year.*10^4))./10^2 );
    day = dateNum-(year.*10^4+month.*10^2);
       
    % print data to survey out
    surveyOut = [year, month, day, hour, min, sec, lat, lon, x, y, z];
    fid = fopen(fnameOut, 'w');
    fprintf(fid, 'Year\tMonth\tDay\tHour\tMin\tSec\tLat\t\tLon\t\tX\t\tY\t\tZ\r\n');
    fprintf(fid, '%4d\t%02d\t%02d\t%02d\t%02d\t%02d\t%2.10f\t%2.10f\t%4.3f\t\t%4.3f\t\t%3.3f\r\n', surveyOut');
    fclose(fid);

end