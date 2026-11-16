# data/volare_*.parquet: daily realized measures and realized covariances from
# VOLARE, the VOLatility Archive for Realized Estimates (volare.unime.it;
# Cipollini, Cruciani, Gallo, Insana, Otranto & Spagnolo, 2026,
# doi:10.48550/arXiv.2602.19732), release of 30 October 2026.
#
# Three asset classes, two files each:
# - stocks: 40 US stocks (the 30 Dow Jones stocks and 10 more from the
#   S&P 100), 2 January 2015 to 30 October 2026;
# - futures: corn (C), crude oil (CL), the E-mini S&P 500 (ES), gold (GC) and
#   natural gas (NG), from September 2009;
# - forex: AUDUSD, EURUSD, GBPUSD, USDCAD and USDJPY, from September 2009.
#
# realized_measures: one row per asset and trading day. Variances are daily,
# in squared decimal returns (multiply by 252 for annual variances): realized
# variance from 1- and 5-minute returns (rv1, rv5; rv5_ss subsampled),
# bipower variation (bv*), positive and negative semivariances (rsp*, rsn*),
# median and minimum realized variance (medrv*, minrv*), the realized kernel
# (rk), realized quarticity (rq*), and range-based estimators (pr, gkr, rr5).
# For stocks, also volume, trades, and whether the stock is in the Dow Jones
# 30 (dow30) and the S&P 100 (sp100), today's membership for all dates.
#
# realized_covariances: one row per pair of assets and trading day, each
# pair once (asset1 <= asset2, including asset1 == asset2): realized
# covariance from 1-minute returns (rcov; its diagonal equals rv1), bipower
# covariance (rbpcov), and the semicovariances (rscov_p, rscov_n, rscov_mp,
# rscov_mn).
#
# The files are licensed: students get them through Absalon, and Git ignores
# them. The downloads are zip files from volare.unime.it, which needs an
# account; VOLARE_DIR is the folder that holds them.
#
# From the repository root: uvr run data-raw/volare.R

library(tidyverse)
library(nanoparquet)

volare_dir <- Sys.getenv("VOLARE_DIR", "~/data/volare-raw")
release <- "20261030"
asset_classes <- c("stocks", "futures", "forex")

text_columns <- c("symbol", "asset_type", "asset1", "asset2", "index")

# Every column is a number except the date and the names, so the types are
# set from the header instead of guessed from the first rows
read_volare <- function(data_type, asset_class) {
  name <- paste0(data_type, "_", asset_class, "_", release)
  csv <- \() unz(file.path(path.expand(volare_dir), paste0(name, ".zip")), paste0(name, ".csv"))
  header <- names(read_csv(csv(), n_max = 0, show_col_types = FALSE))
  types <- map(header, \(column) {
    if (column == "date") col_date() else if (column %in% text_columns) col_character() else col_double()
  })
  read_csv(csv(), col_types = do.call(cols, set_names(types, header)))
}

for (asset_class in asset_classes) {
  measures <- read_volare("realized_variance", asset_class) |>
    select(-asset_type) |>
    arrange(symbol, date)

  # Index membership as two flags instead of a list in one text field
  if ("index" %in% names(measures)) {
    measures <- measures |>
      mutate(
        dow30 = str_detect(coalesce(index, ""), "DOW30"),
        sp100 = str_detect(coalesce(index, ""), "S&P100"),
        .after = symbol
      ) |>
      select(-index)
  }

  covariances <- read_volare("realized_covariance", asset_class) |>
    arrange(date, asset1, asset2)

  write_parquet(measures, paste0("data/volare_", asset_class, "_realized_measures_daily.parquet"))
  write_parquet(covariances, paste0("data/volare_", asset_class, "_realized_covariances_daily.parquet"))
}
