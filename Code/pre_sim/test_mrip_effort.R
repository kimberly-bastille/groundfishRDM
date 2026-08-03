################################################################################
# Script:       get_mrip_trips.R
# Purpose:      Uses the most recent version of mrip_pullDATE.Rds to construct trips
#               using MRIP tacklebox. Verify that MRIP tacklebox matches known good code
#               before switching to other harder metrics (catch by weight)
# Inputs:       mrip_pull{}.Rds
# Outputs:      None yet
# Dependencies: Packages here, mriptacklebox, ROracle, tidyverse, DBI, glue,
#               haven, conflicted. Sources developer_setup.R (for gf.data.dir).
# Pipeline:     Not in pipeline yet
#
# To Do:        Subset
################################################################################


# Load libraries
# install the main branch
library("here")
library("tidyverse")
library("glue")
library("conflicted")
conflicts_prefer(dplyr::filter)
conflicts_prefer(dplyr::lag)


mrip_pull<-read_rds("~/groundfishRDM/Data/2027_mgt_cycle/miscellaneous/mrip_pull2026-07-16.Rds")

# cast to upper case
mrip_pull <- map(mrip_pull, ~rename_with(.x, toupper))
devtools::load_all()
# What kinds of types should we look at

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


targets_COD[6]
targets_HADDOCK[6]




targets_COD2 <- types %>%
  map(~ mrip_effort(
    dom = c("YEAR"),
    microdata = mrip_pull,
    dir_trip = list(
      comname = c('ATLANTIC COD'),
      typ = .x
    )
  )) %>%
  set_names(list_names)

targets_HADDOCK2 <- types %>%
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

targets_EITHER2 <- types %>%
  map(~ mrip_effort(
    dom = c("YEAR"),
    microdata = mrip_pull,
    dir_trip = list(
      comname =  c('ATLANTIC COD', 'HADDOCK'),
      typ = .x
    )
  )) %>%
  set_names(list_names)

# no changes to the single species
all.equal(targets_COD,targets_COD2)
all.equal(targets_HADDOCK,targets_HADDOCK2)

