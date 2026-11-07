# Factor zoo: the running example of the ML lectures

Prototype code for the plan in [course-homepage#16](https://github.com/advanced-empirical-finance/course-homepage/issues/16).

- **Running example:** the long-short anomaly portfolios of [Open Source Asset Pricing](https://www.openassetpricing.com) (Chen & Zimmermann), one dataset for every ML lecture.
- **Scoreboard:** each lecture adds its rows to the same table of Sharpe ratios.

`scoreboard.py` builds the first rows. Run it from the course repository:

```sh
uv run python lecture-slides/factor-zoo/scoreboard.py
```

On the first run it downloads the October 2026 data release from Hugging Face into `data/osap_portfolios.parquet`. Git ignores that file. Once tidyfinance can download these portfolios (r-tidyfinance#352, py-tidyfinance#89), the script will use `download_data()` and get an R twin.

**Output** (158 anomalies with complete returns 1973–2023; estimation sample up to 1999, test sample from 2000):

| Model | Sharpe ratio, estimation | Sharpe ratio, test |
|---|---:|---:|
| Market | 0.47 | 0.42 |
| 1/N over all anomalies | 2.80 | 1.44 |
| Plug-in MVE (no shrinkage) | 15.75 | 2.52 |
| Ridge SDF (Kozak, Nagel & Santosh) | 12.79 | 2.90 |
| PCA, 1 / 5 / 20 factors | 0.10 / 2.09 / 4.32 | −0.03 / 0.70 / 1.72 |
| RP-PCA, 1 / 5 / 20 factors | 2.95 / 5.94 / 8.07 | 1.30 / 2.34 / 2.54 |

**Next rows:** return prediction (B3), a light version of Chen, Pelger & Zhu (B4), and Sharpe ratios after transaction costs (B5).
