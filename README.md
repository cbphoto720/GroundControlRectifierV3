# GroundControlRectifierV3
This software was written to streamline the addition of new camera systems to the CPG Camera station Database for georectification.

# Required Data
- GPS location of the Camera
- GPS ground control file (with set descriptions: Code = "set1"..."set2"...etc)
- Camera intrinsics (Checkerboard pattern with Matlab CameraCalibrator)
- Ground control images that include the targets
- a blank entry in the CPG camera database (covered in the Tutorial section)

# Outputs
- Camera Beta parameters that can be used to rectify any subsequent images!  (add these to the database)
- GCPs with ImageU and ImageV coordinates (add these to the database)

# Tutorial
### Before Deploying the Camera
1. Collect checkerboard calibration images.  Ideally with lots of light and a clean background
2. Run the Matlab Camera Calibrator App to generate camera intrinsics.  (I won't go into details about best practices)
3. Make sure that 3 coefficients is selected, do not use Skew, and turn on Tangential Distortion.
4. Export Camera Parameters to the workspace (please give it a descriptive name with the CamSN)
5. Save the matlab variable as a .mat file

### Generate the Rectification Parameters
1. Pull any CPG_CamDatabase changes from main and then please make a new branch and name it your SiteID.
2. Create a blank entry in the Camera Database.  Copy the "SiteID: Test" entry with at least one of the survey dates D20250101T000000Z all the way down to CamPose.  From there, modify the SiteID, CamID, CamSN, Filename with any information you already have.  Intrinsics and CamPose will be filled automatically by the program later. <br>
&emsp; -> Potential Variables: SiteID, CamID, CamSN, IMG-Filename,<br>&emsp;&emsp;&nbsp; Northings, Eastings, UTM zone, ImageSize_U, ImageSize_V <br>
&emsp; **%WIP write a function to add a blank camera entry**
3. Locate your GPS survey files for GCPs and camera position.  Fix any errors in the GCP description (add descriptions if blank, fix mislabeled sets).  Denote that you have fixed any issues by adding -SETCORRECTED to the filename.  (example: *20260114_DohenyGCP-SETCORRECTED.txt*)
4. Assemble all potential calibration images into 1 folder (subfolders are fine).  The code compares the GPS capture time to the image capture time to sync the sets.
5. Run GCRV3.


# Improvements
### WIP
- fix PickCamFromDatabase to either delete Filename or display a new column for Filename
- this is to make it easier for img search to work through subfolders
- ensure cam search uses epoch time (most simple way to sync img)
- user must simply delete a bad GCP that was covered by someone in the frame

### Targets
- need a ReadMe on setting up a brand new station from scratch
- Issue a warning that the camera needs to be added to the database before continuing (add it now ... cancel ... continue)
- Survey input GUI needs rework. <br>
&emsp;-> Output folder only (no output folder path)
- Camera DB needs a fcn to add a brand new camera and survey based on the Survey input GUI
- Usable IMGs needs to check all subfolders and needs to ensure the CamSN is in the filename
- addnewCamera_CPG_CamDatabase needs to be updated for new yaml format
- adding a new feature search to the Cam database is extremely annoying
<br>&emsp; -> Needed to add Var name and expected type to searchtable (ok)
<br>&emsp; -> Had to aded yamlData{i}.Cameras{j}.Filename to final searchtable output
<br>&emsp; -> diffFlags is based on numeric position rather than struct field, so I had to reorder things
<br>&emsp; -> Diff and Mask checking is effective control but should be impletmeneted as a funcion rather than copy pasting a bunch of times as in this instance
<br>&emsp; -> in GCRV3 PickCamFromDatabase expects fields of of a certain size to display