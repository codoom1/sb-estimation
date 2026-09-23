# CRIB parameter sensitivity on the adopted primary sample

The requested table shows the paired survey-weighted difference in waking
sedentary hours/day from the 80% required-sleep / 30-minute minimum-bout
setting, followed by a two-sided p-value. The grouped columns are 70%, 80%,
and 90% required sleep, each with 20, 30, 45, and 60-minute minimum bouts.
Rows are overall, sex, age, BMI, and race/ethnicity. N is unweighted.

## Analysis domain

All settings use the same 9,308 adults and 55,722 primary-eligible days.
The original NHANES within-day non-wear screen has already been applied
in `datasets/primary_daily_sitting.csv`. Non-wear runs bounded by matching or
differing known Wake or Sleep states within a day are allowed. The full repaired participant
minute sequence is classified before selecting those days, preserving the
primary CRIB context. The analysis never reruns CRIB on concatenated selected
days alone. Other CRIB parameters remain at their primary values.

This is a fixed-domain parameter comparison. It does not reselect participants
or days under each setting. If an alternative labels a primary-eligible day
entirely as sleep, that day contributes zero waking sedentary time. A separate
eligibility sensitivity would answer a different question.

Differences are first averaged across the same days within participant. The
survey design uses the complete eligible accelerometer metadata frame and
restricts to the primary adult domain and each subgroup. Tests use the mean
paired difference and its design-based standard error, with survey-design
degrees of freedom for a two-sided t test. P-values are unadjusted and test
change within each subgroup, not heterogeneity between subgroups. The reference
column is exactly zero and has no p-value. BMI is missing for 102 adults.

## Reproduction

From the project root, run all 50 batches and then summarize them:

```sh
for batch in $(seq 1 50); do
  Rscript --vanilla R/run_crib_primary_sensitivity.R --batch-index="$batch" --n-batches=50
done
Rscript --vanilla tests/check_crib_paired_sensitivity.R
Rscript --vanilla R/summarise_crib_primary_sensitivity.R
```

The analysis uses the current repaired merged CRIB parquet, not historical
sensitivity batches. Each participant's 80%/30-minute daily waking and sitting
estimates must reproduce the primary export to within 1e-8 hours. The summary
also checks the exact participant counts, retained-day counts, participant
reference means, and input provenance before writing the table.

Outputs are in `outputs/final_analysis_crib_adult/parameter_sensitivity/`:

- `table_sedentary_differences.html`: standalone grouped table.
- `table_sedentary_differences.csv`: formatted table.
- `table_sedentary_differences.tex`: standalone landscape table source.
- `paired_sedentary_differences.csv`: unrounded differences, SEs, CIs, p-values,
  degrees of freedom, and absolute sedentary means.
- `eligibility_summary.csv`: counts for all 12 settings.
- `provenance.csv` and `batches/`: input provenance and daily/participant results.

Copy the outputs locally and compile the PDF:

```sh
rsync -av unity:/work/pi_jstauden_umass_edu/pctSitting_research/outputs/final_analysis_crib_adult/parameter_sensitivity/ outputs/final_analysis_crib_adult/parameter_sensitivity/
pdflatex -interaction=nonstopmode -halt-on-error -output-directory=outputs/final_analysis_crib_adult/parameter_sensitivity outputs/final_analysis_crib_adult/parameter_sensitivity/table_sedentary_differences.tex
```

The adult report source includes this table with sample and reference-mean
guards. Rendering the entire adult report also requires the separately updated
four-method comparison outputs; that prerequisite is independent of this table.
Historical local parameter-sensitivity outputs are archived under
`old/outputs/waking_time_method_comparison/`.

The current outputs were validated for source freshness, complete setting
coverage, and agreement with the primary estimate on every retained day. Input
hashes and validation results accompany the outputs. Recalculate all settings
with `R/run_crib_primary_sensitivity.R`.

Validation: `Rscript tests/check_crib_paired_sensitivity.R` checks paired-test
equivalence to a paired t test under equal weights and checks unequal-weight
paired variance against the covariance of the two estimates.

## Figure 5: absolute time estimates

The summarizer also calls `R/plot_crib_parameter_sensitivity.R` to estimate
sleep (24 minus CRIB waking time), waking sedentary time, and waking time
for each setting on the same full-frame survey domain. Error bars are pointwise
normal 95% confidence intervals, matching the main absolute-time estimates.
The sleep estimate includes interruptions within CRIB sleep bouts.

Figure 5 is saved as PNG and PDF under `figures/final_analysis_crib_adult/`.
For Google Docs, use `figure5_crib_parameter_sensitivity_google_docs.png`,
which is exported at 6.5 by 3.5 inches and 1000 DPI with larger labels and
thicker lines for page-width placement. A matching vector PDF is also saved as
`figure5_crib_parameter_sensitivity_google_docs.pdf`. The same 36 estimates
are in `parameter_sensitivity/crib_sensitivity_weighted_estimates.csv`.
The report checks the current sample counts and primary-day fingerprint.
The archived figure used a superseded cohort and should not be used in the paper.
