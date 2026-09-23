#!/usr/bin/env Rscript
# Summarize sensitivity to CRIB required-sleep and minimum-bout parameters.
suppressPackageStartupMessages({library(dplyr); library(readr); library(tidyr); library(survey); library(wristsed)})
options(survey.lonely.psu = "adjust")
root <- normalizePath(getwd(), mustWork = TRUE)
out <- file.path(root, "outputs/final_analysis_adult/parameter_sensitivity")
source(file.path(root, "R/parameter_sensitivity_table.R"))
source(file.path(root, "R/parameter_sensitivity_inference.R"))
files <- file.path(out, "batches", sprintf("participant_%03d.csv", 1:50))
stopifnot(all(file.exists(files)))
changes <- bind_rows(lapply(files, read_csv, show_col_types = FALSE)) |>
  mutate(participant_id = as.character(participant_id), dataset = as.character(dataset))
primary_file <- file.path(root, "data/derived/primary_daily_sitting.csv")
provenance <- bind_rows(lapply(file.path(out, "batches", sprintf("provenance_%03d.csv", 1:50)),
                             read_csv, show_col_types = FALSE))
stopifnot(nrow(provenance) == 50L, all(provenance$primary_days_md5 == unname(tools::md5sum(primary_file))),
          length(unique(provenance$source_modified)) == 1L, length(unique(provenance$source_size)) == 1L)
primary <- read_csv(file.path(root, "data/derived/primary_analytic_participants.csv"),
                    show_col_types = FALSE) |> mutate(ID = as.character(ID), Dataset = as.character(Dataset))
cohort <- read_csv(file.path(root, "outputs/final_analysis_adult/qc/primary_day_rule/cohort_summary.csv"), show_col_types = FALSE)
stopifnot(cohort$policy == "known_wake_sleep_bounded_nonwear_v3",
          nrow(primary) == cohort$participants, sum(primary$no_of_valid_days) == cohort$days,
          cohort$primary_days_md5 == unname(tools::md5sum(primary_file)))
keys <- c("participant_id", "dataset", "required_percent", "minimum_bout_minutes")
stopifnot(!anyDuplicated(changes[keys]), nrow(changes) == nrow(primary) * 12L,
          all(is.finite(changes$difference_hours)),
          max(abs(changes$difference_hours - (changes$sedentary_hours - changes$reference_sedentary_hours))) < 1e-8)
changes <- changes |> rename(ID = participant_id, Dataset = dataset) |>
  left_join(primary |> select(ID, Dataset, no_of_valid_days, est_sedentary_hours), by = c("ID", "Dataset"))
stopifnot(!anyNA(changes$no_of_valid_days), all(changes$n_days == changes$no_of_valid_days),
          max(abs(changes$reference_sedentary_hours - changes$est_sedentary_hours)) < 1e-8)
reference <- changes |> filter(required_percent == 80, minimum_bout_minutes == 30)
stopifnot(max(abs(reference$difference_hours)) < 1e-8)
frame <- get_participant_data("swan", "1h", collect = TRUE) |>
  select(ID, Dataset, Exam_weight_recal, PSU, Stratum) |>
  mutate(ID = as.character(ID), Dataset = as.character(Dataset)) |>
  distinct(ID, Dataset, .keep_all = TRUE) |>
  filter(!is.na(Exam_weight_recal), !is.na(PSU), !is.na(Stratum)) |>
  left_join(primary |> select(ID, Dataset, Age_group, Gender, Race, BMI_cat_crib), by = c("ID", "Dataset"))
stopifnot(nrow(anti_join(primary, frame, by = c("ID", "Dataset"))) == 0L,
          sum(is.na(primary$BMI_cat_crib)) == cohort$bmi_missing)
rows <- bind_rows(
  tibble(subgroup = "Overall", category = "All adults", variable = NA_character_, value = NA_character_),
  tibble(subgroup = "Sex", category = c("Male", "Female"), variable = "Gender", value = category),
  tibble(subgroup = "Age", category = c("18-34", "35-44", "45-64", ">=65"), variable = "Age_group", value = category),
  tibble(subgroup = "BMI", category = c("Underweight", "Normal weight", "Overweight", "Obesity"),
         variable = "BMI_cat_crib", value = tolower(category)),
  tibble(subgroup = "Race/ethnicity", category = c("Mexican American", "Other Hispanic", "NH White", "NH Black", "NH Asian", "Other/Multi"),
         variable = "Race", value = category)
) |> mutate(row_order = row_number())
settings <- crossing(required_percent = c(70, 80, 90), minimum_bout_minutes = c(20, 30, 45, 60))
results <- list(); eligibility <- list()
for (i in seq_len(nrow(settings))) {
  setting <- settings[i, ]
  delta <- changes |> filter(required_percent == setting$required_percent, minimum_bout_minutes == setting$minimum_bout_minutes)
  design_data <- frame |> left_join(delta |> select(ID, Dataset, difference_hours, sedentary_hours), by = c("ID", "Dataset"))
  design <- svydesign(ids = ~PSU, strata = ~Stratum, weights = ~Exam_weight_recal, nest = TRUE, data = design_data)
  for (j in seq_len(nrow(rows))) {
    row <- rows[j, ]
    keep <- !is.na(design_data$difference_hours)
    if (!is.na(row$variable)) keep <- keep & !is.na(design_data[[row$variable]]) & design_data[[row$variable]] == row$value
    domain <- design[keep, ]
    is_reference <- setting$required_percent == 80 && setting$minimum_bout_minutes == 30
    results[[length(results) + 1L]] <- bind_cols(row |> select(row_order, subgroup, category), setting,
      tibble(n = sum(keep)), crib_paired_estimate(domain, is_reference))
  }
  eligibility[[i]] <- bind_cols(setting, tibble(n_participants = nrow(delta), n_days = sum(delta$n_days)))
}
results <- bind_rows(results) |> arrange(row_order, required_percent, minimum_bout_minutes) |>
  mutate(primary_n = cohort$participants, primary_days = cohort$days,
         bmi_missing = cohort$bmi_missing, policy = cohort$policy,
         primary_days_md5 = cohort$primary_days_md5)
stopifnot(nrow(results) == 17L * 12L, all(results$df > 0),
          all(is.finite(results$p_value[!(results$required_percent == 80 & results$minimum_bout_minutes == 30)])))
write_csv(results, file.path(out, "paired_sedentary_differences.csv"))
write_csv(bind_rows(eligibility), file.path(out, "eligibility_summary.csv"))
wide <- crib_sensitivity_display(results) |>
  mutate(setting = paste0(required_percent, "% / ", minimum_bout_minutes, " min")) |>
  select(row_order, subgroup, category, n, setting, cell) |> pivot_wider(names_from = setting, values_from = cell) |>
  arrange(row_order) |> select(-row_order)
write_csv(wide, file.path(out, "table_sedentary_differences.csv"))
writeLines(crib_sensitivity_html(results, standalone = TRUE), file.path(out, "table_sedentary_differences.html"))
writeLines(crib_sensitivity_latex(results, standalone = TRUE), file.path(out, "table_sedentary_differences.tex"))
write_csv(provenance, file.path(out, "provenance.csv"))
message("Wrote paired sensitivity table: ", out)
source(file.path(root, 'R/plot_parameter_sensitivity.R'))
plot_parameter_sensitivity(changes, frame, cohort, out, root)
