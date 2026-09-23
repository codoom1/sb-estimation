#!/usr/bin/env Rscript
# Paired sensitivity to CRIB sleep-bout parameters on the fixed primary days.
suppressPackageStartupMessages({
  library(arrow); library(dplyr); library(readr); library(tidyr); library(PBpatterns)
})
args <- commandArgs(trailingOnly = TRUE)
arg <- function(name, default) {
  value <- args[startsWith(args, paste0("--", name, "="))]
  if (length(value)) sub(paste0("--", name, "="), "", value[[1]]) else default
}
root <- normalizePath(arg("project-root", getwd()), mustWork = TRUE)
batch_index <- as.integer(arg("batch-index", "1"))
n_batches <- as.integer(arg("n-batches", "50"))
stopifnot(batch_index >= 1L, batch_index <= n_batches)
out <- file.path(root, "outputs", "final_analysis_adult", "parameter_sensitivity")
dir.create(file.path(out, "batches"), recursive = TRUE, showWarnings = FALSE)
primary_file <- file.path(root, "data/derived/primary_daily_sitting.csv")
primary <- read_csv(primary_file, show_col_types = FALSE) |>
  mutate(participant_id = as.character(participant_id), dataset = as.character(dataset))
keys <- c("participant_id", "dataset", "nhanes_wear_day")
people <- primary |> distinct(participant_id, dataset) |> arrange(dataset, participant_id) |>
  mutate(batch = (row_number() - 1L) %% n_batches + 1L) |> filter(batch == batch_index)
cohort <- read_csv(file.path(root, "outputs/final_analysis_adult/qc/primary_day_rule/cohort_summary.csv"), show_col_types=FALSE)
stopifnot(cohort$policy == "known_wake_sleep_bounded_nonwear_v3",
          nrow(primary) == cohort$days, nrow(distinct(primary, participant_id, dataset)) == cohort$participants,
          cohort$primary_days_md5 == unname(tools::md5sum(primary_file)),
          !anyDuplicated(primary[keys]), nrow(people) > 0)
ids <- people$participant_id
# Use the current repaired merged source. Classify full participant records
# before selecting primary days, retaining the same context as primary CRIB.
source_file <- file.path(root, "data/upstream/minute_level_classification.parquet")
records <- open_dataset(source_file) |>
  filter(participant_id %in% ids) |>
  select(participant_id, dataset, nhanes_wear_day, minute_index,
         sleep_prediction, chap_sitting_fraction) |> collect() |>
  mutate(participant_id = as.character(participant_id), dataset = as.character(dataset)) |>
  semi_join(people, by = c("participant_id", "dataset"))
settings <- crossing(required_percent = c(70, 80, 90), minimum_bout_minutes = c(20, 30, 45, 60))
# Validate the reference first, before calculating alternatives.
settings <- settings |> arrange(desc(required_percent == 80 & minimum_bout_minutes == 30))
all_daily <- vector("list", nrow(people))
for (i in seq_len(nrow(people))) {
  person <- people[i, ]
  x <- records |> filter(participant_id == person$participant_id, dataset == person$dataset) |>
    arrange(nhanes_wear_day, minute_index)
  target <- primary |> filter(participant_id == person$participant_id, dataset == person$dataset)
  stopifnot(nrow(x) > 0, !anyNA(x$chap_sitting_fraction),
            !anyDuplicated(x[c(keys, "minute_index")]),
            all(table(x$nhanes_wear_day) == 1440L))
  states <- factor(x$sleep_prediction, levels = c("Wake", "Sleep", "Non-wear", "Unknown"))
  stopifnot(!anyNA(states))
  daily_settings <- vector("list", nrow(settings))
  for (j in seq_len(nrow(settings))) {
    setting <- settings[j, ]
    bouts <- analyze_bouts(
      x = states, target = "Sleep", method = "CRIB", target_buffer_mins = 10,
      longest_allowable_interruption_mins = 10, required_percent = setting$required_percent,
      max_n_interruptions = Inf, minimum_bout_duration_minutes = setting$minimum_bout_minutes,
      epoch_length_sec = 60
    )
    classified <- expand_bouts(bouts)
    stopifnot(length(classified) == nrow(x))
    wake <- !classified %in% c("Sleep", "interruption")
    daily <- x |> mutate(wake = wake, sitting_wake = if_else(wake, chap_sitting_fraction, 0)) |>
      group_by(across(all_of(keys))) |>
      summarise(waking_hours = sum(wake) / 60, sedentary_hours = sum(sitting_wake) / 60,
                .groups = "drop") |>
      inner_join(target |> select(all_of(keys), reference_waking_hours = wake_hours,
                                  reference_sedentary_hours = sitting_hours), by = keys)
    stopifnot(nrow(daily) == nrow(target))
    if (setting$required_percent == 80 && setting$minimum_bout_minutes == 30) {
      stopifnot(max(abs(daily$waking_hours - daily$reference_waking_hours)) < 1e-8,
                max(abs(daily$sedentary_hours - daily$reference_sedentary_hours)) < 1e-8)
    }
    daily_settings[[j]] <- daily |> mutate(required_percent = setting$required_percent,
                                           minimum_bout_minutes = setting$minimum_bout_minutes)
  }
  all_daily[[i]] <- bind_rows(daily_settings)
  if (i %% 10L == 0L) message("Batch ", batch_index, ": ", i, "/", nrow(people), " participants")
}
daily <- bind_rows(all_daily)
participant <- daily |> group_by(participant_id, dataset, required_percent, minimum_bout_minutes) |>
  summarise(n_days = n(), waking_hours = mean(waking_hours), sedentary_hours = mean(sedentary_hours),
            reference_sedentary_hours = mean(reference_sedentary_hours),
            difference_hours = mean(sedentary_hours - reference_sedentary_hours), .groups = "drop")
stopifnot(nrow(participant) == nrow(people) * 12L)
write_csv(daily, file.path(out, "batches", sprintf("daily_%03d.csv", batch_index)))
write_csv(participant, file.path(out, "batches", sprintf("participant_%03d.csv", batch_index)))
write_csv(tibble(batch = batch_index, n_batches, participants = nrow(people),
                 primary_days_md5 = unname(tools::md5sum(primary_file)),
                 source_size = file.info(source_file)$size,
                 source_modified = as.character(file.info(source_file)$mtime),
                 PBpatterns_version = as.character(packageVersion("PBpatterns"))),
          file.path(out, "batches", sprintf("provenance_%03d.csv", batch_index)))
message("Finished primary sensitivity batch ", batch_index)
