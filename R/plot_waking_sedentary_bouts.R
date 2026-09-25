#!/usr/bin/env Rscript

# Plot descriptive waking sedentary-bout summaries for the primary analytic sample.
# A bout is a consecutive run of CRIB-wake minutes with CHAP sitting fraction
# >= 0.50. Bouts never continue across participant-day boundaries.
suppressPackageStartupMessages({
  library(dplyr)
  library(ggplot2)
  library(patchwork)
  library(readr)
})

root <- normalizePath(getwd(), mustWork = TRUE)
adult_root <- file.path(root, "outputs", "final_analysis_adult")
adult_results <- file.path(adult_root, "results")
figure_root <- file.path(root, "figures", "final_analysis_adult")
dir.create(adult_results, recursive = TRUE, showWarnings = FALSE)
dir.create(figure_root, recursive = TRUE, showWarnings = FALSE)

keys <- c("participant_id", "dataset")
sedentary_labels <- c("0-6", "6-8", "8-10", "10-12", "12-14", "14+")
bout_labels <- c("1-10", "11-20", "21-30", "31-40", "41-50", "51+")

eligible_days <- read_csv(
    file.path(root, "data", "derived", "primary_daily_sitting.csv"),
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

participant_summary_file <- file.path(
  adult_results, "sedentary_bout_participant_summary.csv"
)
if (!file.exists(participant_summary_file)) {
  stop("Participant-level sedentary-bout summary was not found.")
}
participant_bouts <- read_csv(participant_summary_file, show_col_types = FALSE) |>
  mutate(
    sedentary_group = factor(sedentary_group, levels = sedentary_labels),
    bout_duration_group = factor(bout_duration_group, levels = bout_labels)
  )
stopifnot(nrow(participant_bouts) == nrow(participant_time))

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
write_csv(group_summary, file.path(adult_results, "sedentary_bout_group_summary.csv"))

plot_theme <- theme_minimal(base_size = 18) +
  theme(
    text = element_text(face = "bold", colour = "#1A1A1A"),
    axis.text = element_text(size = 15, colour = "#1A1A1A"),
    axis.title = element_text(size = 17),
    plot.title = element_text(size = 19),
    plot.caption = element_text(size = 13, face = "plain"),
    panel.grid.major.x = element_blank(),
    panel.grid.minor = element_blank(),
    plot.title.position = "plot"
  )

panel_a <- ggplot(distribution, aes(bout_duration_group, percent_participants)) +
  geom_col(width = 0.68, fill = "#4E79A7", colour = "#17365D", linewidth = 0.8) +
  geom_text(
    aes(label = sprintf("n=%s\n%.1f%%", scales::comma(n_participants), percent_participants)),
    vjust = -0.25, size = 4.8, fontface = "bold"
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
           size = 4.5, fontface = "bold", fill = "white", colour = "#17365D") +
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
ggsave(file.path(figure_root, "figure4_waking_sedentary_bouts.png"), figure,
       width = 11.5, height = 6.2, dpi = 600, bg = "white")
ggsave(file.path(figure_root, "figure4_waking_sedentary_bouts.pdf"), figure,
       width = 11.5, height = 6.2, bg = "white")
message("Wrote Figure 4 and sedentary-bout summaries.")
