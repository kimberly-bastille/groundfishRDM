################################################################################
################################################################################
# Script:       get_cod_assessment_data.R
# Purpose:      Reads the accepted WGOM Atlantic cod WHAM stock-assessment model
#               (terminal year 2023) and its ASAP input file from Google Drive,
#               extracts the biological parameters the bioeconomic model needs,
#               runs a single 0.75*Fmsy (2025-2027) projection, and writes both
#               historical and projected numbers-at-age (NAA). Projected NAA are
#               drawn (num_NAA_draws) from a bias-corrected lognormal built from
#               the projection's log-NAA mean and sd.
# Inputs:       Two files from the Google Drive shared drive:
#               "NMFS NEC READ SSB", cod_assessment/
#                 mod_base_2023_noBLLS.rds       (accepted WHAM model),
#                 WGOM_COD_ASAP_2023_SEL3_2023.DAT (ASAP input file).
# Outputs:      input_data/WGOMCod_Projections_<date>.Rds,
#               input_data/WGOM_Cod_historical_NAA_<date>.{Rds,dta},
#               input_data/WGOM_Cod_projected_NAA_<date>.{Rds,dta}
#               (the NAA files are also uploaded back to Google Drive/input_data).
# Dependencies: wham_version_installer.R must have installed the WHAM version
#               matching the model (verified here via stopifnot on the commit).
#               Code/helpers/naa_helpers.R (pivot_naa_long, validate_naa_data).
#               Google Drive access with cached credentials in .secrets.
# Pipeline:     Assessment-data prep, run once per management cycle. Upstream of
#               the Stata pipeline: its NAA outputs feed the catch-at-length
#               steps (see catch_at_length_projection.do).
#
# Background (units and conventions):
#   - Aggregate weights (SSB, catch) are in metric tons; weight-at-age vectors
#     are in kg.
#   - tail(x, 1) is used to pick the last (most recent) year of a vector/matrix.
#   - The assessment has commercial and recreational fleets (plus a 'blended'
#     fleet). Some parameters go INTO the assessment (natural mortality M,
#     fraction-of-year before spawning); others come OUT (weights-at-age,
#     maturity, historical NAA). BLAST 1.0 consumes the 1xA weight-at-age row
#     vectors built below (cod_jan1_weights, cod_midyear_weights,
#     cod_catch_weights, cod_ssb_weights, cod_discard_weights, cod_maturity;
#     cod_discard_fraction is not modeled for the commercial fleet).  However
#     the current versions of the groundfishRDM does not use these.
#   - There is no stochastic projection for WGOM cod, so future NAA are treated
#     as lognormal and simulated with rlnorm().
#   - Bridging: 2023 and 2024 catch are passed in as actuals (see the "Pull
#     models to make projections" section) rather than read from agg_catch.
#
# Author: Charles Perretti (2024); modified by Min-Yang Lee (2025).
################################################################################
################################################################################
#Load libraries
library(tidyverse)
library(TMB)
library(haven)
library(glue)
library(googledrive)
library(here)
cod_wham_lib <- file.path(Sys.getenv("R_LIBS_USER"), "cod_wham_install")
library(wham,lib.loc = cod_wham_lib)


###########Begin Housekeeping##################################################
#Set paths, input names, and savefile names.

# Assessment folders

here::i_am("Code/pre_sim/get_cod_assessment_data.R")
assessment_output_folder<-here("input_data")
dir.create(file.path(assessment_output_folder), showWarnings = FALSE)

# data version
data_version<-Sys.Date()


# Read in helpers
source(here("Code","helpers","naa_helpers.R"))


# create a small dataframe that holds the stock "characteristics".

stock_stats_df<-tibble(
  fishery= "NE Groundfish",
  common = "ATLANTIC COD",
  species_itis =164712 ,
  stock_abbrev = "WGOM",
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
assessment_file_in<-"mod_base_2023_noBLLS.rds"
ASAP_file_in<-"WGOM_COD_ASAP_2023_SEL3_2023.DAT"
FullProjectionsSaveFile<-glue("WGOMCod_Projections_{data_version}.Rds")
ProjectedNAASaveFile<-glue("WGOM_Cod_projected_NAA_{data_version}")
HistoricalNAASaveFile<-glue("WGOM_Cod_historical_NAA_{data_version}")



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

#read in the assessment file
readin<-file.path("socialsci","RecreationalDST","2027_management_cycle_data","groundfishRDM","cod_assessment",assessment_file_in)
file_id<-drive_get(path = readin, shared_drive = "NMFS NEC READ SSB")$id
#
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


mod_accepted$model_name <- "Accepted"
mod_list <- list(mod_accepted)




# Read the ASAP file from google drive
readin<-file.path("socialsci","RecreationalDST","2027_management_cycle_data","groundfishRDM","cod_assessment",ASAP_file_in)
file_id<-drive_get(path = readin, shared_drive = "NMFS NEC READ SSB")$id
#
# Create a path for a temporary file
temp_path <- tempfile(fileext = ".DAT")

# Download
drive_download(
  file = as_id(file_id),
  path = temp_path,
  overwrite = TRUE
)

# Read in
asap3 <- read_asap3_dat(temp_path)

# cleanup
if (file.exists(temp_path)) {
  file.remove(temp_path)
}


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



################################################################################
################################################################################
# Handle ASAP3 Dat file
################################################################################
################################################################################


# Placeholders and parameters
periods<-12 # there are 12 months in a year
# Which year do you want a projection for, How many projections? Set a seed.
YearProj<-2026
num_NAA_draws<-500
set.seed(6)

# I use tail(.x, 1) to pick the last "thing" out of the ASAP input file

############
# Parameters that go into the stock assessment
############
# Fraction of year that elapses before SSB Calculation (Jan1=0.0)
cMp1=asap3[[1]]$dat$fracyr_spawn
cFp1=cMp1

# Natural Mortality
cMyr=tail(asap3[[1]]$dat$M,1)
# NOTE: M is a vector across ages; dividing by periods yields a monthly rate vector
cM=cMyr/periods



############
# Parameters that come out of the stock assessment
############
# Weights at age. Opem the ASAP3 file in the ASAP gui and pick through the pointers.
# cod_jan1_weights=  Matrix 3 for Jan 1
cod_jan1_weights = tail(asap3[[1]]$dat$WAA_mats[[3]],1)

# cod_midyear_weights -- Matrix 3 for computing SSB
cod_midyear_weights = cod_jan1_weights

#  matrix 1 for commercial catch
cod_catch_weights = tail(asap3[[1]]$dat$WAA_mats[[1]],1)


# cod_ssb_weights  -- Matrix 3 for computing SSB
cod_ssb_weights=cod_jan1_weights

# cod_discard_weights matrix 1 for commercial discards
cod_discard_weights = tail(asap3[[1]]$dat$WAA_mats[[1]],1)

# cod_discard_fraction not in the model for commercial
cod_discard_fraction<-cod_discard_weights*0
# cod_maturity
cod_maturity= tail(asap3[[1]]$dat$maturity,1)

# These parameters aren't actually saved anywhere, because I'm not 100% sure of
# the easiest way to save them.








################################################################################
################################################################################
# Pull models to make projections ##############################################
################################################################################
################################################################################


# Define catch in previous years######################################################
# I use GARFOs quota monitoring page for Rec, since the FY catch is equal to the CY catch.
# Doesn't quite work for commercial

actual_2023_commercial_catch_mt<-438
actual_2024_commercial_catch_mt<-550
actual_2025_commercial_catch_mt<-NA # Update this for 2027 management:
actual_2026_commercial_catch_mt<-NA # Update this for 2028 management:

actual_2023_rec_catch_mt<-192 # From GARFO quota monitoring report
actual_2024_rec_catch_mt<-72
actual_2025_rec_catch_mt<-NA # Update this for 2027 management:
actual_2026_rec_catch_mt<-NA # Update this for 2028 management:


actual_2023_catch_mt<-actual_2023_commercial_catch_mt+actual_2023_rec_catch_mt
actual_2024_catch_mt<-actual_2024_commercial_catch_mt+actual_2024_rec_catch_mt
# 2025 not used (yet)
 actual_2025_catch_mt<-actual_2025_commercial_catch_mt+actual_2025_rec_catch_mt
# 2026 not used (yet)
# actual_2026_catch_mt<-actual_2026_commercial_catch_mt+actual_2026_rec_catch_mt



###################################PROJECTIONS #################################
# Set specs ####################################################################
set_specs <- function(mod) {
  #bridge <- sum(tail(mod$env$data$agg_catch,1)) #Catch in the last year of the assessment
  Fmsy <- exp(mod$rep$log_FXSPR_static)         #FMSY


  proj.opts_list <-
    list(Model = rep(mod$model_name, times = 1),
         scenario    = c("0.75Fmsy (2025-2027)"), #Scenario 2 from the original projections. This is just a string.
         n.yrs       = rep(list(4), times = 1),   # Number of years is set in in (list(numyears)). Number of scenarios is set with times

         # NOTE: proj_F_opt maps projection modes for each of the 4 projection years: 5 = catch in MT, 4 = fixed instantaneous F
         proj_F_opt  = list(c(5, 5, 4, 4)),  # length=numyears.  stack on different things to make different projections. 5=metric tons, 4=an instantanous fishing mortality rate (F)

         # NOTE: Year 1 & 2 use specified MT bridging catch; Year 3 & 4 apply the 75% Fmsy rate
         proj_Fcatch = list(c(actual_2023_catch_mt, actual_2024_catch_mt, rep(0.75 * Fmsy, 2))) #2 # length=numyears
    )
}

proj.opts_list2 <- map_df(mod_list, .f = set_specs)

################################################################################
################################################################################
# Run projections ##############################################################
################################################################################
################################################################################
proj_list <- list()
mod_names <- map_df(mod_list, .f = function(x) data.frame(model_name = x$model_name))
message("Running WGOM cod WHAM projection(s); this may take a while ...")
for(i in 1:length(proj.opts_list2$n.yrs)) {

  mod_index <- which(mod_names$model_name == proj.opts_list2$Model[i])

  proj_list[[i]] <-
    project_wham(model = mod_list[[mod_index]],
                 proj.opts = list(n.yrs = proj.opts_list2$n.yrs[[i]],
                                  proj_F_opt  = proj.opts_list2$proj_F_opt[[i]],
                                  proj_Fcatch = proj.opts_list2$proj_Fcatch[[i]]),
                 do.sdrep = T,
                 MakeADFun.silent = T)

  proj_list[[i]]$scenario <- proj.opts_list2$scenario[i]
  proj_list[[i]]$Model <- proj.opts_list2$Model[i]
}

################################################################################
################################################################################
# Create table of results ######################################################
################################################################################
################################################################################
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
             `Catch (Com.)` = round(x$rep$pred_catch[,1],1),
             `Catch (Rec.)` = round(x$rep$pred_catch[,2],1),
             `Catch (Total)` = `Catch (Com.)` + `Catch (Rec.)`) %>%
      filter(Year >= 2023) %>%
      rename(`Projection scenario` = scenario)

    return(out)
  })

################################################################################
################################################################################
# Save the full set of projections
write_rds(proj_list, file = file.path(assessment_output_folder,FullProjectionsSaveFile))
################################################################################
################################################################################


################################################################################
################################################################################
# Get historical and projected NAA
################################################################################
################################################################################
#This pulls objects out of the sdreport. Models are stacked into the proj_list object
std1 <- list(TMB:::as.list.sdreport(proj_list[[1]]$sdrep, what = "Est", report = TRUE),
             TMB:::as.list.sdreport(proj_list[[1]]$sdrep, what = "Std", report = TRUE))


year<-proj_list[[1]]$years_full
ages<-proj_list[[1]]$input$ages.lab

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

TerminalAssess<-tail(mod_list[[1]]$years_full,1)

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


#To "bias-correct" the lognormal you would change the SIM_NAA[[ageclass]] line to:
NAA<-list()
for (ageclass in 1:length(NAA_logmean)){
  # NOTE: Applies bias correction (- variance/2) to preserve the arithmetic mean when drawing from a lognormal distribution
  NAA[[ageclass]]<-rlnorm(num_NAA_draws,NAA_logmean[ageclass]-NAA_logsd[ageclass]^2/2,NAA_logsd[ageclass]) # Feed it straight into rlnorm
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


# Validate

validate_naa_data(df=NAA_long,
                  age_classes=age_classes,
                  ndraws=num_NAA_draws,
                  years=1)


write_dta(NAA_long, path=file.path(assessment_output_folder,glue("{ProjectedNAASaveFile}.dta")))
write_rds(NAA_long, file=file.path(assessment_output_folder,glue("{ProjectedNAASaveFile}.Rds")))

#Put the historical NAA on google drive
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
