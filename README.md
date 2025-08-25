# GroundControlRectifierV3
This software was written to streamline the addition of new camera systems to the CPG Camera station Database for georectification.

# Required Data
- GPS location of the Camera
- GPS ground control file (with GCP set descriptions: Code = "set1"..."set2"...etc
- Camera intrinsics
- Ground control images (1 frame per GCP set.  Meaning 1 image can contain multiple ground control points if they are given a description as "set1"..."set2"...etc)
- a (mostly) blank entry in the CPG camera database

# Outputs
- Camera Beta parameters that can be used to rectify any subsequent images!  (add these to the database)
- GCPs with ImageU and ImageV coordinates (add these to the database)
