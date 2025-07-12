function FRFRawSurvey2PCP(dirIn,fnameOut)

% FRFRawSurvey2PCP(dirIn,fnameOut)
% =========================================================================
% Current verison = Version 1, 01/12/2018
% 
% Takes all the .RAW files from an FRF survey directory and finds the lat,
% lon, z of the gps antenna.  Lat, lon is then converted to FRF X and FRF
% Y. FRF X, FRF Y, and Z are then written to a file that can be loaded into
% PickControlPoints.m for finding GCPs and getting camera extrnisics.
% 
% Inputs:
%     dirIn = A string of the directory where the .RAW files from an FRF 
%             survey day are located.
%     fnameOut = A string with the name of the output file that can then go
%                to PickControlPoints.m
% 
% Outputs:
%     A file with the name of input fnameOut that can be used with
%     PickControlPoints.m
% 
% Version History:
%     1) 01/12/2018: Original
%  ========================================================================

% list all the files in the input directory
fileNames = ls(dirIn);

% get the number of files in the directory
[numFiles, ~] = size(fileNames);

% set up variables for the for loop
UTCTime = [];
UTCDate = [];
lat = [];
lon = [];
flag = [];
pdop = [];
nsat = [];
eht = [];

% step through all the files in the directory
for ind = 1:numFiles
    
    % if it has extension .RAW then get the survey info from the file
    if regexpi(fileNames(ind,:), '.RAW\s*$')
        disp(['Reading ' fileNames(ind, :)])
        fid = fopen([dirIn '/' fileNames(ind, :)]);
        while 1
            line = fgetl(fid);
            if line == -1
                break
            end
            if regexp(line, '^MSG')
                A = sscanf(line, 'MSG %*d %*f $PTNL,GGK,%f,%f,%f,N,%f,W,%f,%f,%f,EHT%f,M');
                UTCTime(end+1) = A(1);
                UTCDate(end+1) = A(2);
                lat(end+1) = floor(A(3)./100) + (A(3)-floor(A(3)./100).*100)./60;
                lon(end+1) = (floor(A(4)./100) + (A(4)-floor(A(4)./100).*100)./60).*-1;
                flag(end+1) = A(5);
                nsat(end+1) = A(6);
                pdop(end+1) = A(7);
                eht(end+1) = A(8);
            end
        end
        fclose(fid);
    end
    
end

% filter out bad gps values
filtInd = flag ~= 3 | nsat < 5 | pdop > 4;
UTCTime(filtInd) = [];
UTCDate(filtInd) = [];
lat(filtInd) = [];
lon(filtInd) = [];
eht(filtInd) = [];

% convert lat/lon to FRF X/Y
% FRF lat origin = 36.177597325
% FRF lon origin = -75.749685725
% pier heading = 71.8609
[x, y] = lltoxy_survey(lat, lon, 36.177597484, -75.749685973, 72.29326);

% calculate and correct for the geoid
zGeoid = intg_12A(lat,lon);
z = eht - zGeoid;

% Pull out the date and times
UTCMonth = floor(UTCDate./10^4);
UTCDay = floor((UTCDate - UTCMonth.*10^4)./10^2);
UTCYear = 2000 + (UTCDate - (UTCMonth.*10^4+UTCDay.*10^2));
UTCHour = floor(UTCTime./10^4);
UTCMin = floor((UTCTime - UTCHour.*10^4)./10^2);
UTCSec = UTCTime - (UTCHour.*10^4+UTCMin.*10^2);

% print data to survey out
surveyOut = [UTCYear', UTCMonth', UTCDay', UTCHour', UTCMin', UTCSec', lat', lon', x', y', z'];
fid = fopen(fnameOut, 'w');
fprintf(fid, 'Year\tMonth\tDay\tHour\tMin\tSec\tLat\t\tLon\t\tX\t\tY\t\tZ\r\n');
fprintf(fid, '%4d\t%02d\t%02d\t%02d\t%02d\t%02d\t%2.10f\t%2.10f\t%4.3f\t\t%4.3f\t\t%3.3f\r\n', surveyOut');
fclose(fid);



