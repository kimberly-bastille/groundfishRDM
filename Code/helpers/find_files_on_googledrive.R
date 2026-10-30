################################################################################
# Script:       find_files_on_googledrive.R  (helpers)
# Purpose:      Reference / worked-example script showing how to resolve shared
#               Google Drive folders and files (input_data, and the cod &
#               haddock assessment files) from a human path to a Drive file id,
#               which other scripts then use to download.
# Inputs:       None (the paths and filenames are literals to copy/adapt).
# Outputs:      None persisted; assigns folder/file ids to local objects for
#               interactive use.
# Dependencies: Requires a cached Drive token in .secrets (see
#               googledrivesetup.R).
# Pipeline:     Standalone helper / how-to; not called by any wrapper. Run
#               occasionally when you need a file's Drive id.
# Note:         data_version is a hardcoded vintage string
################################################################################

library(tidyverse)
library(glue)
library(googledrive)
library(here)

here::i_am("Code/helpers/find_files_on_googledrive.R")

data_version<-"2026-05-06"
# Connect to Google Drive
drive_auth(cache = here(".secrets"), email = TRUE)
####################################################################################
####################################################################################
#How to find the input_data folder
####################################################################################
####################################################################################
input_data_path<-file.path("socialsci","RecreationalDST","2027_management_cycle_data","groundfishRDM","input_data")
folder_info <- drive_get(
  path = input_data_path,
  shared_drive = "NMFS NEC READ SSB"
)
input_data_path<-folder_info$id

####################################################################################
#How to find the haddock_assessment folder
####################################################################################

groundfish_processed_path<-file.path("socialsci","RecreationalDST","2027_management_cycle_data","groundfishRDM","haddock_assessment")
 folder_info <- drive_get(
   path = groundfish_processed_path,
   shared_drive = "NMFS NEC READ SSB"
 )
 groundfish_processed_path<-folder_info$id
####################################################################################
#how to find the haddock stock assessment files
####################################################################################

 assessment_file_in<-"mod_nola_dcpe_blls2.rds"
waa_file_in<-"waa_pred_2024-08-25.xlsx"

readin<-file.path("socialsci","RecreationalDST","2027_management_cycle_data","groundfishRDM","haddock_assessment",assessment_file_in)
file_id<-drive_get(path = readin, shared_drive = "NMFS NEC READ SSB")$id

readin<-file.path("socialsci","RecreationalDST","2027_management_cycle_data","groundfishRDM","haddock_assessment",waa_file_in)
file_id<-drive_get(path = readin, shared_drive = "NMFS NEC READ SSB")$id




####################################################################################
#how to find the cod stock assessment files
####################################################################################


# input save files
assessment_file_in<-"mod_base_2023_noBLLS.rds"
ASAP_file_in<-"WGOM_COD_ASAP_2023_SEL3_2023.DAT"
readin<-file.path("socialsci","RecreationalDST","2027_management_cycle_data","groundfishRDM","cod_assessment",assessment_file_in)
file_id<-drive_get(path = readin, shared_drive = "NMFS NEC READ SSB")$id

readin<-file.path("socialsci","RecreationalDST","2027_management_cycle_data","groundfishRDM","cod_assessment",ASAP_file_in)
file_id<-drive_get(path = readin, shared_drive = "NMFS NEC READ SSB")$id

