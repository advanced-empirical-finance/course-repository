# Live polls with the poll service on eumel (see ~/live-poll/README.md there).
#
# A deck sources this file in its setup chunk. In the live version
# (--profile live), the poll slides show a QR code and a chart that updates
# every 3 seconds (see _live-poll-ojs.qmd). In the student version, they show
# the answers as they were when the deck was rendered, so render the student
# version again after the lecture.

poll_base <- "https://eumel.tail81c88a.ts.net:10000"

# TRUE when Quarto renders with --profile live
live <- "live" %in% strsplit(Sys.getenv("QUARTO_PROFILE"), ",")[[1]]

# All answers of a poll; an empty tibble if there are none or eumel is unreachable
poll_answers <- function(id) {
  answers <- tryCatch(
    jsonlite::fromJSON(paste0(poll_base, "/data?poll=", id)),
    error = function(e) NULL
  )
  if (!is.data.frame(answers) || nrow(answers) == 0) {
    return(tibble::tibble(time = character(), value = character()))
  }
  tibble::as_tibble(answers)
}

# Bar chart of a multiple-choice poll in the order of `choices`;
# NULL if nobody answered
poll_chart <- function(id, choices) {
  answers <- poll_answers(id)
  if (nrow(answers) == 0) {
    return(NULL)
  }
  counts <- tibble::tibble(choice = factor(choices, levels = rev(choices))) |>
    dplyr::left_join(
      dplyr::count(answers, choice = factor(value, levels = rev(choices))),
      by = "choice"
    ) |>
    dplyr::mutate(n = dplyr::coalesce(n, 0L))
  ggplot2::ggplot(counts, ggplot2::aes(x = n, y = choice)) +
    ggplot2::geom_col(fill = "#901A1E") +
    ggplot2::geom_text(ggplot2::aes(label = n), hjust = -0.5, size = 5) +
    ggplot2::labs(
      x = NULL, y = NULL,
      title = paste0("Answers in the lecture (n = ", nrow(answers), ")")
    ) +
    ggplot2::theme_minimal(base_size = 16) +
    ggplot2::theme(panel.grid = ggplot2::element_blank(), axis.text.x = ggplot2::element_blank())
}
