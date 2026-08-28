################################################################################
# Script:       naa_helpers.R  (helpers)
# Purpose:      Shared helper functions for reshaping and validating stock
#               assessment numbers-at-age (NAA) data, used by both
#               get_cod_assessment_data.R and get_haddock_assessment_data.R so
#               the logic lives in one place.
# Inputs:       None at source time (defines functions only).
# Outputs:      Functions pivot_naa_long() and validate_naa_data() in the
#               calling environment.
# Dependencies:
# Pipeline:     Sourced by the two get_*_assessment_data.R scripts; not called
#               by any wrapper.
################################################################################


#' @title Reshape wide numbers-at-age data to long format
#' @description Takes an assessment data frame with one column per age
#'   (age0, age1, ...) and pivots it long, folding the age number into the
#'   `metric` label (e.g. metric "NAA" for age 3 becomes "NAA 3"). Mirrors the
#'   long shape the dashboard repo expects.
#' @param df Wide NAA data frame containing age columns named ageN and a
#'   `metric` column naming the quantity (e.g. numbers-at-age).
#' @return A long data frame with one row per original row × age, the `age`
#'   folded into `metric`, and the standalone `age` column dropped.
#' @examples
#' \dontrun{
#' pivot_naa_long(cod_naa_wide)
#' }
pivot_naa_long <- function(df) {
  age_cols <- grep("^age\\d+$", names(df), value = TRUE)
  df %>%
    tidyr::pivot_longer(cols = all_of(age_cols),
                        names_to  = "age",
                        values_to = "value") %>%
    mutate(age = as.integer(sub("age", "", age)),
           metric=glue("{metric} {age}")) %>%
    select(-age)
}

#' @title Validate NAA data types and completeness
#' @description Guards downstream steps against malformed assessment data by
#'   asserting that the descriptive columns are non-missing character vectors,
#'   that species_itis and value are numeric, and that data_version is a Date.
#'   `state` and `wave` are deliberately allowed to be NA (not every record
#'   carries them). Stops with an error on the first violated assumption.
#' @param df A long NAA data frame (typically the output of pivot_naa_long()).
#' @param nage_classes The number of age classes in the assessment.
#' @param ndraws The number of replicates in the NAA data. 1 by default.
#' @param years The number of years of NAA data
#' @return The input `df`, returned invisibly so the call can sit inside a
#'   `%>%` pipe without printing.
#' @examples
#' \dontrun{
#' cod_naa_long %>% validate_naa_data()
#' }

validate_naa_data <- function(df, age_classes, ndraws=1, years=1) {
# Ensure specified columns are character vectors and contain no NAs
  stopifnot(
    is.character(df$fishery) && !any(is.na(df$fishery)),
    is.character(df$common) && !any(is.na(df$common)),
    is.character(df$stock_abbrev) && !any(is.na(df$stock_abbrev)),
    is.character(df$metric) && !any(is.na(df$metric)),
    is.character(df$source) && !any(is.na(df$source)),
    is.character(df$units) && !any(is.na(df$units))
  )

  # Ensure species_itis and value are numeric
  stopifnot(is.numeric(df$species_itis))
  stopifnot(is.numeric(df$value))

  # Ensure data_version is a Date class
  stopifnot(inherits(df$data_version, "Date"))

  # Add data whould have nage_classes*ndraws*years
    stopifnot(nrow(df) == nage_classes * ndraws*years)



  # NOTE: state and wave are allowed to be NA; no type enforcement applied here

  # Return the dataframe invisibly to support tidyverse piping (%>%)
  invisible(df)
}
