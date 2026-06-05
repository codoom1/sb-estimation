args <- commandArgs(trailingOnly = TRUE)

analysis_epoch <- if (length(args) >= 1) args[[1]] else Sys.getenv("ANALYSIS_EPOCH", unset = "1h")
render_format <- if (length(args) >= 2) args[[2]] else "html"

valid_epochs <- c("1h", "30m")
valid_formats <- c("html", "pdf")

if (!analysis_epoch %in% valid_epochs) {
  stop("Epoch must be one of: ", paste(valid_epochs, collapse = ", "))
}

if (!render_format %in% valid_formats) {
  stop("Format must be one of: ", paste(valid_formats, collapse = ", "))
}

rmd_path <- "reports/source/manuscript_main.Rmd"
output_dir <- "reports/rendered"
output_format <- if (render_format == "pdf") "pdf_document" else "html_document"
extension <- if (render_format == "pdf") "pdf" else "html"
output_file <- paste0(
  tools::file_path_sans_ext(basename(rmd_path)),
  "_",
  analysis_epoch,
  ".",
  extension
)

Sys.setenv(ANALYSIS_EPOCH = analysis_epoch)
dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

rmarkdown::render(
  input = rmd_path,
  output_format = output_format,
  output_file = output_file,
  output_dir = output_dir,
  knit_root_dir = getwd(),
  clean = TRUE,
  quiet = TRUE
)
