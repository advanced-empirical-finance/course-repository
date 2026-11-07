# Factor zoo scoreboard (prototype): out-of-sample Sharpe ratios of SDF/MVE
# portfolios built from the long-short anomaly portfolios of Open Source Asset
# Pricing (Chen & Zimmermann). Plan and context: course-homepage#16.
#
# Run from the course repository: uv run python lecture-slides/factor-zoo/scoreboard.py
#
# Until tidyfinance can download these portfolios (r-tidyfinance#352,
# py-tidyfinance#89), the script reads the data release from Hugging Face and
# keeps a copy in data/, which Git ignores.
from pathlib import Path

import numpy as np
import polars as pl
import tidyfinance as tf

osap_url = (
    "https://huggingface.co/datasets/OpenSourceAP/CrossSection/resolve/"
    "Data-Release-2026.10/Portfolios/Full%20Sets%20OP/PredictorPortsFull.parquet"
)
osap_file = Path("data/osap_portfolios.parquet")
if not osap_file.exists():
    pl.read_parquet(osap_url).write_parquet(osap_file)

start_date = "1973-01-01"
end_date = "2023-12-31"
split_date = np.datetime64("2000-01-01")  # estimation before, test from here on

# Long-short portfolios of the original papers, one column per anomaly
anomalies = (pl.read_parquet(osap_file)
    .filter(pl.col("port") == "LS")
    .with_columns(date=pl.col("date").dt.truncate("1mo"))
    .filter(pl.col("date").is_between(pl.lit(start_date).str.to_date(), pl.lit(end_date).str.to_date()))
    .pivot(on="signalname", index="date", values="ret")
    .sort("date")
)
# A balanced panel: anomalies with a return in every month (returns in percent)
complete = [c for c in anomalies.columns if c != "date" and anomalies[c].null_count() == 0]
returns = anomalies.select(complete).to_numpy() / 100
dates = anomalies["date"].to_numpy()

factors_ff3_monthly = tf.download_data(
    domain="Fama-French",
    dataset="Fama/French 3 Factors",
    start_date=start_date,
    end_date=end_date,
)
market = factors_ff3_monthly.sort("date")["mkt_excess"].to_numpy()

estimation = dates < split_date
test = dates >= split_date
returns_estimation = returns[estimation]
mu = returns_estimation.mean(axis=0)
sigma = np.cov(returns_estimation, rowvar=False)
n_anomalies = returns.shape[1]


def sharpe_ratio(x):
    """Annualized Sharpe ratio of monthly excess returns."""
    return x.mean() / x.std() * np.sqrt(12)


def scoreboard_row(model, weights):
    """Sharpe ratios of the portfolio with the given anomaly weights."""
    weights = weights / np.abs(weights).sum()  # the Sharpe ratio does not depend on the scale
    return {
        "model": model,
        "sr_estimation": sharpe_ratio(returns[estimation] @ weights),
        "sr_test": sharpe_ratio(returns[test] @ weights),
    }


def ridge_weights(mu, sigma, penalty):
    """SDF coefficients with a ridge penalty (Kozak, Nagel & Santosh, 2020)."""
    return np.linalg.solve(sigma + penalty * np.eye(len(mu)), mu)


def pc_weights(matrix, n_factors):
    """MVE weights on the first principal components of a second-moment matrix."""
    values, vectors = np.linalg.eigh(matrix)
    loadings = vectors[:, np.argsort(values)[::-1][:n_factors]]
    factors = returns_estimation @ loadings
    factor_weights = np.linalg.solve(
        np.cov(factors, rowvar=False).reshape(n_factors, n_factors), factors.mean(axis=0)
    )
    return loadings @ factor_weights


rows = [
    {"model": "Market", "sr_estimation": sharpe_ratio(market[estimation]), "sr_test": sharpe_ratio(market[test])},
    scoreboard_row("1/N over all anomalies", np.ones(n_anomalies)),
    scoreboard_row("Plug-in MVE (no shrinkage)", np.linalg.solve(sigma, mu)),
]

# Ridge penalty by 5-fold cross-validation within the estimation sample
penalties = np.trace(sigma) / n_anomalies * np.logspace(-3, 1, 25)
folds = np.array_split(np.arange(returns_estimation.shape[0]), 5)
cv_sharpe = []
for penalty in penalties:
    fold_sharpe = []
    for fold in folds:
        keep = np.ones(returns_estimation.shape[0], dtype=bool)
        keep[fold] = False
        weights = ridge_weights(
            returns_estimation[keep].mean(axis=0), np.cov(returns_estimation[keep], rowvar=False), penalty
        )
        fold_sharpe.append(sharpe_ratio(returns_estimation[fold] @ weights))
    cv_sharpe.append(np.mean(fold_sharpe))
best_penalty = penalties[int(np.argmax(cv_sharpe))]
rows.append(scoreboard_row("Ridge SDF (Kozak, Nagel & Santosh)", ridge_weights(mu, sigma, best_penalty)))

for k in [1, 5, 20]:
    rows.append(scoreboard_row(f"PCA, {k} factors", pc_weights(sigma, k)))
for k in [1, 5, 20]:
    # RP-PCA (Lettau & Pelger, 2020) with gamma = 10
    rows.append(scoreboard_row(f"RP-PCA, {k} factors", pc_weights(sigma + 10 * np.outer(mu, mu), k)))

scoreboard = pl.DataFrame(rows).with_columns(pl.col("sr_estimation", "sr_test").round(2))
print(f"{n_anomalies} anomalies with complete returns, {start_date[:4]}-{end_date[:4]}, test from {str(split_date)[:4]}")
with pl.Config(tbl_rows=20, tbl_width_chars=100):
    print(scoreboard)
