

################################################################################
# Dev paths note (no full script header yet - out of scope for this pass):
# 7 hardcoded absolute paths to a developer's local machine (C:\ or E:\),
# at lines 44, 45, 47, 48, 49 and 50; plus 1 more in a commented-out line (43).
################################################################################

#Local loop for prediction

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

s<-"summer"
md<-"pr"
dr<-1

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

n_draws<-50

# Data read for non-shiny run of predict_rec_catch.R
## Run this script prior to predict rec catch

#Lou's repos
#test_code_cd="C:/Users/andrew.carr-harris/Desktop/Git/groundfishRDM/Code/test_code"
input_data_cd="E:/Lou_projects/groundfishRDM/input_data"
iterative_input_data_cd="E:/Lou_projects/groundfishRDM/process_data"

final_process_data_cd="E:/Lou_projects/groundfishRDM/final_process_data"
final_process_outcomes_cd="E:/Lou_projects/groundfishRDM/final_process_data/base_outcomes"
final_process_choice_occasions_cd="E:/Lou_projects/groundfishRDM/final_process_data/n_choice_occasions"
final_process_misc_cd="E:/Lou_projects/groundfishRDM/final_process_data/miscellaneous"

code_cd=here("Code", "test_code")

directed_trips_draw<-read_fst(file.path(final_process_misc_cd, paste0("directed_trip_draws_final.fst"))) %>%
  tibble::tibble() %>%
  dplyr::select(mode, day,  dtrip, draw,
                starts_with("cod_bag"), starts_with("cod_min"), starts_with("hadd_bag"),starts_with("hadd_min")) %>%
  dplyr::filter(draw == dr) %>%
  data.table::as.data.table() %>%
  dplyr::mutate(date=as.Date(day, format = "%d%b%Y"),
                season = ifelse(lubridate::month(date) %in% c(9, 10, 11, 12, 1, 2, 3, 4), "winter", "summer")) %>%
  as.data.table()

inch_to_cm <- function(x) x * 2.54

# Initialize “closed” defaults
directed_trips_draw[, `:=`(
  cod_bag_y2_new = 0L,
  cod_min_y2_new = 100,   # effectively closed (very high min)
  hadd_bag_y2_new = 0L,
  hadd_min_y2_new = 100
)]

# pr mode → open September and October
# fh mode → open September and October
directed_trips_draw[
  lubridate::month(date) %in% c(9, 10),
  `:=`(
    cod_bag_y2_new = 1L,                     # change if needed
    cod_min_y2_new = inch_to_cm(23)
  )
]

# -----------------------------
# HADDOCK: open 5/1–2/28 and 4/1–4/30
# bag: 5
# min size: 17 inches -> cm
# -----------------------------

directed_trips_draw[
  lubridate::month(date) %in% c(5,6,7,8,9,10,11,12,1,2,4),
  `:=`(
    hadd_bag_y2_new = 15L,
    hadd_min_y2_new = inch_to_cm(17)
  )
]



get_lowest_min_size_draw<-read_fst(file.path(final_process_misc_cd, paste0("directed_trip_draws_final.fst"))) %>%
  dplyr::select(mode, day,  dtrip, draw,
                starts_with("cod_bag"), starts_with("cod_min"), starts_with("hadd_bag"),starts_with("hadd_min")) %>%
  data.table::as.data.table() %>%
  dplyr::mutate(date=as.Date(day, format = "%d%b%Y")) %>%
  as.data.table()

# Initialize “closed” defaults
get_lowest_min_size_draw[, `:=`(
  cod_bag_y2_new = 0L,
  cod_min_y2_new = 100,   # effectively closed (very high min)
  hadd_bag_y2_new = 0L,
  hadd_min_y2_new = 100
)]

# pr mode → open September and October
# fh mode → open September and October
get_lowest_min_size_draw[
  lubridate::month(date) %in% c(9, 10),
  `:=`(
    cod_bag_y2_new = 1L,                     # change if needed
    cod_min_y2_new = inch_to_cm(23)
  )
]

# -----------------------------
# HADDOCK: open 5/1–2/28 and 4/1–4/30
# bag: 5
# min size: 17 inches -> cm
# -----------------------------
get_lowest_min_size_draw[
  lubridate::month(date) %in% c(5,6,7,8,9,10,11,12,1,2,4),
  `:=`(
    hadd_bag_y2_new = 15L,
    hadd_min_y2_new = inch_to_cm(17)
  )
]

cod_min_size_FY_draw<-min(get_lowest_min_size_draw$cod_min_y2_new)
hadd_min_size_FY_draw<-min(get_lowest_min_size_draw$hadd_min_y2_new)

catch_data0 <- list()
base_outcomes_angler_dems0 <- list()
n_choice_occasions0 <- list()

mode_draw <- c("pr", "fh")
season_draw <- c("summer", "winter")

k<-1

for (md in mode_draw) {
  for (s in season_draw){

    catch_data0[[k]] <- fst::read_fst(file.path(final_process_outcomes_cd, paste0("base_outcomes_final_",s, "_", md, "_", dr,".fst"))) %>%
      dplyr::left_join(directed_trips_draw, by=c("mode", "date")) %>%
      dplyr::rename(tot_cod_catch_base = tot_cod_catch,
                    tot_hadd_catch_base = tot_hadd_catch) %>%
      dplyr::mutate(cod_cat=tot_cod_catch_base,
                    hadd_cat=tot_hadd_catch_base) %>%
      dplyr::select(date, mode, draw,  tripid, catch_draw, season,
                    cod_cat, hadd_cat, starts_with("cod_bag"), starts_with("cod_min"),
                    starts_with("hadd_bag"),starts_with("hadd_min")) %>%
      as.data.table()

    base_outcomes_angler_dems0[[k]] <- fst::read_fst(file.path(final_process_outcomes_cd, paste0("base_outcomes_final_",s, "_", md, "_", dr,".fst"))) %>%
      dplyr::select(date, mode,  tripid, catch_draw,
                    tot_keep_cod_base, tot_rel_cod_base,
                    tot_keep_hadd_base, tot_rel_hadd_base,
                    starts_with("beta"),
                    total_trips_12, fish_pref_more, educ1, educ2, educ3, own_boat, cost) %>%
      dplyr::rename(date_parsed=date) %>%
      as.data.table()

    n_choice_occasions0[[k]] <- fst::read_fst(file.path(final_process_choice_occasions_cd, paste0("n_choice_occasions_final_",s, "_", md, "_", dr,".fst"))) %>%
      dplyr::rename(date_parsed=date)  %>%
      as.data.table()

    k<-k+1

  }
}

catch_data_draw <- bind_rows(catch_data0)
base_outcomes_angler_dems_draw <- bind_rows(base_outcomes_angler_dems0)
n_choice_occasions_draw <- bind_rows(n_choice_occasions0)

rm(base_outcomes_angler_dems0, n_choice_occasions0, catch_data0)

# Size data used in projections is "proj_catch_at_length.fst"
# For testing, change the size data file to "baseline_catch_at_length.fst"
cod_size_data_draw <- read_fst(file.path(final_process_misc_cd, "proj_catch_at_length.fst"))  %>%
  dplyr::filter(species=="cod", draw==dr) %>%
  dplyr::filter(!is.na(fitted_prob)) %>%
  dplyr::select(fitted_prob, length, season) %>%
  as.data.table()

hadd_size_data_draw <- read_fst(file.path(final_process_misc_cd, "proj_catch_at_length.fst"))  %>%
  dplyr::filter(species=="hadd", draw==dr) %>%
  dplyr::filter(!is.na(fitted_prob)) %>%
  dplyr::select(fitted_prob, length, season) %>%
  as.data.table()

calendar_adjustments_draw <- read_fst(file.path(final_process_misc_cd, paste0("calendar_adj_final.fst"))) %>%
  dplyr::filter(draw==dr) %>%
  dplyr::select(-dtrip, -dtrip_y2, -draw, -good_draw) %>%
  as.data.table()

# Pull in calibration comparison information about trip-level harvest/discard re-allocations
calib_comparison_draw<-read_fst(file.path(final_process_misc_cd, "calibrated_model_stats_final.fst")) %>%
  dplyr::filter(draw==dr) %>%
  as.data.table()

calib_comparison_draw<-calib_comparison_draw %>%
  dplyr::rename(n_legal_rel_hadd=n_legal_hadd_rel,
                n_legal_rel_cod=n_legal_cod_rel,
                n_sub_kept_hadd=n_sub_hadd_kept,
                n_sub_kept_cod=n_sub_cod_kept,
                prop_legal_rel_hadd=prop_legal_hadd_rel,
                prop_legal_rel_cod=prop_legal_cod_rel,
                prop_sub_kept_hadd=prop_sub_hadd_kept,
                prop_sub_kept_cod=prop_sub_cod_kept,
                convergence_cod=cod_convergence,
                convergence_hadd=hadd_convergence)

##########
# List of species suffixes
species_suffixes <- c("cod", "hadd")

# Get all variable names
all_vars <- names(calib_comparison_draw)

# Identify columns that are species-specific (contain _cod or _hadd)
species_specific_vars <- all_vars[
  str_detect(all_vars, paste0("(_", species_suffixes, ")$", collapse = "|"))
]

id_vars <- setdiff(all_vars, species_specific_vars)

## --- build draw-specific inputs ---
calib_comparison_draw<-calib_comparison_draw %>%
  dplyr::select(mode, season, all_of(species_specific_vars))

# Extract base variable names (without __cod or _hadd)
base_names <- unique(str_replace(species_specific_vars, "_(cod|hadd)$", ""))

# Pivot the data longer on the species-specific columns
calib_comparison_draw <- calib_comparison_draw %>%
  pivot_longer(
    cols = all_of(species_specific_vars),
    names_to = c(".value", "species"),
    names_pattern = "(.*)_(cod|hadd)"
  ) %>%
  dplyr::distinct()

## --- make draw-specific inputs visible to simulate_cod/hadd by assigning to global names ---

cod_size_data           <<- cod_size_data_draw
hadd_size_data          <<- hadd_size_data_draw
calendar_adjustments    <<- calendar_adjustments_draw
calib_comparison        <<- calib_comparison_draw
directed_trips          <<- directed_trips_draw
catch_data              <<- catch_data_draw
base_outcomes_angler_dems <<- base_outcomes_angler_dems_draw
n_choice_occasions      <<- n_choice_occasions_draw
cod_min_size_FY         <<- cod_min_size_FY_draw
hadd_min_size_FY        <<- hadd_min_size_FY_draw



########## cod  ##############
  data.table::setDTthreads(1)
  #Step 2: Reorganize calibration parameters#
  calib_lookup <- calib_comparison %>%
    dplyr::select(mode,season, species, rel_to_keep, keep_to_rel,
                  p_rel_to_keep, p_keep_to_rel,
                  prop_sub_kept, prop_legal_rel) %>%
    tidyr::pivot_wider(
      names_from = species,
      values_from = c(rel_to_keep, keep_to_rel, p_rel_to_keep, p_keep_to_rel, prop_sub_kept, prop_legal_rel),
      names_glue = "{.value}_{species}"
    )

  setDT(calib_lookup)


  system.time({
  # Original way to compute trip outcomes
  #setkey(calib_lookup, mode)

  # Extract calibration parameters
  calib_row <- calib_lookup[mode == md & season==s]

  rel_to_keep_cod     <- calib_row$rel_to_keep_cod
  keep_to_rel_cod     <- calib_row$keep_to_rel_cod
  p_rel_to_keep_cod   <- calib_row$p_rel_to_keep_cod
  p_keep_to_rel_cod   <- calib_row$p_keep_to_rel_cod
  prop_sublegal_kept_cod <- calib_row$prop_sub_kept_cod
  prop_legal_rel_cod     <- calib_row$prop_legal_rel_cod
  all_keep_to_rel_cod <- as.integer(p_keep_to_rel_cod == 1)

  # Filter trip data by mode and season
  directed_trips_sub <- directed_trips[mode == md][season==s]

  # Filter size data by season
  cod_size_data_sub <- cod_size_data[season==s]


  #Create lowest length at which fish may be illegally harvested.
  #1) This "floor" (floor_subl_harvest) size will be 3 inches (*2.54 to convert to cm's)
  #   below the lowest minimum size across the simulation period
  #2) If the fishery is closed for the simulation period, floor_subl_harvest is the
  #   lowest minimum size across the FY
  #3) I don't think there will be any cases where either species is closed the entire season

  #

  floor_subl_cod_harv<-min(directed_trips_sub$cod_min_y2_new)-3*2.54

  if (min(directed_trips_sub$cod_min_y2_new)==100){
    floor_subl_cod_harv<-cod_min_size_FY-3*2.54
  }

  # Filter catch data by mode and season
  catch_data_sub <- catch_data[mode == md & season==s]
  cod_catch_check <- sum(catch_data_sub$cod_cat)

  if (cod_catch_check == 0) {

    size_data<-catch_data_sub %>%
      dplyr::select("mode","tripid", "catch_draw","date") %>%
      dplyr::mutate(keep_cod_1=0, release_cod_1=0)

    zero_catch <-data.frame(
      date = character(0),
      catch_draw = numeric(0),
      tripid = numeric(0),
      mode = character(0) ,
      tot_keep_cod_new = numeric(0),
      tot_rel_cod_new = numeric(0)
    )

    return(list(
      trip_data = catch_data_sub[, .(date, catch_draw, tripid, mode,
                                     tot_keep_cod_new = 0L, tot_rel_cod_new = 0L,
                                     domain2 = paste0(date, "_", mode, "_", catch_draw, "_", tripid))],
      zero_catch = zero_catch,
      size_data=size_data))
  }

  if (cod_catch_check != 0) {

    # Expand fish by number caught
    cod_catch_data <- catch_data_sub[cod_cat > 0]
    cod_catch_data <- cod_catch_data[rep(1:.N, cod_cat)]
    cod_catch_data[, fishid := .I]

    # Sample fish lengths
    cod_catch_data[, fitted_length := sample(cod_size_data_sub$length, .N,
                                             prob = cod_size_data_sub$fitted_prob, replace = TRUE)]

    # Identify keepable fish
    cod_catch_data[, posskeep := as.integer(fitted_length >= cod_min_y2_new)]
    cod_catch_data[, csum_keep := ave(posskeep, tripid, date, mode, catch_draw, FUN = cumsum)]
    cod_catch_data[, keep_adj := as.integer(posskeep == 1 & csum_keep <= cod_bag_y2_new)]
    cod_catch_data[, `:=`(keep = keep_adj, release = 1L - keep_adj)]
    cod_catch_data[, subl_harv_indicator := as.integer(release == 1 & fitted_length >= floor_subl_cod_harv)]

    # --- Reallocate rel to keep ---
    if (rel_to_keep_cod == 1 && sum(cod_catch_data$release) > 0) {
      sublegal_keeps <- cod_catch_data[subl_harv_indicator == 1]
      base <- cod_catch_data[subl_harv_indicator == 0]

      n_to_keep <- round(prop_sublegal_kept_cod * nrow(sublegal_keeps))
      sublegal_keeps[, uniform := runif(.N)]
      data.table::setorder(sublegal_keeps, uniform)
      sublegal_keeps[, fishid2 := .I]
      sublegal_keeps[, `:=`(
        keep = as.integer(fishid2 <= n_to_keep),
        release = as.integer(fishid2 > n_to_keep)
      )]


      # Drop helper columns *only if they exist*
      cols_to_drop_sub <- intersect(names(sublegal_keeps), c("uniform", "fishid2", "subl_harv_indicator"))
      sublegal_keeps[, (cols_to_drop_sub) := NULL]

      cols_to_drop_base <- intersect(names(base), "subl_harv_indicator")
      base[, (cols_to_drop_base) := NULL]

      cod_catch_data <- data.table::rbindlist(list(sublegal_keeps, base), use.names = TRUE, fill = TRUE)
    }

    # --- Reallocate keep to rel ---
    if (keep_to_rel_cod == 1 && sum(cod_catch_data$keep) > 0) {
      if (all_keep_to_rel_cod == 1) {
        cod_catch_data[, `:=`(release = keep + release, keep = 0L)]
      } else {
        kept <- cod_catch_data[keep == 1]
        base <- cod_catch_data[keep == 0]
        n_to_release <- round(prop_legal_rel_cod * nrow(kept))

        kept[, uniform := runif(.N)]
        data.table::setorder(kept, uniform)
        kept[, fishid2 := .I]
        kept[, `:=`(
          release = as.integer(fishid2 <= n_to_release),
          keep = as.integer(fishid2 > n_to_release)
        )]
        kept[, `:=`(uniform = NULL, fishid2 = NULL)]

        cod_catch_data <- data.table::rbindlist(list(kept, base), use.names = TRUE)
      }
    }

    # --- Append length-specific keep/release summary ---
    cod_catch_data <- data.table::as.data.table(cod_catch_data)

    new_size_data <- cod_catch_data[, .(
      keep = sum(keep),
      release = sum(release)
    ), by = .(mode, date, catch_draw, tripid, fitted_length)]

    keep_size_data <- new_size_data %>%
      dplyr::select(-release) %>%
      tidyr::pivot_wider(
        names_from = fitted_length,
        names_glue = "keep_cod_{fitted_length}",
        names_sort = TRUE,
        values_from = keep,
        values_fill = 0
      )

    release_size_data <- new_size_data %>%
      dplyr::select(-keep) %>%
      tidyr::pivot_wider(
        names_from = fitted_length,
        names_glue = "release_cod_{fitted_length}",
        names_sort = TRUE,
        values_from = release,
        values_fill = 0
      )

    keep_release_size_data <- keep_size_data %>%
      dplyr::left_join(release_size_data, by = c("date", "mode", "tripid", "catch_draw"))


    # Summarize trip-level data
    trip_summary <- cod_catch_data[, .(tot_keep_cod_new = sum(keep), tot_rel_cod_new = sum(release)),
                                   by = .(date, catch_draw, tripid, mode)]

    # Add zero-catch trips
    zero_catch <- catch_data_sub[cod_cat == 0, .(date, catch_draw, tripid, mode)]
    zero_catch[, `:=`(tot_keep_cod_new = 0L, tot_rel_cod_new = 0L)]

    trip_data <- data.table::rbindlist(list(trip_summary, zero_catch))
    trip_data[, domain2 := paste0(date, "_", mode, "_", catch_draw, "_", tripid)]


  }

  })
sum(trip_data$tot_keep_cod_new)
sum(trip_data$tot_rel_cod_new)



# functionalized trip simulation
# probability bins for discrete PMF:
# returns c(p_lt_floor, p_floor_to_min, p_ge_min)
pmf_bins3 <- function(length, prob, floor, min1) {
  o <- order(length)
  length <- length[o]; prob <- prob[o]

  p1 <- sum(prob[length < floor])
  p2 <- sum(prob[length >= floor & length < min1])
  p3 <- sum(prob[length >= min1])

  ps <- c(p1, p2, p3)
  if (!is.finite(sum(ps)) || sum(ps) <= 0) stop("Invalid PMF bins: sum=0")
  ps / sum(ps) # normalize (safety)
}

# fast simulation for many trips with same (floor, min) and varying n and bag
# uses 2 binomials instead of multinomial
simulate_counts_fast <- function(n_catch, bag, probs3,
                                 rel_to_keep, keep_to_rel, all_keep_to_rel,
                                 prop_sub_kept, prop_legal_rel) {

  rel_to_keep     <- as.integer(rel_to_keep)[1]
  keep_to_rel     <- as.integer(keep_to_rel)[1]
  all_keep_to_rel <- as.integer(all_keep_to_rel)[1]
  prop_sub_kept   <- as.numeric(prop_sub_kept)[1]
  prop_legal_rel  <- as.numeric(prop_legal_rel)[1]

  n_catch <- as.integer(n_catch)
  bag     <- as.integer(bag)

  p1 <- probs3[1]; p2 <- probs3[2]; p3 <- probs3[3]
  # conditional prob for floor<=len<min among len<min
  denom <- p1 + p2
  p2_cond <- if (denom > 0) p2 / denom else 0

  # draw n_ge_min and n_floor_to_min
  n_ge_min <- stats::rbinom(length(n_catch), size = n_catch, prob = p3)
  rem      <- n_catch - n_ge_min
  n_floor_to_min <- if (p2_cond > 0) stats::rbinom(length(rem), size = rem, prob = p2_cond) else integer(length(rem))
  n_ge_floor <- n_ge_min + n_floor_to_min

  # baseline keep/release (bag only applies when >0 else 0)
  kept <- pmin(bag, n_ge_min)
  rel  <- n_catch - kept

  # released fish with length >= floor
  indicator <- pmax(n_ge_floor - kept, 0L)

  # rel -> keep
  if (as.integer(rel_to_keep) == 1L) {
    add_keep <- as.integer(round(prop_sub_kept * indicator))
    kept <- kept + add_keep
    rel  <- rel  - add_keep
  }

  # keep -> rel
  if (as.integer(keep_to_rel) == 1L) {
    if (as.integer(all_keep_to_rel) == 1L) {
      rel <- rel + kept
      kept <- 0L
    } else {
      move <- as.integer(round(prop_legal_rel * kept))
      kept <- kept - move
      rel  <- rel  + move
    }
  }

  list(keep = kept, rel = rel)
}



calib_lookup <- calib_comparison %>%
  dplyr::select(mode,season, species, rel_to_keep, keep_to_rel,
                p_rel_to_keep, p_keep_to_rel,
                prop_sub_kept, prop_legal_rel) %>%
  tidyr::pivot_wider(
    names_from = species,
    values_from = c(rel_to_keep, keep_to_rel, p_rel_to_keep, p_keep_to_rel, prop_sub_kept, prop_legal_rel),
    names_glue = "{.value}_{species}"
  )

setDT(calib_lookup)


#setkey(calib_lookup, mode)
system.time({
# Extract calibration parameters
calib_row <- calib_lookup[mode == md & season==s]
rel_to_keep_cod <- calib_row[["rel_to_keep_cod"]][[1]]
keep_to_rel_cod <- calib_row[["keep_to_rel_cod"]][[1]]
p_keep_to_rel_cod <- calib_row[["p_keep_to_rel_cod"]][[1]]
prop_sublegal_kept_cod <- calib_row[["prop_sub_kept_cod"]][[1]]
prop_legal_rel_cod <- calib_row[["prop_legal_rel_cod"]][[1]]
all_keep_to_rel_cod <- as.integer(p_keep_to_rel_cod == 1)

directed_trips_sub  <- directed_trips[mode == md & season == s]
cod_size_data_sub  <- cod_size_data[season == s]

floor_subl_cod_harv <- min(directed_trips_sub$cod_min_y2) - 3*2.54
if (min(directed_trips_sub$cod_min_y2) == 100) {
  floor_subl_cod_harv <- cod_min_size_FY - 3*2.54
}

catch_data_sub <- catch_data[mode == md & season == s,
                             .(date, mode, tripid, catch_draw,
                               cod_cat,
                               cod_bag_y2, cod_min_y2)
]

cod_catch_check <- sum(catch_data_sub$cod_cat, na.rm = TRUE)

if (cod_catch_check == 0) {
  zero_catch <- data.frame(
    date = character(0),
    catch_draw = numeric(0),
    tripid = numeric(0),
    mode = character(0),
    tot_keep_cod_new = numeric(0),
    tot_rel_cod_new = numeric(0)
  )

  return(list(
    trip_data = catch_data_sub[, .(date, catch_draw, tripid, mode,
                                   tot_keep_cod_new = 0L, tot_rel_cod_new = 0L)],
    zero_catch = zero_catch
  ))
}



# bag use: if bag<=0 then 0
catch_data_sub[, bag_use := data.table::fifelse(cod_bag_y2 > 0, as.integer(cod_bag_y2), 0L)]

# only simulate trips with cod_cat > 0
pos <- catch_data_sub[cod_cat > 0]

# --------------------------
# (0) NO-CHANGE (BASELINE) scenario
# min threshold = cod_min_y2 (original)
# bag = bag_use (original)
# --------------------------
pos[, min_size_thr0 := cod_min_y2]

mins0 <- sort(unique(pos$min_size_thr0))
prob_by_min0 <- lapply(mins0, function(mn) {
  pmf_bins3(
    length = cod_size_data_sub$length,
    prob   = cod_size_data_sub$fitted_prob,
    floor  = floor_subl_cod_harv,
    min1   = mn
  )
})
names(prob_by_min0) <- as.character(mins0)

pos[, `:=`(keep_base = 0L, rel_base = 0L)]
for (mn in mins0) {
  idx <- which(pos$min_size_thr0 == mn)
  if (!length(idx)) next

  out0 <- simulate_counts_fast(
    n_catch = pos$cod_cat[idx],
    bag     = pos$bag_use[idx],
    probs3  = prob_by_min0[[as.character(mn)]],
    rel_to_keep     = rel_to_keep_cod,
    keep_to_rel     = keep_to_rel_cod,
    all_keep_to_rel = all_keep_to_rel_cod,
    prop_sub_kept   = prop_sublegal_kept_cod,
    prop_legal_rel  = prop_legal_rel_cod
  )

  pos$keep_base[idx] <- out0$keep
  pos$rel_base[idx]  <- out0$rel
}

trip_data_base <- pos[, .(
  tot_keep_cod_base = sum(keep_base),
  tot_rel_cod_base  = sum(rel_base)
), by = .(date, catch_draw, tripid, mode)]

zero_catch_base <- catch_data_sub[cod_cat == 0, .(date, catch_draw, tripid, mode)]
zero_catch_base[, `:=`(tot_keep_cod_base = 0L, tot_rel_cod_base = 0L)]
trip_data_base <- data.table::rbindlist(list(trip_data_base, zero_catch_base), use.names = TRUE)
})


sum(trip_data$tot_keep_cod_new)
sum(trip_data$tot_rel_cod_new)
