# Render the adopted primary report. CRIB supplies the sleep-bout classification
# used to define waking minutes; the report documents its fixed parameters.
rmarkdown::render('reports/source/final_analysis_adult.Rmd',
                  output_format='html_document',output_dir='reports/rendered',quiet=TRUE)
