suppressPackageStartupMessages({
  library(dplyr)
  library(ggplot2)
  library(haven)
  library(patchwork)
  library(purrr)
  library(readr)
  library(survey)
  library(tidyr)
})

find_project_root <- function(start = getwd()) {
  current <- normalizePath(start, winslash = "/", mustWork = TRUE)
  repeat {
    if (
      dir.exists(file.path(current, "data")) &&
        dir.exists(file.path(current, "figures"))
    ) {
      return(current)
    }

    parent <- dirname(current)
    if (identical(parent, current)) {
      stop("Could not find project root containing data/ and figures/.")
    }
    current <- parent
  }
}

root <- find_project_root()
data_dir <- file.path(root, "data")
fig_dir <- file.path(root, "figures", "manuscript")

options(survey.lonely.psu = "adjust")

message("Reading hourly sedentary and sleep data...")
sedentary_hip_df <- read_csv(file.path(data_dir, "nosleep_data.csv.gz"), show_col_types = FALSE)
sedentary_wrist_df <- read_csv(file.path(data_dir, "wrist_df.csv.gz"), show_col_types = FALSE)
sleep_df <- read_csv(file.path(data_dir, "sleep_est_data.csv.gz"), show_col_types = FALSE)

sedentary_hip_df <- sedentary_hip_df %>%
  rename(
    Day = Date,
    percent_sedentary_hip = PercentSedentary
  ) %>%
  filter(PartialDay != "Yes") %>%
  mutate(Exam_weight_recal = 0.5 * Exam_weight)

sedentary_wrist_df <- sedentary_wrist_df %>%
  rename(percent_sedentary_wrist = percent_sitting) %>%
  select(ID, Day, Hour, percent_sedentary_wrist)

sleep_df <- sleep_df %>%
  transmute(
    ID,
    Day,
    Hour,
    percent_sleep = percent_sleep_nonwear
  )

sedentary_df <- inner_join(
  x = sedentary_wrist_df,
  y = sedentary_hip_df,
  by = c("ID", "Day", "Hour")
)

sleep_sed_df <- inner_join(
  x = sedentary_df,
  y = sleep_df,
  by = c("ID", "Day", "Hour")
)

demo_unique <- sedentary_df %>%
  mutate(
    Age_group = case_when(
      Age < 18 ~ "<18",
      Age <= 34 ~ "18-34",
      Age <= 44 ~ "35-44",
      Age <= 64 ~ "45-64",
      TRUE ~ ">=65"
    ),
    BMI = Weight / (Height / 100)^2,
    BMI_cat = case_when(
      BMI < 25 ~ "under/normal weight",
      BMI < 30 ~ "over weight",
      TRUE ~ "obesity"
    )
  ) %>%
  group_by(ID) %>%
  summarise(
    Age_group = first(Age_group),
    BMI_cat = first(BMI_cat),
    Race = first(Race),
    Gender = first(Gender),
    Education = first(Education_coarse),
    Marital_status = first(Marital_status),
    Exam_weight_recal = first(Exam_weight_recal),
    PSU = first(PSU),
    Stratum = first(Stratum),
    .groups = "drop"
  )

compute_sedentary_by_cutoff <- function(df, cutoffs) {
  id_days <- distinct(df, ID, Day)

  map_dfr(cutoffs, function(cut) {
    df %>%
      filter(percent_sleep < cut) %>%
      group_by(ID, Day) %>%
      summarise(
        total_sed_hours = sum(percent_sedentary_wrist / 100, na.rm = TRUE),
        n_hours = n(),
        .groups = "drop"
      ) %>%
      right_join(id_days, by = c("ID", "Day")) %>%
      mutate(
        total_sed_hours = replace_na(total_sed_hours, 0),
        n_hours = replace_na(n_hours, 0),
        sleep_hrs = 24 - n_hours,
        cutoff = cut
      )
  })
}

get_svy_estimates <- function(data_cut) {
  des <- svydesign(
    id = ~PSU,
    strata = ~Stratum,
    weights = ~Exam_weight_recal,
    nest = TRUE,
    data = data_cut
  )

  sleep_est <- svymean(~mean_sleep_hours, des, na.rm = TRUE)
  sed_est <- svymean(~mean_sed_hours, des, na.rm = TRUE)

  tibble(
    cutoff = unique(data_cut$cutoff),
    sleep_mean = coef(sleep_est)[1],
    sleep_se = SE(sleep_est)[1],
    sed_mean = coef(sed_est)[1],
    sed_se = SE(sed_est)[1]
  )
}

message("Computing survey-weighted estimates across candidate cutoffs...")
cutoffs <- seq(25, 100, 1)

sed_all <- compute_sedentary_by_cutoff(sleep_sed_df, cutoffs)

df_person <- sed_all %>%
  group_by(ID, cutoff) %>%
  summarise(
    mean_sed_hours = mean(total_sed_hours, na.rm = TRUE),
    mean_sleep_hours = mean(sleep_hrs, na.rm = TRUE),
    .groups = "drop"
  )

model_df <- df_person %>%
  left_join(demo_unique, by = "ID") %>%
  filter(
    !is.na(Exam_weight_recal),
    !is.na(PSU),
    !is.na(Stratum)
  )

results <- model_df %>%
  group_split(cutoff) %>%
  map_dfr(get_svy_estimates)

message("Estimating self-reported sleep benchmark...")
sleep_2011_12 <- read_xpt(file.path(data_dir, "self-sleep-2011-12.xpt"))
sleep_2013_14 <- read_xpt(file.path(data_dir, "self-sleep-2013-14.xpt"))

self_sleep <- bind_rows(sleep_2011_12, sleep_2013_14) %>%
  transmute(
    ID = SEQN,
    self_reported_slp_hrs = SLD010H
  ) %>%
  filter(
    !is.na(self_reported_slp_hrs),
    !(self_reported_slp_hrs %in% c(77, 99))
  )

self_sleep_weighted <- self_sleep %>%
  left_join(
    demo_unique %>% select(ID, Exam_weight_recal, PSU, Stratum),
    by = "ID"
  ) %>%
  filter(!is.na(Exam_weight_recal))

des_self_sleep <- svydesign(
  id = ~PSU,
  strata = ~Stratum,
  weights = ~Exam_weight_recal,
  nest = TRUE,
  data = self_sleep_weighted
)

mean_self_sleep <- svymean(~self_reported_slp_hrs, design = des_self_sleep, na.rm = TRUE)

selected_cutoff <- results %>%
  mutate(diff = abs(sleep_mean - as.numeric(coef(mean_self_sleep)[1]))) %>%
  slice_min(diff, n = 1, with_ties = FALSE) %>%
  pull(cutoff)

self_sleep_mean <- as.numeric(coef(mean_self_sleep)[1])
self_sleep_ci <- as.numeric(confint(mean_self_sleep)[1, ])

figure5_df <- results %>%
  mutate(
    sleep_ci_l = sleep_mean - qnorm(0.975) * sleep_se,
    sleep_ci_u = sleep_mean + qnorm(0.975) * sleep_se,
    sed_ci_l = sed_mean - qnorm(0.975) * sed_se,
    sed_ci_u = sed_mean + qnorm(0.975) * sed_se
  )

selected_row <- figure5_df %>%
  filter(cutoff == selected_cutoff) %>%
  slice(1)

fig5_theme <- theme_classic(base_size = 18) +
  theme(
    plot.title = element_text(face = "bold", size = 18, hjust = 0),
    plot.tag = element_text(face = "bold", size = 22),
    axis.title = element_text(face = "bold", size = 16),
    axis.text = element_text(face = "bold", size = 13, color = "black"),
    axis.line = element_line(linewidth = 1.1, color = "black"),
    axis.ticks = element_line(linewidth = 1.1, color = "black"),
    axis.ticks.length = unit(0.16, "cm"),
    legend.position = "none",
    plot.margin = margin(8, 12, 8, 16)
  )

sleep_panel <- ggplot(figure5_df, aes(x = cutoff, y = sleep_mean)) +
  annotate(
    "rect",
    xmin = selected_cutoff - 1.25,
    xmax = selected_cutoff + 1.25,
    ymin = -Inf,
    ymax = Inf,
    fill = "#8B1E2D",
    alpha = 0.08
  ) +
  geom_ribbon(aes(ymin = sleep_ci_l, ymax = sleep_ci_u), fill = "#D9E8F5", alpha = 0.95) +
  geom_line(color = "#2F5F98", linewidth = 1.55) +
  geom_point(
    data = selected_row,
    aes(y = sleep_mean),
    color = "#2F5F98",
    fill = "white",
    shape = 21,
    stroke = 1.3,
    size = 3.8
  ) +
  geom_hline(yintercept = self_sleep_mean, color = "#8B1E2D", linewidth = 1.1, linetype = "dashed") +
  geom_vline(xintercept = selected_cutoff, color = "#8B1E2D", linewidth = 1.1, linetype = "dashed") +
  annotate(
    "text",
    x = selected_cutoff - 1.4,
    y = self_sleep_mean,
    label = "Self-reported sleep mean",
    hjust = 1,
    vjust = -0.5,
    color = "#8B1E2D",
    fontface = "bold",
    size = 4.5
  ) +
  annotate(
    "text",
    x = selected_cutoff,
    y = selected_row$sleep_mean,
    label = paste0(selected_cutoff, "%"),
    hjust = -0.2,
    vjust = -1.7,
    color = "#8B1E2D",
    fontface = "bold",
    size = 4.6
  ) +
  scale_x_continuous(breaks = seq(30, 100, 10), limits = c(25, 100)) +
  scale_y_continuous(
    limits = range(c(figure5_df$sleep_ci_l, figure5_df$sleep_ci_u, self_sleep_ci), na.rm = TRUE) + c(-0.15, 0.25),
    expand = expansion(mult = c(0, 0))
  ) +
  labs(
    tag = "A",
    title = "Sleep-duration calibration",
    x = "Sleep percentage cutoff",
    y = "Mean sleep duration (h/day)"
  ) +
  fig5_theme

sed_panel <- ggplot(figure5_df, aes(x = cutoff, y = sed_mean)) +
  annotate(
    "rect",
    xmin = selected_cutoff - 1.25,
    xmax = selected_cutoff + 1.25,
    ymin = -Inf,
    ymax = Inf,
    fill = "#8B1E2D",
    alpha = 0.08
  ) +
  geom_ribbon(aes(ymin = sed_ci_l, ymax = sed_ci_u), fill = "#E8DFF4", alpha = 0.95) +
  geom_line(color = "#7B3FC6", linewidth = 1.55) +
  geom_point(
    data = selected_row,
    aes(y = sed_mean),
    color = "#7B3FC6",
    fill = "white",
    shape = 21,
    stroke = 1.3,
    size = 3.8
  ) +
  geom_vline(xintercept = selected_cutoff, color = "#8B1E2D", linewidth = 1.1, linetype = "dashed") +
  annotate(
    "text",
    x = selected_cutoff,
    y = selected_row$sed_mean,
    label = paste0(round(selected_row$sed_mean, 2), " h/day"),
    hjust = 1.08,
    vjust = -1.0,
    color = "#7B3FC6",
    fontface = "bold",
    size = 4.6
  ) +
  annotate(
    "text",
    x = selected_cutoff,
    y = max(figure5_df$sed_ci_u, na.rm = TRUE),
    label = paste0(selected_cutoff, "% cutoff"),
    hjust = 1.05,
    vjust = 1.3,
    color = "#8B1E2D",
    fontface = "bold",
    size = 4.6
  ) +
  scale_x_continuous(breaks = seq(30, 100, 10), limits = c(25, 100)) +
  scale_y_continuous(
    limits = range(c(figure5_df$sed_ci_l, figure5_df$sed_ci_u), na.rm = TRUE) + c(-0.12, 0.18),
    expand = expansion(mult = c(0, 0))
  ) +
  labs(
    tag = "B",
    title = "Sedentary-time sensitivity",
    x = "Sleep percentage cutoff",
    y = "Mean sedentary time (h/day)"
  ) +
  fig5_theme

cutplt <- sleep_panel / sed_panel +
  plot_layout(heights = c(1, 1)) &
  theme(plot.margin = margin(10, 12, 10, 18))

dir.create(fig_dir, showWarnings = FALSE, recursive = TRUE)
png_path <- file.path(fig_dir, "cutoff_sensi.png")
pdf_path <- file.path(fig_dir, "cutoff_sensi.pdf")

ggsave(png_path, plot = cutplt, width = 9, height = 8, dpi = 600, bg = "white")
ggsave(pdf_path, plot = cutplt, width = 9, height = 8, bg = "white")

message("Selected cutoff: ", selected_cutoff, "%")
message("Wrote ", png_path)
message("Wrote ", pdf_path)
