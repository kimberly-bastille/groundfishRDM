################################################################################
################################################################################
# Script:       calibrate_rec_catch0.R
# Purpose:      Calibration-year trip simulation for Gulf of Maine cod and
#               haddock, PASS 0 (no harvest/release reallocation). For each
#               draw x season x mode it simulates fish lengths from the baseline
#               catch-at-length distribution, applies bag and minimum-size
#               regulations to classify each fish as kept vs released, computes
#               trip utility via a numerically stable binary logit (take-the-trip
#               vs opt-out), probability-weights and expands trip outcomes to
#               population totals, and builds a model-vs-MRIP comparison table.
#               The comparison it writes is what the reallocation passes
#               (calibrate_rec_catch1.R) use to derive keep<->release fractions.
# Inputs:       final_process_misc_cd/simulated_catch_totals.dta (MRIP totals),
#               final_process_misc_cd/directed_trip_draws.fst,
#               final_process_misc_cd/baseline_catch_at_length.csv,
#               final_process_calib_catch_cd/calib_catch_draws_<i>.fst.
# Outputs:      final_process_misc_cd/calibration_comparison.fst.
# Dependencies: The final_process_* path objects and n_simulations must exist in
#               the calling environment (set by R code wrapper.R /
#               calibration_routine.R).
# Pipeline:     Part of the R calibration stage (Code/sim). Sibling of
#               calibrate_rec_catch1.R, which reuses several helpers defined here.
#
# Key design choices:
#   1. Runs at season x mode x draw, matching the cod/haddock model structure.
#   2. Reads directed trips and catch-at-length once, not in the inner loop.
#   3. Simulates fish lengths with one reusable species function.
#   4. Keeps separate "accounting" columns (tot_keep_*_new, tot_rel_*_new,
#      tot_*_catch) and "utility" columns (util_keep_*_new, util_rel_*_new): a
#      fish moved from harvest to release stays a release in accounting totals
#      but is still counted as harvested in utility.
#   5. Avoids assign()/get() by reshaping to long format for the comparison.
################################################################################
################################################################################

library(data.table)
library(readr)
library(haven)
library(fst)

safe_divide <- function(num, den) {
  fifelse(is.na(den) | den == 0, NA_real_, num / den)
}

calc_prob_trip <- function(v_trip, v_optout) {
  # Numerically stable binary logit probability for the trip alternative.
  z <- v_trip - v_optout
  out <- numeric(length(z))
  pos <- z >= 0
  out[pos] <- 1 / (1 + exp(-z[pos]))
  ez <- exp(z[!pos])
  out[!pos] <- ez / (1 + ez)
  out
}

as_calib_date <- function(x) {
  # Existing data use day strings like "01MAY2011" in some files, but may
  # already be Date in newer files.
  if (inherits(x, "Date")) return(x)
  as.Date(x, format = "%d%b%Y")
}

cod_hadd_season <- function(date_parsed) {
  fifelse(data.table::month(date_parsed) %in% c(9, 10, 11, 12, 1, 2, 3, 4),
          "winter", "summer")
}

check_required_cols <- function(dt, cols, object_name) {
  missing_cols <- setdiff(cols, names(dt))
  if (length(missing_cols)) {
    stop(object_name, " is missing required columns: ",
         paste(missing_cols, collapse = ", "), call. = FALSE)
  }
  invisible(TRUE)
}


#' @title Simulate keep/release outcomes for one species
#' @description Expands each trip's simulated catch into individual fish, draws a
#'   length for each from the catch-at-length distribution, and applies the
#'   bag and minimum-size rules to decide keep vs release. Returns trip-level
#'   counts of kept and released fish in both "accounting" and "utility" terms
#'   (identical here unless realloc_dt supplies keep<->release fractions).
#' @param catch_dt Trip-level catch table (one row per trip x catch_draw) with
#'   the key columns date_parsed, mode, tripid, catch_draw plus the catch, bag,
#'   and minimum-size columns named below.
#' @param catch_col Name of the integer catch column to expand (e.g. "cod_cat").
#' @param bag_col Name of the bag-limit column (e.g. "cod_bag").
#' @param min_col Name of the minimum-size column, in cm (e.g. "cod_min").
#' @param size_dt Catch-at-length lookup with columns length and fitted_prob,
#'   already subset to this species/draw/season.
#' @param species_prefix Either "cod" or "hadd"; sets the output column names.
#' @param realloc_dt Optional table of keep<->release reallocation fractions from
#'   a prior calibration pass; NULL (the default) means no reallocation.
#' @return A keyed data.table with one row per trip x catch_draw and the columns
#'   tot_keep_<sp>_new, tot_rel_<sp>_new, util_keep_<sp>_new, util_rel_<sp>_new.
simulate_species <- function(catch_dt,
                             catch_col,
                             bag_col,
                             min_col,
                             size_dt,
                             species_prefix = c("cod", "hadd"),
                             realloc_dt = NULL) {

  species_prefix <- match.arg(species_prefix)

  key_cols <- c("date_parsed", "mode", "tripid", "catch_draw")

  keep_col      <- paste0("tot_keep_", species_prefix, "_new")
  rel_col       <- paste0("tot_rel_",  species_prefix, "_new")
  util_keep_col <- paste0("util_keep_", species_prefix, "_new")
  util_rel_col  <- paste0("util_rel_",  species_prefix, "_new")

  check_required_cols(catch_dt, c(key_cols, catch_col, bag_col, min_col), "catch_dt")
  check_required_cols(size_dt, c("length", "fitted_prob"), "size_dt")

  if (nrow(size_dt) == 0L || all(is.na(size_dt$fitted_prob))) {
    stop("No usable catch-at-length probabilities for species = ", species_prefix,
         call. = FALSE)
  }

  out_zero <- unique(catch_dt[, ..key_cols])
  out_zero[, c(keep_col, rel_col, util_keep_col, util_rel_col) := .(0L, 0L, 0L, 0L)]

  pos_dt <- catch_dt[get(catch_col) > 0,
                     .(date_parsed, mode, tripid, catch_draw,
                       catch_n = as.integer(round(get(catch_col))),
                       bag     = get(bag_col),
                       min_sz  = get(min_col))]

  if (nrow(pos_dt) == 0L) {
    setkeyv(out_zero, key_cols)
    return(out_zero[])
  }

  fish_dt <- pos_dt[rep(seq_len(.N), catch_n)]
  fish_dt[, fishid := seq_len(.N)]

  fish_dt[, fitted_length := sample(size_dt$length,
                                    .N,
                                    replace = TRUE,
                                    prob = size_dt$fitted_prob)]

  setorder(fish_dt,date_parsed, mode, tripid, catch_draw, fishid)

  fish_dt[, posskeep := fifelse(fitted_length >= min_sz, 1L, 0L)]
  fish_dt[, csum_keep := cumsum(posskeep), by = key_cols]
  fish_dt[, keep_reg := fifelse(bag > 0 & posskeep == 1L & csum_keep <= bag, 1L, 0L)]
  fish_dt[, rel_reg  := fifelse(keep_reg == 1L, 0L, 1L)]

  # Default: no reallocation. Accounting and utility are identical.
  fish_dt[, `:=`(
    keep_accounting = keep_reg,
    rel_accounting  = rel_reg,
    keep_utility    = keep_reg,
    rel_utility     = rel_reg
  )]

  # Optional first-pass reallocation logic, for use when calibration fractions
  # from a previous pass are available. The special utility rule is applied here:
  # harvested fish moved to release remain harvested in utility.
  if (!is.null(realloc_dt) && nrow(realloc_dt) > 0L) {
    realloc_sub <- as.data.table(realloc_dt)[species == species_prefix]

    if (nrow(realloc_sub) > 0L) {
      # Expected columns are season, mode, species, draw, p_keep_to_rel,
      # p_rel_to_keep, keep_to_rel, rel_to_keep. Missing fractions are treated as 0.
      keep_to_rel_flag <- isTRUE(realloc_sub$keep_to_rel[1] == 1)
      rel_to_keep_flag <- isTRUE(realloc_sub$rel_to_keep[1] == 1)
      p_keep_to_rel <- fifelse(is.na(realloc_sub$p_keep_to_rel[1]), 0, realloc_sub$p_keep_to_rel[1])
      p_rel_to_keep <- fifelse(is.na(realloc_sub$p_rel_to_keep[1]), 0, realloc_sub$p_rel_to_keep[1])

      p_keep_to_rel <- max(0, min(1, p_keep_to_rel))
      p_rel_to_keep <- max(0, min(1, p_rel_to_keep))

      if (keep_to_rel_flag && p_keep_to_rel > 0) {
        fish_dt[keep_reg == 1L, move_keep_to_rel := rbinom(.N, 1L, p_keep_to_rel)]
        fish_dt[is.na(move_keep_to_rel), move_keep_to_rel := 0L]

        # Accounting changes: keep -> release.
        fish_dt[move_keep_to_rel == 1L, `:=`(
          keep_accounting = 0L,
          rel_accounting  = 1L,
          keep_utility    = 1L,  # retain as harvest in utility
          rel_utility     = 0L
        )]
      }

      if (rel_to_keep_flag && p_rel_to_keep > 0) {
        fish_dt[rel_reg == 1L, move_rel_to_keep := rbinom(.N, 1L, p_rel_to_keep)]
        fish_dt[is.na(move_rel_to_keep), move_rel_to_keep := 0L]

        # Accounting and utility both treat these as harvested fish.
        fish_dt[move_rel_to_keep == 1L, `:=`(
          keep_accounting = 1L,
          rel_accounting  = 0L,
          keep_utility    = 1L,
          rel_utility     = 0L
        )]
      }
    }
  }

  trip_pos <- fish_dt[, .(
    keep_n      = sum(keep_accounting),
    rel_n       = sum(rel_accounting),
    util_keep_n = sum(keep_utility),
    util_rel_n  = sum(rel_utility)
  ), by = key_cols]

  setnames(trip_pos,
           c("keep_n", "rel_n", "util_keep_n", "util_rel_n"),
           c(keep_col, rel_col, util_keep_col, util_rel_col))

  trip_out <- rbindlist(list(trip_pos, out_zero[!trip_pos, on = key_cols]),
                        use.names = TRUE, fill = TRUE)

  fill_cols <- c(keep_col, rel_col, util_keep_col, util_rel_col)
  for (cc in fill_cols) set(trip_out, which(is.na(trip_out[[cc]])), cc, 0L)

  setkeyv(trip_out, key_cols)
  trip_out[]
}

#' @title Build a model-vs-MRIP comparison table for one mode
#' @description Reshapes the simulated ("model") and MRIP totals to long form,
#'   joins them by species/disposition, and computes differences and percent
#'   differences. Also derives the keep<->release reallocation flags and
#'   fractions (p_rel_to_keep, p_keep_to_rel) that a later pass uses to nudge the
#'   simulated harvest toward the MRIP estimate.
#' @param summed_results Simulated totals for this mode (keep/rel/catch by species).
#' @param MRIP_comparison_draw MRIP totals for the same draw/season/mode.
#' @param md Mode label ("pr" or "fh") stamped onto the output.
#' @return A data.table (one row per mode x species) of MRIP vs model totals,
#'   their differences, and the derived reallocation direction and fractions.
build_compare_table <- function(summed_results, MRIP_comparison_draw, md) {
  metric_cols <- c(
    "cod_keep", "cod_rel", "cod_catch",
    "hadd_keep", "hadd_rel", "hadd_catch"
  )

  model_metrics  <- intersect(metric_cols, names(summed_results))
  mrip_metrics   <- intersect(metric_cols, names(MRIP_comparison_draw))
  common_metrics <- intersect(model_metrics, mrip_metrics)

  if (length(common_metrics) == 0L) {
    stop("No common metric columns found between summed_results and MRIP_comparison_draw.",
         call. = FALSE)
  }

  model_long <- melt(
    as.data.table(summed_results)[, c("mode", common_metrics), with = FALSE],
    id.vars = "mode",
    measure.vars = common_metrics,
    variable.name = "metric",
    value.name = "model"
  )

  mrip_long <- melt(
    as.data.table(MRIP_comparison_draw)[, c("mode", common_metrics), with = FALSE],
    id.vars = "mode",
    measure.vars = common_metrics,
    variable.name = "metric",
    value.name = "MRIP"
  )

  cmp <- merge(model_long, mrip_long, by = c("mode", "metric"), all = FALSE)
  cmp[, c("species", "disposition") := tstrsplit(metric, "_", fixed = TRUE, keep = 1:2)]
  cmp[, `:=`(
    model = as.numeric(model),
    MRIP  = as.numeric(MRIP)
  )]
  cmp[, diff := model - MRIP]
  cmp[, pct_diff := fifelse(MRIP != 0, 100 * diff / MRIP, NA_real_)]
  cmp[, abs_diff_val := abs(diff)]
  cmp[, abs_pct_diff_val := fifelse(MRIP != 0, abs(100 * diff / MRIP), NA_real_)]
  cmp[, mode := md]

  compare_k <- cmp[disposition == "keep",
                   .(mode, species,
                     MRIP_keep = MRIP,
                     model_keep = model,
                     diff_keep = diff,
                     pct_diff_keep = pct_diff)]

  compare_c <- cmp[disposition == "catch",
                   .(mode, species,
                     MRIP_catch = MRIP,
                     model_catch = model,
                     diff_catch = diff,
                     pct_diff_catch = pct_diff)]

  compare_r <- cmp[disposition == "rel",
                   .(mode, species,
                     MRIP_rel = MRIP,
                     model_rel = model,
                     diff_rel = diff,
                     pct_diff_rel = pct_diff)]

  out <- merge(compare_r, compare_k, by = c("mode", "species"), all = TRUE)
  out <- merge(out, compare_c, by = c("mode", "species"), all = TRUE)

  out[, rel_to_keep := fifelse(diff_keep < 0, 1L, 0L)]
  out[, keep_to_rel := fifelse(diff_keep > 0, 1L, 0L)]
  out[, p_rel_to_keep := abs(safe_divide(diff_keep, model_rel))]
  out[, p_keep_to_rel := abs(safe_divide(diff_keep, model_keep))]

  out[]
}

# ---- Inputs ----


MRIP_comparison <- as.data.table(
  haven::read_dta(file.path(final_process_misc_cd, "simulated_catch_totals.dta"))
)

setnames(
  MRIP_comparison,
  old = c("tot_dtrip_sim",
          "tot_cod_cat_sim", "tot_hadd_cat_sim",
          "tot_cod_keep_sim", "tot_hadd_keep_sim",
          "tot_cod_rel_sim", "tot_hadd_rel_sim"),
  new = c("estimated_trips",
          "cod_catch", "hadd_catch",
          "cod_keep", "hadd_keep",
          "cod_rel", "hadd_rel"),
  skip_absent = TRUE
)

mode_draw   <- c("pr", "fh")
season_draw <- c("summer", "winter")
draws       <- seq_len(n_simulations)

# Directed trips are draw-specific, but the file is common. Read once.
dtrip_all <- as.data.table(read_fst(file.path(final_process_misc_cd, "directed_trip_draws.fst")))
dtrip_all[, season := cod_hadd_season(date_parsed)]
dtrip_all <- dtrip_all[, .(draw, mode, date_parsed, season, dtrip,
                           cod_bag, cod_min, hadd_bag, hadd_min)]
setkey(dtrip_all, draw, season, mode, date_parsed)

# Catch-at-length is common. Read once.
size_lookup <- as.data.table(
  readr::read_csv(file.path(final_process_misc_cd, "baseline_catch_at_length.csv"),
                  show_col_types = FALSE)
)
check_required_cols(size_lookup,
                    c("species", "draw", "season", "fitted_prob", "length"),
                    "baseline_catch_at_length.csv")
size_lookup <- size_lookup[!is.na(fitted_prob), .(species, draw, season, fitted_prob, length)]
setkey(size_lookup, species, draw, season)

calib_comparison <- vector("list", length(season_draw) * length(mode_draw) * length(draws))
k <- 1L

# ---- Main loop ----

for (i in draws) {

  message("calibrate_rec_catch0: simulating draw ", i, " of ", max(draws))

  catch_path_fst <- file.path(final_process_calib_catch_cd, paste0("calib_catch_draws_", i, ".fst"))
  catch_draw_dt <- as.data.table(read_fst(catch_path_fst))
  setnames(
    catch_draw_dt,
    old = c("cod_cat_sim", "hadd_cat_sim", "cost_sim"),
    new = c("cod_cat", "hadd_cat", "cost"),
    skip_absent = TRUE
  )


  check_required_cols(catch_draw_dt,
                      c("mode", "date_parsed", "tripid", "catch_draw", "cod_cat", "hadd_cat"),
                      paste0("calib_catch_draws_", i))

  catch_draw_dt[, season := cod_hadd_season(date_parsed)]

  # Keep the beta and angler variables on catch_draw_dt; they are merged into
  # trip-level outcomes below.

  for (s in season_draw) {
    for (md in mode_draw) {

      dtripz <- dtrip_all[list(i, s, md)]
      catch_data <- merge(
        catch_draw_dt[mode == md & season == s],
        dtripz[, .(mode, date_parsed, dtrip, cod_bag, cod_min, hadd_bag, hadd_min)],
        by = c("mode", "date_parsed"),
        all.x = TRUE
      )

      MRIP_comparison_draw <- MRIP_comparison[draw == i & season == s & mode == md,
                                              .(mode, cod_keep, cod_rel, cod_catch,
                                                hadd_keep, hadd_rel, hadd_catch)]

      if (nrow(MRIP_comparison_draw) == 0L) {
        MRIP_comparison_draw <- data.table(
          mode = md,
          cod_keep = NA_real_, cod_rel = NA_real_, cod_catch = NA_real_,
          hadd_keep = NA_real_, hadd_rel = NA_real_, hadd_catch = NA_real_
        )
      }

      if (nrow(catch_data) == 0L) {
        summed_results <- data.table(
          mode = md,
          cod_catch = 0, cod_keep = 0, cod_rel = 0,
          hadd_catch = 0, hadd_keep = 0, hadd_rel = 0,
          estimated_trips = 0, n_choice_occasions = 0
        )

        compare_out <- build_compare_table(summed_results, MRIP_comparison_draw, md)
        compare_out[, `:=`(draw = i, season = s)]
        calib_comparison[[k]] <- compare_out
        k <- k + 1L
        next
      }

      angler_cols <- intersect(
        c("date_parsed", "mode", "tripid", "total_trips_12", "fish_pref_more",
          "educ1", "educ2", "educ3", "own_boat", "cost", "age",
          grep("^beta", names(catch_data), value = TRUE)),
        names(catch_data)
      )
      angler_dems <- unique(catch_data[, ..angler_cols])

      cod_size_data  <- size_lookup[list("cod",  i, s), .(fitted_prob, length)]
      hadd_size_data <- size_lookup[list("hadd", i, s), .(fitted_prob, length)]

      cod_trip_data <- simulate_species(
        catch_dt = catch_data,
        catch_col = "cod_cat",
        bag_col = "cod_bag",
        min_col = "cod_min",
        size_dt = cod_size_data,
        species_prefix = "cod"
      )

      hadd_trip_data <- simulate_species(
        catch_dt = catch_data,
        catch_col = "hadd_cat",
        bag_col = "hadd_bag",
        min_col = "hadd_min",
        size_dt = hadd_size_data,
        species_prefix = "hadd"
      )

      key_cols <- c("date_parsed", "mode", "tripid", "catch_draw")
      trip_data <- merge(cod_trip_data, hadd_trip_data, by = key_cols, all = TRUE)

      zero_fill_cols <- grep("^(tot|util)_(keep|rel)_(cod|hadd)_new$", names(trip_data), value = TRUE)
      for (cc in zero_fill_cols) set(trip_data, which(is.na(trip_data[[cc]])), cc, 0L)

      trip_data[, `:=`(
        tot_cod_catch  = tot_keep_cod_new  + tot_rel_cod_new,
        tot_hadd_catch = tot_keep_hadd_new + tot_rel_hadd_new,
        util_cod_catch  = util_keep_cod_new  + util_rel_cod_new,
        util_hadd_catch = util_keep_hadd_new + util_rel_hadd_new
      )]

      trip_data <- merge(trip_data, angler_dems, by = c("date_parsed", "mode", "tripid"), all.x = TRUE)

      required_utility_cols <- c(
        "beta_sqrt_cod_keep", "beta_sqrt_cod_release",
        "beta_sqrt_hadd_keep", "beta_sqrt_hadd_release",
        "beta_sqrt_cod_hadd_keep", "beta_cost", "cost",
        "beta_opt_out", "beta_opt_out_trips12", "total_trips_12",
        "beta_opt_out_fish_pref", "fish_pref_more",
        "beta_opt_out_educ2", "educ2",
        "beta_opt_out_educ3", "educ3",
        "beta_opt_out_ownboat", "own_boat"
      )
      check_required_cols(trip_data, required_utility_cols, "trip_data before utility calculation")

      # Utility uses util_* columns, not accounting columns. This is the line that
      # implements the special rule: harvested fish moved to release stay in
      # util_keep_*_new but are counted in tot_rel_*_new for accounting.
      trip_data[, `:=`(
        vA_trip =
          beta_sqrt_cod_keep    * sqrt(util_keep_cod_new) +
          beta_sqrt_cod_release * sqrt(util_rel_cod_new) +
          beta_sqrt_hadd_keep   * sqrt(util_keep_hadd_new) +
          beta_sqrt_hadd_release * sqrt(util_rel_hadd_new) +
          beta_sqrt_cod_hadd_keep * (sqrt(util_keep_cod_new) * sqrt(util_keep_hadd_new)) +
          beta_cost * cost,

        vA_optout =
          beta_opt_out +
          beta_opt_out_trips12  * total_trips_12 +
          beta_opt_out_fish_pref * fish_pref_more +
          beta_opt_out_educ2    * educ2 +
          beta_opt_out_educ3    * educ3 +
          beta_opt_out_ownboat  * own_boat
      )]

      mean_trip_data <- copy(trip_data)

      drop_cols <- intersect(
        c(grep("^beta", names(mean_trip_data), value = TRUE),
          "opt_out", "cost", "total_trips_12", "educ1", "educ2", "educ3",
          "fish_pref_more", "own_boat", "age"),
        names(mean_trip_data)
      )
      if (length(drop_cols)) mean_trip_data[, (drop_cols) := NULL]

      keep_vars <- setdiff(names(mean_trip_data), c("date_parsed", "mode", "tripid"))
      mean_trip_data <- mean_trip_data[, lapply(.SD, mean),
                                       by = .(date_parsed, mode, tripid),
                                       .SDcols = keep_vars]

      mean_trip_data[, probA := calc_prob_trip(vA_trip, vA_optout)]
      mean_trip_data[, c("vA_trip", "vA_optout", "catch_draw") := NULL]

      # Probability weighting is applied to accounting totals. Utility-only
      # columns are retained only for diagnostics and are not used as harvest or
      # release estimates.
      accounting_cols <- c("tot_keep_cod_new", "tot_rel_cod_new", "tot_cod_catch",
                           "tot_keep_hadd_new", "tot_rel_hadd_new", "tot_hadd_catch")
      mean_trip_data[, (accounting_cols) := lapply(.SD, function(x) x * probA),
                     .SDcols = accounting_cols]

      mean_trip_data <- merge(mean_trip_data,
                              dtripz[, .(mode, date_parsed, dtrip)],
                              by = c("mode", "date_parsed"),
                              all.x = TRUE)

      mean_trip_data[, mean_prob := mean(probA), by = .(mode, date_parsed)]
      mean_trip_data[is.na(mean_prob) | mean_prob == 0, mean_prob := NA_real_]
      mean_trip_data[, sims := fifelse(!is.na(mean_prob), round(dtrip / mean_prob), 0)]
      mean_trip_data[, expand := sims / 50]
      mean_trip_data[, n_choice_occasions := 1]

      expand_cols <- c(accounting_cols, "n_choice_occasions", "probA")
      mean_trip_data[, (expand_cols) := lapply(.SD, function(x) x * expand),
                     .SDcols = expand_cols]

      for (j in names(mean_trip_data)) setattr(mean_trip_data[[j]], "label", NULL)

      aggregate_trip_data <- mean_trip_data[, lapply(.SD, sum),
                                            by = .(date_parsed, mode),
                                            .SDcols = expand_cols]

      setnames(
        aggregate_trip_data,
        old = c("probA", "tot_cod_catch", "tot_hadd_catch",
                "tot_keep_cod_new", "tot_keep_hadd_new",
                "tot_rel_cod_new", "tot_rel_hadd_new"),
        new = c("estimated_trips", "cod_catch", "hadd_catch",
                "cod_keep", "hadd_keep",
                "cod_rel", "hadd_rel"),
        skip_absent = TRUE
      )

      list_names <- c("hadd_catch", "hadd_keep", "hadd_rel",
                      "cod_catch", "cod_keep", "cod_rel",
                      "estimated_trips", "n_choice_occasions")

      summed_results <- aggregate_trip_data[, lapply(.SD, sum),
                                            by = .(mode),
                                            .SDcols = list_names]

      compare_out <- build_compare_table(summed_results, MRIP_comparison_draw, md)
      compare_out[, `:=`(draw = i, season = s)]

      calib_comparison[[k]] <- compare_out
      k <- k + 1L
    }
  }
}

calib_comparison_combined <- rbindlist(calib_comparison, use.names = TRUE, fill = TRUE)
calib_comparison_combined <- calib_comparison_combined[!is.na(mode)]

setcolorder(calib_comparison_combined,
            c("season", "mode", "species", "draw",
              setdiff(names(calib_comparison_combined),
                      c("season", "mode", "species", "draw"))))

fst::write_fst(calib_comparison_combined,
               file.path(final_process_misc_cd, "calibration_comparison.fst"))
