# Sedentary-Time-Estimation in United States- NHANES 2011-2014

Repository for a manuscript on estimating waking sedentary time from wearable accelerometer data. The analysis combines wrist-worn CHAP posture predictions, SWaN sleep/non-wear classification, and survey-weighted NHANES models to evaluate sedentary time across participant characteristics and to calibrate a 91% sleep/non-wear cutoff.

## Repository Scope

This repository provides the manuscript source, analysis notebooks, reusable R scripts, data inputs, and exported outputs needed to reproduce the paper's figures and tables. It is intended as a companion repository for readers, reviewers, and future users who want to inspect or rerun the workflow.

## Main Files

- `manuscript_main.Rmd` - primary manuscript source used to generate the report.
- `analysis.Rmd` - supporting analysis notebook for intermediate calculations and outputs.
- `R/` - reusable R scripts for figures and other project helpers.
- `data/` - analysis input data retained for reproducibility.
- `figures/` - exported figure files used in the manuscript.
- `outputs/` - exported tables and text outputs used in the manuscript.
- `renv/`, `renv.lock` - project package environment.
- `pctSitting_research.Rproj` - RStudio project file.

## Data Included In The Repo

The repository retains the data files required by the manuscript workflow, including:

- `data/nosleep_data.csv.gz`
- `data/wrist_df.csv.gz`
- `data/sleep_est_data.csv.gz`
- `data/self-sleep-2011-12.xpt`
- `data/self-sleep-2013-14.xpt`
- `data/top_level_data/` - CHAP, SWaN, and raw accelerometer inputs used by the preprocessing figure workflow

## Reproducing The Manuscript

From the project root:

```bash
Rscript -e "renv::restore()"
Rscript -e "rmarkdown::render('manuscript_main.Rmd')"
```

To run the supporting analysis notebook instead:

```bash
Rscript -e "rmarkdown::render('analysis.Rmd')"
```

## Outputs

- The rendered manuscript HTML is stored as `manuscript_main.html` for convenience.
- Figures are written to `figures/` and tables/text outputs are written to `outputs/`.
- The repository uses `renv` to keep package versions consistent across machines.

## Related Repository

Readers interested in how the analysis inputs were generated and summarized can find the top-level Python preprocessing workflow here: [SedentaryBproject](https://github.com/codoom1/SedentaryBproject). That repository contains the CHAP and SWaN processing steps used to create the summary data consumed by this manuscript project.

## License

This repository is released under the Apache License 2.0. See [LICENSE](LICENSE) for the full text.
