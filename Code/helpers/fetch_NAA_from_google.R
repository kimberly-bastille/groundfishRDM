################################################################################
# Script:       fetch_NAA_from_google.R  (helpers)
# Purpose:      Downloads the historical and projected  numbers-at-age (NAA)
#               files for WGOM cod and GOM haddock
#               from the shared Google Drive into the repo's local input_data
#               folder.
# Inputs:       {WGOM_Cod,GOM_Haddock}_{historical,projected}_NAA_*_<data_version>.Rds
#               on the shared drive's input_data folder.
# Outputs:      The same files written to input_data/ inside the repo.
# Dependencies: Requires a cached Drive token in .secrets (see
#               googledrivesetup.R).
# Pipeline:     Standalone helper, run occasionally; not called by any wrapper.
# Note:         data_version is a hardcoded vintage string
#               set below — update it when a new assessment vintage is
#               published.
################################################################################

library(tidyverse)
library(glue)
library(googledrive)
library(here)

here::i_am("Code/helpers/fetch_NAA_from_google.R")

data_version<-"2026-05-06"
# Connect to Google Drive
drive_auth(cache = here(".secrets"), email = TRUE)

################################################################################
################################################################################
# Section A: Download WGOM cod NAA files
################################################################################
################################################################################
message("Downloading WGOM cod NAA files from Google Drive ...")
ProjectedNAASaveFile<-glue("WGOM_Cod_projected_NAA_from_2024Assessment_{data_version}")
HistoricalNAASaveFile<-glue("WGOM_Cod_historical_NAA_from_2024Assessment_{data_version}")

# Get the historical NAA file
readin<-file.path("socialsci","RecreationalDST","2027_management_cycle_data","groundfishRDM","input_data",glue("{HistoricalNAASaveFile}.Rds"))
file_id<-drive_get(path = readin, shared_drive = "NMFS NEC READ SSB")$id

# change the path to save this to a different place.
#path = here("input_data2",glue("{HistoricalNAASaveFile}.Rds")) saves it to the folder input_data2 inside the repository

# Download
drive_download(
  file = as_id(file_id),
  path = here("input_data",glue("{HistoricalNAASaveFile}.Rds")),
  overwrite = TRUE
)


# Get the projected NAA file
readin<-file.path("socialsci","RecreationalDST","2027_management_cycle_data","groundfishRDM","input_data",glue("{ProjectedNAASaveFile}.Rds"))
file_id<-drive_get(path = readin, shared_drive = "NMFS NEC READ SSB")$id

# Download
drive_download(
  file = as_id(file_id),
  path = here("input_data",glue("{ProjectedNAASaveFile}.Rds")),
  overwrite = TRUE
)


################################################################################
################################################################################
# Section B: Download GOM haddock NAA files
################################################################################
################################################################################
message("Downloading GOM haddock NAA files from Google Drive ...")
ProjectedNAASaveFile<-glue("GOM_Haddock_projected_NAA_2024Assessment_{data_version}")
HistoricalNAASaveFile<-glue("GOM_Haddock_historical_NAA_2024Assessment_{data_version}")

# Get the historical NAA file
readin<-file.path("socialsci","RecreationalDST","2027_management_cycle_data","groundfishRDM","input_data",glue("{HistoricalNAASaveFile}.Rds"))
file_id<-drive_get(path = readin, shared_drive = "NMFS NEC READ SSB")$id

# Download
drive_download(
  file = as_id(file_id),
  path = here("input_data",glue("{HistoricalNAASaveFile}.Rds")),
  overwrite = TRUE
)





# Get the projected NAA file
readin<-file.path("socialsci","RecreationalDST","2027_management_cycle_data","groundfishRDM","input_data",glue("{ProjectedNAASaveFile}.Rds"))
file_id<-drive_get(path = readin, shared_drive = "NMFS NEC READ SSB")$id

# Download
drive_download(
  file = as_id(file_id),
  path = here("input_data",glue("{ProjectedNAASaveFile}.Rds")),
  overwrite = TRUE
)

