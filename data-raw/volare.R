# data/volare_*.parquet: daily realized measures and realized covariances from
# VOLARE, the VOLatility Archive for Realized Estimates (volare.unime.it;
# Cipollini, Cruciani, Gallo, Insana, Otranto & Spagnolo, 2026,
# doi:10.48550/arXiv.2602.19732), release of 30 October 2026.
#
# Two files:
# - volare_realized_measures_daily.parquet: the realized measures of stocks
#   and futures, with asset_class "stock" or "future";
# - volare_realized_covariances_daily.parquet: the realized covariances of
#   the stocks.
# The stocks are 40 US stocks (the 30 Dow Jones stocks and 10 more from the
# S&P 100), 2 January 2015 to 30 October 2026; the futures are corn (C),
# crude oil (CL), the E-mini S&P 500 (ES), gold (GC) and natural gas (NG),
# from September 2009. VOLARE's forex files and the covariances of the
# futures are not used in the course.
#
# Realized measures: one row per asset and trading day. Variances are daily,
# in squared decimal returns (multiply by 252 for annual variances): realized
# variance from 1- and 5-minute returns (rv1, rv5; rv5_ss subsampled),
# bipower variation (bv*), positive and negative semivariances (rsp*, rsn*),
# median and minimum realized variance (medrv*, minrv*), the realized kernel
# (rk), realized quarticity (rq*), and range-based estimators (pr, gkr, rr5).
# For stocks, also volume, trades, and whether the stock is in the Dow Jones
# 30 (dow30) and the S&P 100 (sp100), today's membership for all dates; these
# columns are missing (NA) for futures.
#
# Realized covariances: one row per pair of stocks and trading day, each
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

# Stocks: index membership as two flags instead of a list in one text field
stocks <- read_volare("realized_variance", "stocks") |>
  mutate(
    dow30 = str_detect(coalesce(index, ""), "DOW30"),
    sp100 = str_detect(coalesce(index, ""), "S&P100")
  ) |>
  select(-index)
futures <- read_volare("realized_variance", "futures")

# One file for both: the stock-only columns (dow30, sp100, volume, trades)
# are NA for futures
measures <- bind_rows(
  stock = stocks,
  future = futures,
  .id = "asset_class"
) |>
  select(-asset_type) |>
  relocate(asset_class, date, symbol, dow30, sp100, volume, trades) |>
  arrange(asset_class, symbol, date)

covariances <- read_volare("realized_covariance", "stocks") |>
  arrange(date, asset1, asset2)

write_parquet(measures, "data/volare_realized_measures_daily.parquet")
write_parquet(covariances, "data/volare_realized_covariances_daily.parquet")
