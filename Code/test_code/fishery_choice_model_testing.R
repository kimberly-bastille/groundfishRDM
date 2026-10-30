
################################################################################
# Dev paths note (no full script header yet - out of scope for this pass):
# 5 hardcoded absolute paths to a developer's local machine (E:\),
# at lines 10, 11, 12, 13 and 14.
################################################################################

library(data.table)
library(fst)
library(readr)
library(conflicted)
library(dplyr)
conflicts_prefer(data.table::month)
# Optional parallel backend is loaded only in the wrapper below.

final_process_data_cd="E:/Lou_projects/groundfishRDM/2027_mgt_cycle"
final_process_outcomes_cd="E:/Lou_projects/groundfishRDM/2027_mgt_cycle/base_outcomes"
final_process_choice_occasions_cd="E:/Lou_projects/groundfishRDM/2027_mgt_cycle/n_choice_occasions"
final_process_misc_cd="E:/Lou_projects/groundfishRDM/2027_mgt_cycle/miscellaneous"
final_process_calib_catch_cd="E:/Lou_projects/groundfishRDM/2027_mgt_cycle/calib_catch_draws"


# -----------------------------------------------------------------------------
# User-facing controls
# -----------------------------------------------------------------------------
draws         <- 1:5
n_simulations <- 5
mode_draw     <- c("pr", "fh")
season_draw   <- c("summer", "winter")
draws         <- if (exists("draws")) draws else seq_len(n_simulations)
n_draws       <- 50L

# Length-weight parameters from the calibration script.
cod_lw_a <- if (exists("cod_lw_a")) cod_lw_a else 0.000005132
cod_lw_b <- if (exists("cod_lw_b")) cod_lw_b else 3.1625
had_lw_a <- if (exists("had_lw_a")) had_lw_a else 0.000009298
had_lw_b <- if (exists("had_lw_b")) had_lw_b else 3.0205

# -----------------------------------------------------------------------------
# Helper functions
# -----------------------------------------------------------------------------

parse_date_any <- function(x) {
  data.table::as.IDate(as.Date(
    x,
    tryFormats = c("%d%b%Y", "%Y-%m-%d", "%m/%d/%Y", "%d/%m/%Y")
  ))
}

cod_hadd_season <- function(date_parsed) {
  data.table::fifelse(data.table::month(date_parsed) %in% c(9, 10, 11, 12, 1, 2, 3, 4),
                      "winter", "summer")
}

first_existing_file <- function(path_candidates, required = TRUE) {
  path <- path_candidates[file.exists(path_candidates)][1]
  if (is.na(path) && isTRUE(required)) {
    stop("None of these files exist: ", paste(path_candidates, collapse = "; "), call. = FALSE)
  }
  path
}

check_required_cols <- function(dt, cols, object_name) {
  missing_cols <- setdiff(cols, names(dt))
  if (length(missing_cols)) {
    stop(object_name, " is missing required columns: ", paste(missing_cols, collapse = ", "), call. = FALSE)
  }
  invisible(TRUE)
}

zero_missing_cols <- function(dt, cols) {
  cols <- intersect(cols, names(dt))
  for (cc in cols) data.table::set(dt, which(is.na(dt[[cc]])), cc, 0)
  invisible(dt)
}



# packages
# install.packages(c("data.table", "fst", "survey", "lubridate"))

# -------------------------
# 1. Estimate logit model
# -------------------------
mrip_trip_data <- as.data.table(haven::read_dta(file.path(final_process_misc_cd,"historical_trips_cod_hadd.dta")))

logit_est_data <- data.table::copy(mrip_trip_data)
logit_est_data<-logit_est_data %>%
  dplyr::filter(target_pop3==1)

logit_est_data[, cod_season_open := as.integer(cod_bag_limit > 0)]
logit_est_data[, month := as.integer(month1)]
logit_est_data[, mode2 := factor(mode1)]
logit_est_data[, month_fac := factor(month)]

des <- survey::svydesign(
  ids = ~1,
  weights = ~wp_int,
  data = logit_est_data
)

m0 <- survey::svyglm(
  cod_trip ~ cod_season_open * month_fac + mode2 + cod_bag_limit,
  design = des,
  family = quasibinomial()
)

summary(m0)

months <- sort(unique(logit_est_data$month))

margin_grid <- data.table::CJ(
  month = months,
  cod_season_open = c(0, 1)
)

margin_grid[, month_fac := factor(
  month,
  levels = levels(logit_est_data$month_fac)
)]

# choose reference mode
margin_grid[, mode2 := factor(
  "pr",
  levels = levels(logit_est_data$mode2)
)]

# representative bag limits
margin_grid[, cod_bag_limit := fifelse(
  cod_season_open == 1,
  1,
  0
)]

margin_grid[, pred := predict(
  m0,
  newdata = margin_grid,
  type = "response"
)]


ggplot2::ggplot(
  margin_grid,
  ggplot2::aes(
    x = month,
    y = pred,
    color = factor(cod_season_open)
  )
) +
  ggplot2::geom_line(linewidth = 1) +
  ggplot2::geom_point() +
  ggplot2::scale_x_continuous(breaks = 3:12) +
  ggplot2::labs(
    x = "Month",
    y = "Predicted probability of cod trip",
    color = "Cod season open"
  ) +
  ggplot2::theme_bw()
# -------------------------
# 2. Build baseline prediction data
# -------------------------
directed_trips <- data.table::as.data.table(
  fst::read_fst(file.path(final_process_misc_cd, "directed_trip_draws.fst"))
)

directed_trips[, season := cod_hadd_season(date_parsed)]

check_required_cols(
  directed_trips,
  c("draw", "season", "mode", "date_parsed", "dtrip", "cod_bag", "dtrip"),
  "directed_trips"
)

directed_trips <- directed_trips[
  draw<= 10
  ]

directed_trips <- directed_trips[
  ,
  .(draw,
    dtrip,
    season,
    mode,
    date_parsed,
    month = lubridate::month(date_parsed),
    cod_bag
  )
]

directed_trips[, cod_season_open := as.integer(cod_bag > 0)]

read_nchoice_one <- function(s, md, dr) {
  nchoice_path <- file.path(
    final_process_choice_occasions_cd,
    paste0("n_choice_occasions_", s, "_", md, "_", dr, ".fst")
  )

  x <- data.table::as.data.table(fst::read_fst(nchoice_path))

  x <- x[
    ,
    .(
      date_parsed = as.Date(date_parsed),
      mode = as.character(mode),
      n_choice_occasions
    )
  ]

  x[, `:=`(
    season = as.character(s),
    draw = as.integer(dr),
    mode = as.character(md)
  )]

  x[]
}

seasons <- c("summer", "winter")   # adjust if needed
modes   <- c("pr", "fh")           # adjust if needed
draws   <- 1:10


n_choice_occasions_all <- data.table::rbindlist(
  lapply(seasons, function(s) {
    data.table::rbindlist(
      lapply(modes, function(md) {
        data.table::rbindlist(
          lapply(draws, function(dr) {
            read_nchoice_one(s, md, dr)
          }),
          use.names = TRUE,
          fill = TRUE
        )
      }),
      use.names = TRUE,
      fill = TRUE
    )
  }),
  use.names = TRUE,
  fill = TRUE
)


logit_data <- merge(
  directed_trips,
  n_choice_occasions_all,
  by = c("draw", "season", "mode", "date_parsed"),
  all.x = TRUE
)

logit_data <- data.table::as.data.table(logit_data)
logit_data <- data.table::copy(logit_data)

logit_data<-logit_data %>%
  dplyr::filter(dtrip>0)

# create prediction variables using same names as model
logit_data[, cod_season_open := as.integer(cod_bag > 0)]
logit_data[, month := as.integer(month)]
logit_data[, mode2 := factor(mode)]
logit_data[, month_fac := factor(month)]
logit_data[, cod_bag_limit := as.integer(cod_bag )]


# 3.  Predict baseline probabilities
logit_data[, p_cod_trip_base := as.numeric(
  stats::predict(m0, newdata = logit_data, type = "response")
)]


# 4. Create counterfactual regulation scenario - this will be automated based on Shiny app
cf_data <- data.table::copy(logit_data)

cf_data[, scenario := "counterfactual"]

cf_data[
  month == 5,
  `:=`(
    cod_season_open = 1L,
    cod_bag = 1
  )
]

cf_data[, p_cod_trip_cf := as.numeric(
  stats::predict(m0, newdata = cf_data, type = "response")
)]


# 5. Compute probability changes and expansion ratios
pred_compare <- data.table::copy(logit_data)

pred_compare[, p_cod_trip_cf := cf_data$p_cod_trip_cf]

pred_compare[, prob_change := p_cod_trip_cf - p_cod_trip_base]

pred_compare[, prob_ratio := data.table::fifelse(
  p_cod_trip_base > 0,
  p_cod_trip_cf / p_cod_trip_base,
  NA_real_
)]

eps <- 1e-6

pred_compare[, prob_ratio_safe := (p_cod_trip_cf + eps) / (p_cod_trip_base + eps)]

# 6. Compute expanded choice occasions

pred_compare[,
             n_choice_occasions_cod_base := p_cod_trip_base*
               n_choice_occasions
]

pred_compare[,
             n_choice_occasions_noncod_base := (1-p_cod_trip_base)*
               n_choice_occasions
]

pred_compare[, n_choice_occasions_cod_cf :=
               n_choice_occasions_cod_base * prob_ratio_safe
]


pred_compare[,
             n_choice_occasions_cf_all := n_choice_occasions_cod_cf + n_choice_occasions_noncod_base


]



monthly_summary <- pred_compare[
  ,
  .(
    n_choice_occasions = sum(n_choice_occasions, na.rm = TRUE),
    n_choice_occasions_cf = sum(n_choice_occasions_cf_all, na.rm = TRUE)
  ),
  by = .(month, draw)
][
  ,
  `:=`(
    change = n_choice_occasions_cf - n_choice_occasions,
    pct_change = 100 * (n_choice_occasions_cf / n_choice_occasions - 1)
  )
][order(month, draw)]

monthly_summary <- monthly_summary[
  ,
  .(
    mean_n_choice_occasions = mean(n_choice_occasions, na.rm = TRUE),
    mean_n_choice_occasions_cf = mean(n_choice_occasions_cf, na.rm = TRUE),
    mean_change = mean(change, na.rm = TRUE),
    mean_pct_change = mean(pct_change, na.rm = TRUE),
    sd_change = stats::sd(change, na.rm = TRUE),
    q025_change = stats::quantile(change, 0.025, na.rm = TRUE),
    q975_change = stats::quantile(change, 0.975, na.rm = TRUE)
  ),
  by = month
][order(month)]



# Pull in directed trips, retain regs by day
directed_trips <- as.data.table(read_fst(file.path(final_process_misc_cd,"directed_trip_draws.fst")))
directed_trips[, season := cod_hadd_season(date_parsed)]

check_required_cols(directed_trips, c("draw", "season", "mode", "date_parsed", "dtrip"), "directed_trips")
directed_trips <- directed_trips[draw %in% draws & season %in% season_draw & mode %in% mode_draw]
data.table::setkey(directed_trips, draw, season, mode, date_parsed)

directed_trips <- directed_trips[draw ==1 & season=="summer" & mode=="pr"]
directed_trips<-directed_trips[, .(mode, month, date_parsed, cod_bag)]

logit_data <- merge(directed_trips, n_choice_occasions, by = c("date_parsed", "mode"), all.x = TRUE)


nchoice_path <- file.path(final_process_choice_occasions_cd, paste0("n_choice_occasions_", s, "_", md, "_", dr, ".fst"))
n_choice_occasions <- data.table::as.data.table(fst::read_fst(nchoice_path))
n_choice_occasions <- n_choice_occasions[, .(date_parsed, mode, n_choice_occasions)]
