################################################################################
# Script:       rdb_catch_per_trip_to_drive.R
# Purpose:      Reads the dashboard-formatted catch-per-trip .dta, saves it as an
#               .Rds stamped with its data_version, and uploads that .Rds to the
#               shared Google Drive input_data folder for the rec dashboard.
# Inputs:       <gf.data.dir>/miscellaneous/rdb_sim_catch_per_trip.dta (written by rdb_processing_catch_per_trip.do)
# Outputs:      <gf.data.dir>/miscellaneous/rdb_catch_per_trip_<date>.Rds,
#               and a copy of that file uploaded to Google Drive.
# Dependencies: Requires shared_drive_root and gf.data.dir to be defined in developer_setup.R.
# Pipeline:     Step in model_wrapper.do gated by `rdb_catch_per_trip_to_drive'
#               (default ON), run via `rscript using`.
################################################################################

#Load libraries
library(tidyverse)
library(haven)
library(glue)
library(here)

# Define arguments
args <- commandArgs(trailingOnly = TRUE)
if (length(args) != 2) {
  stop("Error: This script requires exactly two argument.", call. = FALSE)
}


#read in arguments. Ensure they are numeric
Fishery<-args[1]
management_cycle<-as.numeric(args[2])


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


# Output folder on google drive
miscellaneous_path<-file.path("socialsci","RecreationalDST",
                              glue("{management_cycle}_management_cycle_data"),
                              glue("{Fishery}RDM"),
                              "miscellaneous"
)

#updated output folder on google drive
groundfish_processed_path<-file.path("socialsci","RecreationalDST",
                                     glue("{management_cycle}_management_cycle_data"),
                                     glue("{Fishery}RDM"),
                                     "input_data"
)

file.copy(from=file.path(output_folder,glue("{SimCPTSaveFile}.Rds")),
          to=file.path(groundfish_processed_path, glue("{SimCPTSaveFile}.Rds"))
)

message("Catch-per-trip upload complete.")


