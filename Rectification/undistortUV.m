function [Uu, Vu] = undistortUV(Ud, Vd, icp)

% [Uu, Vu] = undistortUV(Ud, Vd, icp)
% =================================================
% Current verison = Version 1, 04/19/2017
% 
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
% 
% Version History:
%     1) 04/19/2017: Original
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