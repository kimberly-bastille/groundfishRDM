################################################################################
# Script:       googledrivesetup.R  (helpers)
# Purpose:      One-time setup of a cached googledrive OAuth token in the
#               project .secrets folder, so later scripts can authenticate to
#               the shared drive non-interactively. Also documents the one-line
#               re-auth call those scripts use.
# Inputs:       Your Google account email (edit the drive_auth() call below).
# Outputs:      Cached OAuth token files under .secrets/.
# Dependencies: Run once from RStudio.
# Pipeline:     Not called by any wrapper; manual per-developer setup. The
#               scripts that push/pull Drive data (rdb_*_to_drive.R,
#               get_assessment_*, find_files_on_googledrive.R) rely on the token
#               this file caches.
################################################################################

#########################################################################
####################RUN this once to setup your token####################
#########################################################################
# Open the project in Rstudio
#
library(here)
library(googledrive)
options(gargle_oauth_cache = here(".secrets"))

# # Put your email in, then run to authorize your token.
drive_auth(email = "your email here")
#
#
# Verify tokens were cached
list.files(here(".secrets"))

#########################################################################
####################END of token setup ##################################
#########################################################################


# In any code that you have that needs access to google drive, run the following:
library(here)
library(googledrive)
drive_auth(cache = here(".secrets"), email = TRUE)






