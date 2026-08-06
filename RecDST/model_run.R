################################################################################
################################################################################
# Script:       RecDST/model_run.R
# Purpose:      Standalone driver that runs the recreational cod/haddock catch
#               projection for one named policy scenario. Loads the scenario's
#               regulation settings from a saved CSV (saved_regs folder), rewrites
#               each directed-trip day's bag and minimum-size limits by season/mode, runs the
#               projection (optionally in parallel), writes the raw output.
# Inputs:       Data/miscellaneous/directed_trip_draws.fst (directed trips),
#               saved_regs/regs_<policy_name>.csv (scenario regulation inputs),
#               Data/miscellaneous/calibrated_model_stats.fst (baseline stats),
#               Code/sim/predict_rec_catch_functions.R (sourced functions).
# Outputs:      directed_trips_before.csv, directed_trips_after.csv,
#               output/output_<policy_name>_<timestamp>.csv.
# Dependencies: predict_rec_catch_functions.R supplies run_cod_hadd_projection(),
#               in_season() and safe_divide().
# Pipeline:     RecDST = Recreational Decision Support Tool. This is the
#               script-mode counterpart to app.R's server logic: it exercises the
#               same projection engine outside the Shiny app for one hard-coded
#               scenario (see policy_name below).
################################################################################
################################################################################


library(data.table)
library(fst)
library(readr)
library(dplyr)
library(lubridate)
library(stringr)
library(tidyr)
library(here)
library(furrr)
library(future)
library(conflicted)
conflicts_prefer(data.table::month)

final_process_data_cd=here::here("Data")
final_process_outcomes_cd=here::here("Data/base_outcomes")
final_process_choice_occasions_cd=here::here("Data/n_choice_occassions")
final_process_misc_cd=here::here("Data/miscellaneous")
final_process_calib_catch_cd=here::here("Data/calib_catch_draws")

################################################################################
################################################################################
# Section A: User-facing controls and inputs
################################################################################
################################################################################

draws         <- 1:5
n_simulations <- 5
mode_draw     <- c("pr", "fh")
season_draw   <- c("summer", "winter")
draws         <- if (exists("draws")) draws else seq_len(n_simulations)
n_draws       <- 50L

policy_name <- args[1]
#policy_name <- "SQactual"


source(here::here("Code/sim/predict_rec_catch_functions.R"))
# Length-weight parameters from the calibration script.
cod_lw_a <- if (exists("cod_lw_a")) cod_lw_a else 0.000005132
cod_lw_b <- if (exists("cod_lw_b")) cod_lw_b else 3.1625
had_lw_a <- if (exists("had_lw_a")) had_lw_a else 0.000009298
had_lw_b <- if (exists("had_lw_b")) had_lw_b else 3.0205



################################################################################
################################################################################
# Section B: Load the scenario's regulations and apply them to directed trips
################################################################################
################################################################################

saved_regs <- read.csv(here::here(paste0("saved_regs/regs_", policy_name, ".csv")))

# Push each row of saved_regs into the environment as a named variable
# (input name -> value), so the case_when() blocks below can reference the
# season open/close dates and limits (e.g. codFH_seas3_op) by bare name.
list2env(setNames(as.list(saved_regs$value), saved_regs$input), envir = environment())

directed_trips <- as.data.table(read_fst(file.path(final_process_misc_cd,"directed_trip_draws.fst")))

directed_trips<- directed_trips %>%
  dplyr::select(mode, date_parsed, dtrip,
                cod_bag, cod_min, hadd_bag, hadd_min, draw) %>%
  dplyr::mutate(date_adj = date_parsed)

# Overwrite each day's bag/size limits with the scenario's rules. Within each
# case_when the seasons are tested 3 -> 2 -> 1 so that, if seasons overlap, the
# later-numbered season wins (first matching condition applies). The final
# TRUE ~ 0 (bag) / 100 (min size) are the closed-fishery defaults: bag 0 and a
# 100 cm minimum no fish reaches, matching set_regulations.do. Size limits are
# stored in inches and converted to cm (* 2.54).
directed_trips <- directed_trips %>%
  dplyr::mutate(
    cod_bag = dplyr::case_when(
      #mode == "fh" & in_season(date_adj, codFH_seas3_op, codFH_seas3_cl) ~ as.numeric(codFH_3_bag),
      #mode == "pr" & in_season(date_adj, codPR_seas3_op, codPR_seas3_cl) ~ as.numeric(codPR_3_bag),
      mode == "fh" & in_season(date_adj, codFH_seas2_op, codFH_seas2_cl) ~ as.numeric(codFH_2_bag),
      mode == "pr" & in_season(date_adj, codPR_seas2_op, codPR_seas2_cl) ~ as.numeric(codPR_2_bag),
      mode == "fh" & in_season(date_adj, codFH_seas1_op, codFH_seas1_cl) ~ as.numeric(codFH_1_bag),
      mode == "pr" & in_season(date_adj, codPR_seas1_op, codPR_seas1_cl) ~ as.numeric(codPR_1_bag),
      TRUE ~ 0),
    cod_min = dplyr::case_when(
      #mode == "fh" & in_season(date_adj, codFH_seas3_op, codFH_seas3_cl) ~ as.numeric(codFH_3_len) * 2.54,
      #mode == "pr" & in_season(date_adj, codPR_seas3_op, codPR_seas3_cl) ~ as.numeric(codPR_3_len) * 2.54,
      mode == "fh" & in_season(date_adj, codFH_seas2_op, codFH_seas2_cl) ~ as.numeric(codFH_2_len) * 2.54,
      mode == "pr" & in_season(date_adj, codPR_seas2_op, codPR_seas2_cl) ~ as.numeric(codPR_2_len) * 2.54,
      mode == "fh" & in_season(date_adj, codFH_seas1_op, codFH_seas1_cl) ~ as.numeric(codFH_1_len) * 2.54,
      mode == "pr" & in_season(date_adj, codPR_seas1_op, codPR_seas1_cl) ~ as.numeric(codPR_1_len) * 2.54,
      TRUE ~ 100),
    hadd_bag = dplyr::case_when(
      mode == "fh" & in_season(date_adj, hadFH_seas3_op, hadFH_seas3_cl) ~ as.numeric(hadFH_3_bag),
      mode == "pr" & in_season(date_adj, hadPR_seas3_op, hadPR_seas3_cl) ~ as.numeric(hadPR_3_bag),
      mode == "fh" & in_season(date_adj, hadFH_seas2_op, hadFH_seas2_cl) ~ as.numeric(hadFH_2_bag),
      mode == "pr" & in_season(date_adj, hadPR_seas2_op, hadPR_seas2_cl) ~ as.numeric(hadPR_2_bag),
      mode == "fh" & in_season(date_adj, hadFH_seas1_op, hadFH_seas1_cl) ~ as.numeric(hadFH_1_bag),
      mode == "pr" & in_season(date_adj, hadPR_seas1_op, hadPR_seas1_cl) ~ as.numeric(hadPR_1_bag),
      TRUE ~ 0),
    hadd_min = dplyr::case_when(
      mode == "fh" & in_season(date_adj, hadFH_seas3_op, hadFH_seas3_cl) ~ as.numeric(hadFH_3_len) * 2.54,
      mode == "pr" & in_season(date_adj, hadPR_seas3_op, hadPR_seas3_cl) ~ as.numeric(hadPR_3_len) * 2.54,
      mode == "fh" & in_season(date_adj, hadFH_seas2_op, hadFH_seas2_cl) ~ as.numeric(hadFH_2_len) * 2.54,
      mode == "pr" & in_season(date_adj, hadPR_seas2_op, hadPR_seas2_cl) ~ as.numeric(hadPR_2_len) * 2.54,
      mode == "fh" & in_season(date_adj, hadFH_seas1_op, hadFH_seas1_cl) ~ as.numeric(hadFH_1_len) * 2.54,
      mode == "pr" & in_season(date_adj, hadPR_seas1_op, hadPR_seas1_cl) ~ as.numeric(hadPR_1_len) * 2.54,
      TRUE ~ 100)
  )

################################################################################
################################################################################
# Section C: Run the projection
################################################################################
################################################################################

# In an Azure Shiny app, set n_workers from an environment variable or app option,
# e.g. Sys.getenv("RDM_N_WORKERS", unset = parallel::detectCores(logical = FALSE) - 1).
use_parallel <- TRUE
n_workers <- 4   # or however many Azure workers/cores you want available


## Run Model in parallel

n_workers <- if (exists("n_workers")) n_workers else max(1L, parallel::detectCores(logical = FALSE) - 1L)
use_parallel <- if (exists("use_parallel")) use_parallel else TRUE

message("Running cod/haddock projection for policy '", policy_name,
        "' over ", length(draws), " draw(s); this may take a while ...")
system.time({
  prediction_draws <- run_cod_hadd_projection(
    season_draw  = season_draw,
    mode_draw    = mode_draw,
    draws        = draws,
    n_workers    = n_workers,
    use_parallel = use_parallel,
    common_inputs = NULL
  )
})
message("Projection complete.")

prediction_draws$policy_name <- policy_name
time_saver<-format(Sys.time(), "%Y%m%d_%H%M%S")

# write csv to output folder to be called in app
write_csv(prediction_draws, file = here::here("output", paste0("output_", policy_name, "_", time_saver, ".csv")))

