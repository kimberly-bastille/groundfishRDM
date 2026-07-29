################################################################################
# Script:       get_mrip_trips.R
# Purpose:      Uses the most recent version of mrip_pullDATE.Rds to construct trips
#               using MRIP tacklebox. Verify that MRIP tacklebox matches known good code
#               before switching to other harder metrics (catch by weight)
# Inputs:       mrip_pull{}.Rds
# Outputs:      None yet
# Dependencies: mriptacklebox
#               Sources developer_setup.R (for gf.data.dir).
# Pipeline:     Not in pipeline yet
#
# To Do:        Subset geographically.  Disaggregate to "combined mode"
################################################################################


# Load libraries
# install the main branch, needs main on/after  7/29/2026
# remotes::install_github("NEFSC/READ-PDB-mriptacklebox")

library("here")
library("mriptacklebox")
library("tidyverse")
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

# Do this, and then you can use MODE_COMBINED as one of the domains
# mrip_pull <- mrip_pull %>%
#   modify_at(c("trip", "catch","size","size_b2"), ~ .x %>%
#               mutate(MODE_COMBINED = case_when(
#                 MODE_FX == "SOMETHING" ~ "FORHIRE",
#                 MODE_FX == "SOMETHING_ELSE" ~ "PRIVATE",
#                 MODE_FX == "THIRD_THING" ~ "SHORE",
#                 TRUE ~ MODE_FX
#               ))
#   )

# Sample code to create a my_dom_id var based on state
# mrip_pull <- mrip_pull %>%
#   modify_at("trip", ~ .x %>%
#               mutate(my_dom_id = case_when(
#                 ST_ABB %in% c("ME", "NH", "MA") ~ "InDom",
#                 TRUE ~ "NotInDom"
#               )))
#   )





types<-list(
  'PRIM1',
  'PRIM2',
  'A',
  'B1',
  'B2',
  c('PRIM1', 'PRIM2', 'A','B1', 'B2'),
  c('PRIM1', 'PRIM2'),
  c('A','B1', 'B2'),
  c('A','B1')
)
list_names <- types %>%
  map_chr(~ paste(.x, collapse = "|"))



targets_COD <- types %>%
  map(~ mrip_effort(
    dom = c("YEAR"),
    microdata = mrip_pull,
    dir_trip = list(
      comname = c('ATLANTIC COD'),
      typ = .x
    )
  )) %>%
  set_names(list_names)

targets_HADDOCK <- types %>%
  map(~ mrip_effort(
    dom = c("YEAR"),
    microdata = mrip_pull,
    dir_trip = list(
      comname = c('HADDOCK'),
      typ = .x
    )
  )) %>%
  set_names(list_names)

# Target or caught Either

targets_EITHER <- types %>%
  map(~ mrip_effort(
    dom = c("YEAR"),
    microdata = mrip_pull,
    dir_trip = list(
      comname =  c('ATLANTIC COD', 'HADDOCK'),
      typ = .x
    )
  )) %>%
  set_names(list_names)

# The relationship of some of the entries
# PRIM1 : Cod + haddock=Either by definition
# PRIM2: Same
# Everything else: Either>= Cod, Either>=Haddock, Either<=Cod+Haddock

