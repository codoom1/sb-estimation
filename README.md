# Sedentary-Time-Estimation in United States- NHANES 2011-2014

Repository for a manuscript on estimating waking sedentary time from wearable accelerometer data. The analysis combines wrist-worn CHAP posture predictions, SWaN sleep/non-wear classification, and survey-weighted NHANES models to evaluate sedentary time across participant characteristics and to calibrate an epoch-specific sleep/non-wear cutoff.

## Repository Scope

This repository provides the manuscript source, analysis notebooks, reusable R scripts, data inputs, and exported outputs needed to reproduce the paper's figures and tables. It is intended as a companion repository for readers, reviewers, and future users who want to inspect or rerun the workflow.

## Key Contribution

An important contribution of this paper is that it makes NHANES 2011-2014 wrist accelerometer-derived sedentary behavior estimates available for future epidemiologic research. In addition to reporting survey-weighted manuscript estimates, the workflow exports reusable analytic datasets:

- [Participant-level sedentary estimates](outputs/datasets/analytic_participant_sedentary.csv) with [formal dataset documentation](outputs/documentation/analytic_participant_sedentary_documentation.txt). This file provides one row per participant with usual daily waking sedentary time, sleep/nonwear time, waking time, demographic variables, and NHANES survey design variables.
- [Epoch-level sedentary estimates](outputs/datasets/analytic_epoch_sedentary.csv) with [formal dataset documentation](outputs/documentation/analytic_epoch_sedentary_documentation.txt). This file provides repeated native-epoch records with sitting percentage, sleep/nonwear percentage, cutoff-aware waking/sleep flags, epoch-level sedentary hours, demographic variables, and survey design variables for future repeated-measure and time-of-day analyses.

## Main Files

- `reports/source/manuscript_main.Rmd` - primary manuscript source used to generate the report.
- `reports/source/analysis.Rmd` - supporting analysis notebook for intermediate calculations and outputs.
- `reports/rendered/` - rendered manuscript and notebook outputs.
- `R/` - reusable R scripts for figures and other project helpers.
- `data/` - analysis input data retained for reproducibility.
- `figures/` - grouped exported figure files used in the manuscript and supporting diagnostics.
- `outputs/` - organized exported products, including manuscript tables, reusable datasets, cutoff diagnostics, quality-control files, and dataset documentation.
- `renv/`, `renv.lock` - project package environment.
- `pctSitting_research.Rproj` - RStudio project file.

## Data Included In The Repo

The repository retains the data files required by the manuscript workflow so readers can reproduce the summary tables, figures, and cutoff calibration used in the paper. Each dataset serves a different part of the analysis:

- `data/analysis_ready_1h_epoch/nosleep_data.csv.gz` contains the hip-worn sedentary-time summaries used for the comparison analyses and for manuscript tables that contrast hip and wrist estimates.
- `data/analysis_ready_1h_epoch/wrist_df.csv.gz` contains the wrist-worn 1-hour sitting summaries used as the main exposure source for the waking sedentary analyses.
- `data/analysis_ready_1h_epoch/sleep_est_data.csv.gz` contains the 1-hour sleep and non-wear summaries used to identify records excluded by the calibrated sleep/non-wear rule.
- `data/self-sleep-2011-12.xpt` contains the self-reported sleep data for the 2011-2012 NHANES cycle, used for calibration and validation of the sleep threshold.
- `data/self-sleep-2013-14.xpt` contains the self-reported sleep data for the 2013-2014 NHANES cycle, used alongside the 2011-2012 cycle to support pooled analyses.
- `data/top_level_data_1h_epoch/` contains the upstream raw ActiGraph, CHAP, and SWaN example files used to build the preprocessing workflow figure for the current 1-hour summary analysis. Epoch-specific upstream folders can be added alongside it for future sensitivity analyses, such as 30-second or 1-minute summaries.

## Reproducing The Manuscript

From the project root:

```bash
Rscript -e "renv::restore()"
Rscript R/render_manuscript.R 1h html
```

To render other manuscript versions:

```bash
Rscript R/render_manuscript.R 1h pdf
Rscript R/render_manuscript.R 30m html
Rscript R/render_manuscript.R 30m pdf
```

To run the supporting analysis notebook instead:

```bash
Rscript -e "rmarkdown::render('reports/source/analysis.Rmd', output_dir = 'reports/rendered', knit_root_dir = getwd())"
```

## Outputs

- Figures are written to `figures/`:
  - `figures/manuscript/` - final manuscript figures.
  - `figures/workflow/` - preprocessing/workflow figure variants.
  - `figures/diagnostics/` - cutoff and objective-function diagnostics.
  - `figures/exploratory/` - supporting exploratory or small-panel figures.
- Rendered R Markdown reports are written to `reports/rendered/`.
- Exported products are organized under `outputs/`:
  - `outputs/tables/` - manuscript-ready tables.
  - `outputs/results/` - top-level paper results.
  - `outputs/datasets/` - reusable analytic datasets for future research.
  - `outputs/documentation/` - dataset documentation and data dictionaries.
  - `outputs/cutoff/` - sleep/nonwear cutoff calibration and sensitivity outputs.
  - `outputs/qc/` - quality-control and missingness summaries.
  - `outputs/ids/` - participant identifier lists used for validation and sample tracking.
- The repository uses `renv` to keep package versions consistent across machines.

## Manuscript Tables And Figures

- **Table 1** summarizes the analytic sample and wear-day distribution by NHANES cycle, showing how many participants contributed valid wear days across 2011-2012 and 2013-2014.
- **Table 2** compares sedentary-time estimates across studies, measurement methods, datasets, and populations so readers can place the manuscript results in context.
- **Table 3** reports survey-weighted mean sedentary time by age and gender, highlighting how waking sedentary time varies across demographic groups.
- **Table 4** reports survey-weighted mean sedentary time by race/ethnicity and BMI category, showing how the estimates differ across body composition and population strata.
- **Figure 1** shows the preprocessing workflow from raw 80 Hz accelerometer data to CHAP and SWaN summaries and the hourly sleep/non-wear cutoff logic used to define waking sedentary time.
- **Figure 2** presents survey-weighted hourly sedentary patterns by day type before and after sleep exclusion, comparing CHAP-predicted sitting with waking sedentary estimates.
- **Figure 3** shows how participants are distributed across mean daily waking sedentary-time categories and how those categories map to the 24-hour behavioral composition of sedentary time, sleep/non-wear, and other waking time.
- **Figure 4** shows sleep-cutoff calibration and sedentary-time sensitivity across candidate thresholds, with the selected cutoff marked as the primary rule.

## Featured Figure

![Preprocessing workflow figure](figures/manuscript/fig1.png)

This figure summarizes the preprocessing workflow used in the manuscript, including the raw accelerometer signal, CHAP and SWaN classification summaries, and the calibrated sleep/non-wear cutoff used to define waking sedentary time.

## Related Repository

Readers interested in how the analysis inputs were generated and summarized can find the top-level Python preprocessing workflow here: [SedentaryBproject](https://github.com/codoom1/SedentaryBproject). That repository contains the CHAP and SWaN processing steps used to create the summary data consumed by this manuscript project.

## Citation

Citation details for the manuscript will be added here when the paper is published.

## License

This repository is released under the Apache License 2.0. See [LICENSE](LICENSE) for the full text.
