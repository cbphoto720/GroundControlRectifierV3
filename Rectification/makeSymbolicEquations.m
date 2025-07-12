% =========================================================================
% This is the start of some code to do error analysis of rectified images.
% The goal is to input some error in the camera intrinsic and extrinsic
% parameters and see how the position and, hopefully, PIV velocity varies.
% =========================================================================

% Define variables
syms azimuth pitch roll Cx Cy Cz X Y Z fx fy Px Py s

% define the rotation coefficinets
R11 = sym( cos(azimuth) * cos(roll) + sin(azimuth) * cos(pitch) * sin(roll) );
R12 = sym( -cos(roll) * sin(azimuth) + sin(roll) * cos(pitch) * cos(azimuth) );
R13 = sym( sin(roll) * sin(pitch) );
R21 = sym( -sin(roll) * cos(azimuth) + cos(roll) * cos(pitch) * sin(azimuth) );
R22 = sym( sin(roll) * sin(azimuth) + cos(roll) * cos(pitch) * cos(azimuth) );
R23 = sym( cos(roll) * sin(pitch) );
R31 = sym( sin(pitch) * sin(azimuth) );
R32 = sym( sin(pitch) * cos(azimuth) );
R33 = sym( -cos(pitch) );

% define camera to image coordinate coeffs
Au = fx*R11 + s*R21 + Px*R31;
Bu = fx*R12 + s*R22 + Px*R32;
Cu = fx*R13 + s*R23 + Px*R33;

Av = Px*R31 - fy*R21;
Bv = Px*R32 - fy*R22;
Cv = Px*R33 - fy*R23;

% define Zc (Z in camera coordinates, which is normal to the lens and out of the camera)
Zc = R31*X + R32*Y + R33*Z - ( R31*Cx + R32*Cy + R33*Cz );

% Find U and V from X Y Z
U = ( Au*X + Bu*Y + Cu*Z - (Au*Cx + Bu*Cy + Cu*Cz) )/Zc;
V = ( Av*X + Bv*Y + Cv*Z - (Av*Cx + Bv*Cy + Cv*Cz) )/Zc;