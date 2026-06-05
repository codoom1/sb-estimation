# Reports

This directory keeps R Markdown source files separate from rendered report outputs.

## Folders

- `source/` contains editable R Markdown files.
- `rendered/` contains generated HTML and PDF outputs.

## Rendering

From the project root, render the main manuscript with:

```bash
Rscript R/render_manuscript.R 1h html
Rscript R/render_manuscript.R 1h pdf
```

The first argument selects the analysis epoch (`1h` or `30m`). The second argument selects the output format (`html` or `pdf`). Rendered files are written to `reports/rendered/`.

To render the supporting analysis notebook:

```bash
Rscript -e "rmarkdown::render('reports/source/analysis.Rmd', output_dir = 'reports/rendered', knit_root_dir = getwd())"
```
