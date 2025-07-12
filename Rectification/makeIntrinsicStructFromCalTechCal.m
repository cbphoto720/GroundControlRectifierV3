function icp = makeIntrinsicStructFromCalTechCal(cal_mat)

% icp = makeIntrinsicStructFromCalTechCal(cal_mat)
% ================================================
% Current verison = Version 1, 04/11/2017
% 
% This program takes a calibration *.mat file from the Cal Tech calibration
% toolbox and converts the important contents into a structure.  This
% structure is used to either distort or undistort an image.  The structure
% is compatible with CIRN programs.
% 
% Inputs:
%     cal_mat = a string with the full path and file name of the .mat file
%               that is saved when doing a calibration with the Cal Tech
%               calibration tool box
% 
% Outputs:
%     icp = a strucutre that contains the relevent camera calibration
%           parameters (image size, focal length, principal Point Offset,
%           radial distortion, tangential distortion, and skewness).  This
%           stucture is compatible with the UAV toolbox
% 
% Version History:
%     1) 04/11/2017: Original
% ================================================

% check to see if the file exists.
if ~exist(cal_mat, 'file')
    fprintf(1, 'File Can Not Be Found\n')
    return
end

% Check that the required variables are in the mat file
cal_vars = whos('-file', cal_mat);
cal_var_names = extractfield(cal_vars, 'name');
err_string = '';
if ~any(strcmp(cal_var_names, 'fc'))
    err_string = [err_string 'Focal Length Not Found\n'];
end
if ~any(strcmp(cal_var_names, 'cc'))
    err_string = [err_string 'Principal Point Not Found\n'];
end
if ~any(strcmp(cal_var_names, 'alpha_c'))
    err_string = [err_string 'Skew Coefficinet Not Found\n'];
end
if ~any(strcmp(cal_var_names, 'kc'))
    err_string = [err_string 'Distortion Coefficinets Not Found\n'];
end
if ~any(strcmp(cal_var_names, 'nx')) || ~any(strcmp(cal_var_names, 'ny'))
    err_string = [err_string 'Image Size Is Missing\n'];
end
if ~isempty(err_string)
    err_string = [err_string 'Ending Program\n'];
    fprintf(1, err_string)
    return
end

% Load the relevent variables from the mat file
cal_dat = load(cal_mat, 'fc', 'cc', 'alpha_c', 'kc', 'nx', 'ny');

% Parse out the calibration parameters
icp.NU  = cal_dat.nx;
icp.NV  = cal_dat.ny;
icp.c0U = cal_dat.cc(1);
icp.c0V = cal_dat.cc(2);
icp.fx  = cal_dat.fc(1);
icp.fy  = cal_dat.fc(2);
icp.d1  = cal_dat.kc(1);
icp.d2  = cal_dat.kc(2);
icp.d3  = cal_dat.kc(5);
icp.t1  = cal_dat.kc(3);
icp.t2  = cal_dat.kc(4);
icp.ac  = cal_dat.alpha_c;
icp = makeRadialDistortion(icp);
icp = makeTangentialDistortion(icp);



