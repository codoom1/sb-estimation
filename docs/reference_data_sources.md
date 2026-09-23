# Locally cached reference data

These static public-use files are downloaded once and read locally by
`reports/source/final_analysis_crib_adult.Rmd`. The pediatric BMI reference is
archived with the former all-age analysis and is not used by the adult report.

| Local file | Source |
|---|---|
| `nhanes-demo-2011-2012.xpt` | https://wwwn.cdc.gov/Nchs/Data/Nhanes/Public/2011/DataFiles/DEMO_G.XPT |
| `nhanes-demo-2013-2014.xpt` | https://wwwn.cdc.gov/Nchs/Data/Nhanes/Public/2013/DataFiles/DEMO_H.XPT |
| `nhanes-bmx-2011-2012.xpt` | https://wwwn.cdc.gov/Nchs/Data/Nhanes/Public/2011/DataFiles/BMX_G.XPT |
| `nhanes-bmx-2013-2014.xpt` | https://wwwn.cdc.gov/Nchs/Data/Nhanes/Public/2013/DataFiles/BMX_H.XPT |
| `../old/data/cdc-bmi-for-age-lms.csv` (archived) | https://www.cdc.gov/growthcharts/data/zscore/bmiagerev.csv |

SHA-256 checksums at download on 2026-08-03:

```text
4814bfc3047ed400b9d43d285f8c3ea7c940ac6489404a9b699579715d158ec3  nhanes-bmx-2011-2012.xpt
fd5e9fc6e6aab0a4aee6e699f51497bbc9b62101f7f43aee924c473e38fd9442  nhanes-bmx-2013-2014.xpt
eaf0525d1952626885af3e935415a1f66ad62c18698080e7354789c125af252d  nhanes-demo-2011-2012.xpt
f8f0cbb3085a323d4cde22349b164878fea1e64dbc404e65b5815c7816b547d7  nhanes-demo-2013-2014.xpt
cbeea0e8d500ee15c652f3fdc45bcd02cb9c15d4d1e86f4d8048bbfea8d166e5  cdc-bmi-for-age-lms.csv
```
