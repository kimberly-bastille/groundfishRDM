################################################################################
# Script:       required_packages.R
# Purpose:      One-time environment setup — installs every R package the
#               pre-simulation scripts, R simulation wrapper, and Shiny apps
#               depend on.
# Inputs:       None.
# Outputs:      None (side effect: packages installed into the R library).
# Dependencies: None. Run manually once per machine / R installation.
# Pipeline:     Not called by any wrapper; standalone setup step.
################################################################################

## Required Packages
install.packages("shiny")
install.packages("shinyjs")
install.packages("shinyWidgets")
install.packages("magrittr")
install.packages("readr")
install.packages("here")
install.packages("dplyr")
install.packages("tidyr")
install.packages("stringr")
install.packages("lubridate")
install.packages("tibble")
install.packages("data.table")
install.packages("knitr")
install.packages("openxlsx")
install.packages("plyr")
install.packages("feather")
install.packages("markdown")
install.packages("webshot")
install.packages("DT")
install.packages("plotly")
install.packages("future")
install.packages("furrr")
install.packages("rlist")
