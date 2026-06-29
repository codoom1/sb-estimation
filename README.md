# Sedentary-Time Analysis

This repository provides the paper code and rendered outputs for estimating
waking sedentary time in NHANES 2011-2014 wrist accelerometer data.

It offers:

- one reproducible analysis report;
- final manuscript tables and figures;
- final CSV outputs used by the report;
- the small local files needed for sleep calibration and the workflow figure.

## Paper

**Sedentary Behavior in the United States Measured by Accelerometer, NHANES
2011-2014**

Authors:

- Christopher Odoom
- John Staudenmayer
- Additional coauthors to be added

Affiliation:

- Department of Mathematics and Statistics, University of Massachusetts,
  Amherst, MA

Funding:

This study was funded by the National Institutes of Health
(NIH 5R01HL1685355-02).

## Repository Contents

```text
R/
  render_report.R
  workflow_figure.R
data/
  self-sleep-2011-12.xpt
  self-sleep-2013-14.xpt
  top_level_data_1h_epoch/
reports/
  source/final_analysis.Rmd
  rendered/
outputs/final_analysis/
figures/final_analysis/
```

## Main Report

The main analysis is:

```text
reports/source/final_analysis.Rmd
```

It produces the rendered report in:

```text
reports/rendered/
```

and writes final analysis products to:

```text
outputs/final_analysis/
figures/final_analysis/
```

## Data

The final epoch-level and participant-level analysis datasets are loaded from
the [`wristsed`](https://github.com/codoom1/wristsed) R data package.

The package is a data product of this paper. It provides the cleaned NHANES
2011-2014 wrist accelerometer sedentary-time datasets used by the analysis,
including the participant-level estimates of waking sedentary time.

Install the package from GitHub with:

```r
# install.packages("remotes")
remotes::install_github("codoom1/wristsed")
```

This repository includes only the local files directly used by the report:

```text
data/self-sleep-2011-12.xpt
data/self-sleep-2013-14.xpt
data/top_level_data_1h_epoch/
```

The `top_level_data_1h_epoch/` files build the workflow figure.

## Reproduce

From the repository root:

```bash
Rscript -e "renv::restore()"
Rscript R/render_report.R html
Rscript R/render_report.R pdf
```

Check the environment:

```bash
Rscript -e "renv::status()"
```

`renv::status()` should report no issues.

## Outputs

Open the rendered report here:

```text
reports/rendered/final_analysis.html
reports/rendered/final_analysis.pdf
```

Final tables, results, cutoff files, QC files, and derived participant data are
under:

```text
outputs/final_analysis/
```

Final figure files are under:

```text
figures/final_analysis/
```

## Citation

Odoom C, Staudenmayer J, additional coauthors to be added. Sedentary Behavior
in the United States Measured by Accelerometer, NHANES 2011-2014. Manuscript in
preparation.
