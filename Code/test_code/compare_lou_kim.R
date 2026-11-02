
library(readr)
library(readxl)
library(dplyr)
library(ggplot2)
library(tidyr)

#===============================================================================
# 1. LOAD AND COMBINE DATA
#===============================================================================

kim <- readr::read_csv(
  "E:/Lou_projects/groundfishRDM/2027_mgt_cycle/archive for testing 9-11-26/simulation_testing/output_KimLocal_SQactual_20261008_215435.csv",
  show_col_types = FALSE
) %>%
  dplyr::select(season, mode, metric, value, iteration) %>%
  dplyr::mutate(source = "Kim")

mine <- read_csv(
  #"E:/Lou_projects/groundfishRDM/2027_mgt_cycle/simulation_testing/lou_local_altregs_10_27_26.xlsx"
  "E:/Lou_projects/groundfishRDM/2027_mgt_cycle/archive for testing 9-11-26/simulation_testing/output_all_18_Hadd_20261023_180043.csv",  show_col_types = FALSE

) %>%
  dplyr::select(season, mode, metric, value, iteration) %>%
  dplyr::mutate(source = "Mine")

cloud <- readr::read_csv(
  "E:/Lou_projects/groundfishRDM/2027_mgt_cycle/archive for testing 9-11-26/simulation_testing/output_KB_test2_20261027_200148.csv",
  show_col_types = FALSE
) %>%
  dplyr::select(season, mode, metric, value, iteration) %>%
  dplyr::mutate(source = "Cloud")

results <- dplyr::bind_rows(mine, cloud) %>%
  dplyr::mutate(source = factor(source, levels = c("Mine",  "Cloud")))

# Verify observations by source
dplyr::count(results, source)
# Check dimensions / metrics
dplyr::count(results, source)
sort(unique(results$metric))

trip_metrics <- c(
  "n_trips_base",
  "n_trips_alt",
  "CV"
)

results %>%
  dplyr::filter(
    mode == "all modes",
    metric %in% trip_metrics
  ) %>%
  ggplot2::ggplot(
    ggplot2::aes(x = source, y = value, fill = source)
  ) +
  ggplot2::geom_boxplot(outlier.alpha = 0.2) +
  ggplot2::facet_grid(metric ~ season, scales = "free_y") +
  ggplot2::labs(
    x = NULL,
    y = "Simulated value",
    fill = NULL
  ) +
  ggplot2::theme_bw() +
  ggplot2::theme(
    legend.position = "none",
    strip.background = ggplot2::element_blank()
  )

catch_metrics <- c(
  "tot_cat_cod_new",
  "tot_keep_cod_new",
  "tot_rel_cod_new",
  "tot_cat_hadd_new",
  "tot_keep_hadd_new",
  "tot_rel_hadd_new"
)

all_metrics <- c(
  "tot_cat_cod_new",
  "tot_keep_cod_new",
  "tot_rel_cod_new",
  "tot_cat_hadd_new",
  "tot_keep_hadd_new",
  "tot_rel_hadd_new",
  "n_trips_base",
  "n_trips_alt",
  "CV"
)

results %>%
  dplyr::filter(
    mode == "all modes",
    metric %in% catch_metrics
  ) %>%
  dplyr::mutate(
    metric = factor(metric, levels = catch_metrics)
  ) %>%
  ggplot2::ggplot(
    ggplot2::aes(x = source, y = value, fill = source)
  ) +
  ggplot2::geom_boxplot(outlier.alpha = 0.2) +
  ggplot2::facet_grid(metric ~ season, scales = "free_y") +
  ggplot2::labs(
    x = NULL,
    y = "Number of fish",
    fill = NULL
  ) +
  ggplot2::theme_bw() +
  ggplot2::theme(
    legend.position = "none",
    strip.background = ggplot2::element_blank()
  )

results %>%
  dplyr::filter(
    mode == "all modes",
    metric %in% trip_metrics
  ) %>%
  dplyr::mutate(
    metric = factor(metric, levels = trip_metrics)
  ) %>%
  ggplot2::ggplot(
    ggplot2::aes(x = source, y = value, fill = source)
  ) +
  ggplot2::geom_boxplot(outlier.alpha = 0.2) +
  ggplot2::facet_grid(metric ~ season, scales = "free_y") +
  ggplot2::labs(
    x = NULL,
    y = "Number of trips/CV",
    fill = NULL
  ) +
  ggplot2::theme_bw() +
  ggplot2::theme(
    legend.position = "none",
    strip.background = ggplot2::element_blank()
  )


paired <- results %>%
  tidyr::pivot_wider(
    id_cols = c(season, mode, metric, iteration),
    names_from = source,
    values_from = value
  ) %>%
  dplyr::mutate(
    diff_kim_mine = Kim - Mine,
    diff_cloud_mine = Cloud - Mine,
    diff_cloud_kim = Cloud - Kim
  )

# Reshape differences into long format
paired_long <- paired %>%
  tidyr::pivot_longer(
    cols = dplyr::starts_with("diff_"),
    names_to = "comparison",
    values_to = "diff"
  ) %>%
  dplyr::mutate(
    comparison = dplyr::recode(comparison,
                               "diff_kim_mine" = "Kim - Mine",
                               "diff_cloud_mine" = "Cloud - Mine",
                               "diff_cloud_kim" = "Cloud - Kim"
    )
  )

# Catch comparisons
paired_long %>%
  dplyr::filter(mode == "all modes", metric %in% catch_metrics) %>%
  dplyr::mutate(metric = factor(metric, levels = catch_metrics)) %>%
  ggplot2::ggplot(ggplot2::aes(x = comparison, y = diff, fill = comparison)) +
  ggplot2::geom_hline(yintercept = 0, linetype = "dashed") +
  ggplot2::geom_boxplot(outlier.alpha = 0.2) +
  ggplot2::facet_grid(metric ~ season, scales = "free_y") +
  ggplot2::labs(x = NULL, y = "Difference in projected catch") +
  ggplot2::theme_bw() +
  ggplot2::theme(legend.position = "none", strip.background = ggplot2::element_blank())

# Trip and welfare comparisons
paired_long %>%
  dplyr::filter(mode == "all modes", metric %in% trip_metrics) %>%
  dplyr::mutate(metric = factor(metric, levels = trip_metrics)) %>%
  ggplot2::ggplot(ggplot2::aes(x = comparison, y = diff, fill = comparison)) +
  ggplot2::geom_hline(yintercept = 0, linetype = "dashed") +
  ggplot2::geom_boxplot(outlier.alpha = 0.2) +
  ggplot2::facet_grid(metric ~ season, scales = "free_y") +
  ggplot2::labs(x = NULL, y = "Difference in projected outcomes") +
  ggplot2::theme_bw() +
  ggplot2::theme(legend.position = "none", strip.background = ggplot2::element_blank())

comparison_summary2 <- results %>%
  dplyr::filter(mode=="all modes") %>%
  dplyr::group_by(mode, metric, source) %>%
  dplyr::summarise(
    median_value = median(value, na.rm = TRUE),
    mean_value = mean(value, na.rm = TRUE),
    .groups = "drop"
  ) %>%
  tidyr::pivot_wider(
    id_cols = c(mode, metric),
    names_from = source,
    values_from = c(median_value, mean_value)
  ) %>%
  dplyr::mutate(
    diff_median_cloud_mine = median_value_Cloud - median_value_Mine
  ) %>%
  dplyr::select(mode, metric, diff_median_cloud_mine)

comparison_summary2 %>%
  dplyr::mutate(dplyr::across(where(is.numeric), ~ scales::comma(.x, accuracy = 0.01))) %>%
  print(n = Inf, width = Inf)

options(scipen=999)
print(comparison_summary2, n = Inf)

comparison_summary2 <- comparison_summary2 %>%
  dplyr::mutate(
    pct_median_kim_mine = 100 * (median_value_Kim / median_value_Mine - 1),
    pct_median_cloud_mine = 100 * (median_value_Cloud / median_value_Mine - 1),
    pct_median_cloud_kim = 100 * (median_value_Cloud / median_value_Kim - 1)
  )
print(comparison_summary2, n = Inf, digits=6)


kim_dir <- readr::read_csv("E:/Lou_projects/groundfishRDM/2027_mgt_cycle/archive for testing 9-11-26/simulation_testing/directed_trips_kim_18inHadd.csv", show_col_types = FALSE) %>%
  dplyr::select(-dplyr::any_of("Unnamed: 0")) %>%
  dplyr::mutate(date = as.Date(date_parsed))


orig_dir <- fst::read_fst("D:/Shared drives/NMFS NEC READ SSB/socialsci/RecreationalDST/2027_management_cycle_data/groundfishRDM/miscellaneous/directed_trip_draws.fst") %>%
  dplyr::mutate(date = as.Date(date_parsed)) %>%
  dplyr::select(-date_parsed)

write.csv(orig_dir, "E:/Lou_projects/groundfishRDM/2027_mgt_cycle/archive for testing 9-11-26/simulation_testing/lou_directed_trips.csv")

dir_compare <- kim_dir %>%
  dplyr::filter(mode!="sh") %>%
  dplyr::inner_join(
    orig_dir,
    by = c("mode", "date", "draw"),
    suffix = c("_kim", "_orig")
  ) %>%
  dplyr::mutate(
    diff_hadd_bag = hadd_bag_kim - hadd_bag_orig,
    diff_hadd_min = hadd_min_kim - hadd_min_orig,
    diff_cod_bag = cod_bag_kim - cod_bag_orig,
    diff_cod_min = cod_min_kim - cod_min_orig,
    diff_dtrip = dtrip_kim - dtrip_orig
  ) %>%
  dplyr::filter(diff_dtrip!=0)


dir_compare %>%
  dplyr::select(date, mode, draw, dplyr::starts_with("diff_")) %>%
  tidyr::pivot_longer(
    cols = dplyr::starts_with("diff_"),
    names_to = "variable",
    values_to = "difference"
  ) %>%
  dplyr::group_by(date, mode, variable) %>%
  dplyr::summarise(difference = mean(difference), .groups = "drop") %>%
  ggplot2::ggplot(ggplot2::aes(x = date, y = difference)) +
  ggplot2::geom_hline(yintercept = 0, linetype = "dashed") +
  ggplot2::geom_line() +
  ggplot2::facet_grid(variable ~ mode, scales = "free_y") +
  ggplot2::labs(x = "Date", y = "Kim - Original") +
  ggplot2::theme_bw()



# Aggregate across seasons within each simulation draw
weight_data <- results %>%
  dplyr::filter(mode == "all modes",
                metric %in% c(
                  "tot_keep_cod_new", "tot_rel_cod_new",
                  "tot_keep_hadd_new", "tot_rel_hadd_new",
                  "tot_keep_cod_weight_lb_new", "tot_rel_cod_weight_lb_new",
                  "tot_keep_hadd_weight_lb_new", "tot_rel_hadd_weight_lb_new"
                )
  ) %>%
  dplyr::group_by(source, iteration, metric) %>%
  dplyr::summarise(value = sum(value, na.rm = FALSE), .groups = "drop") %>%
  tidyr::pivot_wider(names_from = metric, values_from = value) %>%
  dplyr::mutate(
    avg_wt_cod_keep = tot_keep_cod_weight_lb_new / dplyr::na_if(tot_keep_cod_new, 0),
    avg_wt_cod_rel = tot_rel_cod_weight_lb_new / dplyr::na_if(tot_rel_cod_new, 0),
    avg_wt_hadd_keep = tot_keep_hadd_weight_lb_new / dplyr::na_if(tot_keep_hadd_new, 0),
    avg_wt_hadd_rel = tot_rel_hadd_weight_lb_new / dplyr::na_if(tot_rel_hadd_new, 0)
  )

weight_comparison <- weight_data %>%
  dplyr::select(source, iteration, dplyr::starts_with("avg_wt_")) %>%
  tidyr::pivot_longer(cols = dplyr::starts_with("avg_wt_"),
                      names_to = "metric", values_to = "avg_weight") %>%
  dplyr::group_by(source, metric) %>%
  dplyr::summarise(
    median_weight = median(avg_weight, na.rm = TRUE),
    mean_weight = mean(avg_weight, na.rm = TRUE),
    .groups = "drop"
  ) %>%
  tidyr::pivot_wider(names_from = source, values_from = c(median_weight, mean_weight)) %>%
  dplyr::mutate(
    diff_median = median_weight_Cloud - median_weight_Mine,
    diff_mean = mean_weight_Cloud - mean_weight_Mine
  )

weight_comparison %>%
  dplyr::mutate(dplyr::across(where(is.numeric), ~round(.x, 3))) %>%
  print(n = Inf, width = Inf)

weight_plot_data <- weight_data %>%
  dplyr::select(source, iteration, dplyr::starts_with("avg_wt_")) %>%
  tidyr::pivot_longer(cols = dplyr::starts_with("avg_wt_"),
                      names_to = "metric", values_to = "avg_weight") %>%
  dplyr::mutate(
    metric = dplyr::recode(metric,
                           "avg_wt_cod_keep" = "Cod - Kept",
                           "avg_wt_cod_rel" = "Cod - Released",
                           "avg_wt_hadd_keep" = "Haddock - Kept",
                           "avg_wt_hadd_rel" = "Haddock - Released"
    )
  )

ggplot2::ggplot(weight_plot_data, ggplot2::aes(x = source, y = avg_weight, fill = source)) +
  ggplot2::geom_boxplot(outlier.alpha = 0.2) +
  ggplot2::facet_wrap(~metric, scales = "free_y", ncol = 2) +
  ggplot2::labs(x = NULL, y = "Average weight per fish (lb)") +
  ggplot2::theme_bw() +
  ggplot2::theme(legend.position = "none")
