########################################################
########################################################
# Some helper functions that are used by both get_cod_assessment_data.R
# and get_haddock_assessment_data.R
# better to put 1 function in a single space than have to maintain two.


########################################################
#
# From the dashboard repo, this wrestles the wide NAA data into long format.
#
########################################################
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


########################################################
# Define the validation function
# Is our data what it claims to be.  We should have some characters, some
# numerics, a date. These should have no missing values.
########################################################
validate_naa_data <- function(df, file_in, type, age_classes, ndraws=1, years=1) {

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

  # Historical data should have the same number of rows as age classes* years.
  # projected data  should have age_classes*ndraws*years
    stopifnot(nrow(df) == age_classes * ndraws*years)



  # NOTE: state and wave are allowed to be NA; no type enforcement applied here

  # Return the dataframe invisibly to support tidyverse piping (%>%)
  invisible(df)
}
