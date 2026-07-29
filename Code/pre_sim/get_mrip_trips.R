################################################################################
# Script:       get_mrip_trips.R
# Purpose:      Uses the most recent version of mrip_pullDATE.Rds to construct trips
#               using MRIP tacklebox. Verify that MRIP tacklebox matches known good code
#               before switching to other harder metrics (catch by weight)
# Inputs:       mrip_pull{}.Rds
# Outputs:      None yet
# Dependencies: Packages here, mriptacklebox, ROracle, tidyverse, DBI, glue,
#               haven, conflicted. Sources developer_setup.R (for gf.data.dir).
#               Requires Oracle access.
# Pipeline:     Not in pipeline yet
################################################################################


# Load libraries
# install the main branch
#remotes::install_github("NEFSC/READ-PDB-mriptacklebox")

library("here")
library("mriptacklebox")
library("ROracle")
library("tidyverse")
library("DBI")
library("glue")
library("haven")
library("conflicted")
conflicts_prefer(dplyr::filter)
conflicts_prefer(dplyr::lag)




# standard "here", username setup, and paths
here::i_am("Code/pre_sim/get_mrip_trips.R")
source(here("Code", "helpers", "developer_setup.R"))

output_folder<-file.path(gf.data.dir, "miscellaneous")

vintage_string<-list.files(output_folder, pattern=glob2rx("mrip_pull*Rds"))
vintage_string<-gsub("mrip_pull","",vintage_string)
vintage_string<-gsub(".Rds","",vintage_string)
data_vintage<-max(vintage_string)

# write this to an rds file.
mrip_pull<-read_rds(file=file.path(output_folder, glue("mrip_pull{data_vintage}.Rds")))

# cast to upper case
mrip_pull <- map(mrip_pull, ~rename_with(.x, toupper))

# mrip_pull <- mrip_pull %>%
#   modify_at("trip", ~ .x %>%
#               mutate(my_dom_id = case_when(
#                 PRIM1_COMMON == "ATLANTIC COD" ~ "InDom",
#                 TRUE ~ "NotInDom"
#               )) %>%
#               mutate(my_dom_id=glue("{my_dom_id}_{YEAR}{WAVE}"))
#   )




# mrip_pull <- mrip_pull %>%
#   modify_at(c("catch","size","size_b2"), ~ .x %>%
#               mutate(my_dom_id = case_when(
#                 COMMON == "ATLANTIC COD" ~ "ATLANTIC_COD",
#                 COMMON == "HADDOCK" ~ "HADDOCK",
#                 TRUE ~ "NONE"
#               )) %>%
#               mutate(my_dom_id=glue("{my_dom_id}_{YEAR}{WAVE}"))
#   )


# Target or caught COD
targets_COD<-mrip_effort(dom=c("YEAR", "WAVE"),
                            microdata=mrip_pull,
                            dir_trip = list(comname = c('ATLANTIC COD'),
                                            typ = c('PRIM1', 'PRIM2', 'B1', 'B2')))
# Target or caught Haddock

targets_HADDOCK<-mrip_effort(dom=c("YEAR", "WAVE"),
                         microdata=mrip_pull,
                         dir_trip = list(comname = c('HADDOCK'),
                                         typ = c('PRIM1', 'PRIM2', 'B1', 'B2')))

# Target or caught Either

targets_EITHER<-mrip_effort(dom=c("YEAR", "WAVE"),
                            microdata=mrip_pull,
                            dir_trip = list(comname = c('ATLANTIC COD', 'HADDOCK'),
                                             typ = c('PRIM1', 'PRIM2', 'B1', 'B2')))


targets_COD[1,]
targets_HADDOCK[1,]
targets_EITHER[1,]
