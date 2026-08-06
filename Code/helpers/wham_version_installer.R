################################################################################
# Script:       wham_version_installer.R  (helpers)
# Purpose:      Installs the exact WHAM package versions that were used to fit the
#               accepted cod and haddock assessment models, each into its own
#               library location, so projections can switch WHAM versions by
#               pointing at an explicit lib path instead of reinstalling WHAM
#               every time.
# Inputs:       Accepted assessment .rds models on Google Drive:
#               cod: mod_base_2023_noBLLS.rds
#               haddock: mod_nola_dcpe_blls2.rds.
# Outputs:      Two installed WHAM builds under
#               R_LIBS_USER/{cod_wham_install, haddock_wham_install}.
# Dependencies: Requires a cached Drive token (.secrets) and internet access to
#               install WHAM from GitHub.
# Pipeline:     Standalone helper; not called by any wrapper.
################################################################################

library(tidyverse)
library(TMB)
library(haven)
library(glue)
library(googledrive)
library(here)
here::i_am("Code/helpers/wham_version_installer.R")

drive_auth(cache = here(".secrets"), email = TRUE)

################################################################################
################################################################################
# Section A: Housekeeping — per-model WHAM library locations
################################################################################
################################################################################
#Set paths, input names, and savefile names.

cod_wham_lib <- file.path(Sys.getenv("R_LIBS_USER"), "cod_wham_install")
haddock_wham_lib <- file.path(Sys.getenv("R_LIBS_USER"), "haddock_wham_install")

dir.create(file.path(cod_wham_lib), showWarnings = FALSE)
dir.create(file.path(haddock_wham_lib), showWarnings = FALSE)


################################################################################
################################################################################
# Section B: Cod — read the accepted model and install its WHAM version
################################################################################
################################################################################

# Read in accepted cod model

# this is the google drive location of the cod model
assessment_file_in<-"mod_base_2023_noBLLS.rds"
readin<-file.path("socialsci","RecreationalDST","2027_management_cycle_data","groundfishRDM","cod_assessment",assessment_file_in)
file_id<-drive_get(path = readin, shared_drive = "NMFS NEC READ SSB")$id

temp_path <- tempfile(fileext = ".rds")

# Download
message("Downloading cod assessment model from Google Drive ...")
drive_download(
  file = as_id(file_id),
  path = temp_path,
  overwrite = TRUE
)

# Read in using  into your environment
mod_accepted <- read_rds(temp_path)

# Make sure the WHAM version used to generate the model is installed.

# The model stores its provenance string as "...@<commit>)"; pull out the commit
# hash (text after "@") and strip the trailing ")".
model_wham_commit<-strsplit(mod_accepted$wham_commit,split="@")[[1]][2]
model_wham_commit<-gsub(")", "", model_wham_commit)


message("Installing cod WHAM version ", model_wham_commit, " (GitHub build; this can take a while) ...")
remotes::install_github(glue("timjmiller/wham@{model_wham_commit}"), lib=cod_wham_lib, auth_token=NULL , upgrade="never")






################################################################################
################################################################################
# Section C: Haddock — read the accepted model and install its WHAM version
################################################################################
################################################################################

# read in the haddock assessment
assessment_file_in<-"mod_nola_dcpe_blls2.rds"
readin<-file.path("socialsci","RecreationalDST","2027_management_cycle_data","groundfishRDM","haddock_assessment",assessment_file_in)
file_id<-drive_get(path = readin, shared_drive = "NMFS NEC READ SSB")$id


# Create a path for a temporary file
temp_path <- tempfile(fileext = ".rds")

# Download
message("Downloading haddock assessment model from Google Drive ...")
drive_download(
  file = as_id(file_id),
  path = temp_path,
  overwrite = TRUE
)

# Read in using  into your environment
haddock_accepted <- read_rds(temp_path)
# cleanup
if (file.exists(temp_path)) {
  file.remove(temp_path)
}
# Make sure the WHAM version used to generate the model is installed.

# The model stores its provenance string as "...@<commit>)"; pull out the commit
# hash (text after "@") and strip the trailing ")".
model_wham_commit<-strsplit(haddock_accepted$wham_commit,split="@")[[1]][2]
model_wham_commit<-gsub(")", "", model_wham_commit)


message("Installing haddock WHAM version ", model_wham_commit, " (GitHub build; this can take a while) ...")
remotes::install_github(glue("timjmiller/wham@{model_wham_commit}"), lib=haddock_wham_lib, auth_token=NULL, upgrade="never")

