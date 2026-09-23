#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  library(arrow)
  library(dplyr)
  library(haven)
  library(purrr)
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
input_dir <- get_arg(
  "input-dir",
  file.path(project_root, "outputs", "final_analysis", "results")
)
output_dir <- get_arg(
  "output-dir",
  file.path(project_root, "outputs", "final_analysis_crib_adult", "results")
)
batch_index <- as.integer(get_arg("batch-index", Sys.getenv("SLURM_ARRAY_TASK_ID", "0")))
batch_count <- as.integer(get_arg("batch-count", Sys.getenv("SLURM_ARRAY_TASK_COUNT", "1")))
if (is.na(batch_index) || is.na(batch_count) || batch_index < 0 || batch_count < 1) {
  stop("Invalid batch-index or batch-count.", call. = FALSE)
}

files <- sort(list.files(
  input_dir,
  pattern = "^crib_ppt_df_batch_[0-9]+\\.parquet$",
  full.names = TRUE
))
first_file_index <- batch_index + 1L
if (first_file_index <= length(files)) {
  files <- files[seq.int(
    from = first_file_index,
    to = length(files),
    by = batch_count
  )]
} else {
  files <- character()
}
if (length(files) == 0) {
  message("No input batch parquet files assigned to task ", batch_index, ".")
  quit(save = "no", status = 0)
}

longest_run <- function(values, target) {
  target_values <- !is.na(values) & values == target
  runs <- rle(target_values)
  if (!any(runs$values)) 0L else max(runs$lengths[runs$values])
}

adult_ids <- bind_rows(
  read_xpt(
    file.path(project_root, "data", "nhanes-demo-2011-2012.xpt"),
    col_select = c(SEQN, RIDAGEYR)
  ) |>
    transmute(participant_id = as.character(SEQN), dataset = "2011-2012", age_years = RIDAGEYR),
  read_xpt(
    file.path(project_root, "data", "nhanes-demo-2013-2014.xpt"),
    col_select = c(SEQN, RIDAGEYR)
  ) |>
    transmute(participant_id = as.character(SEQN), dataset = "2013-2014", age_years = RIDAGEYR)
) |>
  filter(age_years >= 18) |>
  select(participant_id, dataset)

process_file <- function(file) {
  message("Reading ", basename(file))
  sitting_df <- read_parquet(
    file,
    as_data_frame = TRUE,
    col_select = c(
      "participant_id", "dataset", "nhanes_wear_day", "timestamp",
      "day", "hour", "sleep_prediction", "wake_ind", "chap_sitting_fraction"
    )
  )

  sitting_df <- sitting_df |>
    semi_join(adult_ids, by = c("participant_id", "dataset"))

  daily_validity <- sitting_df |>
    arrange(participant_id, dataset, nhanes_wear_day, timestamp) |>
    group_by(participant_id, dataset, nhanes_wear_day) |>
    summarise(
      total_minutes = n(),
      chap_matched_minutes = sum(!is.na(chap_sitting_fraction)),
      longest_nonwear_minutes = longest_run(sleep_prediction, "Non-wear"),
      crib_wake_minutes = sum(wake_ind == "wake", na.rm = TRUE),
      .groups = "drop"
    ) |>
    mutate(
      complete_protocol_day = total_minutes == 1440,
      complete_chap_day = chap_matched_minutes == 1440,
      has_crib_wake_time = crib_wake_minutes > 0,
      # A day with no CRIB-classified wake time cannot contribute a waking
      # sedentary estimate. Make this explicit rather than allowing the later
      # wake-minute filter to silently remove it from the daily summary.
      # A full CHAP match is also required: `sum(..., na.rm = TRUE)` would
      # otherwise convert an all-missing CHAP day into zero sedentary time.
      valid_day = complete_protocol_day &
        complete_chap_day &
        has_crib_wake_time
    )

  valid_participants <- daily_validity |>
    filter(valid_day) |>
    count(participant_id, dataset, name = "number_of_days") |>
    filter(number_of_days >= 1)

  valid_days <- daily_validity |>
    filter(valid_day) |>
    inner_join(valid_participants, by = c("participant_id", "dataset")) |>
    select(participant_id, dataset, nhanes_wear_day, number_of_days)

  daily_sitting <- sitting_df |>
    filter(wake_ind == "wake") |>
    group_by(participant_id, dataset, nhanes_wear_day) |>
    summarise(
      wake_minutes = n(),
      wake_hours = wake_minutes / 60,
      sitting_minutes = sum(chap_sitting_fraction, na.rm = TRUE),
      sitting_hours = sitting_minutes / 60,
      sitting_percent_wake = 100 * sitting_minutes / wake_minutes,
      .groups = "drop"
    ) |>
    inner_join(
      valid_days,
      by = c("participant_id", "dataset", "nhanes_wear_day")
    )

  daily_sitting_org <- sitting_df |>
    filter(sleep_prediction == "Wake") |>
    group_by(participant_id, dataset, nhanes_wear_day) |>
    summarise(
      wake_minutes = n(),
      wake_hours = wake_minutes / 60,
      sitting_minutes = sum(chap_sitting_fraction, na.rm = TRUE),
      sitting_hours = sitting_minutes / 60,
      sitting_percent_wake = 100 * sitting_minutes / wake_minutes,
      .groups = "drop"
    )

  hourly_sitting <- sitting_df |>
    mutate(
      hour_of_day = as.integer(hour),
      day_type = if_else(
        as.POSIXlt(as.Date(day))$wday %in% c(0, 6),
        "Weekend",
        "Weekday"
      )
    ) |>
    filter(!is.na(hour_of_day), hour_of_day >= 0, hour_of_day <= 23) |>
    group_by(participant_id, dataset, nhanes_wear_day, day_type, hour_of_day) |>
    summarise(
      total_minutes = n(),
      wake_minutes = sum(wake_ind == "wake", na.rm = TRUE),
      wake_hours = wake_minutes / 60,
      sitting_minutes = sum(if_else(wake_ind == "wake", chap_sitting_fraction, 0), na.rm = TRUE),
      sitting_hours = sitting_minutes / 60,
      sitting_percent_hour = 100 * sitting_minutes / total_minutes,
      sitting_percent_wake = if_else(wake_minutes > 0, 100 * sitting_minutes / wake_minutes, NA_real_),
      .groups = "drop"
    ) |>
    inner_join(
      valid_days,
      by = c("participant_id", "dataset", "nhanes_wear_day")
    )

  list(
    daily_sitting = daily_sitting,
    daily_sitting_org = daily_sitting_org,
    hourly_sitting = hourly_sitting
  )
}

outputs <- map(files, process_file)
daily_sitting <- map_dfr(outputs, "daily_sitting")
daily_sitting_org <- map_dfr(outputs, "daily_sitting_org")
hourly_sitting <- map_dfr(outputs, "hourly_sitting")

dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
write.csv(
  daily_sitting,
  file.path(output_dir, sprintf("sitting_daily_batch_%03d.csv", batch_index)),
  row.names = FALSE
)
write.csv(
  daily_sitting_org,
  file.path(output_dir, sprintf("sitting_daily_org_batch_%03d.csv", batch_index)),
  row.names = FALSE
)
write.csv(
  hourly_sitting,
  file.path(output_dir, sprintf("sitting_hourly_batch_%03d.csv", batch_index)),
  row.names = FALSE
)
message("Finished batch ", batch_index, " with ", length(files), " input files")
