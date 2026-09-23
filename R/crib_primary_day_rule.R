# Select complete CRIB days after processing, using original within-day states.
crib_nonwear_run_is_bounded <- function(prev_state, next_state, start_minute, end_minute) {
  # A transition into and out of non-wear is sufficient. The flanking states
  # may match: Wake/Non-wear/Wake and Sleep/Non-wear/Sleep both qualify.
  observed_states <- c('Wake', 'Sleep')
  !is.na(prev_state) & !is.na(next_state) &
    prev_state %in% observed_states & next_state %in% observed_states &
    !is.na(start_minute) & !is.na(end_minute) &
    start_minute > 0 & end_minute < 1439
}

apply_crib_primary_day_rule <- function(daily, hourly, qc_root) {
  keys <- c('participant_id','dataset','nhanes_wear_day')
  runs <- readr::read_csv(file.path(qc_root,'transition_nonwear_audit','nonwear_run_context.csv'),show_col_types=FALSE) |>
    dplyr::mutate(participant_id=as.character(participant_id),dataset=as.character(dataset))
  coverage <- readr::read_csv(file.path(qc_root,'age_nonwear_audit','daily_nonwear_runs.csv'),show_col_types=FALSE) |>
    dplyr::mutate(participant_id=as.character(participant_id),dataset=as.character(dataset))
  # Restore source participants with only one waking day, excluded by the legacy merge.
  extra_root <- file.path(qc_root,'primary_day_rule')
  read_extra <- function(name) readr::read_csv(file.path(extra_root,paste0('upstream_single_day_',name,'.csv')),show_col_types=FALSE) |>
    dplyr::mutate(participant_id=as.character(participant_id),dataset=as.character(dataset))
  daily <- dplyr::bind_rows(daily,dplyr::anti_join(read_extra('daily'),daily,by=keys))
  hourly <- dplyr::bind_rows(hourly,dplyr::anti_join(read_extra('hourly'),hourly,by=c(keys,'hour_of_day')))
  runs <- dplyr::bind_rows(runs,read_extra('runs'))
  coverage <- dplyr::bind_rows(coverage,read_extra('nonwear'))
  stopifnot(!anyDuplicated(daily[keys]),!anyDuplicated(coverage[keys]),
            nrow(dplyr::anti_join(daily,coverage,by=keys))==0)
  # Recompute rather than trusting the historical transition boolean.
  runs <- runs |> dplyr::mutate(qualifies=crib_nonwear_run_is_bounded(
    prev_state, next_state, start_minute, end_minute))
  by_day <- runs |> dplyr::group_by(dplyr::across(dplyr::all_of(keys))) |>
    dplyr::summarise(run_nonwear_minutes=sum(run_minutes),exclude_nonwear=any(!qualifies),.groups='drop')
  audit <- daily |> dplyr::left_join(coverage |> dplyr::select(dplyr::all_of(keys),nonwear_minutes),by=keys) |>
    dplyr::left_join(by_day,by=keys) |>
    dplyr::mutate(run_nonwear_minutes=dplyr::coalesce(run_nonwear_minutes,0),
      exclude_nonwear=dplyr::coalesce(exclude_nonwear,FALSE),keep_day=!exclude_nonwear & wake_minutes>0)
  stopifnot(all(audit$nonwear_minutes==audit$run_nonwear_minutes),!anyNA(audit$keep_day))
  selected <- audit |> dplyr::filter(keep_day) |> dplyr::select(dplyr::all_of(names(daily)))
  list(daily=selected,hourly=dplyr::semi_join(hourly,selected,by=keys),audit=audit,
       retained_runs=dplyr::semi_join(runs,selected,by=keys))
}
