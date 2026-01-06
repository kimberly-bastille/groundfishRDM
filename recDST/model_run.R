print("start model")
library(magrittr)
library(fst)
library(plyr)
library(dplyr)
library(lubridate)
library(conflicted)

conflicts_prefer(
  lubridate::yday(),
  dplyr::filter()
  )
#library(tidyverse)
#devtools::install_github("NEFSC/READ.SSB.groundfishRecDST")

Run_Name <- args[1]


saved_regs<- read.csv(here::here(paste0("saved_regs/regs_", Run_Name, ".csv")))

for (a in seq_len(nrow(saved_regs))) {
  # Extract name and value
  obj_name <- saved_regs$input[a]
  obj_value <- saved_regs$value[a]

  # Assign to object in the environment
  assign(obj_name, obj_value)
}


predictions_all = list()

n_draws<-50

mode_draw   <- c("pr", "fh")
season_draw <- c("summer", "winter")

param_grid <- expand.grid(
  md = mode_draw,
  s  = season_draw,
  stringsAsFactors = FALSE
)


fst::threads_fst(1)

disc_mort<- fst::read_fst(file.path(here::here("Data/miscellaneous"), "Discard_Mortality.fst")) %>%
  dplyr::rename(month=Month)

cod_size_data <- fst::read_fst(file.path(here::here("Data/miscellaneous"), "baseline_catch_at_length.fst"))  %>%
  dplyr::filter(species=="cod") %>%
  dplyr::filter(!is.na(fitted_prob)) %>%
  dplyr::select(fitted_prob, length, season, draw ) %>%
  data.table::as.data.table()

hadd_size_data <- fst::read_fst(file.path(here::here("Data/miscellaneous"), "baseline_catch_at_length.fst"))  %>%
  dplyr::filter(species=="hadd") %>%
  dplyr::filter(!is.na(fitted_prob)) %>%
  dplyr::select(fitted_prob, length, season, draw ) %>%
  data.table::as.data.table()

calendar_adjustments <- fst::read_fst(file.path(here::here("Data/miscellaneous"), paste0("calendar_adj_final.fst"))) %>%
  dplyr::select(-dtrip, -dtrip_y2, -good_draw) %>%
  data.table::as.data.table()

# Pull in calibration comparison information about trip-level harvest/discard re-allocations
calib_comparison<-fst::read_fst(file.path(here::here("Data/miscellaneous"), "calibrated_model_stats_final.fst")) %>%
  data.table::as.data.table()

#print(directed_trips)
directed_trips<-fst::read_fst(file.path(here::here("Data/miscellaneous"), paste0("directed_trip_draws_final.fst")))

directed_trips <- directed_trips %>%
  dplyr::select(mode, day, day_y2, dtrip, cod_bag_y2_alt, cod_min_y2_alt, hadd_bag_y2_alt, hadd_min_y2_alt, good_draw, draw) %>%
  dplyr::mutate(date_adj = lubridate::dmy(day),
                date_adj = lubridate::yday(date_adj)) %>%
  dplyr::mutate(
    cod_bag_y2_alt=dplyr::case_when(mode == "fh" & date_adj >= yday(ymd(codFH_seas1_op)) & date_adj <= yday(ymd(codFH_seas1_cl)) ~ as.numeric(codFH_1_bag), TRUE ~ cod_bag_y2_alt),
    cod_bag_y2_alt=dplyr::case_when(mode == "pr" & date_adj >= yday(ymd(codPR_seas1_op)) & date_adj <= yday(ymd(codPR_seas1_cl)) ~ as.numeric(codPR_1_bag), TRUE ~ cod_bag_y2_alt),
    cod_bag_y2_alt=dplyr::case_when(mode == "fh" & date_adj >= yday(ymd(codFH_seas2_op)) & date_adj <= yday(ymd(codFH_seas2_cl)) ~ as.numeric(codFH_2_bag), TRUE ~ cod_bag_y2_alt),
    cod_bag_y2_alt=dplyr::case_when(mode == "pr" & date_adj >= yday(ymd(codPR_seas2_op)) & date_adj <= yday(ymd(codPR_seas2_cl)) ~ as.numeric(codPR_2_bag), TRUE ~ cod_bag_y2_alt),
    cod_bag_y2_alt=dplyr::case_when(mode == "fh" & date_adj >= yday(ymd(codFH_seas3_op)) & date_adj <= yday(ymd(codFH_seas3_cl)) ~ as.numeric(codFH_3_bag), TRUE ~ cod_bag_y2_alt),
    cod_bag_y2_alt=dplyr::case_when(mode == "pr" & date_adj >= yday(ymd(codPR_seas3_op)) & date_adj <= yday(ymd(codPR_seas3_cl)) ~ as.numeric(codPR_3_bag), TRUE ~ cod_bag_y2_alt),

    cod_min_y2_alt=dplyr::case_when(mode == "fh" & date_adj >= yday(ymd(codFH_seas1_op)) & date_adj <= yday(ymd(codFH_seas1_cl)) ~ as.numeric(codFH_1_len)*2.54, TRUE ~ cod_min_y2_alt),
    cod_min_y2_alt=dplyr::case_when(mode == "pr" & date_adj >= yday(ymd(codPR_seas1_op)) & date_adj <= yday(ymd(codPR_seas1_cl)) ~ as.numeric(codPR_1_len)*2.54, TRUE ~ cod_min_y2_alt),
    cod_min_y2_alt=dplyr::case_when(mode == "fh" & date_adj >= yday(ymd(codFH_seas2_op)) & date_adj <= yday(ymd(codFH_seas2_cl)) ~ as.numeric(codFH_2_len)*2.54, TRUE ~ cod_min_y2_alt),
    cod_min_y2_alt=dplyr::case_when(mode == "pr" & date_adj >= yday(ymd(codPR_seas2_op)) & date_adj <= yday(ymd(codPR_seas2_cl)) ~ as.numeric(codPR_2_len)*2.54, TRUE ~ cod_min_y2_alt),
    cod_min_y2_alt=dplyr::case_when(mode == "fh" & date_adj >= yday(ymd(codFH_seas3_op)) & date_adj <= yday(ymd(codFH_seas3_cl)) ~ as.numeric(codFH_3_len)*2.54, TRUE ~ cod_min_y2_alt),
    cod_min_y2_alt=dplyr::case_when(mode == "pr" & date_adj >= yday(ymd(codPR_seas3_op)) & date_adj <= yday(ymd(codPR_seas3_cl)) ~ as.numeric(codPR_3_len)*2.54, TRUE ~ cod_min_y2_alt),

    hadd_bag_y2_alt=dplyr::case_when(mode == "fh" & date_adj >= yday(ymd(hadFH_seas1_op)) & date_adj <= yday(ymd(hadFH_seas1_cl)) ~ as.numeric(hadFH_1_bag), TRUE ~ hadd_bag_y2_alt),
    hadd_bag_y2_alt=dplyr::case_when(mode == "pr" & date_adj >= yday(ymd(hadPR_seas1_op)) & date_adj <= yday(ymd(hadPR_seas1_cl)) ~ as.numeric(hadPR_1_bag), TRUE ~ hadd_bag_y2_alt),
    hadd_bag_y2_alt=dplyr::case_when(mode == "fh" & date_adj >= yday(ymd(hadFH_seas2_op)) & date_adj <= yday(ymd(hadFH_seas2_cl)) ~ as.numeric(hadFH_2_bag), TRUE ~ hadd_bag_y2_alt),
    hadd_bag_y2_alt=dplyr::case_when(mode == "pr" & date_adj >= yday(ymd(hadPR_seas2_op)) & date_adj <= yday(ymd(hadPR_seas2_cl)) ~ as.numeric(hadPR_2_bag), TRUE ~ hadd_bag_y2_alt),
    hadd_bag_y2_alt=dplyr::case_when(mode == "fh" & date_adj >= yday(ymd(hadFH_seas3_op)) & date_adj <= yday(ymd(hadFH_seas3_cl)) ~ as.numeric(hadFH_3_bag), TRUE ~ hadd_bag_y2_alt),
    hadd_bag_y2_alt=dplyr::case_when(mode == "pr" & date_adj >= yday(ymd(hadPR_seas3_op)) & date_adj <= yday(ymd(hadPR_seas3_cl)) ~ as.numeric(hadPR_3_bag), TRUE ~ hadd_bag_y2_alt),

    hadd_min_y2_alt=dplyr::case_when(mode == "fh" & date_adj >= yday(ymd(hadFH_seas1_op)) & date_adj <= yday(ymd(hadFH_seas1_cl)) ~ as.numeric(hadFH_1_len)*2.54, TRUE ~ hadd_min_y2_alt),
    hadd_min_y2_alt=dplyr::case_when(mode == "pr" & date_adj >= yday(ymd(hadPR_seas1_op)) & date_adj <= yday(ymd(hadPR_seas1_cl)) ~ as.numeric(hadPR_1_len)*2.54, TRUE ~ hadd_min_y2_alt),
    hadd_min_y2_alt=dplyr::case_when(mode == "fh" & date_adj >= yday(ymd(hadFH_seas2_op)) & date_adj <= yday(ymd(hadFH_seas2_cl)) ~ as.numeric(hadFH_2_len)*2.54, TRUE ~ hadd_min_y2_alt),
    hadd_min_y2_alt=dplyr::case_when(mode == "pr" & date_adj >= yday(ymd(hadPR_seas2_op)) & date_adj <= yday(ymd(hadPR_seas2_cl)) ~ as.numeric(hadPR_2_len)*2.54, TRUE ~ hadd_min_y2_alt),
    hadd_min_y2_alt=dplyr::case_when(mode == "fh" & date_adj >= yday(ymd(hadFH_seas3_op)) & date_adj <= yday(ymd(hadFH_seas3_cl)) ~ as.numeric(hadFH_3_len)*2.54, TRUE ~ hadd_min_y2_alt),
    hadd_min_y2_alt=dplyr::case_when(mode == "pr" & date_adj >= yday(ymd(hadPR_seas3_op)) & date_adj <= yday(ymd(hadPR_seas3_cl)) ~ as.numeric(hadPR_3_len)*2.54, TRUE ~ hadd_min_y2_alt)) %>%
  dplyr::rename(cod_min_y2 = cod_min_y2_alt,
                cod_bag_y2 = cod_bag_y2_alt,
                hadd_min_y2 = hadd_min_y2_alt,
                hadd_bag_y2 = hadd_bag_y2_alt)


future::plan(future::multisession, workers = 6)
set.seed(915)
#future::plan(future::multisession, workers = 124)
get_predictions_out<- function(x){
#pred <- data.frame()
#for(x in 1:2){

  directed_trips2<-directed_trips %>%
    tibble::tibble() %>%
    dplyr::select(mode, day,  dtrip, draw,
                  starts_with("cod_bag"), starts_with("cod_min"), starts_with("hadd_bag"),starts_with("hadd_min")) %>%
    dplyr::mutate(date=as.Date(day, format = "%d%b%Y"),
                  season = ifelse(lubridate::month(date) %in% c(9, 10, 11, 12, 1, 2, 3, 4), "winter", "summer")) %>%
    dplyr::filter(draw == x) %>%
    data.table::as.data.table()

  get_lowest_min_size_draw<-directed_trips2%>%
    tibble::tibble() %>%
    dplyr::select(mode, day,  dtrip, draw,
                  starts_with("cod_bag"), starts_with("cod_min"), starts_with("hadd_bag"),starts_with("hadd_min"))

  cod_min_size_FY_draw<-min(get_lowest_min_size_draw$cod_min_y2_alt)
  hadd_min_size_FY_draw<-min(get_lowest_min_size_draw$hadd_min_y2_alt)

  catch_data0 <- list()
  base_outcomes_angler_dems0 <- list()
  n_choice_occasions0 <- list()

  mode_draw <- c("pr", "fh")
  season_draw <- c("summer", "winter")

  k<-1

  for (md in mode_draw) {
    for (s in season_draw){

      catch_data0[[k]] <- fst::read_fst(file.path(here::here("Data/base_outcomes"), paste0("base_outcomes_final_",s, "_", md, "_", x,".fst"))) %>%
        dplyr::left_join(directed_trips2, by=c("mode", "date")) %>%
        dplyr::rename(tot_cod_catch_base = tot_cod_catch,
                      tot_hadd_catch_base = tot_hadd_catch) %>%
        dplyr::mutate(cod_cat=tot_cod_catch_base,
                      hadd_cat=tot_hadd_catch_base) %>%
        dplyr::select(date, mode, draw,  tripid, catch_draw, season,
                      cod_cat, hadd_cat, starts_with("cod_bag"), starts_with("cod_min"),
                      starts_with("hadd_bag"),starts_with("hadd_min")) %>%
        data.table::as.data.table()

      base_outcomes_angler_dems0[[k]] <- fst::read_fst(file.path(here::here("Data/base_outcomes"),  paste0("base_outcomes_final_",s, "_", md, "_", x,".fst"))) %>%
        dplyr::select(date, mode,  tripid, catch_draw,
                      tot_keep_cod_base, tot_rel_cod_base,
                      tot_keep_hadd_base, tot_rel_hadd_base,
                      starts_with("beta"),
                      total_trips_12, fish_pref_more, educ1, educ2, educ3, own_boat, cost) %>%
        dplyr::rename(date_parsed=date) %>%
        data.table::as.data.table()

      n_choice_occasions0[[k]] <- fst::read_fst(file.path(here::here("Data/n_choice_occasions"), paste0("n_choice_occasions_final_",s, "_", md, "_", x,".fst"))) %>%
        dplyr::rename(date_parsed=date)  %>%
        data.table::as.data.table()

      k<-k+1

    }
  }

  catch_data <- dplyr::bind_rows(catch_data0)
  base_outcomes <- dplyr::bind_rows(base_outcomes_angler_dems0)
  n_choice_occasions <- dplyr::bind_rows(n_choice_occasions0)

  rm(base_outcomes_angler_dems0, n_choice_occasions0, catch_data0)

  # Size data used in projections is "baseline"proj_catch_at_length.fst"
  # For testing, change the size data file to "baseline_catch_at_length.fst"
  cod_size_data2 <- cod_size_data  %>%
    dplyr::filter(draw==x) %>%
    dplyr::select(fitted_prob, length, season, )

  hadd_size_data2 <- hadd_size_data  %>%
    dplyr::filter(draw==x) %>%
    dplyr::select(fitted_prob, length, season, )

  calendar_adjustments2 <- calendar_adjustments %>%
    dplyr::filter(draw==x) %>%
    dplyr::select(-draw )

  # Pull in calibration comparison information about trip-level harvest/discard re-allocations
  calib_comparison2<-calib_comparison %>%
    dplyr::filter(draw==x)

  calib_comparison2<-calib_comparison2 %>%
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
  all_vars <- names(calib_comparison2)

  # Identify columns that are species-specific (contain _cod or _hadd)
  species_specific_vars <- all_vars[
    stringr::str_detect(all_vars, paste0("(_", species_suffixes, ")$", collapse = "|"))
  ]

  id_vars <- setdiff(all_vars, species_specific_vars)

  ## --- build draw-specific inputs ---
  calib_comparison2<-calib_comparison2 %>%
    dplyr::select(mode, season, all_of(species_specific_vars))

  # Extract base variable names (without __cod or _hadd)
  base_names <- unique(stringr::str_replace(species_specific_vars, "_(cod|hadd)$", ""))

  # Pivot the data longer on the species-specific columns
  calib_comparison2 <- calib_comparison2 %>%
    tidyr::pivot_longer(
      cols = all_of(species_specific_vars),
      names_to = c(".value", "species"),
      names_pattern = "(.*)_(cod|hadd)"
    ) %>%
    dplyr::distinct()

  source(here::here("Code/sim/predict_rec_catch_data_functions.R"))
  source(here::here("Code/sim/predict_rec_catch.R"))

  test<- predict_rec_catch(dr = x,
                           directed_trips = directed_trips2,
                           catch_data = catch_data,
                           cod_size_data = cod_size_data2,
                           had_size_data = hadd_size_data2,
                           calib_comparison = calib_comparison2,
                           n_choice_occasions = n_choice_occasions,
                           calendar_adjustments = calendar_adjustments2,
                           base_outcomes = base_outcomes,
                           discard_mortality_dat = disc_mort,
                           param_grid = param_grid)

  test <- test %>%
    dplyr::mutate(draw = c(x),
                  #model = c("Alt"))
                  model = c(Run_Name))

}
#})
# use furrr package to parallelize the get_predictions_out function 100 times
# This will spit out a dataframe with 100 predictions


#write.csv(predictions_out10, file = here::here("SQ_predictions_1_5.csv"))
predictions_out10<- furrr::future_map_dfr(
  1:5,
  ~{
    data.table::setDTthreads(1)
    get_predictions_out(.x)
  },
  .id = "draw",
  .options = furrr::furrr_options(seed = TRUE)
)

readr::write_csv(predictions_out10, file = here::here(paste0("output/output_", Run_Name, "_", format(Sys.time(), "%Y%m%d_%H%M%S"),  ".csv")))
