function [X, Y, Z] = getXYZfromUV(U, V, icp, beta0, val, flag, varargin)

% [X, Y, Z] = getXYZfromUV(U, V, icp, beta0, val, flag)
% [X, Y, Z] = getXYZfromUV(U, V, icp, beta0, val, flag, mask)
% ================================================================
% Current Verion = Version 2, 02/15/2018
% 
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
%     mask = An optional input that masks pixel a number of degrees below
%            the horizon.  Input is in degrees.  If no input then mask is
%            set to 5 degrees.
% 
% Outputs:
%     X = The real world, rectangular, X coordinate.  is the same size as U
%         and V.
%     Y = The real world, rectangular, Y coordinate.  is the same size as U
%         and V.
%     Z = The real world, rectangual, Z coordinate.  is the same size as U
%         and V.
% 
% Version History:
%     1) 05/30/2017: Original
%     2) 02/05/2018: Version 2
%           - Added in a more robust horizon mask.  This was done by using
%             a rotation matrix from the g_rect toolbox.  Once rotated
%             correctly, the horizon can be found by finding all positive
%             y values and converting those to nans
%           - Added an option to also mask out pixels within a certain
%             number of degrees from the horizon.  This is an optional user
%             input.  If left blank it defaults to 5 degrees.
%           - Added that if no physical location is defined, then default
%             to z = 0.
% 
% ================================================================

% Check the variable arguments
lv = length(varargin);
if lv == 0
    mask = 5;
elseif lv == 1
    mask = varargin{1};
else
    error('Too many inputs')
end

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
hR = makeHorizonRotation(beta0(4)+mask, beta0(5), beta0(6));
IC = [eye(3) beta0(1:3)']; % opposite sign from x, y, z to U, V;

% apply the camera matrix and rotaion to go from U, V to untranslated
% coordinated space divided by Zc. [Xt/Zc; Yt/Zc; Zt/Zc]
XYZtilZc = R^-1*K^-1*UV;
XYZHor = hR*K^-1*UV;

% Normalize by the Zt/Zc value to get rid of the Zc dependency
tilXYZNorm = XYZtilZc./repmat(XYZtilZc(flagNum,:),3,1);

% Find Y values greater than or equal to zero. These are points on or above
% the horrizon and should be masked out
iHor = find(XYZHor(2,:) >= 0);
tilXYZNorm(:,iHor) = nan;

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
