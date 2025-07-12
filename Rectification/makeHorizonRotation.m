function R = makeHorizonRotation(pitch, roll, azimuth)

% R = makeHorizonRotation(pitch, roll, azimuth)
% ==============================================
% Current Version = Version 1, 02/15/2018
% 
% This function makes a rotation matrix that rotates a camera in a camera 
% centric coordiante system ([0,0,0] is the lens center, y is positive up, 
% x is positive to the left, and z is positive out of the camera.  This is
% made by applying the inverse of the camera matrix, K, to the image 
% pixels.) by the camera extrinsic values pitch, roll, and azimuth.  This
% is done to find pixels above the horizon in an image.  If after rotation
% a pixel location has a positive y value, then it is above the horizon.
% 
% The Rotation matrix is adapted from the rotation matrix used in the
% g_rect toolbox.  The bigest change is the defenition of the pitch angle.
% g_rect uses 0 degrees as level and 90 degrees as nadir. I use the
% standard notaion wich is 0 degrees as nadir and 90 degrees as level.
% 
% Inputs:
%     pitch = camera angle in degrees from nadir. (rotation about cameras y
%             axis)
%     roll = Rotation about the camera's z axis in degrees
%     azimuth = Rotation about the cameras y axis in degrees from north.
% 
% Outputs:
%     R = camera's rotation matrix to rotate the camera inside a camera
%         centric coordinate system. Used to find the level horizon.
% 
% Version History:
%     1) 02/15/2018: Original
% 
% ==============================================

pitch = 90 - pitch;

R_roll =  [ cosd( roll )  -sind( roll )  0;
            sind( roll )   cosd( roll )  0;
	        0              0             1];

R_pitch = [ 1   0               0;
	       0   cosd( pitch )  -sind( pitch );
	       0   sind( pitch )   cosd( pitch )];

R_azimuth = [  cosd( azimuth )  0   sind( azimuth );
	         0                1   0;
	        -sind( azimuth )  0   cosd( azimuth )];
          

% R_roll =  [ cosd( roll )  -sind( roll )  0;
%             sind( roll )   cosd( roll )  0;
% 	        0              0             1];
% 
% R_pitch = [ 1   0               0;
% 	        0   sind( pitch )  -cosd( pitch );
% 	        0   cosd( pitch )   sind( pitch )];
% 
% R_azimuth = [  cosd( azimuth )  0   sind( azimuth );
% 	           0                1   0;
% 	          -sind( azimuth )  0   cosd( azimuth )];
        
% apply the roll first and then the pitch
R = R_azimuth*R_pitch*R_roll;


% The original g_rect rotation matrix is .....
% Camera Roll
% R_phi =  [ cosd(-(-beta0(5))), -sind(-(-beta0(5))), 0;
%            sind(-(-beta0(5))),  cosd(-(-beta0(5))), 0;
% 	               0,            0, 1]
% 
% Camera Pitch
% R_lambda = [ 1,          0,        0;
% 	         0, cosd( -(beta0(4)) ), -sind( -(beta0(4)) );
% 	         0, sind( -(beta0(4)) ),  cosd( -(beta0(4)) )]
% 
% Camera Azimuth
% R_theta = [ cosd(-beta0(6)), 0, -sind(-beta0(6));
% 	                   0, 1,           0;
% 	        sind(-beta0(6)), 0,  cosd(-beta0(6))]      
               