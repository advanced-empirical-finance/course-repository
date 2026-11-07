# Live polls and surveys with the poll service on eumel (see
# ~/live-poll/README.md there).
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

# All questions of a survey with the number of answers per choice
# (see /survey on eumel); NULL if eumel is unreachable
survey_results <- function(id) {
  tryCatch(
    jsonlite::fromJSON(paste0(poll_base, "/survey/data?id=", id)),
    error = function(e) NULL
  )
}

# One bar chart per survey question; NULL if nobody answered
survey_chart <- function(id) {
  results <- survey_results(id)
  if (is.null(results) || results$respondents == 0) {
    return(NULL)
  }
  # Choices are made unique per question ("1|None"), so questions with the
  # same choices keep their own order in their own panel
  counts <- results$questions |>
    dplyr::mutate(question = dplyr::row_number()) |>
    dplyr::select(question, short, choices, counts) |>
    tidyr::unnest(c(choices, counts)) |>
    dplyr::mutate(
      short = factor(short, levels = unique(short)),
      choice = paste(question, choices, sep = "|"),
      choice = factor(choice, levels = rev(unique(choice)))
    )
  ggplot2::ggplot(counts, ggplot2::aes(x = counts, y = choice)) +
    ggplot2::geom_col(fill = "#901A1E") +
    ggplot2::geom_text(ggplot2::aes(label = counts), hjust = -0.4, size = 4) +
    ggplot2::facet_wrap(~short, scales = "free_y", ncol = 3) +
    ggplot2::scale_y_discrete(labels = function(x) sub("^[0-9]+[|]", "", x)) +
    ggplot2::scale_x_continuous(expand = ggplot2::expansion(mult = c(0, 0.25))) +
    ggplot2::labs(
      x = NULL, y = NULL,
      title = paste0("Answers in the first lecture (n = ", results$respondents, ")")
    ) +
    ggplot2::theme_minimal(base_size = 14) +
    ggplot2::theme(
      panel.grid = ggplot2::element_blank(),
      axis.text.x = ggplot2::element_blank(),
      strip.text = ggplot2::element_text(face = "bold", hjust = 0)
    )
}
