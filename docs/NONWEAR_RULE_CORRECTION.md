# Correction to the primary non-wear screen

The adopted rule accepts only Sleep–Non-wear–Wake, Wake–Non-wear–Sleep,
Wake–Non-wear–Wake, and Sleep–Non-wear–Sleep within the same midnight-to-midnight
day. Unknown is not a valid flank, even if it later becomes Wake or Sleep.
A day fails if any run has an Unknown/missing flank or reaches a day boundary.
Days without non-wear pass. No run-duration cutoff is applied.

Apply this screen after CRIB processing of the full complete-day sequence.
Require a complete CHAP-matched day with some CRIB wake and retain adults
with at least one passing day and complete survey metadata.

| Quantity | Superseded Unknown-allowed rule | Adopted known-state rule |
|---|---:|---:|
| Adults | 9,430 | 9,308 |
| Participant-days | 58,053 | 55,722 |
| Adults excluded by non-wear screen | 576 | 698 |

This removes 2,331 days and 122 adults; daily CRIB estimates on retained days
are unchanged. One adult has no complete day with CRIB wake. The final sample
is 9,308 of 10,007 adults (93.0%). The minimum-two-day sensitivity has 8,989 adults.

## Retained run durations

There are 398 retained runs, all Wake–Non-wear–Wake. Durations range from 39
to 1,281 minutes, with median 298.5 and IQR 114.25–487.75 minutes. None are
30 minutes or shorter; 62 (15.6%) are at most 60 minutes. These are unweighted
run summaries, not population estimates. They do not support describing the
retained runs as predominantly brief classification errors. The boundary rule
does not distinguish classification error from actual device removal.

The report exports duration summaries and bin counts in `qc/primary_day_rule/`
and Figure S2 in `figures/final_analysis_adult/`.

## Reproduction and preservation

The preceding Unknown-allowed outputs and source are preserved locally under
`old/known_state_nonwear_correction_20260922/`; corresponding output directories
are also preserved on Unity. Earlier different-state results remain under
`old/nonwear_rule_correction_20260922/`.

Rebuild the method comparison, bout figure, and parameter sensitivity, then
render with `R/render_primary_report.R`.
The policy identifier is `known_wake_sleep_bounded_nonwear_v3`. The day-rule test
covers all nine Wake/Sleep/Unknown pairs and rejects all five Unknown pairs,
plus missing-state and day-edge cases. Downstream guards check the current
cohort fingerprint.

## Independent run-length verification

An independent verification reconstructed every maximal Non-wear sequence
directly from all 50 current minute-source batches and compared every retained
run's start, end, length, and flanking states with the primary audit.
All 398 retained runs agree exactly. The synthetic Sleep–Non-wear–Non-wear–Sleep
example has length 2; separate runs are never combined into daily totals.
The verification outputs are `retained_nonwear_minute_verification.csv` and
`minute_source_nonwear_patterns.csv` in `qc/primary_day_rule/`. The latter includes
all source participants/days outside the retained sample, not only excluded adults.
