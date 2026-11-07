# Factor zoo scoreboard: Sharpe ratios of SDF/MVE portfolios built from the
# long-short anomaly portfolios of Open Source Asset Pricing (Chen &
# Zimmermann), the running example of the ML lectures (course-homepage#16).
#
# Run from the course repository: uvr run lecture-slides/factor-zoo/scoreboard.R

library(tidyverse)
library(nanoparquet)
library(tidyfinance)

start_date <- ymd("1973-01-01")
end_date <- ymd("2023-12-31")
split_date <- ymd("2000-01-01") # estimation sample before, test sample from here on

# Long-short returns of all anomalies, in percent, one column per anomaly. Once
# tidyfinance downloads them (r-tidyfinance#352), this becomes
# download_data("Open Source Asset Pricing", start_date = ..., end_date = ...).
osap_file <- "data/osap_long_short_returns.parquet"
if (!file.exists(osap_file)) {
  download.file(
    paste0(
      "https://huggingface.co/datasets/OpenSourceAP/CrossSection/resolve/",
      "Data-Release-2026.10/Portfolios/Full%20Sets%20OP/PredictorLSretWide.parquet"
    ),
    osap_file,
    mode = "wb"
  )
}

# A balanced panel: the anomalies with a return in every month
anomalies <- read_parquet(osap_file) |>
  mutate(date = floor_date(as.Date(date), "month")) |>
  filter(between(date, start_date, end_date)) |>
  select(date, where(\(x) !anyNA(x)))

returns <- anomalies |>
  select(-date) |>
  as.matrix() / 100
estimation <- anomalies$date < split_date
test <- !estimation

market <- download_data(
  domain = "Fama-French",
  dataset = "Fama/French 3 Factors",
  start_date = start_date,
  end_date = end_date
) |>
  right_join(select(anomalies, date), join_by(date)) |>
  pull(mkt_excess)

mu <- colMeans(returns[estimation, ])
sigma <- cov(returns[estimation, ])
n_anomalies <- ncol(returns)

sharpe_ratio <- function(x) mean(x) / sd(x) * sqrt(12)

scoreboard_row <- function(model, weights) {
  tibble(
    model = model,
    sr_estimation = sharpe_ratio(returns[estimation, ] %*% weights),
    sr_test = sharpe_ratio(returns[test, ] %*% weights)
  )
}

# SDF coefficients with a ridge penalty (Kozak, Nagel & Santosh, 2020)
ridge_weights <- function(mu, sigma, penalty) {
  solve(sigma + penalty * diag(length(mu)), mu)
}

# MVE weights on the first principal components of a second-moment matrix
pc_weights <- function(matrix, n_factors) {
  loadings <- eigen(matrix, symmetric = TRUE)$vectors[, 1:n_factors, drop = FALSE]
  factors <- returns[estimation, ] %*% loadings
  loadings %*% solve(cov(factors), colMeans(factors))
}

# Ridge penalty by 5-fold cross-validation within the estimation sample
penalties <- sum(diag(sigma)) / n_anomalies * 10^seq(-3, 1, length.out = 25)
folds <- cut(seq_len(sum(estimation)), 5, labels = FALSE)
returns_estimation <- returns[estimation, ]
cv_sharpe <- map_dbl(penalties, \(penalty) {
  map_dbl(1:5, \(fold) {
    keep <- folds != fold
    weights <- ridge_weights(
      colMeans(returns_estimation[keep, ]), cov(returns_estimation[keep, ]), penalty
    )
    sharpe_ratio(returns_estimation[!keep, ] %*% weights)
  }) |>
    mean()
})
best_penalty <- penalties[which.max(cv_sharpe)]

scoreboard <- bind_rows(
  tibble(
    model = "Market",
    sr_estimation = sharpe_ratio(market[estimation]),
    sr_test = sharpe_ratio(market[test])
  ),
  scoreboard_row("1/N over all anomalies", rep(1 / n_anomalies, n_anomalies)),
  scoreboard_row("Plug-in MVE (no shrinkage)", solve(sigma, mu)),
  scoreboard_row("Ridge SDF (Kozak, Nagel & Santosh)", ridge_weights(mu, sigma, best_penalty)),
  map(c(1, 5, 20), \(k) scoreboard_row(str_c("PCA, ", k, " factors"), pc_weights(sigma, k))),
  # RP-PCA (Lettau & Pelger, 2020) with gamma = 10
  map(c(1, 5, 20), \(k) {
    scoreboard_row(str_c("RP-PCA, ", k, " factors"), pc_weights(sigma + 10 * mu %*% t(mu), k))
  })
) |>
  mutate(across(starts_with("sr_"), \(x) round(x, 2)))

cat(n_anomalies, "anomalies with complete returns,", year(start_date), "to", year(end_date), "\n")
print(scoreboard)
