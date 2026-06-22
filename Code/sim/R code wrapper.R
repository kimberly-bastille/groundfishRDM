

# run this file after data processing in Stata

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


#Set up R globals for input/output data and code scripts
code_cd=here("Code", "sim")

#Data folders
  #input miscellaneous - contains:
      # raw and processed MRIP data
      # biological data (e.g., discard mortality rates, NEFSC trawl survey)
      # angler characteristics and preferences data,
      # scalars to adjust for differing # of weekend/weekday days per month btw calibration year and projection year
  #base_outcomes - stores simulated trip-level outcomes from the calibration
  #n_choice_occasions - stores # of choice occasions per day from calibration
  #calib_catch_draws - stores catch-per-trip datasets (currently the same for calibration and projection year)

final_process_data_cd="E:/Lou_projects/groundfishRDM/2027_mgt_cycle"
final_process_outcomes_cd=file.path(final_process_data_cd, "base_outcomes")
final_process_choice_occasions_cd=file.path(final_process_data_cd,"n_choice_occasions")
final_process_misc_cd=file.path(final_process_data_cd,"miscellaneous")
final_process_calib_catch_cd=file.path(final_process_data_cd,"calib_catch_draws")

n_simulations<-50 # Number of model iterations
n_draws<-50 # Number of simulated trips per day

# helpers
parse_date_any <- function(x) {
  data.table::as.IDate(as.Date(
    x,
    tryFormats = c("%d%b%Y", "%Y-%m-%d", "%m/%d/%Y", "%d/%m/%Y")
  ))
}

### MODEL CALIBRATION ###
# Simulation stratum are the groups in which we allocate and simulate choice occasions.
# For the 2026 GF RDM, the stratum is the combination of mode (pr/fh) and season (winter/summer)

# Projection results are based on X iterations of the model. In each iteration we pull
# in new distributions of catch-per-trip, directed fishing effort, projected catch-at-length,
# and angler preferences.

# Transfer some files from .csv to .fst to reduce computing time
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


# STEP 1
# Run the simulation to determine and retain percent/absolute differences between
# model-based harvest and MRIP-based harvest harvest numbers by species.

source(file.path(code_cd,"calibrate_rec_catch0.R"))

# Output files:
# calibration_comparison.fst

# STEP 2
# Re-run the simulation, but this time reallocate trip-level discards to harvest or harvest to discards,
# until the difference between model-based harvest and MRIP-based harvest is within abs(5%) or <500 fish.

# If a transfer of discards to harvest is needed, reallocate r* percent of all released
# fish that are between [(min. size - 3 inches), min.size] as harvest. If a transfer of
# harvest to discards is needed, reallocate h* percent of all harvested fish as discards.

# Retain calibrated baseline trip outcomes, n_choice_occasions, calibration statistics (e.g. r*, h*)

source(file.path(code_cd,"calibration_routine.R"))

# Output files:
# calibrated_model_stats.fst
# file.path(final_process_choice_occasions_cd,paste0("n_choice_occasions_", s, "_", md, "_", i,".fst"))
# file.path(final_process_outcomes_cd, paste0("base_outcomes_", s, "_", md, "_", i, ".fst"))

### END MODEL CALIBRATION ###

# Export files to Google Drive
source(file.path(code_cd, "export_to_GoogleDrive.R"))




### MODEL PROJECTION ###
# Run the simulation using baseline trip outcomes (to compute welfare and demand response),
# n_choice_occasions, calibration statistics,  population-adjusted catch-at-length distributions,
# projection year calendar adjustments

source(file.path(code_cd, "predict_rec_catch.R"))











