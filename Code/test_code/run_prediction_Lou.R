### Run this Lou

################################################################################
# Dev paths note (no full script header yet - out of scope for this pass):
# 5 hardcoded absolute paths to a developer's local machine (E:\),
# at lines 17, 18, 19, 20 and 21.
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
# Optional parallel backend is loaded only in the wrapper below.

final_process_data_cd="E:/Lou_projects/groundfishRDM/2027_mgt_cycle"
final_process_outcomes_cd="E:/Lou_projects/groundfishRDM/2027_mgt_cycle/base_outcomes"
final_process_choice_occasions_cd="E:/Lou_projects/groundfishRDM/2027_mgt_cycle/n_choice_occasions"
final_process_misc_cd="E:/Lou_projects/groundfishRDM/2027_mgt_cycle/miscellaneous"
final_process_calib_catch_cd="E:/Lou_projects/groundfishRDM/2027_mgt_cycle/calib_catch_draws"

# -----------------------------------------------------------------------------
# User-facing controls
# -----------------------------------------------------------------------------
draws         <- 1:5
n_simulations <- 5
mode_draw     <- c("pr", "fh")
season_draw   <- c("summer", "winter")
draws         <- if (exists("draws")) draws else seq_len(n_simulations)
n_draws       <- 50L

source(here::here("Code/sim/predict_rec_catch_functions.R"))
# Length-weight parameters from the calibration script.
cod_lw_a <- if (exists("cod_lw_a")) cod_lw_a else 0.000005132
cod_lw_b <- if (exists("cod_lw_b")) cod_lw_b else 3.1625
had_lw_a <- if (exists("had_lw_a")) had_lw_a else 0.000009298
had_lw_b <- if (exists("had_lw_b")) had_lw_b else 3.0205

directed_trips <- as.data.table(read_fst(file.path(final_process_misc_cd,"directed_trip_draws.fst")))

# -----------------------------------------------------------------------------
# Main projection execution
# -----------------------------------------------------------------------------

# In an Azure Shiny app, set n_workers from an environment variable or app option,
# e.g. Sys.getenv("RDM_N_WORKERS", unset = parallel::detectCores(logical = FALSE) - 1).
use_parallel <- TRUE
n_workers <- 4   # or however many Azure workers/cores you want available


## Run Model in parallel

n_workers <- if (exists("n_workers")) n_workers else max(1L, parallel::detectCores(logical = FALSE) - 1L)
use_parallel <- if (exists("use_parallel")) use_parallel else TRUE

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


# -----------------------------------------------------------------------------
# Final baseline-vs-projected comparison
# -----------------------------------------------------------------------------

prediction_long <- copy(prediction_draws)
prediction_long[, metric := as.character(metric)]
prediction_long[, species := data.table::fcase(
  grepl("_cod_", metric), "cod",
  grepl("_hadd_", metric), "hadd",
  default = NA_character_
)]

trip_compare <- data.table::dcast(
  prediction_long[metric %in% c("n_trips_alt", "n_trips_base")],
  season + mode + iteration ~ metric,
  value.var = "value"
)

trip_compare <- trip_compare[, .(
  season, mode, iteration,
  species = NA_character_,
  metric = "trips",
  baseline_value = n_trips_base,
  projected_value = n_trips_alt
)]

prediction_long2 <- prediction_long[!metric %in% c("n_trips_alt", "n_trips_base")]
prediction_long2[, metric_clean := data.table::fcase(
  metric == "CV", "compensating variation ($)",
  grepl("tot_keep_.*weight_lb", metric), "harvest (lbs.)",
  grepl("tot_rel_.*weight_lb", metric), "discards (lbs.)",
  grepl("tot_discmort_.*weight_lb", metric), "dead discards (lbs.)",
  grepl("tot_keep_", metric), "harvest (#s)",
  grepl("tot_rel_", metric), "discards (#s)",
  grepl("tot_cat_", metric), "catch (#s)",
  default = metric
)]
prediction_long2[, metric := metric_clean]
prediction_long2[, metric_clean := NULL]
data.table::setnames(prediction_long2, "value", "projected_value")

calib_full <- data.table::as.data.table(fst::read_fst(file.path(final_process_misc_cd, "calibrated_model_stats.fst")))
calib_keep_cols <- intersect(
  c("season", "mode", "draw", "species", "model_keep", "model_rel", "model_catch",
    "model_keep_lbs", "model_rel_lbs", "model_discmort_lbs"),
  names(calib_full)
)
calib_keep <- calib_full[season %in% season_draw & mode %in% mode_draw & draw %in% draws, ..calib_keep_cols]
data.table::setnames(calib_keep, "draw", "iteration", skip_absent = TRUE)

calib_all_modes <- calib_keep[, .(
  model_keep = sum(model_keep, na.rm = TRUE),
  model_rel = sum(model_rel, na.rm = TRUE),
  model_catch = sum(model_catch, na.rm = TRUE),
  model_keep_lbs = sum(model_keep_lbs, na.rm = TRUE),
  model_rel_lbs = sum(model_rel_lbs, na.rm = TRUE),
  model_discmort_lbs = sum(model_discmort_lbs, na.rm = TRUE)
), by = .(season, iteration, species)]
calib_all_modes[, mode := "all modes"]

calib_keep <- data.table::rbindlist(list(calib_keep, calib_all_modes), use.names = TRUE, fill = TRUE)

calib_long <- data.table::melt(
  calib_keep,
  id.vars = c("season", "mode", "iteration", "species"),
  measure.vars = intersect(c("model_keep", "model_rel", "model_keep_lbs",
                             "model_rel_lbs", "model_discmort_lbs", "model_catch"), names(calib_keep)),
  variable.name = "metric",
  value.name = "baseline_value"
)

calib_long[, metric := data.table::fcase(
  metric == "model_keep", "harvest (#s)",
  metric == "model_rel", "discards (#s)",
  metric == "model_catch", "catch (#s)",
  metric == "model_keep_lbs", "harvest (lbs.)",
  metric == "model_rel_lbs", "discards (lbs.)",
  metric == "model_discmort_lbs", "dead discards (lbs.)",
  default = as.character(metric)
)]

final_compare <- merge(
  prediction_long2,
  calib_long,
  by = c("season", "mode", "iteration", "species", "metric"),
  all.x = TRUE
)

final_compare <- data.table::rbindlist(list(final_compare, trip_compare), use.names = TRUE, fill = TRUE)
final_compare[, difference := projected_value - baseline_value]
final_compare[, pct_difference := safe_divide(projected_value - baseline_value, baseline_value) * 100]
final_compare[, difference := round(difference, 1)]
final_compare[, pct_difference := round(pct_difference, 1)]
final_compare[, projected_value := round(projected_value, 0)]
final_compare[, baseline_value := round(baseline_value, 0)]

data.table::setcolorder(
  final_compare,
  c("iteration", "season", "mode", "species", "metric",
    "baseline_value", "projected_value", "difference", "pct_difference")
)
data.table::setorder(final_compare, iteration, season, mode, species, metric)

# ---- Summarize by draw, then average across draws ----
# 1. Sum output within each draw across seasons/modes where appropriate
final_compare_draw_sums <- final_compare[ , .(
  baseline_value  = sum(baseline_value, na.rm = TRUE),
  projected_value = sum(projected_value, na.rm = TRUE)
),  by = .(iteration, mode, species, metric)
]

final_compare_draw_sums[, difference := projected_value - baseline_value]
final_compare_draw_sums[, pct_difference :=
                          safe_divide(difference, baseline_value) * 100
]

# 2. Average summed draw-level outputs across draws
final_compare_draw_avg <- final_compare_draw_sums[,  .(
  baseline_value  = mean(baseline_value, na.rm = TRUE),
  projected_value = mean(projected_value, na.rm = TRUE),
  difference      = mean(difference, na.rm = TRUE),
  pct_difference  = mean(pct_difference, na.rm = TRUE)
),
by = .(mode, species, metric)
]

final_compare_draw_avg[, iteration := "draw average"]

# 3. Optional rounding and ordering
final_compare_draw_avg[, `:=`(
  baseline_value  = round(baseline_value, 0),
  projected_value = round(projected_value, 0),
  difference      = round(difference, 1),
  pct_difference  = round(pct_difference, 1)
)]

data.table::setcolorder(
  final_compare_draw_avg,
  c("iteration", "mode", "species", "metric",
    "baseline_value", "projected_value", "difference", "pct_difference")
)
