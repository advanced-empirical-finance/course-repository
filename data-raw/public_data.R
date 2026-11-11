# The public datasets in data/, downloaded as in the Tidy Finance chapter
# "Accessing and managing financial data". Students do not run this script:
# the files are part of the repository, so everyone works with the same
# numbers. Run it only to extend the sample, then commit the new files.
#
# From the repository root: uvr run data-raw/public_data.R

library(tidyverse)
library(tidyfinance)
library(nanoparquet)

start_date <- "1960-01-01"
end_date <- "2025-12-31"

# Fama-French three factors (Kenneth French's data library), monthly
factors_ff3_monthly <- download_data(
  domain = "Fama-French",
  dataset = "Fama/French 3 Factors",
  start_date = start_date,
  end_date = end_date
)

# Ten industry portfolios (Kenneth French's data library), monthly
industries_ff_monthly <- download_data(
  domain = "Fama-French",
  dataset = "10 Industry Portfolios",
  start_date = start_date,
  end_date = end_date
)

# Macroeconomic predictors of Welch and Goyal (2008), monthly
macro_predictors <- download_data(
  domain = "Goyal-Welch",
  dataset = "monthly",
  start_date = start_date,
  end_date = end_date
)

# Consumer price index (FRED series CPIAUCNS), scaled to 1 in the last month
cpi_monthly <- download_data(
  domain = "FRED",
  series = "CPIAUCNS",
  start_date = start_date,
  end_date = end_date
) |>
  mutate(cpi = value / value[date == max(date)])

lst(factors_ff3_monthly, industries_ff_monthly, macro_predictors, cpi_monthly) |>
  iwalk(\(data, name) write_parquet(data, file.path("data", paste0(name, ".parquet"))))
