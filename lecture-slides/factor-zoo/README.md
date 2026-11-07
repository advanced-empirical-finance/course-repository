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

## B3 and B4 (prototype)

`scoreboard.R` also builds the first B3 and B4 rows:

- **B3:** return forecasts from a pooled model (OLS, ridge, lasso, random forest, a small neural network), used as the means of the MVE portfolio.
- **B4, linear:** state-dependent weights as the ridge MVE portfolio of managed portfolios.

Forecasts reach an out-of-sample R² of about 1 %. Both approaches still lose to the static ridge SDF out of sample: Sharpe ratios of 1.1–1.5 against 2.89.

`cpz_light.py` is a light version of Chen, Pelger & Zhu (2024).

- **SDF network:** a feed-forward network maps the macro state and each anomaly's own features (last return, momentum, historical mean, loadings on the first principal components) to its weight.
- **Adversary:** a second network builds the test assets of the conditional moment conditions.
- **Samples:** training 1974–1994, validation 1995–1999 (early stopping), test from 2000.

It is a uv script with its own dependencies (PyTorch); it uses a GPU if there is one:

```sh
uv run lecture-slides/factor-zoo/cpz_light.py --seeds 9
```

First results on a CPU (2 networks per ensemble):

| Inputs | Model | Train | Validation | Test |
|---|---|---:|---:|---:|
| Macro + anomaly features | Feed-forward SDF | 2.80 | 2.50 | 1.04 |
| | Chen–Pelger–Zhu light | 2.76 | 2.41 | 0.98 |
| + loadings on 10 principal components | Feed-forward SDF | 3.36 | 2.89 | 1.08 |
| | Chen–Pelger–Zhu light | 3.52 | 2.97 | 1.13 |
| Anomaly features and loadings, no macro | Feed-forward SDF | 3.46 | 2.94 | 0.88 |
| | Chen–Pelger–Zhu light | 4.69 | 3.89 | 1.37 |

## Hyperparameter search on UCloud

`cpz_light_sweep.sh` tries 72 settings: hidden units, dropout, weight decay, loadings on or off, macro on or off. Each setting uses 9 networks per ensemble. Every run appends its settings and Sharpe ratios to `results/cpz_light_runs.csv`.

On a UCloud machine with a GPU (for example the *Terminal* or *JupyterLab* app), in a terminal:

```sh
curl -LsSf https://astral.sh/uv/install.sh | sh   # installs uv; open a new terminal afterwards
git clone https://github.com/advanced-empirical-finance/course-repository.git
cd course-repository
bash lecture-slides/factor-zoo/cpz_light_sweep.sh
```

The first lines of each run should report `device: cuda`. Afterwards, download the `results/` folder or commit it.

**Next rows:** Sharpe ratios after transaction costs (B5), from our factor library with trading costs.
