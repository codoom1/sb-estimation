# Final adult CRIB sedentary-time analysis

The active workspace reproduces the adult NHANES 2011–2014 CRIB report:
**9,308 participants and 55,722 eligible days**. The non-wear screen retains
runs bounded within the day by known Wake or Sleep states, including matching states
such as Wake–Non-wear–Wake.

- [Full report](reports/rendered/final_analysis_crib_adult.html)
- [Report source](reports/source/final_analysis_crib_adult.Rmd)
- [Primary analysis specification](docs/PRIMARY_CRIB_ANALYSIS.md)
- [Parameter sensitivity methods and reproduction](docs/CRIB_PARAMETER_SENSITIVITY.md)

## Render and check

From the project root, with the project R environment and local inputs available:

```sh
Rscript R/render_crib_primary_report.R
Rscript tests/check_crib_primary_day_rule.R
Rscript tests/check_crib_hourly_summaries.R
Rscript tests/check_crib_paired_sensitivity.R
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
| `data/` | NHANES metadata, self-reported sleep, and the raw reference signal used in Figure 1 |
| `outputs/final_analysis_crib_adult/` | Final tables, datasets, sensitivity results, and required source summaries/audits |
| `outputs/waking_time_method_comparison/` | Current four-method comparison inputs and results |
| `outputs/final_analysis/results/` | Shared CRIB minute-source files retained at the upstream pipeline's existing path |
| `figures/final_analysis_crib_adult/` | Figures used in the final report |
| `tests/` | Primary day-rule, hourly-summary, and paired-inference checks |
| `old/` | Superseded analyses, reports, presentations, diagnostics, and other workspace material |

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
