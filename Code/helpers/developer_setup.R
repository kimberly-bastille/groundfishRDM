################################################################################
# Script:       developer_setup.R  (helpers)
# Purpose:      Sets the R object gf.data.dir to the correct data root for the
#               current developer. TP/ML/KB use a repo-relative Data folder;
#               LCH points at an external E: drive because that developer stores
#               the (large) processed data outside the repo.
# Inputs:       Object `developer` (one of "TP","LCH","ML","KB"), which must
#               already be set in the calling R session/environment.
# Outputs:      Object gf.data.dir in the calling environment. For TP/ML/KB,
#               also creates Data/2027_mgt_cycle if it does not exist.
# Dependencies: `developer` set upstream.   `developer` is set
#               in .Rprofile .
# Pipeline:     Sourced near the top of the R side of the pipeline
#               (R code wrapper.R), and independently by scripts run one-off via
#               Stata's `rscript using` (e.g. rdb_*_to_drive.R). R twin of
#               developer_setup_stata.do.
################################################################################

stopifnot(developer %in% c("TP", "LCH", "ML", "KB"))
if (developer=="LCH"){
  gf.data.dir<-"E:/Lou_projects/groundfishRDM/2027_mgt_cycle"
} else if (developer %in% c("TP","ML", "KB")){
  dir.create(here("Data","2027_mgt_cycle"), showWarnings = FALSE, recursive=TRUE)
  gf.data.dir<-here("Data","2027_mgt_cycle")
}

message("Hello ", developer, "  Use the object gf.data.dir in place of here(Data, YYYY_mgt_cycle).")

message("The value of gf.data.dir is: ", gf.data.dir)
