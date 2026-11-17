################################################################################
################################################################################
# Script:       hash_check_calib_catch_draws.R
# Purpose:      check that local and google drive folders are identical by verifying that the
#               md5 hashes are identical
# Inputs:       local calib_catch_draws and access to remote calib catch draws
# Outputs:      none.
# Dependencies: Google Drive access with cached credentials in .secrets.
# Pipeline:     data quality. not in pipeline yet, but this goes after the google drive upload
#
################################################################################
################################################################################
#Load libraries
library(tidyverse)
library(googledrive)
library(here)
library(cli)


###########Begin Housekeeping##################################################
#Set paths, input names, and savefile names.

# Assessment folders

here::i_am("Code/helpers/hash_check_calib_catch_draws.R")
source(here("Code", "helpers", "developer_setup.R"))
assessment_output_folder<-here("input_data")
dir.create(file.path(assessment_output_folder), showWarnings = FALSE)
miscellaneous_folder<-file.path(gf.data.dir, "miscellaneous")

# data version
data_version<-Sys.Date()



################## hashes for local files #################################
local_dir <- file.path(gf.data.dir, "calib_catch_draws")

local_file_paths <- list.files(
  path = local_dir,
  pattern = "^calib_catch_draws_.*\\.fst$",
  full.names = TRUE
)

# Calculate MD5 hashes and align column structure with remote dribble frame
local_hashes <- tibble(
  name = basename(local_file_paths),
  local_md5 = unname(tools::md5sum(local_file_paths))
)



################## hashes for google drive files #################################

target_folder <- drive_get(
  path = file.path(
    "socialsci", "RecreationalDST", "2027_management_cycle_data",
    "groundfishRDM","calib_catch_draws"
  ),
  shared_drive = "NMFS NEC READ SSB"
)

remote_files <- drive_ls(
  path = target_folder,
  pattern = "^calib_catch_draws_.*\\.fst$"
)

remote_hashes <- remote_files %>%
  mutate(remote_md5 = map_chr(drive_resource, ~ .x$md5Checksum)) %>%
  select(name, remote_md5)


# join together#

hashes<-local_hashes %>%
  full_join(remote_hashes, by=join_by(name))

stopifnot(hashes$remote_md5==hashes$local_md5)
message("all calib_catch_draw files match")
