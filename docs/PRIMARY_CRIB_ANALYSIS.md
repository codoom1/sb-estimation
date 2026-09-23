# Primary adult CRIB analysis

Implementation corrected September 22, 2026. CRIB is applied before eligibility post-processing.
Retain a complete 1,440-minute CHAP-matched day with some CRIB wake only when
it has no original NHANES non-wear or every non-wear run is bounded within that
midnight-to-midnight day by known Wake or Sleep states. The four qualifying
patterns are Sleep–Non-wear–Wake, Wake–Non-wear–Sleep, Wake–Non-wear–Wake,
and Sleep–Non-wear–Sleep. Unknown on either side, missing flanks, or day-boundary
runs exclude the entire day. Days are
screened independently; later passing days are retained. Require at least one
passing day per adult participant-cycle and complete survey metadata.

The primary outputs include 9,308 adults and 55,722 days. Both previous rules
(the different-state rule and the rule allowing Unknown boundaries) are superseded.
At least two passing days remains a sensitivity analysis. Retained non-wear run
durations are summarized in the report, including a histogram and duration bins.

## Files and reproduction

- `R/crib_primary_day_rule.R`: within-day selection and legacy single-day restoration.
- `reports/source/final_analysis_crib_adult.Rmd`: primary estimates, tables, hourly figures, cohort exports, and minimum-two-day sensitivity.
- `R/plot_crib_waking_sedentary_bouts.R`: regenerate the bout figure using exactly `datasets/primary_daily_sitting.csv`.
- `R/render_crib_primary_report.R`: render the primary HTML locally once source extracts and refreshed bout outputs are available.
- `tests/check_crib_primary_day_rule.R`: selection, single-day restoration, independent-day retention, and hourly coverage checks.

The report's load-data chunk exports the primary day and participant datasets
before the bout figure is generated. The figure's cohort-size guard prevents
accidentally presenting an older figure. The reference example uses the verified
1,440-minute extract `qc/primary_day_rule/figure1_reference_minutes.csv` from the
current CRIB parquet. The correction audit records the days removed by the known-state boundary rule;
daily waking and sitting values on retained days remain unchanged.
See [the non-wear correction audit](NONWEAR_RULE_CORRECTION.md).

The four-method waking-time comparison uses common days drawn from the adopted
primary eligible-day dataset, requires at least one common day, and recalibrates
the SWaN cutoff in that common domain. Run `R/run_waking_time_method_comparison.R`
on Unity and copy the outputs back before rendering. The report checks that its
primary cohort counts match.
The CRIB-parameter sensitivity table uses paired differences on the fixed
primary sample; see [parameter sensitivity documentation](CRIB_PARAMETER_SENSITIVITY.md).
Historical local parameter-comparison outputs are archived under
`old/outputs/waking_time_method_comparison/`.
The archived non-wear effects report identifies cross-day and stopping-after-first-exclusion
analyses as sensitivity investigations, not the adopted policy.

The independent original-file non-wear audit outputs, including the distribution
figure and retained-run comparisons, are preserved in
`qc/original_nhanes_nonwear/`. The one-time extraction and correction utilities
are archived locally rather than included with the final analysis code.
