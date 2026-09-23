# Final adult CRIB sedentary-time analysis

The active workspace reproduces the adult NHANES 2011–2014 CRIB report:
**9,308 participants and 55,722 eligible days**. The non-wear screen retains
runs bounded within the day by known Wake or Sleep states, including matching states
such as Wake–Non-wear–Wake.

- [Full report](reports/rendered/final_analysis_adult.html)
- [Report source](reports/source/final_analysis_adult.Rmd)
- [Primary analysis specification](docs/PRIMARY_ANALYSIS.md)
- [Parameter sensitivity methods and reproduction](docs/PARAMETER_SENSITIVITY.md)

## Render and check

From the project root, with the project R environment and local inputs available:

```sh
Rscript R/render_primary_report.R
Rscript tests/check_primary_day_rule.R
Rscript tests/check_hourly_summaries.R
Rscript tests/check_paired_sensitivity.R
```

Use `renv::restore()` when setting up the project R environment on another machine.
The `wristsed` package supplies the survey metadata and hourly comparison inputs.
The large minute records and original CHAP/SWaN inputs are maintained on Unity.

## Active layout

| Directory | Contents |
|---|---|
| `R/` | Final-report renderer, primary day selection, daily summaries, method comparison, sensitivity analysis, and figure generation |
| `docs/` | Analysis specifications, correction notes, and data-source documentation |
| `reports/source/` | The single final CRIB report Rmd |
| `reports/rendered/` | The rendered final CRIB HTML report |
| `data/nhanes/` | Public NHANES demographic, body-measure, and self-reported sleep source files |
| `data/derived/` | Final day-level and participant-level analytic datasets used by the report |
| `data/figure1/` | Raw reference signal used to construct Figure 1 |
| `data/upstream/` | Local or Unity-only minute-level inputs; ignored because of file size |
| `outputs/final_analysis_adult/` | Final tables, sensitivity results, and required source summaries/audits |
| `outputs/waking_time_method_comparison/` | Current four-method comparison inputs and results |
| `outputs/final_analysis/results/` | Shared CRIB minute-source files retained at the upstream pipeline's existing path |
| `figures/final_analysis_adult/` | Figures used in the final report |
| `tests/` | Primary day-rule, hourly-summary, and paired-inference checks |
| `old/` | Superseded analyses, reports, presentations, diagnostics, and other workspace material |

## Data provenance

### Public NHANES source files

The files under `data/nhanes/` were obtained from the CDC/NCHS NHANES public-use
releases. They are stored with descriptive local names and are not modified by
the analysis.

| Files | How obtained | Use in this report |
|---|---|---|
| `nhanes-demo-2011-2012.xpt`, `nhanes-demo-2013-2014.xpt` | Downloaded from the NHANES 2011–2012 DEMO_G and 2013–2014 DEMO_H releases | Supplies age; the `wristsed` participant frame supplies the examination weight, masked stratum, and masked PSU |
| `nhanes-bmx-2011-2012.xpt`, `nhanes-bmx-2013-2014.xpt` | Downloaded from the NHANES 2011–2012 BMX_G and 2013–2014 BMX_H releases | Supplies measured BMI used to define underweight, normal-weight, overweight, and obesity categories |
| `self-sleep-2011-12.xpt`, `self-sleep-2013-14.xpt` | Downloaded from the corresponding NHANES sleep-questionnaire releases | Supplies self-reported sleep duration for the supplementary waking-time method comparison; it is not used to define the primary CRIB estimate |

The download URLs and SHA-256 checksums are recorded in
[the data-source documentation](docs/reference_data_sources.md).

### Derived analytic datasets

The report creates the files under `data/derived/` from the verified CRIB and
CHAP daily summaries. They are the main analysis datasets committed to this
repository.

| File | How derived | Use in this report |
|---|---|---|
| `primary_daily_sitting.csv` | Starts with complete 1,440-minute participant-days. CRIB is applied to the full minute sequence, waking sedentary minutes are calculated by summing CHAP sitting fractions over CRIB-wake minutes, and the adopted within-day non-wear rule is applied. Only eligible adult participant-days are retained. | Primary day-level dataset; 55,722 days from 9,308 adult participant-cycles. It is also the fixed day set for the CRIB parameter sensitivity analysis. |
| `primary_analytic_participants.csv` | Daily waking sedentary and waking-time values are averaged within participant. The result is joined to age, measured BMI, and the NHANES survey-design metadata, then restricted to adults with complete design information. | One record per analytic participant-cycle; used for the overall, cycle-specific, and subgroup survey estimates. |

The report rewrites these two files when it is rendered, so their contents must
agree with the current eligibility rule and report code. Cohort counts and an
MD5 fingerprint guard the downstream sensitivity analyses against stale data.

### Figure 1 reference data

`data/figure1/raw80HZ_83724_data/2000-01-12.csv` is a reference extract from the
raw 80-Hz wrist-acceleration input maintained on Unity. It is used only to show
the signal-processing workflow in Figure 1 and does not contribute to any
population estimate.

### Large upstream data kept outside GitHub

The minute-level CHAP and CRIB files are maintained on Unity because they are
too large for the repository. The local merged input, when present, is stored as
`data/upstream/minute_level_classification.parquet` and is ignored by Git.
`R/sitting_time_est_batch.R` summarizes the minute records
minute records by participant-day and clock hour, and
`R/sitting_time_est_merge.R` combines the batch summaries. The final report
reads the merged `daily_sitting.csv` and `hourly_sitting_daily.csv` files from
the ignored `outputs/final_analysis_adult/results/` directory. Participant
survey metadata and supporting hourly comparison inputs are obtained from the
[`wristsed`](https://github.com/codoom1/wristsed) R package.

Some required non-wear inputs retain historical audit directory names. They are
used by the primary day-selection code and remain active.
The local shared minute parquet predates the current Unity source; use Unity's
repaired merged minute records for upstream recalculation. Local report rendering
uses the verified daily/hourly summaries and reference-minute extract instead.

## Archive

Archived files retain their original relative paths beneath `old/`.
[The move manifest](old/MOVE_MANIFEST.csv) records original and archived paths,
file sizes, and SHA-256 checksums. Files were moved without changing their
contents; the archive is not a separate runnable project.

This organization applies to the local workspace. Existing Unity paths and jobs
are unchanged.

The superseded different-flanking-state analysis is preserved in
`old/nonwear_rule_correction_20260922/`. See the
[correction audit](docs/NONWEAR_RULE_CORRECTION.md) for the rule change and
its effect on the analytic sample.

## Paper

**Sedentary Behavior in the United States Measured by Accelerometer, NHANES
2011–2014.** Christopher Odoom, John Staudenmayer, and additional coauthors to be
added. Department of Mathematics and Statistics, University of Massachusetts,
Amherst. Funded by NIH 5R01HL1685355-02. Manuscript in preparation.
