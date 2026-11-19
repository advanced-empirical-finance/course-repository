# lecture-slides/figures/lobster-spy-2024-03-20.png: the SPY order book on
# NASDAQ around the Fed statement at 14:00 on 20 March 2024, from LOBSTER
# (lobsterdata.com), 20 levels on each side. Also
# lecture-slides/figures/lobster-spy-2024-03-20-messages.csv: eight rows of
# the message file a second after the statement, with the best ask and bid of
# the order book file after each message.
#
# The LOBSTER files are licensed and stay on eumel in LOBSTER_DIR (default
# ~/data/lobster); only the figure is committed. The download is one 7z archive
# with a message file and an order book file for the whole day. The 45 seconds
# used here were cut out once, with the rows of both files side by side:
#
#   a=SPY_2024-03-20_2024-03-20_20.7z
#   paste -d, <(7z e -so $a SPY_2024-03-20_34140000_57660000_message_20.csv) \
#             <(7z e -so $a SPY_2024-03-20_34140000_57660000_orderbook_20.csv) |
#     awk -F, '$1 >= 50385 && $1 <= 50430 { print } $1 > 50430 { exit }' \
#     > SPY_2024-03-20_window_135945_140030.csv
#
# From the repository root: uvr run data-raw/lobster_snapshot.R

library(tidyverse)

lobster_dir <- Sys.getenv("LOBSTER_DIR", "~/data/lobster")
window_file <- file.path(
  path.expand(lobster_dir),
  "SPY_2024-03-20_window_135945_140030.csv"
)

# Times are seconds after midnight, New York time
shown_from <- 50390 # 13:59:50
shown_to <- 50425 # 14:00:25
fed_statement <- 50400 # 14:00:00
n_levels <- 20
snapshot_seconds <- 0.2
depth_cap <- 1000 # shares; larger orders get the largest dot
ku_red <- "#901A1E"

book_names <- as.vector(t(outer(
  seq_len(n_levels),
  c("ask_price", "ask_size", "bid_price", "bid_size"),
  \(level, variable) paste0(variable, "_", level)
)))
events <- read_csv(
  window_file,
  col_names = c(
    "time",
    "type",
    "order_id",
    "size",
    "price",
    "direction",
    "mpid",
    book_names
  ),
  col_types = cols(.default = col_double(), mpid = col_character())
)

# One snapshot of the book every 0.2 seconds: the book after the last event
# before the snapshot, kept until the next event
snapshots <- events |>
  mutate(snapshot = floor(time / snapshot_seconds)) |>
  slice_tail(n = 1, by = snapshot) |>
  select(snapshot, all_of(book_names)) |>
  complete(
    snapshot = seq(min(snapshot), round(shown_to / snapshot_seconds) - 1)
  ) |>
  arrange(snapshot) |>
  fill(everything(), .direction = "down") |>
  mutate(time = snapshot * snapshot_seconds) |>
  filter(time >= shown_from, time < shown_to) |>
  select(-snapshot) |>
  pivot_longer(
    -time,
    names_to = c("side", ".value", "level"),
    names_pattern = "(ask|bid)_(price|size)_(\\d+)"
  ) |>
  # LOBSTER fills empty levels with dummy prices of +-9999999999
  filter(abs(price) < 9e9) |>
  mutate(price = price / 1e4, depth = pmin(size, depth_cap))

# Executions of visible (type 4) and hidden (type 5) orders, starting with the
# last trade before the window so that the line starts at its left edge
trades <- events |>
  filter(type %in% c(4, 5)) |>
  mutate(price = price / 1e4, time = pmax(time, shown_from)) |>
  filter(
    time > shown_from | row_number() == max(which(time == shown_from)),
    time < shown_to
  )

clock <- \(seconds) {
  format(as.POSIXct(seconds, origin = "2024-03-20", tz = "UTC"), "%H:%M:%S")
}

figure <- ggplot(snapshots, aes(x = time, y = price)) +
  geom_point(aes(size = depth, alpha = depth, colour = side), stroke = 0) +
  geom_step(data = trades, colour = "black", linewidth = 0.35) +
  geom_vline(
    xintercept = fed_statement,
    linetype = "dashed",
    colour = "grey40"
  ) +
  scale_colour_manual(
    values = c(ask = ku_red, bid = "#4D4D4D"),
    guide = "none"
  ) +
  scale_size_area(max_size = 2.6, guide = "none") +
  scale_alpha_continuous(range = c(0.25, 0.9), guide = "none") +
  scale_x_continuous(
    labels = clock,
    breaks = seq(shown_from, shown_to, by = 5),
    minor_breaks = seq(shown_from, shown_to, by = 1)
  ) +
  labs(x = "20 March 2024 (New York time)", y = "Price (USD)") +
  theme_minimal(base_size = 12)

ggsave(
  "lecture-slides/figures/lobster-spy-2024-03-20.png",
  figure,
  width = 10,
  height = 4.6,
  dpi = 200,
  bg = "white"
)

# Eight messages a second after the statement, as stored in the files: time in
# seconds after midnight, prices in units of 1/10,000 dollar
example_from <- 50401.0229
example_to <- 50401.0298

events |>
  filter(between(time, example_from, example_to)) |>
  select(
    time,
    type,
    order_id,
    size,
    price,
    direction,
    ask_price_1,
    ask_size_1,
    bid_price_1,
    bid_size_1
  ) |>
  write_csv(
    "lecture-slides/figures/lobster-spy-2024-03-20-messages.csv"
  )
