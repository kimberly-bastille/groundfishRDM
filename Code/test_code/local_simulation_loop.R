

################################################################################
# Dev paths note (no full script header yet - out of scope for this pass):
# 7 hardcoded absolute paths to a developer's local machine (C:\ or E:\),
# at lines 40, 41, 43, 44, 45 and 46; plus 1 more in a commented-out line (39).
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
#n_draws<-25
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
source(file.path(code_cd,"predict_rec_catch_functions2.R"))
source(file.path(code_cd,"predict_rec_catch_data_functions1.R"))


mode_draw   <- c("pr", "fh")
season_draw <- c("summer", "winter")

param_grid <- expand.grid(
  md = mode_draw,
  s  = season_draw,
  stringsAsFactors = FALSE
)


#ndraws=50 #number of choice occasions to simulate per strata
#ndraws=25 #number of choice occasions to simulate per strata
ndraws=10 #number of choice occasions to simulate per strata

#l_w_conversion parameters =
cod_lw_a = 0.000005132
cod_lw_b = 3.1625
had_lw_a = 0.000009298
had_lw_b = 3.0205


disc_mort<- fst::read_fst(file.path(final_process_misc_cd, "Discard_Mortality.fst")) %>%
  dplyr::rename(month=Month)

system.time({

# Local loop
draws <- 1:201
predictions_all <- purrr::map_dfr(
  draws,
  run_one_draw
)

})

# predictions_check<-predictions_all %>%
#   dplyr::filter(mode=="all modes")
#
# predictions_check <- predictions_check %>%
#   dplyr::select(-month) %>%
#   group_by(metric, species,mode, draw)%>%
#   summarise(across(where(is.numeric), sum, .names = "{.col}")) %>%
#   dplyr::ungroup()
#
# predictions_check <- predictions_check %>%
#   dplyr::select(-draw) %>%
#   dplyr::group_by(metric, species,mode)%>%
#   dplyr::summarise(across(where(is.numeric), mean, .names = "{.col}")) %>%
#   ungroup() %>%
#   dplyr::mutate(value=value/2205)

#write_csv(predictions_all, file.path(code_cd, paste0("SQ_updated_2_19.csv")))
#write_csv(predictions_all, file.path(code_cd, paste0("SQalt_updated_2_19.csv")))
#write_csv(predictions_all, file.path(code_cd, paste0("KLB8_updated_2_19.csv")))
#write_csv(predictions_all, file.path(code_cd, paste0("WRTIII5_updated_2_19.csv")))
#write_csv(predictions_all, file.path(code_cd, paste0("SQ_updated_hadd17_2_19.csv")))
#write_csv(predictions_all, file.path(code_cd, paste0("SQ_updated_hadd17_4_6_26_draws25.csv")))
#write_csv(predictions_all, file.path(code_cd, paste0("SQ_updated_hadd17_4_6_26_draws50.csv")))
write_csv(predictions_all, file.path(code_cd, paste0("SQ_updated_hadd17_4_6_26_draws10.csv")))

summary_predictions<-predictions_all %>%
  as.data.table() %>%
  dplyr::filter(mode=="all modes" ) %>%
  dplyr::group_by(metric, species) %>%
  dplyr::summarise(mean_value=mean(value), sd=sd(value))


