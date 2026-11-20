################################################################################
################################################################################
# Script:       export_assess_to_gdrive.R
# Purpose:      Exports historical and projected NAA files to google drive
# Inputs:       Historical and projected numbers at age
#   			glue("WGOMCod_Projections_{data_version}.Rds")
#				glue("WGOM_Cod_projected_NAA_{data_version}")
#				glue("WGOM_Cod_historical_NAA_{data_version}")
#				glue("GOM_Haddock_projected_NAA_{data_version}")
#				glue("GOM_Haddock_historical_NAA_{data_version}")
#				takes "cod", "haddock", "both" as args.
# Outputs:      Same files, but on the shared google drive. These files ARE versioned
# Dependencies: Google Drive access with cached credentials in .secrets.
# Pipeline:     Assessment-data prep, run once per management cycle. Upstream of
#               the Stata pipeline: its NAA outputs feed the catch-at-length
#               steps (see catch_at_length_projection.do).
# Notes:        Hard-coded path (2027_management_cycle_data) that will need to be updated at the
#				next management cycle.
################################################################################
################################################################################
#Load libraries
library(tidyverse)
library(haven)
library(glue)
library(here)

# Define arguments
args <- commandArgs(trailingOnly = TRUE)
if (length(args) != 3) {
  stop("Error: This script requires exactly three argument.", call. = FALSE)
}


#read in arguments. Ensure they are numeric
Fishery<-args[1]
management_cycle<-as.numeric(args[2])
stocks<- args[3]

if (!Fishery %in% c("groundfish","fluke")) {
  stop(glue("First argument is {Fishery}. It must take on value of \"groundfish\" or \"fluke\"."), call. = FALSE)
}


if (!stocks %in% c("cod","haddock","both")) {
  stop(glue("First argument is {stocks}. It must take on value of \"cod\", \"haddock\" or \"both\"."), call. = FALSE)
}

# Show them, just in case.
cat("Fishery:", Fishery, "\n")
cat("management cycle:", management_cycle, "\n")

cat("Stocks to export:", stocks, "\n")



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


#Assemble beginning of path
groundfish_processed_path<-file.path(shared_drive_root, "socialsci","RecreationalDST",
                                     glue("{management_cycle}_management_cycle_data"),
                                     glue("{Fishery}RDM"),
                                     "input_data"
                                     )

#################################put cod on gdrive depending on the value of stocks ############################

if (stocks %in% c("cod","both")) {

  file.copy(from=file.path(assessment_output_folder,glue("{CodHistoricalNAASaveFile}.Rds")),
            to=file.path(groundfish_processed_path, glue("{CodHistoricalNAASaveFile}.Rds"))
            )

  file.copy(from=file.path(assessment_output_folder,glue("{CodHistoricalNAASaveFile}.dta")),
            to=file.path(groundfish_processed_path, glue("{CodHistoricalNAASaveFile}.dta"))
  )
  file.copy(from=file.path(assessment_output_folder,glue("{CodProjectedNAASaveFile}.Rds")),
            to=file.path(groundfish_processed_path, glue("{CodProjectedNAASaveFile}.Rds"))
  )

  file.copy(from=file.path(assessment_output_folder,glue("{CodProjectedNAASaveFile}.dta")),
            to=file.path(groundfish_processed_path, glue("{CodProjectedNAASaveFile}.dta"))
  )
}


#################################put haddock on gdrive depending on the value of stocks ############################

if (stocks %in% c("haddock","both")) {
  #Put the historical NAA on google drive (dta and Rds)

  file.copy(from=file.path(assessment_output_folder,glue("{HaddockHistoricalNAASaveFile}.Rds")),
            to=file.path(groundfish_processed_path, glue("{HaddockHistoricalNAASaveFile}.Rds"))
  )

  file.copy(from=file.path(assessment_output_folder,glue("{HaddockHistoricalNAASaveFile}.dta")),
            to=file.path(groundfish_processed_path, glue("{HaddockHistoricalNAASaveFile}.dta"))
  )
  file.copy(from=file.path(assessment_output_folder,glue("{HaddockProjectedNAASaveFile}.Rds")),
            to=file.path(groundfish_processed_path, glue("{HaddockProjectedNAASaveFile}.Rds"))
  )

  file.copy(from=file.path(assessment_output_folder,glue("{HaddockProjectedNAASaveFile}.dta")),
            to=file.path(groundfish_processed_path, glue("{HaddockProjectedNAASaveFile}.dta"))
  )


}


cat("Export of ",stocks," assessment data complete \n")

