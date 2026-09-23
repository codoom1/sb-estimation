# CRIB is the sleep-bout algorithm varied in this sensitivity analysis. The
# filename describes the analysis purpose; method-specific details remain here.
# Called by summarise_parameter_sensitivity.R after cohort/provenance checks.
export_crib_sensitivity_google_docs <- function(root = ".") {
  root <- normalizePath(root)
  out <- file.path(root, "outputs/final_analysis_adult")
  estimates <- readr::read_csv(
    file.path(out, "parameter_sensitivity/parameter_sensitivity_weighted_estimates.csv"),
    show_col_types = FALSE
  )
  cohort <- readr::read_csv(
    file.path(out, "qc/primary_day_rule/cohort_summary.csv"),
    show_col_types = FALSE
  )
  stopifnot(
    nrow(estimates) == 36L,
    all(estimates$n == cohort$participants),
    all(estimates$primary_days_md5 == unname(tools::md5sum(
      file.path(root, "data/derived/primary_daily_sitting.csv")
    )))
  )
  estimates$measure <- factor(
    estimates$measure,
    levels = c("Sleep estimate", "Waking sedentary time", "Waking time")
  )
  estimates$required_sleep <- factor(
    paste0(estimates$required_percent, "%"), levels = c("70%", "80%", "90%")
  )
  document_plot <- ggplot2::ggplot(
    estimates,
    ggplot2::aes(minimum_bout_minutes, mean_hours, colour = required_sleep, group = required_sleep)
  ) +
    ggplot2::geom_errorbar(
      ggplot2::aes(ymin = lower_95, ymax = upper_95), width = 1.6, linewidth = 0.6
    ) +
    ggplot2::geom_line(linewidth = 0.85) +
    ggplot2::geom_point(size = 2.4) +
    ggplot2::facet_wrap(
      ~measure, nrow = 1, scales = "free_y",
      labeller = ggplot2::as_labeller(c(
        "Sleep estimate" = "Sleep estimate",
        "Waking sedentary time" = "Waking sedentary\ntime",
        "Waking time" = "Waking time"
      ))
    ) +
    ggplot2::scale_colour_manual(
      values = c("70%" = "#71ADD7", "80%" = "#477EAF", "90%" = "#174A72"),
      name = "Required sleep"
    ) +
    ggplot2::scale_x_continuous(
      breaks = c(20, 30, 45, 60), expand = ggplot2::expansion(mult = c(0.10, 0.10))
    ) +
    ggplot2::scale_y_continuous(
      labels = function(x) sprintf("%.1f", x), breaks = scales::breaks_pretty(n = 4)
    ) +
    ggplot2::labs(x = "Minimum bout duration (minutes)", y = "Hours/day") +
    ggplot2::theme_minimal(base_size = 11, base_family = "sans") +
    ggplot2::theme(
      legend.position = "top",
      legend.title = ggplot2::element_text(face = "bold", size = 11),
      legend.text = ggplot2::element_text(size = 11),
      legend.key.width = grid::unit(0.38, "in"),
      legend.margin = ggplot2::margin(0, 0, 3, 0),
      strip.text = ggplot2::element_text(face = "bold", size = 11, margin = ggplot2::margin(4, 0, 7, 0)),
      axis.title = ggplot2::element_text(face = "bold", size = 12),
      axis.text = ggplot2::element_text(colour = "#222222", size = 10.5),
      axis.title.x = ggplot2::element_text(margin = ggplot2::margin(t = 9)),
      panel.grid.minor = ggplot2::element_blank(),
      panel.grid.major = ggplot2::element_line(colour = "#E5E5E5", linewidth = 0.35),
      panel.spacing = grid::unit(0.17, "in"),
      plot.margin = ggplot2::margin(5, 7, 5, 5)
    )
  stem <- file.path(
    root, "figures/final_analysis_adult/figure5_parameter_sensitivity_google_docs"
  )
  ggplot2::ggsave(paste0(stem, ".png"), document_plot,
                  width = 6.5, height = 3.5, units = "in", dpi = 1000, bg = "white")
  ggplot2::ggsave(paste0(stem, ".pdf"), document_plot,
                  width = 6.5, height = 3.5, units = "in",
                  device = grDevices::cairo_pdf, bg = "white")
  invisible(document_plot)
}

plot_parameter_sensitivity <- function(changes, frame, cohort, out, root) {
  settings <- tidyr::crossing(required_percent=c(70,80,90),minimum_bout_minutes=c(20,30,45,60))
  results <- lapply(seq_len(nrow(settings)),function(i) {
    setting <- settings[i,]
    values <- changes |> dplyr::filter(required_percent==setting$required_percent,
      minimum_bout_minutes==setting$minimum_bout_minutes) |>
      dplyr::transmute(ID,Dataset,sedentary_hours,waking_hours,sleep_hours=24-waking_hours)
    design_data <- frame |> dplyr::left_join(values,by=c('ID','Dataset'))
    design <- survey::svydesign(ids=~PSU,strata=~Stratum,weights=~Exam_weight_recal,nest=TRUE,data=design_data)
    domain <- subset(design,!is.na(waking_hours))
    stopifnot(nrow(domain$variables)==cohort$participants)
    fit <- survey::svymean(~sleep_hours+sedentary_hours+waking_hours,domain)
    ci <- confint(fit)
    dplyr::bind_cols(setting,tibble::tibble(
      measure=c('Sleep estimate','Waking sedentary time','Waking time'),
      mean_hours=as.numeric(coef(fit)),se_hours=as.numeric(survey::SE(fit)),
      lower_95=ci[,1],upper_95=ci[,2],n=cohort$participants,days=cohort$days,
      policy=cohort$policy,primary_days_md5=cohort$primary_days_md5))
  }) |> dplyr::bind_rows()
  paired <- readr::read_csv(file.path(out,'paired_sedentary_differences.csv'),show_col_types=FALSE) |>
    dplyr::filter(subgroup=='Overall')
  check <- results |> dplyr::filter(measure=='Waking sedentary time') |>
    dplyr::inner_join(paired,by=c('required_percent','minimum_bout_minutes'))
  stopifnot(nrow(results)==36L,nrow(check)==12L,
    max(abs(check$mean_hours-check$mean_sedentary_hours))<1e-8)
  for (i in seq_len(nrow(settings))) {
    z <- results |> dplyr::filter(required_percent==settings$required_percent[i],minimum_bout_minutes==settings$minimum_bout_minutes[i])
    stopifnot(abs(sum(z$mean_hours[z$measure %in% c('Sleep estimate','Waking time')])-24)<1e-8)
  }
  readr::write_csv(results,file.path(out,'parameter_sensitivity_weighted_estimates.csv'))
  plot_data <- results |> dplyr::mutate(
    measure=factor(measure,levels=c('Sleep estimate','Waking sedentary time','Waking time')),
    required_sleep=factor(paste0(required_percent,'%'),levels=c('70%','80%','90%')))
  p <- ggplot2::ggplot(plot_data,ggplot2::aes(minimum_bout_minutes,mean_hours,colour=required_sleep,group=required_sleep))+
    ggplot2::geom_errorbar(ggplot2::aes(ymin=lower_95,ymax=upper_95),width=2,linewidth=.55)+
    ggplot2::geom_line(linewidth=.8)+ggplot2::geom_point(size=2.5)+
    ggplot2::facet_wrap(~measure,nrow=1,scales='free_y')+
    ggplot2::scale_colour_manual(values=c('70%'='#8EC0E4','80%'='#4F7EAE','90%'='#1E4F7A'),name='Required sleep')+
    ggplot2::scale_x_continuous(breaks=c(20,30,45,60))+
    ggplot2::labs(title='CRIB parameter sensitivity: weighted time estimates',
      subtitle=paste0('Same ',format(cohort$participants,big.mark=','),' adults and ',format(cohort$days,big.mark=','),' days at every setting'),
      x='Minimum bout duration (minutes)',y='Hours/day')+
    ggplot2::theme_minimal(base_size=13)+ggplot2::theme(
      plot.title=ggplot2::element_text(face='bold',size=17),axis.title=ggplot2::element_text(face='bold'),
      legend.position='top',panel.grid.minor=ggplot2::element_blank())
  figure_root <- file.path(root,'figures/final_analysis_adult')
  for(ext in c('png','pdf')) ggplot2::ggsave(file.path(figure_root,paste0('figure5_parameter_sensitivity.',ext)),p,width=14,height=5,dpi=450,bg='white')
  export_crib_sensitivity_google_docs(root)
  invisible(results)
}
