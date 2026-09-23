suppressPackageStartupMessages(library(survey))
source("R/crib_sensitivity_inference.R")
x <- data.frame(
  reference = c(6, 12, 8, 11, 7, 14, 9, 10),
  difference_hours = c(-0.3, -0.1, -0.2, -0.4, -0.15, -0.25, -0.35, -0.05),
  weight = rep(1, 8)
)
x$sedentary_hours <- x$reference + x$difference_hours
design <- svydesign(ids = ~1, weights = ~weight, data = x)
result <- crib_paired_estimate(design)
expected_se <- sd(x$difference_hours) / sqrt(nrow(x))
stopifnot(abs(result$difference_hours - mean(x$difference_hours)) < 1e-12,
          abs(result$se_hours - expected_se) < 1e-12,
          abs(result$p_value - t.test(x$sedentary_hours, x$reference, paired = TRUE)$p.value) < 1e-12)
# Unequal weights: the paired variance must include the covariance, rather
# than combining setting and reference as independent estimates.
x$weight <- 1:8
design <- svydesign(ids = ~1, weights = ~weight, data = x)
result <- crib_paired_estimate(design)
joint <- svymean(~sedentary_hours + reference, design)
v <- vcov(joint)
expected_se <- sqrt(v[1, 1] + v[2, 2] - 2 * v[1, 2])
stopifnot(abs(result$se_hours - expected_se) < 1e-10,
          abs(result$difference_hours - weighted.mean(x$difference_hours, x$weight)) < 1e-12)
reference <- update(design, difference_hours = 0 * difference_hours)
result <- crib_paired_estimate(reference, TRUE)
stopifnot(result$difference_hours == 0, result$se_hours == 0, is.na(result$p_value))
cat("Paired sensitivity inference checks passed.\n")
