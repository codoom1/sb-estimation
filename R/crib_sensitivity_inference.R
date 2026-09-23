# Test the survey-weighted mean of paired participant-level changes.
crib_paired_estimate <- function(design, is_reference = FALSE) {
  estimate <- survey::svymean(~difference_hours, design)
  absolute <- survey::svymean(~sedentary_hours, design)
  difference <- unname(stats::coef(estimate)[[1]])
  se <- unname(survey::SE(estimate)[[1]])
  df <- survey::degf(design)
  stopifnot(is.finite(difference), is.finite(se), df > 0)
  if (is_reference) {
    stopifnot(all(abs(design$variables$difference_hours) < 1e-8))
    difference <- 0
    se <- 0
  }
  p <- if (is_reference) NA_real_ else if (se > 0) {
    2 * stats::pt(-abs(difference / se), df = df)
  } else if (difference == 0) 1 else 0
  data.frame(
    difference_hours = difference, se_hours = se, df = df,
    lower_95 = difference - stats::qt(0.975, df) * se,
    upper_95 = difference + stats::qt(0.975, df) * se,
    p_value = p, mean_sedentary_hours = unname(stats::coef(absolute)[[1]])
  )
}
