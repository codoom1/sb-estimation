# Render the adopted primary analysis after generating the exact-cohort bout outputs.
rmarkdown::render('reports/source/final_analysis_crib_adult.Rmd',
                  output_format='html_document',output_dir='reports/rendered',quiet=TRUE)
