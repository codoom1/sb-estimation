suppressPackageStartupMessages({
  library(dplyr)
  library(ggplot2)
  library(patchwork)
  library(readr)
  library(scales)
  library(tidyr)
  library(vroom)
})

find_project_root <- function(start = getwd()) {
  current <- normalizePath(start, winslash = "/", mustWork = TRUE)
  repeat {
    if (
      dir.exists(file.path(current, "data", "top_level_data")) &&
        dir.exists(file.path(current, "figures"))
    ) {
      return(current)
    }

    parent <- dirname(current)
    if (identical(parent, current)) {
      stop("Could not find project root containing data/top_level_data and figures.")
    }
    current <- parent
  }
}

root <- find_project_root()
data_dir <- file.path(root, "data", "top_level_data")
fig_dir <- file.path(root, "figures")

raw_path <- file.path(data_dir, "raw80HZ_83724_data", "2000-01-12.csv")
chap_path <- file.path(data_dir, "CHAP_pred83724_data", "2000-01-12.csv")
swan_path <- file.path(data_dir, "SWaN_pred83724_data", "2000-01-12_sleep_predictions.csv")

INK <- "#111111"
MUTED <- "#5A5A5A"
GRID <- "#E1E5EA"
FRAME <- "#1A1A1A"
BLUE <- "#2F5F98"
BLUE_LIGHT <- "#D8E4F2"
CYAN <- "#9ECAE1"
CYAN_DARK <- "#4C9BC2"
GREEN <- "#4C9A3F"
GREEN_DARK <- "#2F7D32"
GRAY <- "#B9C0CB"
RED <- "#8B1E2D"
GOLD <- "#D8902F"
PURPLE <- "#8E63CE"
TEAL <- "#2296A7"

base_theme <- theme_bw(base_size = 18) +
  theme(
    plot.title = element_text(face = "bold", size = 20, color = INK, hjust = 0, margin = margin(b = 9)),
    plot.tag = element_text(face = "bold", size = 28, color = INK),
    plot.tag.position = c(-0.045, 1.02),
    axis.title = element_text(face = "bold", size = 17, color = INK),
    axis.text = element_text(face = "bold", size = 14, color = INK),
    axis.title.x = element_text(margin = margin(t = 8)),
    axis.title.y = element_text(margin = margin(r = 8)),
    axis.ticks = element_line(color = FRAME, linewidth = 1.2),
    axis.ticks.length = unit(0.16, "cm"),
    panel.grid.major = element_line(color = GRID, linewidth = 0.75),
    panel.grid.minor = element_blank(),
    panel.border = element_rect(color = FRAME, linewidth = 1.35, fill = NA),
    legend.title = element_blank(),
    legend.text = element_text(face = "bold", size = 13, color = INK),
    legend.key.width = unit(1.75, "lines"),
    legend.key.height = unit(0.95, "lines"),
    plot.margin = margin(10, 24, 10, 54)
  )

read_raw_day <- function(path) {
  header_scan <- readLines(path, n = 20, warn = FALSE)
  header_line <- which(grepl("^Accelerometer X,", header_scan))[1]
  if (is.na(header_line)) {
    stop("Could not locate raw accelerometer header in ", path)
  }

  vroom::vroom(
    path,
    skip = header_line - 1,
    delim = ",",
    show_col_types = FALSE,
    progress = FALSE,
    altrep = FALSE
  ) %>%
    rename(
      X = `Accelerometer X`,
      Y = `Accelerometer Y`,
      Z = `Accelerometer Z`
    ) %>%
    mutate(
      sample_index = row_number() - 1,
      hour = sample_index / (80 * 3600),
      minute_bin = floor(hour * 60) / 60
    ) %>%
    group_by(hour = minute_bin) %>%
    summarise(across(c(X, Y, Z), \(x) mean(x, na.rm = TRUE)), .groups = "drop") %>%
    arrange(hour)
}

read_data <- function() {
  raw <- read_raw_day(raw_path)
  chap <- read_csv(chap_path, show_col_types = FALSE) %>%
    mutate(timestamp = as.POSIXct(timestamp, format = "%Y-%m-%d %H:%M:%S", tz = "UTC"))
  swan <- read_csv(swan_path, show_col_types = FALSE) %>%
    mutate(
      START_TIME = as.POSIXct(START_TIME, format = "%Y-%m-%d %H:%M:%S", tz = "UTC"),
      STOP_TIME = as.POSIXct(STOP_TIME, format = "%Y-%m-%d %H:%M:%S", tz = "UTC")
    )
  list(raw = raw, chap = chap, swan = swan)
}

hourly_summaries <- function(chap, swan) {
  out <- tibble(hour = 0:23)

  sitting <- chap %>%
    mutate(hour = as.integer(format(timestamp, "%H"))) %>%
    group_by(hour) %>%
    summarise(percent_sitting = 100 * mean(tolower(prediction) == "sitting", na.rm = TRUE), .groups = "drop")

  sleep_nonwear <- swan %>%
    mutate(hour = as.integer(format(START_TIME, "%H"))) %>%
    group_by(hour) %>%
    summarise(percent_sleep_nonwear = 100 * mean(STATE %in% c("SLEEP", "NON-WEAR"), na.rm = TRUE), .groups = "drop")

  out %>%
    left_join(sitting, by = "hour") %>%
    left_join(sleep_nonwear, by = "hour") %>%
    mutate(
      included = percent_sleep_nonwear < 91,
      waking_sedentary = ifelse(included, percent_sitting, NA_real_)
    )
}

make_panel_a <- function(panel_label = "A") {
  node_df <- tibble(
    id = c("raw", "chap", "swan", "hour", "wake"),
    label = c(
      "Raw signal\n80 Hz; X/Y/Z",
      "CHAP posture\n10-s windows",
      "SWaN\n30-s windows",
      "Hourly dataset\n% sitting + % sleep/nonwear",
      "Waking SB\n91% rule"
    ),
    x = c(0.09, 0.31, 0.31, 0.60, 0.88),
    y = c(0.50, 0.72, 0.28, 0.50, 0.50),
    w = c(0.16, 0.21, 0.21, 0.24, 0.15),
    h = c(0.28, 0.24, 0.24, 0.28, 0.28),
    color = c(FRAME, BLUE, GREEN, RED, FRAME),
    fill = c("white", "#F8FBFF", "#F8FCF7", "#FFFBFB", "white")
  )

  arrow_df <- tibble(
    x = c(0.17, 0.17, 0.41, 0.41, 0.73),
    y = c(0.58, 0.42, 0.72, 0.28, 0.50),
    xend = c(0.21, 0.21, 0.49, 0.49, 0.81),
    yend = c(0.72, 0.28, 0.56, 0.44, 0.50),
    color = c(BLUE, GREEN, BLUE, GREEN, RED)
  )

  ggplot() +
    geom_segment(
      data = arrow_df,
      aes(x = x, y = y, xend = xend, yend = yend, color = color),
      arrow = arrow(length = unit(0.16, "inches"), type = "closed"),
      linewidth = 1.45,
      lineend = "round"
    ) +
    geom_label(
      data = node_df,
      aes(x = x, y = y, label = label, color = color, fill = fill),
      size = 4.7,
      fontface = "bold",
      linewidth = 1.0,
      label.r = unit(0.16, "lines"),
      label.padding = unit(0.32, "lines"),
      lineheight = 0.9
    ) +
    scale_color_identity() +
    scale_fill_identity() +
    coord_cartesian(xlim = c(0, 1), ylim = c(0.05, 0.95), clip = "off") +
    labs(tag = panel_label, title = "Preprocessing architecture") +
    theme_void(base_size = 18) +
    theme(
      plot.title = element_text(face = "bold", size = 20, color = INK, hjust = 0, margin = margin(b = 6)),
      plot.tag = element_text(face = "bold", size = 28, color = INK),
      plot.tag.position = c(-0.045, 1.02),
      plot.margin = margin(8, 16, 8, 54)
    )
}

make_panel_b <- function(raw, panel_label = "B") {
  raw_long <- raw %>%
    pivot_longer(cols = c(X, Y, Z), names_to = "axis", values_to = "acceleration") %>%
    mutate(axis = recode(axis, X = "X axis", Y = "Y axis", Z = "Z axis"))

  ggplot(raw_long, aes(x = hour, y = acceleration, color = axis)) +
    geom_line(linewidth = 1.3, alpha = 0.96) +
    scale_color_manual(values = c("X axis" = PURPLE, "Y axis" = TEAL, "Z axis" = GREEN)) +
    scale_x_continuous(breaks = seq(0, 24, 4), limits = c(0, 24), expand = expansion(mult = c(0, 0))) +
    scale_y_continuous(limits = c(-1.5, 1.7), breaks = seq(-1, 1, 1), expand = expansion(mult = c(0, 0.02))) +
    labs(
      tag = panel_label,
      title = "Raw 80 Hz triaxial acceleration summarized at 1-minute intervals",
      x = "Hour of day",
      y = "Acceleration (g)"
    ) +
    guides(color = guide_legend(nrow = 1, byrow = TRUE, override.aes = list(linewidth = 2.4, alpha = 1))) +
    base_theme +
    theme(
      legend.position = "bottom",
      legend.justification = "center",
      legend.background = element_blank(),
      legend.margin = margin(t = 2, b = 0),
      plot.margin = margin(10, 16, 16, 54)
    )
}

make_panel_c <- function(chap, swan, panel_label = "C") {
  day_start <- as.POSIXct("2000-01-12 00:00:00", tz = "UTC")

  mode_label <- function(x) {
    tab <- sort(table(x), decreasing = TRUE)
    names(tab)[1]
  }

  chap_bins <- chap %>%
    mutate(
      start_hour = as.numeric(difftime(timestamp, day_start, units = "hours")),
      bin_hour = floor(start_hour * 6) / 6,
      state = if_else(tolower(prediction) == "sitting", "CHAP sitting", "CHAP not sitting")
    ) %>%
    group_by(bin_hour) %>%
    summarise(state = mode_label(state), .groups = "drop") %>%
    mutate(lane = 2, start_hour = bin_hour, end_hour = bin_hour + 10 / 60)

  swan_bins <- swan %>%
    mutate(
      start_hour = as.numeric(difftime(START_TIME, day_start, units = "hours")),
      bin_hour = floor(start_hour * 6) / 6,
      state = recode(STATE, "WEAR" = "wake-wear", "SLEEP" = "sleep/nonwear", "NON-WEAR" = "sleep/nonwear")
    ) %>%
    group_by(bin_hour) %>%
    summarise(state = mode_label(state), .groups = "drop") %>%
    mutate(lane = 1, start_hour = bin_hour, end_hour = bin_hour + 10 / 60)

  window_df <- bind_rows(chap_bins, swan_bins)

  ggplot(window_df) +
    geom_rect(
      aes(xmin = start_hour, xmax = end_hour, ymin = lane - 0.23, ymax = lane + 0.23, fill = state),
      color = "white",
      linewidth = 0.28
    ) +
    scale_fill_manual(values = c(
      "CHAP sitting" = BLUE,
      "CHAP not sitting" = BLUE_LIGHT,
      "sleep/nonwear" = GOLD,
      "wake-wear" = GREEN_DARK
    ),
    breaks = c("CHAP not sitting", "CHAP sitting", "sleep/nonwear", "wake-wear"),
    labels = c(
      "CHAP: not sitting",
      "CHAP: sitting",
      "SWaN: sleep/nonwear",
      "SWaN: wake-wear"
    )) +
    scale_x_continuous(breaks = seq(0, 24, 4), limits = c(0, 24), expand = expansion(mult = c(0, 0))) +
    scale_y_continuous(
      breaks = c(2, 1),
      labels = c("CHAP\n10-s", "SWaN\n30-s"),
      limits = c(0.18, 2.5),
      expand = expansion(mult = c(0, 0))
    ) +
    labs(
      tag = panel_label,
      title = "Full-day window classifications",
      x = "Hour of day",
      y = NULL
    ) +
    guides(fill = guide_legend(
      nrow = 1,
      byrow = TRUE,
      override.aes = list(linewidth = 0, color = NA)
    )) +
    base_theme +
    theme(
      legend.position = "bottom",
      legend.justification = "center",
      legend.background = element_blank(),
      legend.margin = margin(t = 2, b = 0),
      plot.margin = margin(10, 16, 22, 54)
    )
}

make_panel_d <- function(summary_df, panel_label = "D") {
  excluded <- summary_df %>% filter(!included)

  ggplot(summary_df, aes(x = hour)) +
    geom_rect(
      data = excluded,
      aes(xmin = hour - 0.5, xmax = hour + 0.5, ymin = 0, ymax = 100),
      inherit.aes = FALSE,
      fill = scales::alpha("#F5DEDF", 0.85),
      color = NA
    ) +
    geom_line(aes(y = percent_sitting), color = "#AEB9C8", linewidth = 1.45, na.rm = TRUE) +
    geom_point(aes(y = percent_sitting), color = "#AEB9C8", size = 3.6, na.rm = TRUE) +
    geom_line(aes(y = percent_sleep_nonwear), color = "purple", linewidth = 1.85, na.rm = TRUE) +
    geom_point(aes(y = percent_sleep_nonwear), color = "purple", size = 3.9, shape = 15, na.rm = TRUE) +
    geom_line(aes(y = waking_sedentary), color = BLUE, linewidth = 2.35, na.rm = TRUE) +
    geom_point(aes(y = waking_sedentary), color = BLUE, size = 4.2, na.rm = TRUE) +
    geom_hline(yintercept = 91, color = RED, linewidth = 1.35, linetype = "dashed") +
    annotate("text", x = 16.8, y = 14, label = "sleep/nonwear", color = "purple", size = 4.8, fontface = "bold", hjust = 0) +
    annotate("text", x = 13, y = 77, label = "91% cutoff", color = RED, size = 4.8, fontface = "bold", hjust = 1, vjust = -0.35) +
    annotate("text", x = 19, y = 70, label = "waking sedentary", color = BLUE, size = 5.0, fontface = "bold", hjust = 1) +
    annotate("text", x = 0.25, y = 9, label = "shaded hours excluded", color = RED, size = 4.7, fontface = "bold", hjust = 0) +
    scale_x_continuous(breaks = seq(0, 24, 4), limits = c(0, 24.5), expand = expansion(mult = c(0, 0))) +
    scale_y_continuous(breaks = seq(0, 100, 20), limits = c(0, 108), expand = expansion(mult = c(0, 0))) +
    labs(
      tag = panel_label,
      title = "Sleep/nonwear exclusion and waking sedentary estimate",
      x = "Hour of day",
      y = "Hour classified (%)"
    ) +
    coord_cartesian(clip = "off") +
    base_theme +
    theme(plot.margin = margin(10, 16, 8, 54))
}

data <- read_data()
hourly <- hourly_summaries(data$chap, data$swan)

p_a <- make_panel_a()
p_b <- make_panel_b(data$raw)
p_c <- make_panel_c(data$chap, data$swan)
p_d <- make_panel_d(hourly)

fig <- wrap_plots(p_a, p_b, p_c, p_d, ncol = 1, heights = c(0.88, 1.05, 0.9, 1.05))

fig_three_panel <- wrap_plots(
  make_panel_b(data$raw, panel_label = "A"),
  make_panel_c(data$chap, data$swan, panel_label = "B"),
  make_panel_d(hourly, panel_label = "C"),
  ncol = 1,
  heights = c(1.05, 0.9, 1.05)
)

dir.create(fig_dir, showWarnings = FALSE, recursive = TRUE)
png_path <- file.path(fig_dir, "preprocessing_workflow_figure.png")
pdf_path <- file.path(fig_dir, "preprocessing_workflow_figure.pdf")
three_panel_png_path <- file.path(fig_dir, "preprocessing_workflow_figure_three_panel.png")
three_panel_pdf_path <- file.path(fig_dir, "preprocessing_workflow_figure_three_panel.pdf")
fig1_png_path <- file.path(fig_dir, "fig1.png")
fig1_pdf_path <- file.path(fig_dir, "fig1.pdf")

ggsave(png_path, plot = fig, width = 11, height = 12.5, units = "in", dpi = 600, bg = "white")
ggsave(pdf_path, plot = fig, width = 11, height = 12.5, units = "in", bg = "white")
ggsave(three_panel_png_path, plot = fig_three_panel, width = 11, height = 9.4, units = "in", dpi = 600, bg = "white")
ggsave(three_panel_pdf_path, plot = fig_three_panel, width = 11, height = 9.4, units = "in", bg = "white")
ggsave(fig1_png_path, plot = fig_three_panel, width = 11, height = 9.4, units = "in", dpi = 600, bg = "white")
ggsave(fig1_pdf_path, plot = fig_three_panel, width = 11, height = 9.4, units = "in", bg = "white")

cat("Wrote ", png_path, "\n", sep = "")
cat("Wrote ", pdf_path, "\n", sep = "")
cat("Wrote ", three_panel_png_path, "\n", sep = "")
cat("Wrote ", three_panel_pdf_path, "\n", sep = "")
cat("Wrote ", fig1_png_path, "\n", sep = "")
cat("Wrote ", fig1_pdf_path, "\n", sep = "")
