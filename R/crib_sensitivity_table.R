# Shared presentation for the primary-cohort paired CRIB sensitivity table.
crib_sensitivity_note <- function(results) {
  info <- unique(results[c("primary_n", "primary_days", "bmi_missing")])
  stopifnot(nrow(info) == 1L)
  paste(
  "Cells show the survey-weighted paired difference in waking sedentary hours/day",
  "(two-sided p-value), alternative setting minus the primary 80%/30-minute setting.",
  "Positive values indicate more estimated sedentary time. All 12 settings use the same",
  paste0(format(info$primary_n, big.mark=","), " adults and ", format(info$primary_days, big.mark=","),
         " primary-eligible days; days are averaged within participant"),
  "before survey estimation. N is the unweighted subgroup count.",
  "P-values use the survey-design t distribution for the mean within-participant difference",
  "and are unadjusted for multiple comparisons. Ref. denotes the identical reference setting,",
  paste0("for which no test is performed. BMI is missing for ", info$bmi_missing, " participants."),
  "Eligibility is fixed to the primary analysis: alternative settings do not select a new cohort."
)
}

crib_sensitivity_display <- function(results) {
  results |>
    dplyr::mutate(
      cell = dplyr::case_when(
        required_percent == 80 & minimum_bout_minutes == 30 ~ "0.00 (Ref.)",
        TRUE ~ paste0(sprintf("%+.2f", difference_hours), " (",
                      ifelse(p_value < 0.001, "<0.001", sprintf("%.3f", p_value)), ")")
      )
    )
}

crib_sensitivity_html <- function(results, standalone = FALSE) {
  esc <- function(x) {
    x <- gsub("&", "&amp;", x, fixed = TRUE)
    x <- gsub("<", "&lt;", x, fixed = TRUE)
    gsub(">", "&gt;", x, fixed = TRUE)
  }
  data <- crib_sensitivity_display(results)
  rows <- data |> dplyr::distinct(row_order, subgroup, category, n) |> dplyr::arrange(row_order)
  header <- paste0(
    '<div class="crib-sensitivity"><table><caption>CRIB parameter sensitivity: difference from the primary estimate</caption>',
    '<thead><tr><th rowspan="2" scope="col">Group</th><th rowspan="2" scope="col">N</th>',
    paste0('<th colspan="4" scope="colgroup">', c(70, 80, 90), '% required sleep</th>', collapse = ''),
    '</tr><tr>', paste0('<th scope="col">', rep(c(20, 30, 45, 60), 3), ' min</th>', collapse = ''),
    '</tr></thead><tbody>'
  )
  body <- character()
  last_group <- "Overall"
  for (i in seq_len(nrow(rows))) {
    row <- rows[i, ]
    if (row$subgroup != last_group) {
      body <- c(body, paste0('<tr class="group"><th colspan="14" scope="rowgroup">', esc(row$subgroup), '</th></tr>'))
    }
    cells <- data |> dplyr::filter(row_order == row$row_order) |>
      dplyr::arrange(required_percent, minimum_bout_minutes)
    stopifnot(nrow(cells) == 12L)
    body <- c(body, paste0('<tr><th scope="row">', esc(row$category), '</th><td>',
                          format(row$n, big.mark = ',', trim = TRUE), '</td>',
                          paste0('<td', ifelse(cells$required_percent == 80 & cells$minimum_bout_minutes == 30,
                                              ' class="reference"', ''), '>', esc(cells$cell), '</td>', collapse = ''), '</tr>'))
    last_group <- row$subgroup
  }
  style <- paste0('<style>.crib-sensitivity{font-family:Arial,sans-serif;color:#172536;overflow-x:auto}',
    '.crib-sensitivity table{border-collapse:collapse;width:100%;font-size:11px;font-variant-numeric:tabular-nums}',
    '.crib-sensitivity caption{text-align:left;font-size:19px;font-weight:bold;padding:12px 0}',
    '.crib-sensitivity th,.crib-sensitivity td{padding:8px 6px;text-align:center;white-space:nowrap}',
    '.crib-sensitivity thead{border-top:2px solid #23394b;border-bottom:2px solid #23394b}',
    '.crib-sensitivity tbody th{text-align:left}.crib-sensitivity .group th{background:#edf2f6;padding-top:10px}',
    '.crib-sensitivity .reference{background:#edf6f0}.crib-sensitivity tbody tr:last-child{border-bottom:2px solid #23394b}',
    '.crib-sensitivity .note{font-size:12px;line-height:1.6;max-width:1500px}',
    '@page{size:legal landscape;margin:12mm}@media print{.crib-sensitivity table{font-size:8px}',
    '.crib-sensitivity th,.crib-sensitivity td{padding:5px 3px}}</style>')
  fragment <- paste0(style, header, paste(body, collapse = '\n'), '</tbody></table><p class="note">',
                     esc(crib_sensitivity_note(results)), '</p></div>')
  if (standalone) paste0('<!doctype html><html lang="en"><head><meta charset="utf-8">',
                         '<title>Primary CRIB parameter sensitivity</title></head><body>', fragment, '</body></html>') else fragment
}

crib_sensitivity_latex <- function(results, standalone = FALSE) {
  data <- crib_sensitivity_display(results)
  rows <- data |> dplyr::distinct(row_order, subgroup, category, n) |> dplyr::arrange(row_order)
  esc <- function(x) {
    x <- gsub(">=", "$\\geq$", x, fixed = TRUE)
    x <- gsub("%", "\\%", x, fixed = TRUE)
    gsub("&", "\\&", x, fixed = TRUE)
  }
  body <- character()
  last_group <- "Overall"
  for (i in seq_len(nrow(rows))) {
    row <- rows[i, ]
    if (row$subgroup != last_group) body <- c(body, paste0('\\addlinespace[5pt]\\multicolumn{14}{l}{\\textbf{', esc(row$subgroup), '}}\\\\'))
    cells <- data |> dplyr::filter(row_order == row$row_order) |> dplyr::arrange(required_percent, minimum_bout_minutes)
    cell_text <- gsub('<0.001', '$<0.001$', cells$cell, fixed = TRUE)
    body <- c(body, paste0(paste(c(esc(row$category), format(row$n, big.mark = ',', trim = TRUE), cell_text), collapse = ' & '), ' \\\\'))
    last_group <- row$subgroup
  }
  fragment <- paste0(
    '\\begingroup\n\\setlength{\\tabcolsep}{3pt}\n\\renewcommand{\\arraystretch}{1.3}\n',
    '\\noindent\\textbf{CRIB parameter sensitivity: difference from the primary estimate}\\par\\medskip\n',
    '\\noindent\\resizebox{\\linewidth}{!}{\\begin{tabular}{lr*{12}{r}}\\toprule\n',
    'Group & N & \\multicolumn{4}{c}{70\\% required sleep} & \\multicolumn{4}{c}{80\\% required sleep} & \\multicolumn{4}{c}{90\\% required sleep} \\\\\n',
    '\\cmidrule(lr){3-6}\\cmidrule(lr){7-10}\\cmidrule(lr){11-14}\n',
    ' & & ', paste(rep(paste0(c(20, 30, 45, 60), ' min'), 3), collapse = ' & '), ' \\\\ \\midrule\n',
    paste(body, collapse = '\n'), '\n\\bottomrule\\end{tabular}}\n\\par\\medskip\n',
    '\\footnotesize ', esc(crib_sensitivity_note(results)), '\n\\endgroup\n')
  if (standalone) paste0('\\documentclass[10pt]{article}\n\\usepackage[legalpaper,landscape,margin=0.45in]{geometry}\n',
                         '\\usepackage{booktabs,graphicx}\n\\usepackage[T1]{fontenc}\n\\usepackage{lmodern}\n',
                         '\\pagestyle{empty}\n\\begin{document}\n', fragment, '\\end{document}\n') else fragment
}
