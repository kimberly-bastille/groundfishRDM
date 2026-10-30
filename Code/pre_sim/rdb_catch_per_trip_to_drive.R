################################################################################
# Script:       rdb_catch_per_trip_to_drive.R
# Purpose:      Reads the dashboard-formatted catch-per-trip .dta, saves it as an
#               .Rds stamped with its data_version, and uploads that .Rds to the
#               shared Google Drive miscellaneous folder for the rec dashboard.
# Inputs:       <gf.data.dir>/miscellaneous/rdb_sim_catch_per_trip.dta (written by rdb_processing_catch_per_trip.do)
# Outputs:      <gf.data.dir>/miscellaneous/rdb_catch_per_trip_<date>.Rds,
#               and a copy of that file uploaded to Google Drive.
# Dependencies: Sources developer_setup.R (for gf.data.dir). Requires a cached
#               Drive token in .secrets (see googledrivesetup.R).
# Pipeline:     Step in model_wrapper.do gated by `Rpush_cpt_to_gdrive'
#               (default ON), run via `rscript using`. Near-identical twin of
#               rdb_catch_at_len_to_drive.R (differs only in the input file and
#               object names).
################################################################################

#Load libraries
library(tidyverse)
library(haven)
library(glue)
library(googledrive)
library(here)

here::i_am("Code/pre_sim/rdb_catch_per_trip_to_drive.R")
source(here("Code", "helpers", "developer_setup.R"))

output_folder<-file.path(gf.data.dir, "miscellaneous")
vintage_string<-list.files(output_folder, pattern=glob2rx("mrip_pull*Rds"))
vintage_string<-gsub("mrip_pull","",vintage_string)
vintage_string<-gsub(".Rds","",vintage_string)
data_vintage<-max(vintage_string)

input_file <- file.path(gf.data.dir,"miscellaneous","rdb_sim_catch_per_trip.dta")

# Read in my .dta file
rdb_catch_per_trip <- read_dta(input_file)
rdb_catch_per_trip$data_version <- data_vintage

# Save the data version
file_date <- rdb_catch_per_trip$data_version[1]
SimCPTSaveFile<-glue("rdb_catch_per_trip_{file_date}")

# convert character date to a date variable
rdb_catch_per_trip$data_version<-as.Date(rdb_catch_per_trip$data_version)

# Save dataframe as Rds
write_rds(rdb_catch_per_trip, file=file.path(output_folder,glue("{SimCPTSaveFile}.Rds")))


# Connect to Google Drive
# NOTE: Relies on cached credentials in .secrets. Will prompt interactive auth if missing or expired.
message("Uploading catch-per-trip Rds to Google Drive ...")
drive_auth(cache = here(".secrets"), email = TRUE)

# Output folder on google drive
miscellaneous_path <-file.path("socialsci","RecreationalDST","2027_management_cycle_data",
                               "groundfishRDM","miscellaneous")

folder_info <- drive_get(
  path = miscellaneous_path,
  shared_drive = "NMFS NEC READ SSB"
)
miscellaneous_path<-folder_info$id


#Put the catch per trip Rds on google drive
drive_upload(
  media = file.path(output_folder,glue("{SimCPTSaveFile}.Rds")),
  path = as_id(miscellaneous_path),
  name = glue("{SimCPTSaveFile}.Rds"),
  overwrite = TRUE
)
message("Catch-per-trip upload complete.")


