# Report data sources

The report data are grouped by purpose. `data/nhanes/` contains static public-use
source files, `data/derived/` contains the final analytic datasets, and
`data/figure1/` contains the reference signal used only for the workflow figure.
The pediatric BMI reference is archived with the former all-age analysis and is
not used by the adult report.

| Analytic file | Unit of observation |
|---|---|
| `data/derived/primary_daily_sitting.csv` | One eligible participant-day (55,722 rows) |
| `data/derived/primary_analytic_participants.csv` | One adult participant-cycle (9,308 rows) |

| Local file | Source |
|---|---|
| `data/nhanes/nhanes-demo-2011-2012.xpt` | https://wwwn.cdc.gov/Nchs/Data/Nhanes/Public/2011/DataFiles/DEMO_G.XPT |
| `data/nhanes/nhanes-demo-2013-2014.xpt` | https://wwwn.cdc.gov/Nchs/Data/Nhanes/Public/2013/DataFiles/DEMO_H.XPT |
| `data/nhanes/nhanes-bmx-2011-2012.xpt` | https://wwwn.cdc.gov/Nchs/Data/Nhanes/Public/2011/DataFiles/BMX_G.XPT |
| `data/nhanes/nhanes-bmx-2013-2014.xpt` | https://wwwn.cdc.gov/Nchs/Data/Nhanes/Public/2013/DataFiles/BMX_H.XPT |
| `data/nhanes/self-sleep-2011-12.xpt` | NHANES 2011–2012 sleep questionnaire file |
| `data/nhanes/self-sleep-2013-14.xpt` | NHANES 2013–2014 sleep questionnaire file |
| `data/figure1/raw80HZ_83724_data/2000-01-12.csv` | Reference wrist-acceleration signal for Figure 1 |
| `../old/data/cdc-bmi-for-age-lms.csv` (archived) | https://www.cdc.gov/growthcharts/data/zscore/bmiagerev.csv |

SHA-256 checksums at download on 2026-08-03:

```text
4814bfc3047ed400b9d43d285f8c3ea7c940ac6489404a9b699579715d158ec3  data/nhanes/nhanes-bmx-2011-2012.xpt
fd5e9fc6e6aab0a4aee6e699f51497bbc9b62101f7f43aee924c473e38fd9442  data/nhanes/nhanes-bmx-2013-2014.xpt
eaf0525d1952626885af3e935415a1f66ad62c18698080e7354789c125af252d  data/nhanes/nhanes-demo-2011-2012.xpt
f8f0cbb3085a323d4cde22349b164878fea1e64dbc404e65b5815c7816b547d7  data/nhanes/nhanes-demo-2013-2014.xpt
cbeea0e8d500ee15c652f3fdc45bcd02cb9c15d4d1e86f4d8048bbfea8d166e5  cdc-bmi-for-age-lms.csv
```
