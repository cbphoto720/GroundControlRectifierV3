function UV = findUVFrom6DOF(beta0, icp, xyz)

% UV = findUVFrom6DOF(beta0, icp, xyz)
% =====================================================
% Current verison = Version 1, 04/13/2017
% 
% Converts a set of real world x, y, and zs into the corresponding image
% coordinates U, and V.  The convertion uses camera intrinsic and 
% distortion parameters, defined in icp, and extrinsic parameters, defined
% in beta0.  This program is to be used as the model function for nlinfit.m
% to find the best extrinsic camera parameters given a set of GCPs.
% 
% If you want to find the pixel a given [x, y, z] location falls in then
% use getUVfromXYZ.m
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
% 
% Version History:
%     1) 04/13/2017: Original
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