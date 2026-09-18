################################################################################
################################################################################
# Script:       get_haddock_assessment_data.R
# Purpose:      Reads the accepted GOM haddock WHAM stock-assessment model
#               (terminal year 2023) and its projected weight-at-age workbook
#               from Google Drive, runs the two standard PDT projections
#               (Fmsy and 0.75*Fmsy, 2025-2027), and writes historical and
#               projected numbers-at-age (NAA). NAA are taken from the SECOND
#               projection (0.75*Fmsy) and, for the projection year, drawn
#               (num_NAA_draws) from a bias-corrected lognormal.
# Inputs:       Two files from the Google Drive shared drive:
#               "NMFS NEC READ SSB", haddock_assessment/
#                 mod_nola_dcpe_blls2.rds     (accepted WHAM model),
#                 waa_pred_2024-08-25.xlsx    (projected SSB/Catch weight-at-age).
# Outputs:      input_data/GOM_Haddock_Projections_<date>.Rds,
#               input_data/GOM_Haddock_historical_NAA_<date>.{Rds,dta},
#               input_data/GOM_Haddock_projected_NAA_<date>.{Rds,dta}
#               (the NAA files are also uploaded back to Google Drive/input_data).
# Dependencies: wham_version_installer.R must have installed the WHAM version
#               matching the model (verified here via stopifnot on the commit).
#               Code/helpers/naa_helpers.R (pivot_naa_long, validate_naa_data).
#               Google Drive access with cached credentials in .secrets.
# Pipeline:     Assessment-data prep, run once per management cycle. Upstream of
#               the Stata pipeline: its NAA outputs feed the catch-at-length
#               steps (see catch_at_length_projection.do). Sibling of
#               get_cod_assessment_data.R.
#
# Background (units and conventions):
#   - Aggregate weights (SSB, catch) are in metric tons; weight-at-age vectors
#     are in kg. tail(x, 1) picks the last (most recent) year of a vector/matrix.
#   - Some parameters go INTO the assessment, others come OUT (weights-at-age,
#     historical NAA). Future NAA are treated as lognormal (no stochastic
#     projection) and simulated with rlnorm().
#   - Bridging (2024 removals) was originally the PDT's 2105 mt; it has been
#     updated to the 2024 actual catch (see "Define catch in previous years").
#   - The two projections differ only in the out-year F: projection 1 uses Fmsy
#     (this is the projection in the MT report, and produces the 2025 OFL);
#     projection 2 uses 0.75*Fmsy (potential ABCs) and supplies the saved NAA.
#
# Author: Charles Perretti (2024-NOV); modified by Min-Yang Lee (2025-Nov).
################################################################################
################################################################################
#Load libraries
library(tidyverse)
library(TMB)
library(haven)
library(glue)
library(googledrive)
library(here)
#load the haddock specific version of WHAM.
haddock_wham_lib <- file.path(Sys.getenv("R_LIBS_USER"), "haddock_wham_install")
library(wham,lib.loc = haddock_wham_lib)

###########Begin Housekeeping##################################################
#Set paths, input names, and savefile names.

# Assessment folders
here::i_am("Code/pre_sim/get_haddock_assessment_data.R")

assessment_output_folder<-here("input_data")
dir.create(file.path(assessment_output_folder), showWarnings = FALSE)

# data version
data_version<-Sys.Date()


# Read in helpers
source(here("Code","helpers","naa_helpers.R"))

# create a small dataframe that holds the stock "characteristics".
stock_stats_df<-tibble(
  fishery= "NE Groundfish",
  common = "HADDOCK",
  species_itis =164744 ,
  stock_abbrev = "GOM",
  state=NA,
  wave=NA,
  metric="Numbers At Age",
  units = "Thousands",
  source = "2024 Assessment",
  data_version= data_version
)
# Save 3 years years of historical NAA
yearinwindow<-3


#names of output save files
FullProjectionsSaveFile<-"GOM_Haddock_Projections"
ProjectedNAASaveFile<-glue("GOM_Haddock_projected_NAA_{data_version}")
HistoricalNAASaveFile<-glue("GOM_Haddock_historical_NAA_{data_version}")

# input save files
assessment_file_in<-"mod_nola_dcpe_blls2.rds"
waa_file_in<-"waa_pred_2024-08-25.xlsx"


# Connect to Google Drive
# NOTE: Relies on cached credentials in .secrets. Will prompt interactive auth if missing or expired.
drive_auth(cache = here(".secrets"), email = TRUE)

# Output folder on google drive
groundfish_processed_path<-file.path("socialsci","RecreationalDST","2027_management_cycle_data","groundfishRDM","input_data")
folder_info <- drive_get(
  path = groundfish_processed_path,
  shared_drive = "NMFS NEC READ SSB"
)
groundfish_processed_path<-folder_info$id

# Read in the assessment file
readin<-file.path("socialsci","RecreationalDST","2027_management_cycle_data","groundfishRDM","haddock_assessment",assessment_file_in)
file_id<-drive_get(path = readin, shared_drive = "NMFS NEC READ SSB")$id

# Create a path for a temporary file
# NOTE: tempfile handles cross-platform path safe creation and garbage collection upon session end
temp_path <- tempfile(fileext = ".rds")

# Download
drive_download(
  file = as_id(file_id),
  path = temp_path,
  overwrite = TRUE
)

# Read in using  into your environment
mod_accepted <- read_rds(temp_path)
# cleanup
if (file.exists(temp_path)) {
  file.remove(temp_path)
}


# readin the WAA file
readin<-file.path("socialsci","RecreationalDST","2027_management_cycle_data","groundfishRDM","haddock_assessment",waa_file_in)
file_id<-drive_get(path = readin, shared_drive = "NMFS NEC READ SSB")$id
temp_path <- tempfile(fileext = ".xlsx")

drive_download(
  file = as_id(file_id),
  path = temp_path,
  overwrite = TRUE
)


# Load WAA projections (specific to GOM haddock) ###############################
waa_proj_ssb <-
  readxl::read_excel(path=temp_path,
                     sheet = "SSB WAA") %>%
  filter(YEAR %in% 2024:2027) %>%
  select(-YEAR)

waa_proj_catch <-
  readxl::read_excel(path=temp_path,
                     sheet = "Catch WAA") %>%
  filter(YEAR %in% 2024:2027) %>%
  select(-YEAR)


# cleanup
if (file.exists(temp_path)) {
  file.remove(temp_path)
}


stock_name <- "GOM haddock"
model_name <- "2024MT"

mod_accepted$model_name <- "Accepted"
mod_list <- list(mod_accepted)


###################################################################################
###################################################################################
#Make sure that the version of WHAM that was used to generate the model is installed
###################################################################################
###################################################################################


# take a look at the version of WHAM used to generate the model.
# NOTE: Splits the commit string at '@' to isolate the hash, then strips trailing ')'
model_wham_commit<-strsplit(mod_accepted$wham_commit,split="@")[[1]][2]
model_wham_commit<-gsub(")", "", model_wham_commit)

stopifnot(model_wham_commit==packageDescription("wham")$RemoteSha)
# keep getting a warning message about magrittr, but things seem to work.


cat("Model Wham version is", model_wham_commit, "\n")
cat("Installed wham commit is", packageDescription("wham")$RemoteSha,"\n")

###################################################################################
###################################################################################
#End WHAM commit verification
###################################################################################
###################################################################################

# Placeholders and parameters
periods<-12 # there are 12 months in a year
# Which year do you want a projection for, How many projections? Set a seed.
YearProj<-2026
num_NAA_draws<-500
set.seed(6)
###########End Housekeeping#####################################################





# Define catch in previous years  ######################################################
old_bridge_year_catch <- 2105 #GOM haddock 2024 MT PDT-supplied catch
# I use GARFOs quota monitoring page for Rec, since the FY catch is equal to the CY catch.
# Doesn't quite work for commercial

actual_2023_commercial_catch_mt<-2277
actual_2024_commercial_catch_mt<-1405
actual_2025_commercial_catch_mt<-NA # Update for 2027
actual_2026_commercial_catch_mt<-NA # Update for 2028

actual_2023_rec_catch_mt<-793 # From GARFO quota monitoring report
actual_2024_rec_catch_mt<-899
actual_2025_rec_catch_mt<-NA #Update for 2027
actual_2025_rec_catch_mt<-NA #Update for 2028


actual_2023_catch_mt<-actual_2023_commercial_catch_mt+actual_2023_rec_catch_mt
actual_2024_catch_mt<-actual_2024_commercial_catch_mt+actual_2024_rec_catch_mt

# 2025 not used yet.
 actual_2025_catch_mt<-actual_2025_commercial_catch_mt+actual_2025_rec_catch_mt


#Handle WAA ###############################################################################

# NOTE: The 6 rows map to fleets/indices defined in input$data$waa_pointers. Verify this alignment if model fleet structure changes.
# NOTE2: Array structure is [fleet/index source, projection year (1:4), age (1:9)]
waa_input_blls <- array(dim = c(6,4,9)) #new wham wants the waa doubled for some reason
for(i in 1:9){ # the order of the sources matches input$data$waa_pointers
  waa_input_blls[,,i] <- rbind(t(waa_proj_catch[,i]), t(waa_proj_ssb[,i]), t(waa_proj_ssb[,i]),
                               t(waa_proj_catch[,i]), t(waa_proj_ssb[,i]), t(waa_proj_ssb[,i]))
}

# In theory, you shouldn't have to touch anything below here:

# Pull models to make projections ##############################################

# Assign some short names to the models (can do more than one if desired)
mod_accepted$model_name <- model_name

mod_list <- list(mod_accepted)

# Set specs ####################################################################
# If I want to pass in a different catch for 2025, I can just modify this to have 2 args bridge_year_catch1, bridge_year_catch2 or something
# Also would need to set the proj_F_opt option accordingly.

set_specs <- function(mod, bridge_year_catch) {

  Fmsy <- exp(mod$rep$log_FXSPR_static)

  proj.opts_list <-
    list(Model = rep(mod$model_name, times = 2),
         scenario    = c("(1) Fmsy (2025-2027)",                  #1
                         "(2) 0.75Fmsy (2025-2027)"               #2
         ),
         n.yrs       = rep(list(4), times = 2),
         proj_R_opt  = rep(list(2), times = 2),

         # NOTE: proj_F_opt specifies fixed catch (5) in year 1, and fixed instantaneous F (4) in years 2-4
         proj_F_opt  = list(c(5, 4, 4, 4),  #1
                            c(5, 4, 4, 4)  #2
         ),

         # NOTE: Year 1 uses bridge catch; Years 2-4 apply Fmsy scalar corresponding to the scenario
         proj_Fcatch = list(c(bridge_year_catch, rep(Fmsy, 3)),                #1
                            c(bridge_year_catch, rep(0.75 * Fmsy, 3))         #2
         ),
         proj_waa = list(waa_input_blls,
                         waa_input_blls)

    )
}

# pass in "actual_2024_catch_mt"
proj.opts_list2 <- map_df(mod_list, .f = set_specs, actual_2024_catch_mt)


# Run projections ##############################################################
proj_list <- list()
mod_names <- map_df(mod_list, .f = function(x) data.frame(model_name = x$model_name))
for(i in 1:length(proj.opts_list2$n.yrs)) {

  print(paste0("Running projection: ", proj.opts_list2$Model[i],
               " ", proj.opts_list2$scenario[i]))

  mod_index <- which(mod_names$model_name == proj.opts_list2$Model[i])

  proj_list[[i]] <-
    project_wham(model = mod_list[[mod_index]],
                 proj.opts = list(n.yrs = proj.opts_list2$n.yrs[[i]],
                                  proj_R_opt  = proj.opts_list2$proj_R_opt[[i]],
                                  proj_F_opt  = proj.opts_list2$proj_F_opt[[i]],
                                  proj_Fcatch = proj.opts_list2$proj_Fcatch[[i]],
                                  proj_waa    = proj.opts_list2$proj_waa[[i]]
                 ),
                 do.sdrep = T,
                 MakeADFun.silent = T,
                 check.version = FALSE)

  proj_list[[i]]$scenario <- proj.opts_list2$scenario[i]
  proj_list[[i]]$Model <- proj.opts_list2$Model[i]
}


# Create table of results ######################################################
proj_out <-
  map_df(proj_list, .f = function(x) {

    # NOTE: Extracts standard TMB sdreport tables. "Est" is the estimates list; "Std" is standard errors.
    std <- list(TMB:::as.list.sdreport(x$sdrep, what = "Est", report = TRUE),
                TMB:::as.list.sdreport(x$sdrep, what = "Std", report = TRUE))

    logssb <- std[[1]]$log_SSB
    logssb_sd <- std[[2]]$log_SSB
    ssb <- exp(std[[1]]$log_SSB)[,1]

    # NOTE: qnorm(0.95) implies a 90% CI mapping around a lognormal distribution
    ssb_90lo <- exp(logssb - qnorm(0.95) * logssb_sd)[,1]
    ssb_90hi <- exp(logssb + qnorm(0.95) * logssb_sd)[,1]


    out <-
      tibble(Model = x$Model,
             scenario = x$scenario,
             Year = x$years_full,
             `F`  = round(apply(exp(x$rep$log_FAA_tot), 1, max),2),
             SSB  = round(ssb, 1),
             `SSB CI (90% low)`  = round(ssb_90lo,1),
             `SSB CI (90% high)` = round(ssb_90hi,1),
             `Catch Fleet` = round(x$rep$pred_catch,1),
             `Catch (Total)` = rowSums(`Catch Fleet`)) %>%
      filter(Year >= max(x$years)) %>%
      rename(`Projection scenario` = scenario)

    return(out)
  })


################################################################################
################################################################################
# Save the full set of projections
write_rds(proj_list, file = file.path(assessment_output_folder,glue("{FullProjectionsSaveFile}_{data_version}.Rds")))
################################################################################
################################################################################



# Plot projections #############################################################
proj2plot <-
  proj_out %>%
  gather(variable, value, -Year, -`Projection scenario`, -Model)

ggplot(proj2plot %>% filter(variable %in% c("Catch (Total)", "SSB")),
       aes(x = Year, y = value, color = `Projection scenario`)) +
  {if(length(unique(proj2plot$Model)) > 1) geom_line(linetype = Model) else
    geom_line()} +
  geom_point() +
  facet_wrap(~variable, scales = "free_y", ncol = 1) +
  ylab("Metric tons") +
  theme_bw() +
  ggtitle(paste0(stock_name, " projections"))

#ggsave(paste0("projections_for_PDT.png"), w = 9, h = 6)


# Show NAA projection uncertainty ######################################
# This is a pretty slick way to do things.The log_naa tibble ends up in tidy format (Years and then ages)
# x <- proj_list[[1]] # Grab the Fmsy projections
# log_naa_ind <- which(names(x$sdrep$value) == "log_NAA_rep")
# log_naa <-
#   tibble(Year = rep(x$years_full, x$input$data$n_ages),
#          Age  = rep(1:x$input$data$n_ages, each = length(x$years_full)),
#          log_NAA = x$sdrep$value[log_naa_ind],
#          log_NAA_sd = x$sdrep$sd[log_naa_ind],
#          log_NAA_95lo = log_NAA - 1.96 * log_NAA_sd,
#          log_NAA_95hi = log_NAA + 1.96 * log_NAA_sd,
#          NAA = exp(log_NAA),
#          NAA_95lo = exp(log_NAA_95lo),
#          NAA_95hi = exp(log_NAA_95hi))
#
# ggplot(log_naa %>% filter(Year >= 2010), aes(x = Year, y = NAA)) +
#   geom_point() +
#   geom_line() +
#   geom_ribbon(aes(ymin = NAA_95lo, ymax = NAA_95hi), alpha = 0.3) +
#   geom_vline(xintercept = 2023.5, linetype= 2) +
#   facet_wrap(~Age) +
#   theme_bw()


################################################################################
################################################################################
# Get historical and projected NAA
################################################################################
################################################################################
#This pulls objects out of the sdreport. Models are stacked into the proj_list object
# this is pulling out the 2nd model (75% FMSY)
std1 <- list(TMB:::as.list.sdreport(proj_list[[2]]$sdrep, what = "Est", report = TRUE),
             TMB:::as.list.sdreport(proj_list[[2]]$sdrep, what = "Std", report = TRUE))
year<-proj_list[[2]]$years_full

#get age classes from the wham model.
ages<-proj_list[[2]]$input$ages.lab

#remove the +
# NOTE: Regex \\D matches non-digits. Strips characters like '+' from terminal age groupings (e.g., "1+" -> "1")
ages<-gsub("\\D", "", ages)


# Extract the mean and std dev of log_NAA from the results.
# the 1st dimension of this array contains stock, the second contains region.
# This particular WHAM model only contained 1 stock and 1 region.
# NOTE: Array structure is [stock, region, year, age]
NAA_logmean<-std1[[1]]$log_NAA_rep[1,1,,]
NAA_logsd<-std1[[2]]$log_NAA_rep[1,1,,]

#column names
names<-glue("age{ages}")

TerminalAssess<-tail(mod_accepted$years_full,1)


# Construct a dataframe of historical Numbers at Age
historical_NAA<-exp(NAA_logmean)


colnames(historical_NAA)<-names
historical_NAA<-as.data.frame(cbind(year,historical_NAA))


historical_NAA <- historical_NAA %>%
  dplyr::filter(year<YearProj)

# add in stock statistics
historical_NAA<-historical_NAA %>%
  arrange(-year) %>%
  slice_head(n=yearinwindow)%>%
  cross_join(stock_stats_df)%>%
  mutate(metric="Historical Mean Numbers of Age")

age_classes<-historical_NAA%>%
  select(starts_with("age")) %>%
  ncol()


historical_NAA_long<-pivot_naa_long(historical_NAA)


############### Validate ###############
# Apply the validation function to the historical data
validate_naa_data(df=historical_NAA_long,
                  age_classes=age_classes,
                  ndraws=1,
                  years=yearinwindow)



write_dta(historical_NAA_long, path=file.path(assessment_output_folder,glue("{HistoricalNAASaveFile}.dta")))
write_rds(historical_NAA_long, file=file.path(assessment_output_folder,glue("{HistoricalNAASaveFile}.Rds")))

#Put the historical NAA on google drive
drive_upload(
  media = file.path(assessment_output_folder,glue("{HistoricalNAASaveFile}.Rds")),
  path = as_id(groundfish_processed_path),
  name = glue("{HistoricalNAASaveFile}.Rds"),
  overwrite = TRUE
)

drive_upload(
  media = file.path(assessment_output_folder,glue("{HistoricalNAASaveFile}.dta")),
  path = as_id(groundfish_processed_path),
  name = glue("{HistoricalNAASaveFile}.dta"),
  overwrite = TRUE
)


# Pick exactly 1 year. See the header.
RowPick<-which(year==YearProj)
stopifnot(length(RowPick)==1)


#extract just 1 row
NAA_logmean<-NAA_logmean[RowPick,]
NAA_logsd<-NAA_logsd[RowPick,]

stopifnot(length(NAA_logmean)==length(NAA_logsd))


# Simulate NAA
NAA<-list()


for (ageclass in 1:length(NAA_logmean)){
  # NOTE: Applies bias correction (- variance/2) to preserve the arithmetic mean when drawing from a lognormal distribution
  NAA[[ageclass]]<-rlnorm(num_NAA_draws,NAA_logmean[ageclass]-NAA_logsd[ageclass]^2/2,NAA_logsd[ageclass])

}

#smush the list to a Dataframe, give it nice names, add on the year and a replicate number.
NAA<-list2DF(NAA)
colnames(NAA)<-names
NAA <-NAA %>%
  mutate(replicate= row_number(),
         year=YearProj
  ) %>%
  relocate(replicate,year)


# add in stock statistics

NAA <-NAA %>%
  cross_join(stock_stats_df)%>%
  mutate(metric="Projected Numbers of Age")

NAA_long<-pivot_naa_long(NAA)

#validate


# Validate

validate_naa_data(df=NAA_long,
                  age_classes=age_classes,
                  ndraws=num_NAA_draws,
                  years=1)


write_dta(NAA_long, path=file.path(assessment_output_folder,glue("{ProjectedNAASaveFile}.dta")))
write_rds(NAA_long, file=file.path(assessment_output_folder,glue("{ProjectedNAASaveFile}.Rds")))

#Put the historical NAA_long on google drive
drive_upload(
  media = file.path(assessment_output_folder,glue("{ProjectedNAASaveFile}.Rds")),
  path = as_id(groundfish_processed_path),
  name = glue("{ProjectedNAASaveFile}.Rds"),
  overwrite = TRUE
)

drive_upload(
  media = file.path(assessment_output_folder,glue("{ProjectedNAASaveFile}.dta")),
  path = as_id(groundfish_processed_path),
  name = glue("{ProjectedNAASaveFile}.dta"),
  overwrite = TRUE
)
