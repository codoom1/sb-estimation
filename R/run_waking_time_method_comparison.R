#!/usr/bin/env Rscript

# Produces a common-day, four-method adult waking-time comparison.
suppressPackageStartupMessages({
  library(arrow); library(dplyr); library(haven); library(purrr)
  library(readr); library(survey); library(tidyr); library(wristsed)
})

root <- normalizePath(getwd(), winslash = "/", mustWork = TRUE)
while (!dir.exists(file.path(root, "reports"))) root <- dirname(root)
out <- file.path(root, "outputs", "waking_time_method_comparison")
dir.create(out, recursive = TRUE, showWarnings = FALSE)
options(survey.lonely.psu = "adjust")

metadata <- get_participant_data("swan", "1h", collect = TRUE) |>
  select(ID, Dataset, Exam_weight_recal, PSU, Stratum) |>
  mutate(ID = as.character(ID), Dataset = as.character(Dataset)) |>
  distinct(ID, Dataset, .keep_all = TRUE)
age <- bind_rows(
  read_xpt(file.path(root, "data", "nhanes-demo-2011-2012.xpt"), col_select = c(SEQN, RIDAGEYR)) |>
    transmute(ID = as.character(SEQN), Dataset = "2011-2012", age = as.integer(RIDAGEYR)),
  read_xpt(file.path(root, "data", "nhanes-demo-2013-2014.xpt"), col_select = c(SEQN, RIDAGEYR)) |>
    transmute(ID = as.character(SEQN), Dataset = "2013-2014", age = as.integer(RIDAGEYR))
)
metadata <- metadata |> left_join(age, by = c("ID", "Dataset")) |>
  filter(!is.na(Exam_weight_recal), !is.na(PSU), !is.na(Stratum))

read_epoch <- function(method) {
  get_epoch_data(sleep_method = method, epoch = "1h", collect = TRUE) |>
    mutate(ID = as.character(ID), Dataset = as.character(Dataset), Day = as.character(Day))
}

# Two 2013--2014 participant-cycles (80784 and 81674) were regenerated from
# the original 80-Hz inputs after the packaged one-hour data were created.
# The package therefore contains only their first complete day.  Recreate the
# direct one-hour records from the repaired external CHAP/SWaN files and
# replace the incomplete packaged records before defining the common sample.
repaired_ids <- c("80784", "81674")
external_root <- "/work/pi_jstauden_umass_edu/SBpaper_outputs_10s"
repair_dataset <- "2013-2014"
repair_day_type <- function(day) {
  if_else(as.POSIXlt(as.Date(day))$wday %in% c(0L, 6L), "Weekend", "Weekday")
}
repair_files <- function(epoch_directory) {
  map(
    repaired_ids,
    ~ list.files(
      file.path(
        external_root, epoch_directory, "model=CHAP",
        paste0("Dataset=", repair_dataset), paste0("ID=", .x)
      ),
      pattern = "^part-0\\.parquet$", recursive = TRUE, full.names = TRUE
    )
  ) |>
    unlist(use.names = FALSE)
}
repair_epoch_template <- function(data, method, source_epochs_per_hour) {
  data |>
    mutate(
      ID = as.character(participant_id),
      Dataset = repair_dataset,
      Day = as.character(day),
      DayType = repair_day_type(Day),
      Epoch = as.integer(hour) + 1L,
      epoch_level = "1h",
      epoch_start_minute = as.integer(hour) * 60L,
      epoch_duration_minutes = 60L,
      sleep_method = method,
      expected_source_epochs = source_epochs_per_hour,
      source_coverage = n_source_epochs / expected_source_epochs
    ) |>
    select(
      ID, Dataset, Day, DayType, Epoch, epoch_level, epoch_start_minute,
      epoch_duration_minutes, sleep_method, percent_sedentary,
      percent_waking_sedentary, percent_sleep_nonwear, percent_wake,
      percent_missing_sleep, n_source_epochs, expected_source_epochs,
      source_coverage
    )
}
repaired_nhanes_epochs <- function() {
  files <- repair_files("epoch_1min")
  map_dfr(files, function(path) {
    read_parquet(path, as_data_frame = TRUE) |>
      mutate(participant_id = sub(".*ID=([^/]+)/Day=.*", "\\1", path))
  }) |>
    group_by(participant_id, day, hour) |>
    summarise(
      n_source_epochs = n(),
      percent_sedentary = 100 * sum(chap_sitting_10s_epochs, na.rm = TRUE) / sum(n_10s_epochs),
      percent_waking_sedentary = 100 * sum(
        if_else(nhanes_state == 0L, chap_sitting_fraction, 0), na.rm = TRUE
      ) / 60,
      percent_sleep_nonwear = 100 * mean(nhanes_state %in% c(1L, 2L)),
      percent_wake = 100 * mean(nhanes_state == 0L),
      percent_missing_sleep = 100 * mean(!nhanes_state %in% c(0L, 1L, 2L)),
      .groups = "drop"
    ) |>
    repair_epoch_template("nhanes", 60L)
}
repaired_swan_epochs <- function() {
  files <- repair_files("epoch_10s")
  map_dfr(files, function(path) {
    read_parquet(path, as_data_frame = TRUE) |>
      mutate(
        participant_id = sub(".*ID=([^/]+)/Day=.*", "\\1", path),
        day = sub(".*Day=([^/]+)/part-0\\.parquet$", "\\1", path),
        hour = as.integer(epoch_index %/% 360L)
      )
  }) |>
    group_by(participant_id, day, hour) |>
    summarise(
      n_source_epochs = n(),
      percent_sedentary = 100 * mean(sitting),
      percent_waking_sedentary = 100 * mean(sitting & sleep_state == 0L),
      percent_sleep_nonwear = 100 * mean(sleep_state %in% c(1L, 2L)),
      percent_wake = 100 * mean(sleep_state == 0L),
      percent_missing_sleep = 100 * mean(!valid_sleep),
      .groups = "drop"
    ) |>
    repair_epoch_template("swan", 360L)
}
valid_days <- function(x, method) {
  expected <- if (method == "swan") 8640L else 1440L
  x |> group_by(ID, Dataset, Day) |>
    summarise(n_source_epochs = sum(n_source_epochs, na.rm = TRUE), .groups = "drop") |>
    filter(n_source_epochs >= expected) |> select(ID, Dataset, Day)
}
swan <- read_epoch("swan") |>
  filter(!(ID %in% repaired_ids & Dataset == repair_dataset)) |>
  bind_rows(repaired_swan_epochs())
nhanes <- read_epoch("nhanes") |>
  filter(!(ID %in% repaired_ids & Dataset == repair_dataset)) |>
  bind_rows(repaired_nhanes_epochs())
crib_file <- file.path(root, "outputs", "final_analysis", "results", "crib_ppt_df.parquet")
if (!file.exists(crib_file)) stop("Missing CRIB minute parquet: ", crib_file)
# Use the adopted primary analytic days: complete CRIB-waking days passing
# the original NHANES within-day non-wear screen, with >=1 day per adult.
# All methods use the intersection with available complete SWaN/NHANES days.
crib_retained_file <- file.path(
  root, "outputs", "final_analysis_crib_adult", "datasets", "primary_daily_sitting.csv"
)
if (!file.exists(crib_retained_file)) {
  stop("Missing canonical CRIB daily file: ", crib_retained_file, call. = FALSE)
}
primary_daily <- read_csv(crib_retained_file, show_col_types = FALSE)
crib_retained <- primary_daily |>
  transmute(
    ID = as.character(participant_id),
    Dataset = as.character(dataset),
    nhanes_wear_day = as.integer(nhanes_wear_day)
  ) |>
  distinct()
crib_day_map <- open_dataset(crib_file) |>
  select(participant_id, dataset, nhanes_wear_day, day) |>
  distinct() |>
  collect() |>
  transmute(
    ID = as.character(participant_id),
    Dataset = as.character(dataset),
    nhanes_wear_day = as.integer(nhanes_wear_day),
    Day = as.character(day)
  )
crib_days <- crib_retained |>
  inner_join(crib_day_map, by = c("ID", "Dataset", "nhanes_wear_day")) |>
  select(ID, Dataset, Day) |>
  distinct()
swan_valid_days <- valid_days(swan, "swan")
nhanes_valid_days <- valid_days(nhanes, "nhanes")
common_before_metadata <- swan_valid_days |>
  inner_join(nhanes_valid_days, by = c("ID", "Dataset", "Day")) |>
  inner_join(crib_days, by = c("ID", "Dataset", "Day")) |>
  add_count(ID, Dataset, name = "n_days") |> filter(n_days >= 1)
common_days <- common_before_metadata |>
  inner_join(metadata |> filter(age >= 18) |> select(ID, Dataset), by = c("ID", "Dataset")) |>
  distinct()
people <- common_days |> distinct(ID, Dataset, n_days) |> inner_join(metadata, by = c("ID", "Dataset"))
stopifnot(!anyDuplicated(common_days[c("ID","Dataset","Day")]),
          nrow(anti_join(common_days,crib_days,by=c("ID","Dataset","Day")))==0,
          all(people$n_days>=1))
coverage_audit <- crib_days |>
  left_join(swan_valid_days |> mutate(swan_complete=TRUE),by=c("ID","Dataset","Day")) |>
  left_join(nhanes_valid_days |> mutate(nhanes_complete=TRUE),by=c("ID","Dataset","Day")) |>
  mutate(swan_complete=coalesce(swan_complete,FALSE),nhanes_complete=coalesce(nhanes_complete,FALSE),
         in_common_days=swan_complete & nhanes_complete)
write_csv(coverage_audit,file.path(out,"primary_day_coverage_audit.csv"))
write_csv(tibble(primary_participants=n_distinct(crib_days$ID,crib_days$Dataset),
 primary_days=nrow(crib_days),common_participants=nrow(people),common_days=nrow(common_days),
 common_single_day_participants=sum(people$n_days==1),minimum_days=1L,
 eligibility="Primary within-day non-wear screen after CRIB"),file.path(out,"primary_comparison_eligibility.csv"))


# Calibrate the hourly SWaN rule within the same adult common-day domain used
# for the four-method comparison.  The design is first defined for the full
# eligible wrist-accelerometer frame and is then subset to respondents with
# common eligible days and a valid NHANES self-reported sleep value.
self_sleep <- bind_rows(
  read_xpt(file.path(root, "data", "self-sleep-2011-12.xpt"), col_select = c(SEQN, SLD010H)) |>
    transmute(ID = as.character(SEQN), Dataset = "2011-2012", self_reported_sleep_hours = as.numeric(SLD010H)),
  read_xpt(file.path(root, "data", "self-sleep-2013-14.xpt"), col_select = c(SEQN, SLD010H)) |>
    transmute(ID = as.character(SEQN), Dataset = "2013-2014", self_reported_sleep_hours = as.numeric(SLD010H))
) |>
  filter(is.finite(self_reported_sleep_hours), !self_reported_sleep_hours %in% c(77, 99))

common_keys <- people |> select(ID, Dataset)
survey_frame <- metadata |>
  left_join(self_sleep, by = c("ID", "Dataset")) |>
  mutate(in_common_domain = paste(ID, Dataset) %in% paste(common_keys$ID, common_keys$Dataset))
full_accelerometer_design <- svydesign(
  id = ~PSU, strata = ~Stratum, weights = ~Exam_weight_recal,
  nest = TRUE, data = survey_frame
)
self_report_design <- subset(
  full_accelerometer_design,
  in_common_domain & !is.na(self_reported_sleep_hours)
)
self_report_estimate <- svymean(~self_reported_sleep_hours, self_report_design, na.rm = TRUE)
self_report_target <- unname(coef(self_report_estimate)[[1]])
self_report_ci <- unname(confint(self_report_estimate)[1, ])

calibration_people <- people |>
  inner_join(self_sleep, by = c("ID", "Dataset"))
calibration_epochs <- swan |>
  inner_join(
    calibration_people |> select(ID, Dataset, n_days, Exam_weight_recal),
    by = c("ID", "Dataset")
  ) |>
  inner_join(common_days |> select(ID, Dataset, Day), by = c("ID", "Dataset", "Day")) |>
  transmute(
    percent_sleep_nonwear,
    epoch_weight = Exam_weight_recal / n_days * epoch_duration_minutes / 60
  ) |>
  filter(is.finite(percent_sleep_nonwear), is.finite(epoch_weight), epoch_weight > 0)

if (nrow(calibration_epochs) == 0L) stop("No valid SWaN epochs for common-sample calibration.")
calibration_epochs <- calibration_epochs |> arrange(percent_sleep_nonwear)
cutoff_grid <- seq(50, 100, by = 0.01)
cumulative_weight <- cumsum(calibration_epochs$epoch_weight)
lower_index <- findInterval(cutoff_grid, calibration_epochs$percent_sleep_nonwear, left.open = TRUE)
lower_weight <- ifelse(lower_index > 0L, cumulative_weight[lower_index], 0)
sleep_mean_by_cutoff <- (sum(calibration_epochs$epoch_weight) - lower_weight) /
  sum(calibration_people$Exam_weight_recal)
selected_cutoff_row <- tibble(
  cutoff = cutoff_grid,
  estimated_sleep_hours = sleep_mean_by_cutoff,
  absolute_difference_hours = abs(sleep_mean_by_cutoff - self_report_target)
) |>
  arrange(absolute_difference_hours, cutoff) |>
  slice(1)
cutoff <- selected_cutoff_row$cutoff[[1]]

write_csv(
  tibble(
    common_adult_n = nrow(people),
    calibration_self_report_n = nrow(calibration_people),
    self_reported_sleep_mean = self_report_target,
    self_reported_sleep_ci_lower = self_report_ci[[1]],
    self_reported_sleep_ci_upper = self_report_ci[[2]],
    selected_cutoff = cutoff,
    swan_sleep_mean_at_selected_cutoff = selected_cutoff_row$estimated_sleep_hours,
    absolute_difference_hours = selected_cutoff_row$absolute_difference_hours
  ),
  file.path(out, "common_sample_calibration.csv")
)

# Preserve a compact audit trail for the repaired participant-cycles and for
# any future reconciliation of the common four-method sample.
write_csv(
  bind_rows(
    swan_valid_days |> mutate(source = "Direct SWaN valid day"),
    nhanes_valid_days |> mutate(source = "Direct NHANES valid day"),
    crib_days |> mutate(source = "NHANES + CRIB retained day"),
    common_before_metadata |> mutate(source = "Common day before metadata"),
    common_days |> mutate(source = "Common day after metadata")
  ) |> filter(ID %in% repaired_ids, Dataset == repair_dataset),
  file.path(out, "repaired_participant_day_audit.csv")
)

direct <- function(x, label) {
  x |> inner_join(common_days |> select(ID, Dataset, Day), by = c("ID", "Dataset", "Day")) |>
    mutate(hours = epoch_duration_minutes / 60) |> group_by(ID, Dataset) |>
    summarise(
      waking = sum(percent_wake / 100 * hours, na.rm = TRUE) / n_distinct(Day),
      sedentary = sum(percent_waking_sedentary / 100 * hours, na.rm = TRUE) / n_distinct(Day),
      # Excluded time is the full non-waking complement. Thus, for direct
      # state approaches it includes released sleep/non-wear and any Unknown
      # residual rather than leaving time unaccounted for.
      excluded = 24 - waking,
      unclassified = 0,
      .groups = "drop"
    ) |> mutate(Method = label)
}
calibrated <- swan |> inner_join(common_days |> select(ID, Dataset, Day), by = c("ID", "Dataset", "Day")) |>
  mutate(hours = epoch_duration_minutes / 60, wake = percent_sleep_nonwear < cutoff) |> group_by(ID, Dataset) |>
  summarise(
    waking = sum(if_else(wake, hours, 0)) / n_distinct(Day),
    sedentary = sum(if_else(wake, percent_sedentary / 100 * hours, 0), na.rm = TRUE) / n_distinct(Day),
    excluded = 24 - waking, unclassified = 0, .groups = "drop"
  ) |> mutate(Method = paste0("SWaN + common-sample calibrated cutoff (", sprintf("%.2f", cutoff), "%)"))

# CRIB values come from exactly the primary daily summaries, not a second
# independent minute aggregation that could drift from the adopted analysis.
crib_daily <- primary_daily |>
  transmute(ID=as.character(participant_id),Dataset=as.character(dataset),
            nhanes_wear_day=as.integer(nhanes_wear_day),wake_minutes,
            sitting_wake_minutes=sitting_minutes) |>
  inner_join(crib_day_map,by=c("ID","Dataset","nhanes_wear_day"))
stopifnot(nrow(crib_daily)==nrow(primary_daily),!anyNA(crib_daily$Day))
crib <- crib_daily |>
  inner_join(common_days |> select(ID, Dataset, Day), by = c("ID", "Dataset", "Day")) |>
  group_by(ID, Dataset) |>
  summarise(
    waking = sum(wake_minutes, na.rm = TRUE) / 60 / n_distinct(Day),
    sedentary = sum(sitting_wake_minutes, na.rm = TRUE) / 60 / n_distinct(Day),
    excluded = 24 - waking, unclassified = 0, .groups = "drop"
  ) |> mutate(Method = "NHANES + CRIB")

participant <- bind_rows(
  direct(swan, "Direct SWaN states (1-hour)"), calibrated,
  direct(nhanes, "Direct NHANES states (1-hour)"), crib
) |> inner_join(people, by = c("ID", "Dataset"))
keep <- participant |> count(ID, Dataset) |> filter(n == 4) |> select(ID, Dataset)
stopifnot(nrow(keep)==nrow(people),nrow(participant)==4*nrow(people),
          !anyDuplicated(participant[c("ID","Dataset","Method")]),
          all(abs(participant$waking+participant$excluded-24)<1e-8),
          all(participant$sedentary<=participant$waking+1e-8))
participant <- participant |> semi_join(keep, by = c("ID", "Dataset"))

estimate <- function(x) {
  # Retain the complete adult wrist-accelerometer design frame, then define
  # each method/cycle as a survey domain.  Restricting the input data before
  # svydesign() can lose PSU/stratum information needed for valid variance
  # estimation.
  method_keys <- x |> select(ID, Dataset)
  method_design_frame <- metadata |>
    left_join(
      x |> select(ID, Dataset, waking, sedentary, excluded, unclassified),
      by = c("ID", "Dataset")
    ) |>
    mutate(in_method_domain = paste(ID, Dataset) %in% paste(method_keys$ID, method_keys$Dataset))
  full_method_design <- svydesign(
    id = ~PSU, strata = ~Stratum, weights = ~Exam_weight_recal,
    nest = TRUE, data = method_design_frame
  )
  design <- subset(full_method_design, in_method_domain)
  imap_dfr(c("Waking time" = "waking", "Excluded time" = "excluded", "Waking sedentary time" = "sedentary", "Waking non-sedentary time" = "I(waking-sedentary)"), function(v, label) {
    z <- svymean(as.formula(paste0("~", v)), design, na.rm = TRUE); ci <- confint(z)
    tibble(Measure = label, N = sum(design$variables$in_method_domain), Mean = coef(z)[[1]], SE = SE(z)[[1]], Lower = ci[1,1], Upper = ci[1,2])
  })
}
results <- participant |> group_split(Method) |> map_dfr(function(x) {
  bind_rows(estimate(x) |> mutate(Analysis = "Pooled"), x |> group_split(Dataset) |> map_dfr(function(y) estimate(y) |> mutate(Analysis = first(y$Dataset)))) |>
    mutate(Method = first(x$Method), .before = Analysis)
})
write_csv(participant, file.path(out, "participant_method_estimates.csv"))
write_csv(results, file.path(out, "method_estimates.csv"))
write_csv(common_days, file.path(out, "common_valid_days.csv"))
write_csv(participant |> count(Method,name="N"), file.path(out, "sample_sizes.csv"))
message("Wrote four-method comparison to ", out)
