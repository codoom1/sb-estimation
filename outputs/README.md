# Outputs Directory

This directory contains exported products from the manuscript workflow. Files are grouped by use so readers can distinguish manuscript tables from reusable analytic datasets, cutoff diagnostics, and quality-control artifacts.

## Directory Map

- `tables/` - manuscript-ready tables.
- `results/` - top-level paper results.
- `datasets/` - reusable analytic datasets intended for future epidemiologic analyses.
- `documentation/` - dataset documentation and data dictionaries.
- `cutoff/` - sleep/nonwear cutoff calibration and sensitivity outputs.
- `qc/` - quality-control summaries, including missingness outputs.
- `ids/` - participant identifier lists used for validation and sample tracking.

## Key Files

- `datasets/analytic_participant_sedentary.csv` - participant-level analytic dataset with waking sedentary, sleep/nonwear, waking-time, demographic, and survey-design variables.
- `documentation/analytic_participant_sedentary_documentation.txt` - formal documentation for the participant-level analytic dataset.
- `datasets/analytic_epoch_sedentary.csv` - epoch-level analytic dataset with native-epoch sitting, sleep/nonwear, cutoff-aware waking/sleep flags, sedentary-hour contributions, demographic variables, and survey-design variables.
- `documentation/analytic_epoch_sedentary_documentation.txt` - formal documentation for the epoch-level analytic dataset.
- `results/main_results.csv` - top-level survey-weighted results reported in the manuscript.
- `cutoff/selected_cutoff.csv` - selected sleep/nonwear cutoff from the fine-resolution objective curve.
- `cutoff/objective_curve.csv` - fine-resolution objective curve used for cutoff selection.
- `cutoff/cutoff_sensitivity_grid.csv` - coarse sensitivity grid used for Figure 4.
- `qc/demographic_missingness.csv` - missingness of demographic and survey design variables relative to the analytic sample.

## Notes For Reuse

Use the participant-level dataset in `datasets/` for primary epidemiologic analyses and nationally representative estimates. Use the epoch-level dataset for repeated-measure, time-of-day, day-level, and sensitivity analyses. For nationally representative participant-level estimates, use the included NHANES survey design variables rather than treating epoch rows as independent weighted population observations.
