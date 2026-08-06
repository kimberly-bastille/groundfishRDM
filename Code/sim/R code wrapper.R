################################################################################
# Script:       R code wrapper.R
# Purpose:      Orchestrates the R (simulation) half of the pipeline. Loads
#               packages, sets shared paths and run parameters, converts the
#               Stata-produced calibration inputs from CSV/DTA to FST for speed,
#               then runs the two-step calibration and exports the results to
#               Google Drive.
# Inputs:       Under gf.data.dir: miscellaneous/directed_trip_draws.csv,
#               calib_catch_draws/calib_catch_draws_<i>.dta (i = 1..n_simulations),
#               miscellaneous/Discard_Mortality.csv,
#               miscellaneous/next_year_calendar_adjustments.csv.
# Outputs:      Under gf.data.dir: miscellaneous/directed_trip_draws.fst,
#               calib_catch_draws/calib_catch_draws_<i>.fst (i = 1..n_simulations),
#               miscellaneous/Discard_Mortality.fst,
#               miscellaneous/calendar_adj.fst.
#               These are FST copies of the four inputs above, written by
#               Section C for speed. Note that the calendar adjustments file is
#               renamed on the way through, so its two names do not match.
#               Written by the sourced scripts rather than here:
#               calibration_comparison.fst (calibrate_rec_catch0.R),
#               calibrated_model_stats.fst (calibration_routine.R),
#               base_outcomes_<s>_<md>_<i>.fst and
#               n_choice_occasions_<s>_<md>_<i>.fst (calibrate_rec_catch1.R).
# Dependencies: Object `developer` set in the session; sources developer_setup.R,
#               calibrate_rec_catch0.R, calibration_routine.R,
#               export_to_GoogleDrive.R. The Stata pre-sim pipeline must have run
#               first to produce the inputs.
# Pipeline:     The R simulation wrapper. Invoked as the final toggle-gated step
#               of model_wrapper.do (run_calibration), or run standalone after
#               the Stata stage (see DATAFLOW_GROUNDFISH.md).
################################################################################


################################################################################
################################################################################
# Section A: Package loading and run configuration
################################################################################
################################################################################

options(scipen = 999)

packages <- c("tidyr",  "magrittr", "tidyverse", "reshape2", "splitstackshape","doBy","WriteXLS","Rcpp",
              "ggplot2","rlist","fitdistrplus","MASS","psych","rgl","copula","VineCopula","scales",
              "univariateML","logspline","readr","data.table","conflicted", "readxl", "writexl", "fs", "fst",
              "purrr", "readr", "here", "furrr", "profvis", "future", "magrittr", "feather", "RStata", "haven")

#Install only those not already installed
# installed <- packages %in% rownames(installed.packages())
# if (any(!installed)) {
#   install.packages(packages[!installed])
# }

lapply(packages, library, character.only = TRUE)

library(plyr)
library(dplyr)

conflicts_prefer(here::here)
conflicts_prefer(dplyr::filter)
conflicts_prefer(dplyr::select)
conflicts_prefer(dplyr::mutate)
conflicts_prefer(dplyr::rename)
conflicts_prefer(dplyr::summarize)
conflicts_prefer(dplyr::summarise)
conflicts_prefer(dplyr::count)


################################################################################
################################################################################
# Section B: Run parameters, data paths, and helper functions
################################################################################
################################################################################

#Set up R globals for input/output data and code scripts
code_cd=here("Code", "sim")
source(here("Code", "helpers", "developer_setup.R"))

#Data folders
  #input miscellaneous - contains:
      # raw and processed MRIP data
      # biological data (e.g., discard mortality rates, NEFSC trawl survey)
      # angler characteristics and preferences data,
      # scalars to adjust for differing # of weekend/weekday days per month btw calibration year and projection year
  #base_outcomes - stores simulated trip-level outcomes from the calibration
  #n_choice_occasions - stores # of choice occasions per day from calibration
  #calib_catch_draws - stores catch-per-trip datasets (currently the same for calibration and projection year)

final_process_data_cd=gf.data.dir
final_process_outcomes_cd=file.path(final_process_data_cd, "base_outcomes")
final_process_choice_occasions_cd=file.path(final_process_data_cd,"n_choice_occasions")
final_process_misc_cd=file.path(final_process_data_cd,"miscellaneous")
final_process_calib_catch_cd=file.path(final_process_data_cd,"calib_catch_draws")

# Number of model iterations. Should match Stata's $ndraws
# (model_wrapper.do); the two are not linked in code, so a
# prototyping run that changes $ndraws must change this too.
n_simulations<-101
n_draws<-50 # Number of simulated trips per day

#' @title Parse dates of unknown format to IDate
#' @description Tries several common date encodings in turn and returns a
#'   data.table IDate, so downstream date math is fast. Normalizes the mixed
#'   date formats arriving in the Stata-produced CSV/DTA inputs.
#' @param x Character (or coercible) vector of dates in one of the tried
#'   formats: %d%b%Y, %Y-%m-%d, %m/%d/%Y, %d/%m/%Y.
#' @return A data.table IDate vector.
#' @examples
#' \dontrun{
#' parse_date_any(c("01Nov2024", "2024-11-01"))
#' }
parse_date_any <- function(x) {
  data.table::as.IDate(as.Date(
    x,
    tryFormats = c("%d%b%Y", "%Y-%m-%d", "%m/%d/%Y", "%d/%m/%Y")
  ))
}

################################################################################
################################################################################
# Section C: Model calibration (convert inputs to FST, then calibration STEP 1 -> STEP 2)
################################################################################
################################################################################

# Simulation strata are the groups in which we allocate and simulate choice occasions.
# For the 2026 GF RDM, a stratum is the combination of mode (pr/fh) and season (winter/summer).

# Projection results are based on n_simulations iterations of the model. In each iteration we pull
# in new distributions of catch-per-trip, directed fishing effort, projected catch-at-length,
# and angler preferences.

# Transfer some files from .csv to .fst to reduce computing time
message("Converting calibration inputs from CSV/DTA to FST (this can take a while) ...")
dtrip0<-read.csv(file.path(final_process_misc_cd, paste0("directed_trip_draws.csv"))) %>%
  dplyr::mutate(date_parsed = parse_date_any(day),
                month=data.table::month(date_parsed)) %>%
  dplyr::select(-day, -day_y2)

write_fst(dtrip0, file.path(final_process_misc_cd, paste0("directed_trip_draws.fst")))

for(i in 1:n_simulations) {

    catch0<-read_dta(file.path(final_process_calib_catch_cd, paste0("calib_catch_draws_", i,".dta"))) %>%
      dplyr::mutate(date_parsed = parse_date_any(date),
                    month=data.table::month(date_parsed)) %>%
      dplyr::select(-date)

    write_fst(catch0, file.path(final_process_calib_catch_cd, paste0("calib_catch_draws_", i,".fst")))

  }

disc_mort<- readr::read_csv(file.path(final_process_misc_cd, "Discard_Mortality.csv"), show_col_types = FALSE)
write_fst(disc_mort, file.path(final_process_misc_cd, paste0("Discard_Mortality.fst")))

calendar_adj<- readr::read_csv(file.path(final_process_misc_cd, "next_year_calendar_adjustments.csv"), show_col_types = FALSE)
write_fst(calendar_adj, file.path(final_process_misc_cd, paste0("calendar_adj.fst")))
message("Finished converting inputs to FST.")


# STEP 1
# Run the simulation to determine and retain percent/absolute differences between
# model-based harvest and MRIP-based harvest numbers by species.

message("STEP 1: running calibrate_rec_catch0.R (simulation; this can take a while) ...")
source(file.path(code_cd,"calibrate_rec_catch0.R"))
message("STEP 1 complete.")

# Output files:
# calibration_comparison.fst

# STEP 2
# Re-run the simulation, but this time reallocate trip-level discards to harvest or harvest to discards,
# until the difference between model-based harvest and MRIP-based harvest is within abs(5%) or <500 fish.

# If a transfer of discards to harvest is needed, reallocate r* percent of all released
# fish that are between [(min. size - 3 inches), min.size] as harvest. If a transfer of
# harvest to discards is needed, reallocate h* percent of all harvested fish as discards.

# Retain calibrated baseline trip outcomes, n_choice_occasions, calibration statistics (e.g. r*, h*)

message("STEP 2: running calibration_routine.R (iterative reallocation; this can take a while) ...")
source(file.path(code_cd,"calibration_routine.R"))
message("STEP 2 complete.")

# Output files:
# calibrated_model_stats.fst
# file.path(final_process_choice_occasions_cd,paste0("n_choice_occasions_", s, "_", md, "_", i,".fst"))
# file.path(final_process_outcomes_cd, paste0("base_outcomes_", s, "_", md, "_", i, ".fst"))

################################################################################
################################################################################
# Section D: Export calibration outputs to Google Drive
################################################################################
################################################################################

message("Exporting calibration outputs to Google Drive ...")
source(file.path(code_cd, "export_to_GoogleDrive.R"))
message("Export complete.")












