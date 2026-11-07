# Factor zoo scoreboard: Sharpe ratios of SDF/MVE portfolios built from the
# long-short anomaly portfolios of Open Source Asset Pricing (Chen &
# Zimmermann), the running example of the ML lectures (course-homepage#16).
#
# Run from the course repository: uvr run lecture-slides/factor-zoo/scoreboard.R

library(tidyverse)
library(nanoparquet)
library(tidyfinance)
library(glmnet)
library(ranger)
library(nnet)

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

scoreboard_b1 <- bind_rows(
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


# B3: predicting the anomaly returns ---------------------------------------
# Features of anomaly i for month t: its own return in t - 1, its mean return
# over t - 12 to t - 1 (factor momentum), and five macro predictors known at the
# end of t - 1. One pooled model for all anomalies, fitted once on the
# estimation sample.

rolling_mean <- function(x, k) as.numeric(stats::filter(x, rep(1 / k, k), sides = 1))

macro <- download_data(
  domain = "Goyal-Welch",
  dataset = "monthly",
  start_date = start_date - months(1),
  end_date = end_date
) |>
  transmute(date = date %m+% months(1), dp, tbl, tms, dfy, svar)

macro_names <- c("dp", "tbl", "tms", "dfy", "svar")
macro_scaled <- macro |>
  mutate(across(all_of(macro_names), \(x) {
    (x - mean(x[date < split_date])) / sd(x[date < split_date])
  }))

panel <- anomalies |>
  pivot_longer(-date, names_to = "anomaly", values_to = "ret") |>
  mutate(ret = ret / 100) |>
  arrange(anomaly, date) |>
  group_by(anomaly) |>
  mutate(
    ret_lag_1 = lag(ret),
    momentum_12 = rolling_mean(lag(ret), 12)
  ) |>
  ungroup() |>
  left_join(macro_scaled, join_by(date)) |>
  drop_na()

features <- c("ret_lag_1", "momentum_12", macro_names)
train <- panel |> filter(date < split_date)
x_train <- as.matrix(train[features])
x_all <- as.matrix(panel[features])
scale_center <- colMeans(x_train)
scale_sd <- apply(x_train, 2, sd)
x_train_scaled <- scale(x_train, scale_center, scale_sd)
x_all_scaled <- scale(x_all, scale_center, scale_sd)

# Cross-validation folds: consecutive blocks of months
fold_id <- cut(as.numeric(train$date), 5, labels = FALSE)

set.seed(2027)
predictions <- list(
  "OLS" = as.numeric(cbind(1, x_all_scaled) %*% coef(lm(train$ret ~ x_train_scaled))),
  "Ridge" = cv.glmnet(x_train_scaled, train$ret, alpha = 0, foldid = fold_id) |>
    predict(newx = x_all_scaled, s = "lambda.min") |>
    as.numeric(),
  "Lasso" = cv.glmnet(x_train_scaled, train$ret, alpha = 1, foldid = fold_id) |>
    predict(newx = x_all_scaled, s = "lambda.min") |>
    as.numeric(),
  "Random forest" = ranger(
    x = x_train_scaled, y = train$ret, num.trees = 300, mtry = 3, min.node.size = 500
  ) |>
    predict(data = x_all_scaled) |>
    pluck("predictions"),
  "Neural network" = nnet(
    x_train_scaled, train$ret, size = 5, decay = 0.1, linout = TRUE, maxit = 500, trace = FALSE
  ) |>
    predict(x_all_scaled) |>
    as.numeric()
)
predictions[["Factor momentum (no model)"]] <- panel$momentum_12

# Out-of-sample R^2 against a zero forecast, and the MVE portfolio with the
# predicted means: w_t = (Sigma + penalty * I)^{-1} mu_t, with the ridge
# penalty of the B1 row
prediction_row <- function(model, predicted) {
  test_rows <- panel$date >= split_date
  oos_r2 <- 1 - sum((panel$ret[test_rows] - predicted[test_rows])^2) / sum(panel$ret[test_rows]^2)
  portfolio <- panel |>
    mutate(predicted = predicted) |>
    select(date, anomaly, predicted, ret) |>
    nest(data = -date) |>
    mutate(ret = map_dbl(data, \(d) {
      mu_t <- d$predicted[match(colnames(returns), d$anomaly)]
      ret_t <- d$ret[match(colnames(returns), d$anomaly)]
      sum(ridge_weights(mu_t, sigma, best_penalty) * ret_t)
    }))
  tibble(
    model = str_c("B3 ", model),
    sr_estimation = sharpe_ratio(portfolio$ret[portfolio$date < split_date]),
    sr_test = sharpe_ratio(portfolio$ret[portfolio$date >= split_date]),
    oos_r2 = oos_r2
  )
}

scoreboard_b3 <- imap(predictions, \(predicted, model) prediction_row(model, predicted)) |>
  list_rbind()

# B4: a light version of Chen, Pelger & Zhu ----------------------------------
# State-dependent SDF weights w_{i,t} = b_i' z_{i,t}, with instruments z_{i,t}:
# a constant, the five macro predictors and the anomaly's own momentum. The
# SDF is the MVE portfolio of the managed portfolios r_{i,t+1} * z_{i,t},
# estimated with the ridge penalty chosen by cross-validation as in B1.

managed_portfolios <- function(instruments) {
  panel |>
    select(date, anomaly, ret, all_of(instruments)) |>
    mutate(across(all_of(instruments), \(z) ret * z)) |>
    mutate(constant = ret) |>
    select(-ret) |>
    pivot_wider(names_from = anomaly, values_from = -c(date, anomaly)) |>
    arrange(date)
}

# With more portfolios than months, (Sigma + penalty * I)^{-1} mu is cheaper
# through the Woodbury identity: Sigma = X'X / (T - 1) for the demeaned
# returns X, so only a T x T system has to be solved.
ridge_weights_months <- function(x, penalty) {
  mu <- colMeans(x)
  x <- sweep(x, 2, mu)
  n <- nrow(x)
  (mu - crossprod(x, solve(penalty * (n - 1) * diag(n) + tcrossprod(x), x %*% mu))) / penalty
}

conditional_row <- function(model, managed) {
  m <- as.matrix(select(managed, -date))
  m_estimation <- m[managed$date < split_date, ]
  folds_m <- cut(seq_len(nrow(m_estimation)), 5, labels = FALSE)
  penalties_m <- mean(apply(m_estimation, 2, var)) * 10^seq(-3, 2, length.out = 26)
  cv <- map_dbl(penalties_m, \(penalty) {
    map_dbl(1:5, \(fold) {
      keep <- folds_m != fold
      b <- ridge_weights_months(m_estimation[keep, ], penalty)
      sharpe_ratio(m_estimation[!keep, ] %*% b)
    }) |>
      mean()
  })
  b <- ridge_weights_months(m_estimation, penalties_m[which.max(cv)])
  sdf <- m %*% b
  tibble(
    model = str_c("B4 ", model),
    sr_estimation = sharpe_ratio(sdf[managed$date < split_date]),
    sr_test = sharpe_ratio(sdf[managed$date >= split_date])
  )
}

# Instruments on a common scale: momentum standardized with its estimation-sample
# standard deviation (the macro predictors already are), plus random Fourier
# features of the macro predictors for nonlinear weights
panel <- panel |>
  mutate(momentum_scaled = momentum_12 / sd(momentum_12[date < split_date]))
omega <- matrix(rnorm(length(macro_names) * 5), nrow = length(macro_names))
rff <- as.matrix(panel[macro_names]) %*% omega
panel <- panel |>
  bind_cols(as_tibble(cbind(sin(rff), cos(rff)), .name_repair = \(x) str_c("rff_", seq_along(x))))

scoreboard_b4 <- bind_rows(
  conditional_row("Constant weights (B1 on the same months)", managed_portfolios(character())),
  conditional_row("Momentum as instrument", managed_portfolios("momentum_scaled")),
  conditional_row("Momentum and macro", managed_portfolios(c("momentum_scaled", macro_names))),
  conditional_row("Momentum and random macro features", managed_portfolios(c("momentum_scaled", str_c("rff_", 1:10))))
)

scoreboard <- bind_rows(scoreboard_b1, scoreboard_b3, scoreboard_b4) |>
  mutate(across(c(starts_with("sr_"), oos_r2), \(x) round(x, 3)))

cat(n_anomalies, "anomalies with complete returns,", year(start_date), "to", year(end_date), "\n")
print(scoreboard, n = Inf, width = 120)
