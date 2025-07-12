function betaNew = constructCameraPose(xyzGCP, uvGCP, icp, beta0)

% betaNew = constructCameraPose(xyzGCP, icp, beta0)
% =========================================================================
% Current verison = Version 1, 04/17/2017
% 
% Do a nonlinear least squares regression to find the best parameters for
% the camera's extrinisc parameters (beta = [x y z pitch roll azimuth]).
% The model for the least squares fit in the function findUVFrom6DOF.m
% 
% This program is simple for now, but is being left for future expansion.
% 
% Inputs:
%     xyzGCP = The x, y, z, coordiantes of the ground contorl points.
%              xyzGCP is a three column array, where column 1 is x, column
%              2 is y, and column 3 is z.
%     uvGCP = The u, v, image coordinates of the ground control point in
%             the image.  uvGCP is a two column array, where colun 1 is u
%             and column 2 is v.  Note: [u,v] has [0,0] at the top left
%             pixel in the image.  U increses to the right, v increases
%             down.
%     icp = A structure containing the camera intrinsic and distortion
%           parameters.  icp is made with
%           makeInstinsicStructFromCalTechCal.m
%     beta0 = A row vector with the initial guess of the camera extrnisic 
%             parameters.
%             beta0 = [x y z pitch roll azimuth]
% 
% Outputs:
%     betaNew = A row vector with th solution to the camera extrinsic
%               parameters based on the input GCPs.
%               betaNew = [x y z pitch roll azimuth]
% 
% Version History:
%     1) 04/17/2017: Original
% =========================================================================

UV = [uvGCP(:,1); uvGCP(:,2)];

[betaNew, R, J, CovB, MSE, ErrInfo] = nlinfit(xyzGCP, UV, @(beta0, xyzGCP)findUVFrom6DOF(beta0, icp, xyzGCP),beta0);