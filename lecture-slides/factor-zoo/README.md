# Factor zoo: the running example of the ML lectures

Code for the plan in [course-homepage#16](https://github.com/advanced-empirical-finance/course-homepage/issues/16).

- **Running example:** the long-short anomaly portfolios of [Open Source Asset Pricing](https://www.openassetpricing.com) (Chen & Zimmermann), one dataset for every ML lecture.
- **Scoreboard:** each lecture adds its rows to the same table of Sharpe ratios.
- **Sample split:** the estimation sample runs to 1999, the test sample from 2000.
- **Language:** R only, since the code is for the slides.

`scoreboard.R` builds the first rows. Run it from the course repository:

```sh
uvr run lecture-slides/factor-zoo/scoreboard.R
```

On the first run it downloads the October 2026 data release from Hugging Face into `data/osap_long_short_returns.parquet` (1.4 MB). Git ignores that file. Once tidyfinance can download these returns (r-tidyfinance#352), the download becomes a call to `download_data("Open Source Asset Pricing", ...)`.

**Output** (158 anomalies with complete returns 1973–2023):

| Model | Sharpe ratio, estimation | Sharpe ratio, test |
|---|---:|---:|
| Market | 0.47 | 0.42 |
| 1/N over all anomalies | 2.79 | 1.43 |
| Plug-in MVE (no shrinkage) | 15.7 | 2.51 |
| Ridge SDF (Kozak, Nagel & Santosh) | 12.8 | 2.89 |
| PCA, 1 / 5 / 20 factors | 0.10 / 2.09 / 4.32 | −0.03 / 0.70 / 1.71 |
| RP-PCA, 1 / 5 / 20 factors | 2.94 / 5.93 / 8.06 | 1.30 / 2.34 / 2.53 |

**Next rows:** return prediction (B3), a light version of Chen, Pelger & Zhu (B4), and Sharpe ratios after transaction costs (B5).
