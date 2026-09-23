#!/usr/bin/env Rscript

# Create descriptive waking sedentary-bout summaries for the primary CRIB sample.
# A bout is a consecutive run of CRIB-wake minutes with CHAP sitting fraction
# >= 0.50. Bouts never continue across participant-day boundaries.
suppressPackageStartupMessages({
  library(arrow)
  library(dplyr)
  library(ggplot2)
  library(patchwork)
  library(readr)
})

root <- normalizePath(getwd(), mustWork = TRUE)
crib_results <- file.path(root, "outputs", "final_analysis", "results")
adult_root <- file.path(root, "outputs", "final_analysis_crib_adult")
adult_results <- file.path(adult_root, "results")
figure_root <- file.path(root, "figures", "final_analysis_crib_adult")
dir.create(adult_results, recursive = TRUE, showWarnings = FALSE)
dir.create(figure_root, recursive = TRUE, showWarnings = FALSE)

keys <- c("participant_id", "dataset")
day_keys <- c(keys, "nhanes_wear_day")
sedentary_labels <- c("0-6", "6-8", "8-10", "10-12", "12-14", "14+")
bout_labels <- c("1-10", "11-20", "21-30", "31-40", "41-50", "51+")

eligible_days <- read_csv(
  file.path(adult_root, "datasets", "primary_daily_sitting.csv"),
  col_types = cols(participant_id = col_character(), dataset = col_character())
)
stopifnot(!anyDuplicated(eligible_days[day_keys]))

participant_time <- eligible_days |>
  group_by(across(all_of(keys))) |>
  summarise(mean_sedentary_hours = mean(sitting_hours), .groups = "drop") |>
  mutate(sedentary_group = cut(
    mean_sedentary_hours,
    breaks = c(-Inf, 6, 8, 10, 12, 14, Inf),
    labels = sedentary_labels, right = FALSE
  ))

eligible_days <- eligible_days |>
  inner_join(participant_time |> select(all_of(keys), sedentary_group), by = keys)

batch_files <- sort(Sys.glob(file.path(crib_results, "crib_ppt_df_batch_*.parquet")))
if (!length(batch_files)) stop("No CRIB batch parquet files found.")

summarise_batch <- function(path, index) {
  minute_data <- read_parquet(
    path,
    col_select = all_of(c(day_keys, "minute_index", "wake_ind", "chap_sitting_fraction"))
  ) |>
    mutate(participant_id = as.character(participant_id), dataset = as.character(dataset)) |>
    semi_join(eligible_days |> select(all_of(day_keys)), by = day_keys) |>
    inner_join(eligible_days |> select(all_of(day_keys), sedentary_group), by = day_keys) |>
    arrange(across(all_of(day_keys)), minute_index) |>
    group_by(across(all_of(day_keys))) |>
    mutate(
      is_sedentary = wake_ind == "wake" & chap_sitting_fraction >= 0.50,
      new_bout = is_sedentary &
        (!lag(is_sedentary, default = FALSE) |
           minute_index != lag(minute_index, default = first(minute_index) - 1L) + 1L),
      bout_id = cumsum(new_bout)
    ) |>
    ungroup()

  result <- minute_data |>
    filter(is_sedentary) |>
    group_by(across(all_of(day_keys)), sedentary_group, bout_id) |>
    summarise(bout_minutes = n(), .groups = "drop") |>
    group_by(across(all_of(day_keys)), sedentary_group) |>
    summarise(
      n_bouts = n(),
      mean_bout_minutes = mean(bout_minutes),
      minimum_bout_minutes = min(bout_minutes),
      maximum_bout_minutes = max(bout_minutes),
      .groups = "drop"
    )
  message("Processed ", index, "/", length(batch_files), " CRIB batches")
  result
}

daily_bouts <- bind_rows(Map(summarise_batch, batch_files, seq_along(batch_files)))
stopifnot(!anyDuplicated(daily_bouts[day_keys]))

participant_bouts <- daily_bouts |>
  group_by(across(all_of(keys)), sedentary_group) |>
  summarise(
    days_with_sedentary_bouts = n(),
    mean_bouts_per_day = mean(n_bouts),
    mean_daily_bout_minutes = mean(mean_bout_minutes),
    shortest_daily_mean_bout_minutes = min(mean_bout_minutes),
    longest_daily_mean_bout_minutes = max(mean_bout_minutes),
    .groups = "drop"
  ) |>
  right_join(participant_time, by = c(keys, "sedentary_group"))

if (anyNA(participant_bouts$mean_daily_bout_minutes)) {
  stop(sum(is.na(participant_bouts$mean_daily_bout_minutes)),
       " participants have no waking sedentary bouts.")
}

participant_bouts <- participant_bouts |>
  mutate(bout_duration_group = cut(
    mean_daily_bout_minutes,
    breaks = c(0, 10, 20, 30, 40, 50, Inf),
    labels = bout_labels, include.lowest = TRUE, right = TRUE
  ))

distribution <- participant_bouts |>
  count(bout_duration_group, .drop = FALSE, name = "n_participants") |>
  mutate(percent_participants = 100 * n_participants / sum(n_participants))

group_summary <- participant_bouts |>
  group_by(sedentary_group, .drop = FALSE) |>
  summarise(
    n_participants = n(),
    mean_participant_bout_minutes = mean(mean_daily_bout_minutes),
    q1_participant_bout_minutes = quantile(mean_daily_bout_minutes, 0.25),
    q3_participant_bout_minutes = quantile(mean_daily_bout_minutes, 0.75),
    .groups = "drop"
  )

write_csv(distribution, file.path(adult_results, "sedentary_bout_overall_distribution.csv"))
write_csv(participant_bouts, file.path(adult_results, "sedentary_bout_participant_summary.csv"))
write_csv(group_summary, file.path(adult_results, "sedentary_bout_group_summary.csv"))

plot_theme <- theme_minimal(base_size = 15) +
  theme(
    text = element_text(face = "bold"),
    panel.grid.major.x = element_blank(),
    panel.grid.minor = element_blank(),
    plot.title.position = "plot"
  )

panel_a <- ggplot(distribution, aes(bout_duration_group, percent_participants)) +
  geom_col(width = 0.68, fill = "#4E79A7", colour = "#17365D", linewidth = 0.8) +
  geom_text(
    aes(label = sprintf("n=%s\n%.1f%%", scales::comma(n_participants), percent_participants)),
    vjust = -0.25, size = 3.7, fontface = "bold"
  ) +
  scale_y_continuous(expand = expansion(mult = c(0, 0.22))) +
  labs(
    title = "A. Participant-average bout duration",
    x = "Mean waking sedentary-bout duration (minutes)", y = "Participants, n (%)"
  ) + plot_theme

group_means <- group_summary |>
  arrange(mean_participant_bout_minutes)
annotation <- sprintf(
  "Shortest mean: %s = %.1f min\nLongest mean: %s = %.1f min",
  as.character(first(group_means$sedentary_group)), first(group_means$mean_participant_bout_minutes),
  as.character(last(group_means$sedentary_group)), last(group_means$mean_participant_bout_minutes)
)

panel_b <- ggplot(participant_bouts, aes(sedentary_group, mean_daily_bout_minutes, fill = sedentary_group)) +
  geom_boxplot(outlier.shape = NA, linewidth = 0.8) +
  annotate("label", x = Inf, y = Inf, label = annotation, hjust = 1.05, vjust = 1.2,
           size = 3.8, fontface = "bold", fill = "white", colour = "#17365D") +
  scale_fill_manual(values = c("#DCE8F6", "#BDD7EE", "#9ECAE1", "#6BAED6", "#4292C6", "#2171B5")) +
  coord_cartesian(ylim = c(0, quantile(participant_bouts$mean_daily_bout_minutes, 0.99) * 1.25)) +
  labs(
    title = "B. By sedentary-time group",
    x = "Mean waking sedentary time (h/day)",
    y = "Participant-average bout duration (minutes)",
    caption = "Each box summarizes one participant-cycle's average daily mean waking sedentary-bout duration."
  ) +
  guides(fill = "none") + plot_theme

figure <- panel_a + panel_b + plot_layout(widths = c(1, 1))
ggsave(file.path(figure_root, "figure4_crib_waking_sedentary_bouts.png"), figure,
       width = 16, height = 6.8, dpi = 700, bg = "white")
ggsave(file.path(figure_root, "figure4_crib_waking_sedentary_bouts.pdf"), figure,
       width = 16, height = 6.8, bg = "white")
message("Wrote Figure 4 and sedentary-bout summaries.")
