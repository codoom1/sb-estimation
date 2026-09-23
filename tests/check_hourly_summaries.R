library(dplyr)
library(arrow)
library(purrr)
code <- readLines('reports/source/final_analysis_adult.Rmd')
inside <- FALSE
chunks <- character()
for (line in code) {
 if (startsWith(line, '```{r')) {inside <- TRUE; next}
 if (inside && startsWith(line, '```')) {inside <- FALSE; next}
 if (inside) chunks <- c(chunks, line)
}
invisible(parse(text=chunks))
cat('All Rmd chunks parse successfully\n')
exprs <- parse('R/sitting_time_est_batch.R')
for (e in exprs) {
 if (is.call(e) && identical(e[[1]], as.name('<-')) && as.character(e[[2]]) %in% c('longest_run', 'process_file')) eval(e)
}
adult_ids <- tibble(participant_id='test', dataset='2011-2012')
x <- expand.grid(minute=0:1439, nhanes_wear_day=1:2) |>
 mutate(participant_id='test', dataset='2011-2012',
 timestamp=as.POSIXct('2020-01-06', tz='UTC')+(nhanes_wear_day-1)*86400+minute*60,
 day=as.Date(timestamp), hour=minute %/% 60,
 sleep_prediction=if_else(minute < 45, 'Non-wear', 'Wake'),
 wake_ind=if_else(minute < 60, 'sleep', 'wake'), chap_sitting_fraction=0.25)
f <- tempfile(fileext='.parquet'); write_parquet(x, f)
r <- process_file(f); unlink(f)
stopifnot(nrow(r$daily_sitting)==2, nrow(r$hourly_sitting)==48,
 all(r$hourly_sitting$total_minutes==60),
 all(r$hourly_sitting$sitting_percent_hour[r$hourly_sitting$hour_of_day==0]==0),
 all(r$hourly_sitting$wake_hours[r$hourly_sitting$hour_of_day==0]==0),
 all(r$hourly_sitting$sitting_percent_hour[r$hourly_sitting$hour_of_day==1]==25),
 all(r$daily_sitting$sitting_minutes==1380*0.25))
# Partial wake hour: 20 sitting minutes / 60 samples = 33.33%, versus 66.67% of wake.
x$wake_ind[x$minute>=60 & x$minute<90] <- 'sleep'
x$chap_sitting_fraction[x$minute>=90 & x$minute<120] <- 2/3
f <- tempfile(fileext='.parquet'); write_parquet(x,f)
r <- process_file(f); unlink(f)
h <- filter(r$hourly_sitting, hour_of_day==1)
stopifnot(all(abs(h$sitting_percent_hour-100/3)<1e-8), all(abs(h$sitting_percent_wake-200/3)<1e-8))
cat('PASS: >=30-minute non-wear days retained; asleep hours retained as zeros; fractional sums and full-hour denominator verified.\n')
# The one-day primary analysis must not lose single-day records upstream.
f <- tempfile(fileext='.parquet'); write_parquet(filter(x,nhanes_wear_day==1),f)
r <- process_file(f); unlink(f)
stopifnot(nrow(r$daily_sitting)==1,nrow(r$hourly_sitting)==24)
cat('PASS: single-day input survives upstream summary construction.\n')
