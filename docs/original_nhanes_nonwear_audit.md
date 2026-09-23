# Independent audit of original NHANES non-wear runs

Input files are the original CDC `PAXMIN_G.xpt` and `PAXMIN_H.xpt` files on Unity,
under `/work/pi_jstauden_umass_edu/SBpaper_data_10s/nhanes/paxmin/`.
The audit reads these files directly, without the CRIB parquet, participant cache,
CHAP matching, complete-day selection, or non-wear eligibility exclusions.

A run is a maximal consecutive sequence of `PAXPREDM == 3` records from one
participant. Each record represents a minute; separate runs remain separate
observations. `PAXSSNMP` must advance by 4,800 samples between consecutive
minutes. Missing records break a run. The audit preserves runs across midnight. Runs contained within a retained
day are selected only for comparison with the report.
Record-edge/gap runs are observed durations and may be truncated.

Codes are 1 = Wake, 2 = Sleep, 3 = Non-wear, and 4 = Unknown. State-frequency
totals must exactly match the CDC codebooks before run extraction proceeds:

- [2011–2012 codebook](https://wwwn.cdc.gov/Nchs/Data/Nhanes/Public/2011/DataFiles/PAXMIN_G.htm)
- [2013–2014 codebook](https://wwwn.cdc.gov/Nchs/Data/Nhanes/Public/2013/DataFiles/PAXMIN_H.htm)

No survey weights are used: the requested distribution describes recorded runs.
Adult status comes from `RIDAGEYR >= 18` in each cycle's original DEMO file.
Both all-participant and adult distributions are provided. Known-boundary runs
require Wake or Sleep immediately on both sides. The final report's retained
runs are matched by participant, cycle, and day and checked for exact agreement
in individual run lengths and flanking states.

## Reproduction

On Unity, submit `cluster/audit_original_nhanes_nonwear.sh G` and the same
wrapper with `H`. After both finish, copy the audit CSVs locally and run
`Rscript R/summarise_original_nhanes_nonwear.R`.

## Files

- `original_nonwear_runs_G.csv`, `original_nonwear_runs_H.csv`: individual runs,
  preserving uninterrupted sequences across midnight.
- `state_frequencies_*.csv`: raw state counts checked against CDC totals.
- `source_provenance_*.csv`: exact source paths, sizes, modification dates, and counts.
- `duration_summary_by_scope.csv`: distributions before and after selection.
- `duration_summary_by_flanking_states.csv`: distribution by immediate flanks.
- `duration_summary_by_cycle_pattern.csv`: cycle-specific pattern distributions.
- `duration_bins_by_scope.csv`: run counts and percentages by duration bin.
- `retained_runs_verified_against_original_xpt.csv`: retained runs directly from XPT.
- `original_nhanes_nonwear_distribution.pdf` and `.png`: full and retained distributions.

Eligibility is attached after run extraction in `original_runs_with_eligibility.csv`;
no state records are deleted before computing lengths.
`original_vs_retained_run_lengths.csv` compares each common run's original and
report duration, with a required zero difference for every retained run.

## Results

The original files contain 58,498 continuous non-wear runs, including 39,362
adult runs. Adult run lengths have median 137 minutes (IQR 26–437), range
1–11,530 minutes; 1,572 last one minute and 1,106 last two minutes.
10,468 adult runs (26.6%) last at most 30 minutes.

Before day eligibility screening, 1,882 adult runs have known Wake/Sleep states
immediately on both sides; all are Wake–Non-wear–Wake. Their minimum is already
39 minutes. Of these, 955 are entirely within one day. Thus the short runs are
excluded by the immediate-flanking-state requirement, rather than being
lengthened by day screening. All 398 final retained runs have exactly their
original XPT run lengths and flanking states; every duration difference is zero.

Original adult runs of 30 minutes or less have Unknown or a recording edge/gap
on at least one side. The files contain no immediate Sleep–Non-wear or
Non-wear–Sleep boundary. This statement concerns released NHANES states, not
CRIB-derived sleep labels.
