################################################################################
################################################################################
# Script:       calibrate_rec_catch1.R
# Purpose:      Calibration-year trip simulation WITH optional trip-level
#               harvest/release reallocation (the pass that actually calibrates
#               to MRIP). Same fish-level expansion as calibrate_rec_catch0.R,
#               but additionally: assigns each fish a weight (length-weight
#               relationship) and a month-specific discard mortality, and moves
#               fish between keep and release using the p_keep_to_rel /
#               p_rel_to_keep fractions derived from the previous pass. Writes
#               baseline outcomes and choice-occasion files and returns the
#               model-vs-MRIP comparison for this run.
# Scope:        Runs ONE season x mode x draw. It expects s (season), i (draw),
#               md (mode), the reallocation parameters (rel_to_keep_<sp>,
#               keep_to_rel_<sp>, p_*_<sp>, all_keep_to_rel_<sp>), the
#               MRIP_comparison table, and the discard-mortality tables
#               (cod_disc_mort, hadd_disc_mort) to already exist in the calling
#               environment. calibration_routine.R sets these and sources this
#               file inside its loop.
# Inputs:       final_process_misc_cd/baseline_catch_at_length.csv,
#               final_process_misc_cd/directed_trip_draws.fst,
#               final_process_calib_catch_cd/calib_catch_draws_<i>.fst.
# Outputs:      final_process_outcomes_cd/base_outcomes_<s>_<md>_<i>.fst,
#               final_process_choice_occasions_cd/n_choice_occasions_<s>_<md>_<i>.fst,
#               and calib_comparison1 (returned in the environment).
# Dependencies: Reuses cod_hadd_season() and check_required_cols() defined in
#               calibrate_rec_catch0.R, so the routine must source that file
#               first.
# Pipeline:     Core of the R calibration loop (Code/sim), driven by
#               calibration_routine.R.
#
# Utility adjustment: for both species, a fish reallocated from kept -> released
# still counts as kept in the utility calculation, but is released in the
# harvest/release accounting totals.
################################################################################
################################################################################

# Length-weight conversion parameters (weight in kg = a * length_cm^b; converted
# to lb below). Values from the calibration/assessment length-weight fits.
cod_lw_a = 0.000005132
cod_lw_b = 3.1625
had_lw_a = 0.000009298
had_lw_b = 3.0205


parse_date_any <- function(x) {
  data.table::as.IDate(as.Date(
    x,
    tryFormats = c("%d%b%Y", "%Y-%m-%d", "%m/%d/%Y", "%d/%m/%Y")
  ))
}

safe_divide <- function(num, den) {
  ifelse(is.na(den) | den == 0, NA_real_, num / den)
}

# stable binary logit probability for the trip alternative
calc_prob_trip <- function(v_trip, v_optout) {
  z <- v_trip - v_optout
  out <- numeric(length(z))
  pos <- z >= 0
  out[pos] <- 1 / (1 + exp(-z[pos]))
  ez <- exp(z[!pos])
  out[!pos] <- ez / (1 + ez)
  out
}

#' @title Build a model-vs-MRIP comparison table (numbers and weights)
#' @description Reshapes simulated ("model") and MRIP totals to long form, joins
#'   by species/disposition, and computes differences and percent differences
#'   for both number and weight (lb) metrics. Derives the next pass's
#'   reallocation flags and fractions; p_rel_to_keep is scaled by the count of
#'   release-eligible sublegal fish (original_rel_eligible) rather than by total
#'   releases. Extends the pass-0 version by also carrying harvest/discard weights.
#' @param summed_results Simulated totals for this mode (counts and lb weights).
#' @param MRIP_comparison_draw MRIP number totals for the same draw/season/mode.
#' @param md Mode label ("pr"/"fh") stamped onto the output.
#' @param eligible_dt Optional per-species count of release-eligible fish used to
#'   scale p_rel_to_keep; NULL sets original_rel_eligible to 0.
#' @return A data.table (one row per mode x species) of MRIP vs model totals,
#'   differences, weight columns, and the derived reallocation fractions.
build_compare_table <- function(summed_results, MRIP_comparison_draw, md, eligible_dt = NULL) {

  number_metric_cols <- c(
    "cod_keep", "cod_rel", "cod_catch",
    "hadd_keep", "hadd_rel", "hadd_catch"
  )

  weight_metric_cols <- c(
    "tot_keep_cod_weight_lb_new", "tot_rel_cod_weight_lb_new",
    "tot_discmort_cod_weight_lb_new",
    "tot_keep_hadd_weight_lb_new", "tot_rel_hadd_weight_lb_new",
    "tot_discmort_hadd_weight_lb_new"
  )

  metric_cols <- c(number_metric_cols, weight_metric_cols)

  model_metrics  <- intersect(metric_cols, names(summed_results))
  mrip_metrics   <- intersect(number_metric_cols, names(MRIP_comparison_draw))

  if (length(model_metrics) == 0L) {
    stop("No model metric columns found in summed_results.")
  }

  model_long <- data.table::melt(
    data.table::as.data.table(summed_results)[, c("mode", model_metrics), with = FALSE],
    id.vars = "mode",
    measure.vars = model_metrics,
    variable.name = "metric",
    value.name = "model"
  )

  mrip_long <- data.table::melt(
    data.table::as.data.table(MRIP_comparison_draw)[, c("mode", mrip_metrics), with = FALSE],
    id.vars = "mode",
    measure.vars = mrip_metrics,
    variable.name = "metric",
    value.name = "MRIP"
  )

  model_long[, model := as.numeric(model)]
  mrip_long[, MRIP := as.numeric(MRIP)]

  cmp <- merge(model_long, mrip_long, by = c("mode", "metric"), all.x = TRUE)

  cmp[, `:=`(
    species = data.table::fcase(
      grepl("_cod_", metric) | grepl("^cod_", metric), "cod",
      grepl("_hadd_", metric) | grepl("^hadd_", metric), "hadd",
      default = NA_character_
    ),
    disposition = data.table::fcase(
      grepl("discmort", metric), "discmort",
      grepl("keep", metric), "keep",
      grepl("rel", metric), "rel",
      grepl("catch", metric), "catch",
      default = NA_character_
    ),
    units = data.table::fcase(
      grepl("weight_lb", metric), "lbs",
      default = "numbers"
    )
  )]

  cmp[, diff := model - MRIP]
  cmp[, pct_diff := fifelse(!is.na(MRIP) & MRIP != 0, 100 * diff / MRIP, NA_real_)]
  cmp[, abs_diff_val := abs(diff)]
  cmp[, abs_pct_diff_val := fifelse(!is.na(MRIP) & MRIP != 0, abs(100 * diff / MRIP), NA_real_)]
  cmp[, mode := md]

  cmp <- cmp[
    species %in% c("cod", "hadd") &
      disposition %in% c("keep", "rel", "catch", "discmort"),
    .(species, disposition, units, mode, MRIP, model, diff, pct_diff,
      abs_diff_val, abs_pct_diff_val)
  ]

  cmp_num <- cmp[units == "numbers"]

  compare_k <- cmp_num[disposition == "keep",
                       .(mode, species,
                         MRIP_keep = MRIP,
                         model_keep = model,
                         diff_keep = diff,
                         pct_diff_keep = pct_diff)
  ]

  compare_c <- cmp_num[disposition == "catch",
                       .(mode, species,
                         MRIP_catch = MRIP,
                         model_catch = model,
                         diff_catch = diff,
                         pct_diff_catch = pct_diff)
  ]

  compare_r <- cmp_num[disposition == "rel",
                       .(mode, species,
                         MRIP_rel = MRIP,
                         model_rel = model,
                         diff_rel = diff,
                         pct_diff_rel = pct_diff)
  ]

  out <- merge(compare_r, compare_k, by = c("mode", "species"), all = TRUE)
  out <- merge(out, compare_c, by = c("mode", "species"), all = TRUE)

  cmp_lbs <- cmp[units == "lbs"]

  if (nrow(cmp_lbs) > 0L) {
    weight_wide <- data.table::dcast(
      cmp_lbs,
      mode + species ~ disposition,
      value.var = "model"
    )

    wt_old <- intersect(c("keep", "rel", "catch", "discmort"), names(weight_wide))
    wt_new <- paste0("model_", wt_old, "_lbs")

    if (length(wt_old) > 0L) {
      data.table::setnames(weight_wide, old = wt_old, new = wt_new)
    }

    out <- merge(out, weight_wide, by = c("mode", "species"), all.x = TRUE)
  } else {
    out[, `:=`(
      model_keep_lbs = NA_real_,
      model_rel_lbs = NA_real_
    )]
  }

  if (!is.null(eligible_dt)) {
    out <- merge(out, eligible_dt, by = c("mode", "species"), all.x = TRUE)
  } else {
    out[, original_rel_eligible := NA_real_]
  }

  out[is.na(original_rel_eligible), original_rel_eligible := 0]

  out[, rel_to_keep_new := fifelse(diff_keep < 0, 1, 0)]
  out[, keep_to_rel_new := fifelse(diff_keep > 0, 1, 0)]
  out[, p_rel_to_keep_new := abs(safe_divide(diff_keep, original_rel_eligible))]
  out[, p_rel_to_keep_new := pmin(1, p_rel_to_keep_new)]

  out[, p_keep_to_rel_new := abs(safe_divide(diff_keep, model_keep))]

  out[]
}

# initialize defaults if not supplied by the outer routine
species_defaults <- c("cod", "hadd")
for (sp in species_defaults) {
  if (!exists(paste0("keep_to_rel_", sp), inherits = FALSE)) assign(paste0("keep_to_rel_", sp), 0)
  if (!exists(paste0("rel_to_keep_", sp), inherits = FALSE)) assign(paste0("rel_to_keep_", sp), 0)
  if (!exists(paste0("p_rel_to_keep_", sp), inherits = FALSE)) assign(paste0("p_rel_to_keep_", sp), 0)
  if (!exists(paste0("p_keep_to_rel_", sp), inherits = FALSE)) assign(paste0("p_keep_to_rel_", sp), 0)
  if (!exists(paste0("all_keep_to_rel_", sp), inherits = FALSE)) assign(paste0("all_keep_to_rel_", sp), 0)
}

if (!exists("cod_floor_below_min_in", inherits = FALSE))   cod_floor_below_min_in <- 3
if (!exists("hadd_floor_below_min_in", inherits = FALSE))  hadd_floor_below_min_in <- 3


n_sub_kept_cod <- 0L
prop_sub_kept_cod <- 0
n_legal_rel_cod <- 0L
prop_legal_rel_cod <- 0
original_rel_eligible_cod <- 0

n_sub_kept_hadd <- 0L
prop_sub_kept_hadd <- 0
n_legal_rel_hadd <- 0L
prop_legal_rel_hadd <- 0
original_rel_eligible_hadd <- 0

#' @title Simulate keep/release outcomes with reallocation and weights
#' @description Like simulate_species() but adds fish weight (length-weight),
#'   discard mortality, and reallocation between keep and release. Fish are
#'   expanded from trip catch, given a length and weight, and classified by the
#'   bag/size rules; then a fraction can be moved release->keep (undersized fish
#'   within floor_sublegal of the minimum size) or keep->release, to pull the
#'   simulated harvest toward the MRIP estimate.
#' @param catch_dt,catch_col,bag_col,min_col,size_dt,species_prefix As in
#'   simulate_species(): the trip catch table, the catch/bag/min column names,
#'   the catch-at-length lookup, and the species ("cod"/"hadd").
#' @param floor_sublegal Length floor (cm) below the minimum size within which a
#'   released fish is eligible to be reallocated to harvest.
#' @param rel_to_keep,keep_to_rel Flags (0/1) enabling each reallocation direction.
#' @param p_rel_to_keep,p_keep_to_rel Fractions of eligible fish to move.
#' @param all_keep_to_rel If 1, move ALL kept fish to release (full closure case).
#' @param utility_adjust If TRUE, apply the utility rule (kept-then-released fish
#'   still count as kept for utility).
#' @return A list with `trip` (trip-level keep/release counts and weights,
#'   including discard-mortality weight) plus diagnostic counts of reallocated
#'   fish (n_sub_kept, n_legal_rel, proportions, original_rel_eligible).
simulate_species_realloc <- function(catch_dt,
                                     catch_col,
                                     bag_col,
                                     min_col,
                                     size_dt,
                                     species_prefix = c("cod", "hadd"),
                                     floor_sublegal,
                                     rel_to_keep = 0,
                                     keep_to_rel = 0,
                                     p_rel_to_keep = 0,
                                     p_keep_to_rel = 0,
                                     all_keep_to_rel = 0,
                                     utility_adjust = FALSE) {

  species_prefix <- as.character(species_prefix)[1]

  key_cols <- c("date_parsed", "mode", "tripid", "catch_draw")

  keep_col <- paste0("tot_keep_", species_prefix, "_new")
  rel_col  <- paste0("tot_rel_", species_prefix, "_new")
  keep_wt_col <- paste0("tot_keep_", species_prefix, "_weight_lb_new")
  rel_wt_col  <- paste0("tot_rel_", species_prefix, "_weight_lb_new")
  disc_wt_col  <- paste0("tot_discmort_", species_prefix, "_weight_lb_new")

  util_keep_col <- paste0("util_keep_", species_prefix, "_new")
  util_rel_col  <- paste0("util_rel_",  species_prefix, "_new")


  pos_dt <- catch_dt[get(catch_col) > 0,
                     .(date_parsed, mode, tripid, catch_draw,
                       catch_n = get(catch_col),
                       bag     = get(bag_col),
                       min_sz  = get(min_col))]

  zero_dt <- catch_dt[get(catch_col) == 0,
                      .(date_parsed, mode, tripid, catch_draw)]

  trip_out_zero <- copy(zero_dt)

  trip_out_zero[,
                c(keep_col, rel_col, util_keep_col, util_rel_col, keep_wt_col, rel_wt_col, disc_wt_col) :=
                  .(0L, 0L, 0L, 0L, 0, 0, 0)  ]

  if (nrow(pos_dt) == 0L) {

    setcolorder(trip_out_zero,
                c(key_cols, keep_col, rel_col, util_keep_col, util_rel_col, keep_wt_col, rel_wt_col, disc_wt_col))

    setkeyv(trip_out_zero, key_cols)

    return(list(
      trip = trip_out_zero,
      n_sub_kept = 0L,
      n_legal_rel = 0L,
      prop_sub_kept = 0,
      prop_legal_rel = 0,
      original_rel_eligible = 0

    ))
  }

  fish_dt <- pos_dt[rep(seq_len(.N), catch_n)]
  fish_dt[, fishid := seq_len(.N)]

  fish_dt[, fitted_length := sample(size_dt$length,
                                    .N,
                                    replace = TRUE,
                                    prob = size_dt$fitted_prob)]

   fish_dt[, month := as.integer(format(date_parsed, "%m"))]

    # Compute weight
    if (species_prefix=="cod"){
      fish_dt[, fish_weight_lb := cod_lw_a*fitted_length^cod_lw_b]
      fish_dt<-fish_dt %>% left_join(cod_disc_mort,by="month")
      }

    if (species_prefix=="hadd"){
      fish_dt[, fish_weight_lb := had_lw_a*fitted_length^had_lw_b]
      fish_dt[, spp2 := data.table::fifelse(
        fitted_length > 50, "had_lg","had_sm")]
      fish_dt<-fish_dt %>% left_join(hadd_disc_mort,by=c("spp2", "month"))

     }


    # Convert to lbs
  fish_dt[, fish_weight_lb := fish_weight_lb * 2.20462262185]

  fish_dt <- data.table::copy(data.table::as.data.table(fish_dt))
  fish_dt[, `:=`(
    posskeep = data.table::fifelse(fitted_length >= min_sz, 1L, 0L))]

  setorder(fish_dt, date_parsed, mode, tripid, catch_draw, fishid)
  fish_dt[, csum_keep := cumsum(posskeep), by = key_cols]
  fish_dt[, keep := fifelse(bag > 0 & posskeep == 1L & csum_keep <= bag, 1L, 0L)]
  fish_dt[, release := fifelse(keep == 0L, 1L, 0L)]
  fish_dt[, kept_to_released_flag := 0L]

  fish_dt[, subl_harv_indicator := fifelse(release == 1L & fitted_length >= floor_sublegal, 1L, 0L)]

  n_sub_kept <- 0L
  n_legal_rel <- 0L
  prop_sub_kept <- 0
  prop_legal_rel <- 0

  original_rel_eligible <- fish_dt[
    release == 1L & subl_harv_indicator == 1L,
    .N
  ]

  original_sum_rel <- fish_dt[, sum(release)]
  original_sum_keep <- fish_dt[, sum(keep)]

  if (rel_to_keep == 1 && original_sum_rel > 0) {
    realloc_dt <- fish_dt[subl_harv_indicator == 1L]
    base_dt    <- fish_dt[subl_harv_indicator == 0L]

    if (nrow(realloc_dt) > 0L) {
      realloc_dt[, u := runif(.N)]
      setorder(realloc_dt, u)

      n_row_realloc <- nrow(realloc_dt)
      n_sub_kept <- round(p_rel_to_keep * n_row_realloc)
      n_sub_kept <- max(0L, min(n_sub_kept, n_row_realloc))

      realloc_dt[, idx := seq_len(.N)]
      realloc_dt[, keep_new := fifelse(idx <= n_sub_kept, 1L, 0L)]
      realloc_dt[, rel_new  := fifelse(keep_new == 0L, 1L, 0L)]

      n_sub_kept <- realloc_dt[, sum(keep_new)]
      prop_sub_kept <- safe_divide(n_sub_kept, original_rel_eligible)

      realloc_dt[, `:=`(keep = keep_new, release = rel_new)]
      realloc_dt[, c("u", "idx", "keep_new", "rel_new") := NULL]

      fish_dt <- rbindlist(list(realloc_dt, base_dt), use.names = TRUE)
    }
  }

  if (keep_to_rel == 1 && original_sum_keep > 0) {
    if (all_keep_to_rel == 1) {
      n_legal_rel <- fish_dt[, sum(keep)]
      prop_legal_rel <- safe_divide(n_legal_rel, fish_dt[, sum(keep)])
      fish_dt[, kept_to_released_flag := keep]
      fish_dt[, release := keep + release]
      fish_dt[, keep := 0L]
    } else {
      realloc_dt <- fish_dt[keep == 1L]
      base_dt    <- fish_dt[keep == 0L]

      if (nrow(realloc_dt) > 0L) {
        realloc_dt[, u := runif(.N)]
        setorder(realloc_dt, u)
        realloc_dt[, idx := seq_len(.N)]

        n_row_realloc <- nrow(realloc_dt)
        n_legal_rel <- round(p_keep_to_rel * n_row_realloc)
        n_legal_rel <- max(0L, min(n_legal_rel, n_row_realloc))
        prop_legal_rel <- safe_divide(n_legal_rel, fish_dt[, sum(keep)])

        realloc_dt[, rel_new  := fifelse(idx <= n_legal_rel, 1L, 0L)]
        realloc_dt[, keep_new := fifelse(rel_new == 0L, 1L, 0L)]
        realloc_dt[, kept_to_released_flag := fifelse(rel_new == 1L, 1L, 0L)]
        realloc_dt[, `:=`(keep = keep_new, release = rel_new)]
        realloc_dt[, c("u", "idx", "keep_new", "rel_new") := NULL]

        fish_dt <- rbindlist(list(realloc_dt, base_dt), use.names = TRUE)
      }
    }
  }

  if (utility_adjust) {
    fish_dt[, keep_util := fifelse(keep == 1L | kept_to_released_flag == 1L, 1L, 0L)]
    fish_dt[, release_util := fifelse(release == 1L & kept_to_released_flag == 0L, 1L, 0L)]
  } else {
    fish_dt[, keep_util := keep]
    fish_dt[, release_util := release]
  }

  fish_dt[, keep_weight_lb := keep * fish_weight_lb]
  fish_dt[, release_weight_lb := release * fish_weight_lb]
  fish_dt[, discmort_weight_lb := release_weight_lb * Discard_mortality]


  trip_out_pos <- fish_dt[, .(
    keep_n = sum(keep),
    rel_n = sum(release),
    keep_util_n = sum(keep_util),
    rel_util_n = sum(release_util),
    keep_weight_lb = sum(keep_weight_lb, na.rm = TRUE),
    release_weight_lb = sum(release_weight_lb, na.rm = TRUE),
    discmort_weight_lb = sum(discmort_weight_lb, na.rm = TRUE)
  ), by = key_cols]




  setnames(
    trip_out_pos,
    old = c("keep_n", "rel_n", "keep_util_n", "rel_util_n", "keep_weight_lb", "release_weight_lb", "discmort_weight_lb"),
    new = c(keep_col, rel_col, util_keep_col, util_rel_col, keep_wt_col, rel_wt_col, disc_wt_col)
  )

  trip_out <- rbindlist(list(trip_out_pos, trip_out_zero), use.names = TRUE, fill = TRUE)
  setkeyv(trip_out, key_cols)

  list(
    trip = trip_out,
    n_sub_kept = n_sub_kept,
    n_legal_rel = n_legal_rel,
    prop_sub_kept = prop_sub_kept,
    prop_legal_rel = prop_legal_rel,
    original_rel_eligible = original_rel_eligible
  )
}


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


# one season-draw-mode run; expects s, i, md in the parent environment
dtrip_all <- as.data.table(read_fst(file.path(final_process_misc_cd, "directed_trip_draws.fst")))
dtrip_all[, season := cod_hadd_season(date_parsed)]
dtrip_all <- dtrip_all[, .(draw, mode, date_parsed, season, dtrip,
                           cod_bag, cod_min, hadd_bag, hadd_min)]

setkey(dtrip_all, draw, season, mode, date_parsed)
months_md <- unique(as.integer(format(dtrip_all$date_parsed, "%m")))

if (nrow(dtrip_all) == 0L || sum(dtrip_all$dtrip, na.rm = TRUE) == 0) {

  calib_comparison1 <- data.table(
    mode = md,
    species = c("cod", "hadd"),
    MRIP_keep = NA_real_,
    model_keep = 0,
    diff_keep = NA_real_,
    pct_diff_keep = NA_real_,
    MRIP_rel = NA_real_,
    model_rel = 0,
    diff_rel = NA_real_,
    pct_diff_rel = NA_real_,
    MRIP_catch = NA_real_,
    model_catch = 0,
    diff_catch = NA_real_,
    pct_diff_catch = NA_real_,
    rel_to_keep_new = NA_real_,
    keep_to_rel_new = NA_real_,
    p_rel_to_keep_new = NA_real_,
    p_keep_to_rel_new = NA_real_,
    draw = i,
    season = s
  )

} else {

  dtrip_draw <- dtrip_all[list(i, s, md)]

  catch_path_fst <- file.path(final_process_calib_catch_cd, paste0("calib_catch_draws_", i, ".fst"))
  catch_data <- as.data.table(read_fst(catch_path_fst))
  setnames(
    catch_data,
    old = c("cod_cat_sim", "hadd_cat_sim", "cost_sim"),
    new = c("cod_cat", "hadd_cat", "cost"),
    skip_absent = TRUE
  )

  catch_data[, season := cod_hadd_season(date_parsed)]

  catch_data <- merge(
    catch_data[mode == md & season == s],
    dtrip_draw[, .(mode, date_parsed, dtrip, cod_bag, cod_min, hadd_bag, hadd_min)],
    by = c("mode", "date_parsed"),
    all.x = TRUE
  )

  angler_cols <- intersect(
    c("date_parsed", "mode", "tripid", "total_trips_12", "fish_pref_more",
      "educ1", "educ2", "educ3", "own_boat", "cost", "age",
      grep("^beta", names(catch_data), value = TRUE)),
    names(catch_data)
  )
  angler_dems <- unique(catch_data[, ..angler_cols])

  cod_size_data  <- size_lookup[list("cod",  i, s), .(fitted_prob, length)]
  hadd_size_data <- size_lookup[list("hadd", i, s), .(fitted_prob, length)]


  floor_subl_cod_harv   <- min(dtrip_all$cod_min, na.rm = TRUE) - cod_floor_below_min_in * 2.54
  floor_subl_hadd_harv  <- min(dtrip_all$hadd_min,   na.rm = TRUE) - hadd_floor_below_min_in * 2.54

  cod_res <- simulate_species_realloc(
    catch_dt = catch_data,
    catch_col = "cod_cat",
    bag_col = "cod_bag",
    min_col = "cod_min",
    size_dt = cod_size_data,
    species_prefix = "cod",
    floor_sublegal = floor_subl_cod_harv,
    rel_to_keep = rel_to_keep_cod,
    keep_to_rel = keep_to_rel_cod,
    p_rel_to_keep = p_rel_to_keep_cod,
    p_keep_to_rel = p_keep_to_rel_cod,
    all_keep_to_rel = all_keep_to_rel_cod,
    utility_adjust = TRUE
  )
  # Debugging scaffold (not executed): the argument values for the cod call
  # above, kept so a developer can step through simulate_species_realloc() line
  # by line by assigning these in the console.
  # catch_dt = catch_data
  # catch_col = "cod_cat"
  # bag_col = "cod_bag"
  # min_col = "cod_min"
  # size_dt = cod_size_data
  # species_prefix = "cod"
  # floor_sublegal = floor_subl_cod_harv
  # rel_to_keep = rel_to_keep_cod
  # keep_to_rel = keep_to_rel_cod
  # p_rel_to_keep = p_rel_to_keep_cod
  # p_keep_to_rel = p_keep_to_rel_cod
  # all_keep_to_rel = all_keep_to_rel_cod
  # utility_adjust = TRUE
  hadd_res <- simulate_species_realloc(
    catch_dt = catch_data,
    catch_col = "hadd_cat",
    bag_col = "hadd_bag",
    min_col = "hadd_min",
    size_dt = hadd_size_data,
    species_prefix = "hadd",
    floor_sublegal = floor_subl_hadd_harv,
    rel_to_keep = rel_to_keep_hadd,
    keep_to_rel = keep_to_rel_hadd,
    p_rel_to_keep = p_rel_to_keep_hadd,
    p_keep_to_rel = p_keep_to_rel_hadd,
    all_keep_to_rel = all_keep_to_rel_hadd,
    utility_adjust = TRUE
  )


  n_sub_kept_cod <- cod_res$n_sub_kept
  n_legal_rel_cod <- cod_res$n_legal_rel
  prop_sub_kept_cod <- cod_res$prop_sub_kept
  prop_legal_rel_cod <- cod_res$prop_legal_rel
  original_rel_eligible_cod <- cod_res$original_rel_eligible

  n_sub_kept_hadd <- hadd_res$n_sub_kept
  n_legal_rel_hadd <- hadd_res$n_legal_rel
  prop_sub_kept_hadd <- hadd_res$prop_sub_kept
  prop_legal_rel_hadd <- hadd_res$prop_legal_rel
  original_rel_eligible_hadd <- hadd_res$original_rel_eligible

  key_cols <- c("date_parsed", "mode", "tripid", "catch_draw")
  setkeyv(cod_res$trip, key_cols)
  setkeyv(hadd_res$trip, key_cols)

  trip_data <- merge(cod_res$trip, hadd_res$trip, by = key_cols, all = TRUE)

  zero_fill_cols <- intersect(
    c("tot_keep_cod_new", "tot_rel_cod_new", "util_keep_cod_new", "util_rel_cod_new",
      "tot_keep_hadd_new", "tot_rel_hadd_new", "util_keep_hadd_new", "util_rel_hadd_new",
      "tot_keep_cod_weight_lb_new", "tot_rel_cod_weight_lb_new", "tot_discmort_cod_weight_lb_new",
      "tot_keep_hadd_weight_lb_new", "tot_rel_hadd_weight_lb_new", "tot_discmort_hadd_weight_lb_new"),
    names(trip_data)
  )

  for (cc in zero_fill_cols) {
    set(trip_data, which(is.na(trip_data[[cc]])), cc, 0L)
  }

  trip_data[, `:=`(
    tot_hadd_catch  = tot_keep_hadd_new + tot_rel_hadd_new,
    tot_cod_catch   = tot_keep_cod_new + tot_rel_cod_new
  )]


  setkey(angler_dems, date_parsed, mode, tripid)
  trip_data <- merge(trip_data, angler_dems, by = c("date_parsed", "mode", "tripid"), all.x = TRUE)

  setorder(trip_data, date_parsed, mode, tripid, catch_draw)

  baseline_outcomes <- copy(trip_data)
  setnames(
    baseline_outcomes,
    old = c("tot_keep_hadd_new", "tot_keep_cod_new","util_keep_cod_new", "util_keep_hadd_new",
            "tot_rel_hadd_new", "tot_rel_cod_new", "util_rel_cod_new", "util_rel_hadd_new",
            "tot_hadd_catch", "tot_cod_catch",
            "tot_keep_hadd_weight_lb_new", "tot_keep_cod_weight_lb_new",
            "tot_rel_hadd_weight_lb_new", "tot_rel_cod_weight_lb_new",
            "tot_discmort_cod_weight_lb_new", "tot_discmort_hadd_weight_lb_new"),
    new = c("tot_keep_hadd_base", "tot_keep_cod_base", "util_keep_cod_base", "util_keep_hadd_base",
            "tot_rel_hadd_base", "tot_rel_cod_base","util_rel_cod_base",  "util_rel_hadd_base",
            "tot_cat_hadd_base", "tot_cat_cod_base",
            "tot_keep_hadd_weight_lb_base", "tot_keep_cod_weight_lb_base",
            "tot_rel_hadd_weight_lb_base", "tot_rel_cod_weight_lb_base",
            "tot_discmort_cod_weight_lb_base", "tot_discmort_hadd_weight_lb_base"),
    skip_absent = TRUE
  )

  fst::write_fst(
    baseline_outcomes,
    file.path(final_process_outcomes_cd,
              paste0("base_outcomes_", s, "_", md, "_", i, ".fst"))
  )

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
  mean_trip_data[, c("vA_trip", "vA_optout", "catch_draw",
                     "util_keep_cod_new", "util_rel_cod_new",
                     "util_keep_hadd_new", "util_rel_hadd_new") := NULL]

  wt_cols <- c(
    "tot_keep_cod_new", "tot_rel_cod_new", "tot_cod_catch",
    "tot_keep_hadd_new", "tot_rel_hadd_new", "tot_hadd_catch",
    "tot_keep_cod_weight_lb_new", "tot_rel_cod_weight_lb_new",
    "tot_keep_hadd_weight_lb_new", "tot_rel_hadd_weight_lb_new",
    "tot_discmort_cod_weight_lb_new", "tot_discmort_hadd_weight_lb_new"
  )

  wt_cols <- intersect(wt_cols, names(mean_trip_data))

  mean_trip_data[,
                 (wt_cols) := lapply(.SD, function(x) x * probA),
                 .SDcols = wt_cols]

  mean_trip_data <- merge(mean_trip_data, dtrip_draw, by = c("mode", "date_parsed"), all.x = TRUE)
  drop_reg_cols <- intersect(c("hadd_bag", "hadd_min", "cod_bag", "cod_min"), names(mean_trip_data))
  if (length(drop_reg_cols)) mean_trip_data[, (drop_reg_cols) := NULL]

  mean_trip_data[, mean_prob := mean(probA), by = .(mode, date_parsed)]
  mean_trip_data[is.na(mean_prob) | mean_prob == 0, mean_prob := NA_real_]
  mean_trip_data[, sims := fifelse(!is.na(mean_prob), round(dtrip / mean_prob), 0)]
  mean_trip_data[, expand := sims / n_draws]
  mean_trip_data[, n_choice_occasions := 1]

  expand_cols <- intersect(c(wt_cols, "n_choice_occasions", "probA"), names(mean_trip_data))

  mean_trip_data[,
                 (expand_cols) := lapply(.SD, function(x) x * expand),
                 .SDcols = expand_cols]

  for (j in names(mean_trip_data)) setattr(mean_trip_data[[j]], "label", NULL)

  aggregate_trip_data <- mean_trip_data[, lapply(.SD, sum),
                                        by = .(date_parsed, mode),
                                        .SDcols = expand_cols]

  aggregate_trip_data[, month := data.table::month(date_parsed)]

  setnames(
    aggregate_trip_data,
    old = c("probA", "tot_cod_catch", "tot_hadd_catch",
            "tot_keep_cod_new", "tot_keep_hadd_new",
            "tot_rel_cod_new", "tot_rel_hadd_new" ),
    new = c("estimated_trips", "cod_catch", "hadd_catch",
            "cod_keep", "hadd_keep",
            "cod_rel", "hadd_rel"),
    skip_absent = TRUE
  )

  n_choice_out <- aggregate_trip_data[, .(date_parsed, mode, n_choice_occasions, estimated_trips)]
  fst::write_fst(
    n_choice_out,
    file.path(final_process_choice_occasions_cd,
              paste0("n_choice_occasions_", s, "_", md, "_", i,".fst"))
  )

  list_names <- c(
    "hadd_catch", "hadd_keep", "hadd_rel",
    "cod_catch", "cod_keep", "cod_rel",
    "estimated_trips", "n_choice_occasions",
    "tot_keep_cod_weight_lb_new", "tot_rel_cod_weight_lb_new",
    "tot_keep_hadd_weight_lb_new", "tot_rel_hadd_weight_lb_new",
    "tot_discmort_cod_weight_lb_new", "tot_discmort_hadd_weight_lb_new"
  )

  list_names <- intersect(list_names, names(aggregate_trip_data))

  summed_results <- aggregate_trip_data[  ,
                                          lapply(.SD, sum, na.rm = TRUE),
                                          by = .(mode),
                                          .SDcols = list_names  ]

   eligible_dt <- data.table::data.table(
    mode = md,
    species = c("cod", "hadd"),
    original_rel_eligible = c(
      original_rel_eligible_cod,
      original_rel_eligible_hadd
    )
  )

  MRIP_comparison_draw <- as.data.table(MRIP_comparison)[
    draw == i & season == s & mode == md,
    .(mode, cod_keep, cod_rel, cod_catch,
      hadd_keep, hadd_rel, hadd_catch)
  ]

  calib_comparison1 <- build_compare_table(summed_results, MRIP_comparison_draw, md,
                                           eligible_dt = eligible_dt)
  calib_comparison1[, `:=`(draw = i, season = s)]
}

