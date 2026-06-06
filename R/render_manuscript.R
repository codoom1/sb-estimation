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

find_project_root <- function(start = getwd()) {
  current <- normalizePath(start, winslash = "/", mustWork = TRUE)

  repeat {
    if (
      file.exists(file.path(current, "R", "render_manuscript.R")) &&
        file.exists(file.path(current, "reports", "source", "manuscript_main.Rmd"))
    ) {
      return(current)
    }

    parent <- dirname(current)
    if (identical(parent, current)) {
      stop("Could not find project root containing R/render_manuscript.R and reports/source/manuscript_main.Rmd.")
    }
    current <- parent
  }
}

project_root <- find_project_root()
setwd(project_root)

rmd_path <- file.path(project_root, "reports", "source", "manuscript_main.Rmd")
output_dir <- file.path(project_root, "reports", "rendered")
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
intermediates_dir <- tempfile(paste0("manuscript_main_", analysis_epoch, "_", render_format, "_"))
dir.create(intermediates_dir, recursive = TRUE, showWarnings = FALSE)
on.exit(unlink(intermediates_dir, recursive = TRUE, force = TRUE), add = TRUE)

rmarkdown::render(
  input = rmd_path,
  output_format = output_format,
  output_file = output_file,
  output_dir = output_dir,
  knit_root_dir = project_root,
  intermediates_dir = intermediates_dir,
  clean = TRUE,
  quiet = TRUE
)
