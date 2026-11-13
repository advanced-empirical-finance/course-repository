# data/crsp_monthly.parquet: CRSP monthly stock data as in the Tidy Finance
# chapter "WRDS, CRSP, and Compustat", for the same sample as the public data.
# The file is licensed: students get it through Absalon, and Git ignores it.
# Needs WRDS credentials in the environment (WRDS_USER and WRDS_PASSWORD, for
# example in .Renviron).
#
# From the repository root: uvr run data-raw/crsp_monthly.R

library(tidyverse)
library(tidyfinance)
library(nanoparquet)

start_date <- "1960-01-01"
end_date <- "2025-12-31"

crsp_monthly <- download_data(
  domain = "WRDS",
  dataset = "crsp_monthly",
  start_date = start_date,
  end_date = end_date
)

write_parquet(crsp_monthly, "data/crsp_monthly.parquet")
