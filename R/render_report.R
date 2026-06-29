args <- commandArgs(trailingOnly = TRUE)
render_format <- if (length(args) >= 1L) args[[1]] else "html"
valid_formats <- c("html", "pdf")

if (!render_format %in% valid_formats) {
  stop("Format must be one of: ", paste(valid_formats, collapse = ", "))
}

find_project_root <- function(start = getwd()) {
  current <- normalizePath(start, winslash = "/", mustWork = TRUE)
  repeat {
    if (file.exists(file.path(current, "reports", "source", "final_analysis.Rmd"))) {
      return(current)
    }
    parent <- dirname(current)
    if (identical(parent, current)) stop("Could not find project root.")
    current <- parent
  }
}

project_root <- find_project_root()
setwd(project_root)

output_format <- if (render_format == "pdf") "pdf_document" else "html_document"
extension <- if (render_format == "pdf") "pdf" else "html"
output_dir <- file.path(project_root, "reports", "rendered")
dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

rmarkdown::render(
  input = file.path(project_root, "reports", "source", "final_analysis.Rmd"),
  output_format = output_format,
  output_file = paste0("final_analysis.", extension),
  output_dir = output_dir,
  knit_root_dir = project_root,
  clean = TRUE,
  quiet = TRUE
)
