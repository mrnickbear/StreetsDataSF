library(shiny)
library(leaflet)
library(mapview)

ui <- fluidPage(
  tags$head(
    tags$link(rel = "stylesheet", type = "text/css", href = "excavator.css")
  ),
  titlePanel("SF Streets Explorer"),
  tabsetPanel(
    id = "main_tabs",

    # ── Map tab (existing) ──────────────────────────────────────────────────
    tabPanel(
      "\U0001f5fa\ufe0f Map",
      br(),
      div(
        h4("Arterial Streets from DataSF"),
        uiOutput("tab")
      ),
      leafletOutput("map", width = "100%", height = 800)
    ),

    # ── SQL Curriculum tab ──────────────────────────────────────────────────
    tabPanel(
      "\U0001f4da SQL Curriculum",
      div(
        class = "curriculum-container",

        # Excavator character + narrative
        div(
          class = "excavator-area",
          tags$img(
            class      = "excavator-img",
            src        = "ExcavatorEmoji.png",
            alt        = "Digger the Excavator",
            height     = "130px"
          ),
          div(
            class = "narrative-wrap",
            div(class = "step-counter-wrap", textOutput("step_counter")),
            h4(class  = "step-title",        textOutput("step_title")),
            div(class = "speech-bubble",     textOutput("step_narrative"))
          )
        ),

        # SQL input
        div(
          class = "sql-input-area",
          textAreaInput(
            inputId     = "sql_input",
            label       = "SQL Query \u2014 modify and run:",
            value       = "SELECT * FROM streets LIMIT 5",
            rows        = 5,
            width       = "100%"
          ),
          actionButton("run_sql", "\u25b6 Run Query",
                       class = "btn btn-success btn-run")
        ),

        # SQL output
        div(
          class = "sql-output-area",
          h5("Results:"),
          div(class = "results-table-wrap", tableOutput("sql_output")),
          verbatimTextOutput("sql_error")
        ),

        # Navigation
        div(
          class = "nav-area",
          actionButton("prev_step", "\u25c4 Previous", class = "btn btn-default"),
          uiOutput("step_progress"),
          actionButton("next_step", "Next \u25ba",     class = "btn btn-primary")
        )
      )
    )
  )
)