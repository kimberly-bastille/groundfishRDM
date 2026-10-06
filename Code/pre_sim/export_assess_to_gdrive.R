################################################################################
################################################################################
# Script:       export_assess_to_gdrive.R
# Purpose:      Explorts historical and projected NAA files to google drive
# Inputs:       Historical and projected numbers at age:
# Outputs:      none.
# Dependencies: Google Drive access with cached credentials in .secrets.
# Pipeline:     Assessment-data prep, run once per management cycle. Upstream of
#               the Stata pipeline: its NAA outputs feed the catch-at-length
#               steps (see catch_at_length_projection.do).
#
################################################################################
################################################################################
#Load libraries
library(tidyverse)
library(haven)
library(glue)
library(googledrive)
library(here)

# Define arguments
args <- commandArgs(trailingOnly = TRUE)
if (length(args) != 1) {
  stop("Error: This script requires exactly one argument.", call. = FALSE)
}

#read in arguments. Ensure they are numeric
stocks  <- args[1]

# Show them, just in case.
cat("First Year:", first_yr, "\n")
cat("Last Year:", last_yr, "\n")



###########Begin Housekeeping##################################################
#Set paths, input names, and savefile names.

# Assessment folders

here::i_am("Code/pre_sim/export_assess_to_gdrive.R")
source(here("Code", "helpers", "developer_setup.R"))
assessment_output_folder<-here("input_data")
dir.create(file.path(assessment_output_folder), showWarnings = FALSE)
miscellaneous_folder<-file.path(gf.data.dir, "miscellaneous")

# data version
data_version<-Sys.Date()


# Read in helpers
source(here("Code","helpers","naa_helpers.R"))

#names of output save files
FullProjectionsSaveFile<-glue("WGOMCod_Projections_{data_version}.Rds")
CodProjectedNAASaveFile<-glue("WGOM_Cod_projected_NAA_{data_version}")
CodHistoricalNAASaveFile<-glue("WGOM_Cod_historical_NAA_{data_version}")

HaddockProjectedNAASaveFile<-glue("GOM_Haddock_projected_NAA_{data_version}")
HaddockHistoricalNAASaveFile<-glue("GOM_Haddock_historical_NAA_{data_version}")

# Connect to Google Drive
# NOTE: Relies on cached credentials in .secrets. Will prompt interactive auth if missing or expired.
drive_auth(cache = here(".secrets"), email = TRUE)
# Output folder on google drive
groundfish_processed_path<-file.path("socialsci","RecreationalDST","2027_management_cycle_data","groundfishRDM","input_data")
folder_info <- drive_get(
  path = groundfish_processed_path,
  shared_drive = "NMFS NEC READ SSB"
)
groundfish_processed_path<-folder_info$id

#################################put cod on gdrive ############################

if (stocks %in% c("cod","both")) {

#Put the historical NAA on google drive
drive_upload(
  media = file.path(assessment_output_folder,glue("{CodHistoricalNAASaveFile}.Rds")),
  path = as_id(groundfish_processed_path),
  name = glue("{CodHistoricalNAASaveFile}.Rds"),
  overwrite = TRUE
)

drive_upload(
  media = file.path(assessment_output_folder,glue("{CodHistoricalNAASaveFile}.dta")),
  path = as_id(groundfish_processed_path),
  name = glue("{CodHistoricalNAASaveFile}.dta"),
  overwrite = TRUE
)


#Put the historical NAA on google drive
drive_upload(
  media = file.path(assessment_output_folder,glue("{CodProjectedNAASaveFile}.Rds")),
  path = as_id(groundfish_processed_path),
  name = glue("{CodProjectedNAASaveFile}.Rds"),
  overwrite = TRUE
)

drive_upload(
  media = file.path(assessment_output_folder,glue("{CodProjectedNAASaveFile}.dta")),
  path = as_id(groundfish_processed_path),
  name = glue("{CodProjectedNAASaveFile}.dta"),
  overwrite = TRUE
)
}


#################################put haddock on gdrive ############################

if (stocks %in% c("haddock","both")) {

  #Put the historical NAA on google drive
  drive_upload(
    media = file.path(assessment_output_folder,glue("{HaddockHistoricalNAASaveFile}.Rds")),
    path = as_id(groundfish_processed_path),
    name = glue("{HaddockHistoricalNAASaveFile}.Rds"),
    overwrite = TRUE
  )

  drive_upload(
    media = file.path(assessment_output_folder,glue("{HaddockHistoricalNAASaveFile}.dta")),
    path = as_id(groundfish_processed_path),
    name = glue("{HaddockHistoricalNAASaveFile}.dta"),
    overwrite = TRUE
  )


  #Put the historical NAA on google drive
  drive_upload(
    media = file.path(assessment_output_folder,glue("{HaddockHistoricalNAASaveFile}.Rds")),
    path = as_id(groundfish_processed_path),
    name = glue("{HaddockHistoricalNAASaveFile}.Rds"),
    overwrite = TRUE
  )

  drive_upload(
    media = file.path(assessment_output_folder,glue("{HaddockHistoricalNAASaveFile}.dta")),
    path = as_id(groundfish_processed_path),
    name = glue("{HaddockHistoricalNAASaveFile}.dta"),
    overwrite = TRUE
  )
}

