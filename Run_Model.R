################################################################################
# Script:       Run_Model.R
# Purpose:      Command-line entry point for the Shiny-facing projection run.
#               Reads a policy name from the command line and hands off to
#               RecDST/model_run.R, which executes the cod/haddock catch
#               projection for that named regulation scenario.
# Inputs:       Command-line argument Run_Name (used downstream by model_run.R
#               to locate saved_regs/regs_<Run_Name>.csv).
# Outputs:      None written here directly; all output is produced by the
#               sourced RecDST/model_run.R.
# Dependencies: Sources RecDST/model_run.R.
# Pipeline:     Head of the separate, code-unlinked projection path
#               (Path A in DATAFLOW_GROUNDFISH.md). Invoked as
#               `Rscript Run_Model.R Run_Name`. Not called by either wrapper
#               or by app.R; the link to the rest of the pipeline is by shared
#               output files on disk, not a code call.
################################################################################

library(magrittr)
library(data.table)


args <- commandArgs(trailingOnly = TRUE)

source(here::here("RecDST/model_run.R"))


