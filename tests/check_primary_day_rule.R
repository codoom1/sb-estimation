suppressPackageStartupMessages({library(dplyr);library(readr)})
source('R/primary_day_rule.R')
# Only known Wake/Sleep pairs qualify, including matching states.
pairs <- expand.grid(before=c('Wake','Sleep','Unknown'), after=c('Wake','Sleep','Unknown'))
stopifnot(identical(crib_nonwear_run_is_bounded(pairs$before, pairs$after, 1, 1438),
  pairs$before != 'Unknown' & pairs$after != 'Unknown'))
stopifnot(!any(crib_nonwear_run_is_bounded(
  c('Wake','Wake',NA,'Non-wear','Sleep','Unknown'),
  c('Wake','Wake','Wake','Wake',NA,'Unknown'),
  c(0,1,1,1,1,0), c(30,1439,30,30,30,1439))))
root <- 'outputs/final_analysis_adult'
d <- read_csv(file.path(root,'results/daily_sitting.csv'),show_col_types=FALSE) |> mutate(participant_id=as.character(participant_id))
h <- read_csv(file.path(root,'results/hourly_sitting_daily.csv'),show_col_types=FALSE) |> mutate(participant_id=as.character(participant_id))
z <- apply_crib_primary_day_rule(d,h,file.path(root,'qc'))
stopifnot(nrow(z$daily)==55722,nrow(distinct(z$daily,participant_id,dataset))==9308,
 nrow(z$hourly)==24*nrow(z$daily),
 all(z$daily$wake_minutes>0),all(z$hourly$total_minutes==60),all(z$retained_runs$qualifies),
 all(z$retained_runs$start_minute>0),all(z$retained_runs$end_minute<1439),
 all(z$retained_runs$run_minutes == z$retained_runs$end_minute-z$retained_runs$start_minute+1))
stopifnot(any(z$retained_runs$prev_state == 'Wake' & z$retained_runs$next_state == 'Wake'),
          !any(z$retained_runs$prev_state == 'Unknown' | z$retained_runs$next_state == 'Unknown'))
# A failing day must not invalidate a later passing day for the same participant.
a <- z$audit |> group_by(participant_id,dataset) |> arrange(nhanes_wear_day,.by_group=TRUE) |>
 mutate(after_failure=cumsum(!keep_day)>0) |> ungroup()
stopifnot(any(a$keep_day & a$after_failure))
# Partially observed original cohorts are restored before one-day eligibility.
new_ids <- setdiff(z$daily$participant_id,d$participant_id)
stopifnot(length(new_ids)>0)
cat('Primary day selection, restored single-day records, hourly denominators, and independent-day retention passed.\n')
stopifnot(!any(z$audit$keep_day & z$audit$nonwear_minutes==1440))
