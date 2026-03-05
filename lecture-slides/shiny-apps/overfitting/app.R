library(shiny)
library(arrow)
library(tidyverse)

# Load and prepare data once at startup
data <- read_parquet("../../../data-r/industries_ff_monthly.parquet") |>
  select(date, returns = manuf) |>
  tail(40) |>
  mutate(
    time = as.integer(date),
    time = (time - mean(time)) / sd(time),
    date = as.Date(date)
  )

in_sample_size <- 20
train_set <- data |> slice_head(n = in_sample_size)
test_set  <- data |> slice_tail(n = nrow(data) - in_sample_size)

fit_polynomial <- function(degree, df = train_set) {
  formula <- as.formula(paste0("returns ~ poly(time, ", degree, ")"))
  lm(formula, data = df)
}

ui <- fluidPage(
  titlePanel("Overfitting: Polynomial Regression"),
  sidebarLayout(
    sidebarPanel(
      sliderInput(
        "degree",
        label    = "Polynomial degree (P):",
        min      = 1,
        max      = in_sample_size - 1,
        value    = 1,
        step     = 1
      ),
      hr(),
      helpText(
        "The shaded region is the out-of-sample (test) period.",
        "Increasing P reduces in-sample error but raises out-of-sample error — overfitting."
      ),
      hr(),
      tableOutput("mse_table")
    ),
    mainPanel(
      plotOutput("poly_plot", height = "450px")
    )
  )
)

server <- function(input, output, session) {

  model_results <- reactive({
    req(input$degree)
    d <- input$degree
    m <- fit_polynomial(d)

    preds_train <- predict(m, newdata = train_set)
    preds_test  <- predict(m, newdata = test_set)

    pred_df <- tibble(
      date    = data$date,
      fitted  = c(preds_train, preds_test)
    )

    mse_train <- mean((train_set$returns - preds_train)^2)
    mse_test  <- mean((test_set$returns  - preds_test)^2)

    list(pred_df = pred_df, mse_train = mse_train, mse_test = mse_test)
  })

  output$poly_plot <- renderPlot({
    res <- model_results()

    ggplot(data, aes(x = date, y = returns)) +
      annotate(
        "rect",
        xmin = min(test_set$date), xmax = max(test_set$date),
        ymin = -Inf, ymax = Inf,
        alpha = 0.25, fill = "grey70"
      ) +
      geom_point(size = 2) +
      geom_line(
        data  = res$pred_df,
        aes(x = date, y = fitted),
        color = "#2166ac", linewidth = 1
      ) +
      scale_x_date(date_labels = "%Y-%m") +
      scale_y_continuous(labels = scales::percent) +
      labs(
        title    = paste0("Polynomial degree P = ", input$degree),
        subtitle = sprintf(
          "In-sample MSE: %.4f  |  Out-of-sample MSE: %.4f",
          res$mse_train, res$mse_test
        ),
        x = NULL,
        y = "Return"
      ) +
      theme_bw(base_size = 14)
  })

  output$mse_table <- renderTable({
    res <- model_results()
    tibble(
      Period         = c("In-sample", "Out-of-sample"),
      MSE            = c(res$mse_train, res$mse_test),
      `Root MSE`     = sqrt(c(res$mse_train, res$mse_test))
    )
  }, digits = 4)
}

shinyApp(ui = ui, server = server)
