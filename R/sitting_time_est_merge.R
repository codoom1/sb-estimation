#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  library(dplyr)
})

args <- commandArgs(trailingOnly = TRUE)
get_arg <- function(name, default) {
  prefix <- paste0("--", name, "=")
  value <- args[startsWith(args, prefix)]
  if (length(value) == 0) default else sub(prefix, "", value[[1]])
}

project_root <- normalizePath(
  get_arg("project-root", "/work/pi_jstauden_umass_edu/pctSitting_research"),
  mustWork = FALSE
)
results_dir <- get_arg(
  "results-dir",
  file.path(project_root, "outputs", "final_analysis_adult", "results")
)

read_parts <- function(pattern) {
  files <- sort(list.files(results_dir, pattern = pattern, full.names = TRUE))
  if (length(files) == 0) stop("No files found for ", pattern, call. = FALSE)
  bind_rows(lapply(files, read.csv, stringsAsFactors = FALSE))
}

summarise_participants <- function(daily_data) {
  daily_data |>
    group_by(participant_id, dataset) |>
    summarise(
      number_of_days = n_distinct(nhanes_wear_day),
      avg_wake_hours = mean(wake_hours, na.rm = TRUE),
      avg_sleep_hours = 24 - avg_wake_hours,
      avg_sitting_hours = mean(sitting_hours, na.rm = TRUE),
      avg_sitting_percent_wake = mean(sitting_percent_wake, na.rm = TRUE),
      .groups = "drop"
    )
}

daily_sitting <- read_parts("^sitting_daily_batch_[0-9]+\\.csv$") |>
  distinct(participant_id, dataset, nhanes_wear_day, .keep_all = TRUE) |>
  group_by(participant_id, dataset) |>
  mutate(number_of_days = n_distinct(nhanes_wear_day)) |>
  ungroup() |>
  filter(number_of_days >= 1)

average_sitting <- summarise_participants(daily_sitting)

simple_average <- average_sitting |>
  summarise(
    n_ppt = n_distinct(participant_id),
    mean_n_days = mean(number_of_days),
    mean_wake_hours = mean(avg_wake_hours),
    mean_sleep_hours = mean(avg_sleep_hours),
    mean_sitting_hours = mean(avg_sitting_hours),
    mean_percent_sitting = mean(avg_sitting_percent_wake)
  )

daily_sitting_org <- read_parts("^sitting_daily_org_batch_[0-9]+\\.csv$") |>
  distinct(participant_id, dataset, nhanes_wear_day, .keep_all = TRUE)
average_sitting_org <- summarise_participants(daily_sitting_org)

hourly_sitting_daily <- read_parts("^sitting_hourly_batch_[0-9]+\\.csv$") |>
  filter(!is.na(hour_of_day), hour_of_day >= 0, hour_of_day <= 23) |>
  distinct(
    participant_id, dataset, nhanes_wear_day, day_type, hour_of_day,
    .keep_all = TRUE
  )

hourly_sitting <- hourly_sitting_daily |>
  group_by(participant_id, dataset, day_type, hour_of_day) |>
  summarise(
    number_of_days = n_distinct(nhanes_wear_day),
    avg_wake_hours = mean(wake_hours, na.rm = TRUE),
    avg_sitting_hours = mean(sitting_hours, na.rm = TRUE),
    avg_sitting_percent_hour = mean(sitting_percent_hour, na.rm = TRUE),
    .groups = "drop"
  ) |>
  filter(number_of_days >= 1)

hourly_sitting_profile <- hourly_sitting |>
  group_by(dataset, hour_of_day) |>
  summarise(
    n_participants = n_distinct(participant_id),
    mean_sitting_hours = mean(avg_sitting_hours, na.rm = TRUE),
    sd_sitting_hours = sd(avg_sitting_hours, na.rm = TRUE),
    se_sitting_hours = sd_sitting_hours / sqrt(n_participants),
    mean_sitting_percent_hour = mean(avg_sitting_percent_hour, na.rm = TRUE),
    sd_sitting_percent_hour = sd(avg_sitting_percent_hour, na.rm = TRUE),
    se_sitting_percent_hour = sd_sitting_percent_hour / sqrt(n_participants),
    .groups = "drop"
  )

write.csv(daily_sitting, file.path(results_dir, "daily_sitting.csv"), row.names = FALSE)
write.csv(average_sitting, file.path(results_dir, "average_sitting.csv"), row.names = FALSE)
write.csv(simple_average, file.path(results_dir, "simple_average.csv"), row.names = FALSE)
write.csv(daily_sitting_org, file.path(results_dir, "daily_sitting_org.csv"), row.names = FALSE)
write.csv(average_sitting_org, file.path(results_dir, "average_sitting_org.csv"), row.names = FALSE)
write.csv(hourly_sitting_daily, file.path(results_dir, "hourly_sitting_daily.csv"), row.names = FALSE)
write.csv(hourly_sitting, file.path(results_dir, "hourly_sitting.csv"), row.names = FALSE)
write.csv(hourly_sitting_profile, file.path(results_dir, "hourly_sitting_profile.csv"), row.names = FALSE)
message("Sitting-time summaries written to ", results_dir)
