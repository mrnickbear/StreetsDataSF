
# library(rsconnect)
library(sf)
library(shiny)
# library(leafem)
library(leaflet)
library(mapview)
library(sqldf)

# streets <-  read_sf("K:\\sfbase\\arcview\\SFCity\\ACTIVESTREETS\\activestreets.shp")
# source("R:\\Modeling Work\\oracle_sql\\Ruby\\ScorecardExport\\sfrb.datasf\\R\\datasf.R")

# source("datasf.R")
# Create Data SF URL for CSV or geodata datasets
create.datasf.url <- function(dataset_id, geodata = FALSE, nonce = NA) {
  # Construct Socrata download URL
  today <- gsub("-", "", as.character(Sys.Date()))
  nonce <- ifelse(is.na(nonce), as.integer(as.POSIXct(Sys.time())), nonce)
  api_call <- ifelse(geodata, "geospatial", "views")
  csv_path <- ifelse(geodata, "", "rows.csv")
  geo_params <- ifelse(geodata, "&method=export&format=GeoJSON", "")
  
  url <- glue::glue("https://data.sfgov.org/api/{api_call}/{dataset_id}/{csv_path}?fourfour={dataset_id}&date={today}&cacheBust={nonce}&accessType=DOWNLOAD{geo_params}")
}

# Old supported call
load.dataset.csv <- function(dataset_id) {
  load.dataset(dataset_id)
}

# Download CSV dataset from Data SF, optionally cache in rds
load.dataset <- function(dataset_id, filename.rds = NA) {
  # Check for local rds cache
  if (!is.na(filename.rds)) {
    if (file.exists(filename.rds)) {
      return (readRDS(filename.rds))
    }
  }
  # Download fresh CSV dataset
  dataset.url <- create.datasf.url(dataset_id)
  dataset <- readr::read_csv(dataset.url) |>
    janitor::clean_names()
  attr(dataset, "date") <- Sys.Date()
  
  # Save to optional RDS cache
  if (!is.na(filename.rds)) {
    saveRDS(dataset, filename.rds)
  }
  return(dataset)
}

# Download GeoJSON geodata dataset from Data SF, optionally cache in GeoPackage
load.dataset.geojson <- function(dataset_id, filename.gpkg = NA) {
  # Check for local GeoPackage cache
  if (!is.na(filename.gpkg)) {
    if (file.exists(filename.gpkg)) {
      dataset.gpkg <- sf::st_read(filename.gpkg)
      attr(dataset.gpkg, "driver") <- sf::st_layers(filename.gpkg)$driver
      return (dataset.gpkg)
    }
  }
  
  # Download fresh GeoJSON geodata dataset
  dataset.url <- create.datasf.url(dataset_id, geodata = TRUE)
  dataset.geojson <- sf::st_read(dataset.url) |>
    janitor::clean_names()
  attr(dataset.geojson, "driver") <- sf::st_layers(dataset.url)$driver
  # TODO: Persist this date across gpkg store
  attr(dataset.geojson, "date") <- Sys.Date()
  
  # If Not saving to optional GeoPackage cache, leave early
  if (is.na(filename.gpkg)) {
    return(dataset.geojson)
  }
  # Save to local GeoPackage cache
  sf::st_write(dataset.geojson, dsn = filename.gpkg)
  
  # Speed improvement: read from local GeoPackage cache, faster than GeoJSON driver
  dataset.gpkg <- sf::st_read(filename.gpkg)
  attr(dataset.gpkg, "driver") <- sf::st_layers(filename.gpkg)$driver
  return (dataset.gpkg)
}
#End of datasf.R

# cultural.df <- load.dataset("5xmc-5bjj")
# https://data.sfgov.org/-/Arterial-Streets-of-San-Francisco/3wks-ifmi/about_data
streets <- load.dataset.geojson("3wks-ifmi")


# ── SQL Curriculum: plain data frame for sqldf ────────────────────────────────
# sqldf resolves table names from the calling environment; streets_df is the
# geometry-free data frame that the curriculum SQL queries reference.

streets_df <- sf::st_drop_geometry(streets)

# Detect column names so curriculum queries adapt to whatever DataSF returns
.detect_col <- function(haystack, candidates) {
  for (cand in candidates) {
    if (cand %in% haystack) return(cand)
  }
  haystack[1]   # fallback: first available column
}

.col <- tolower(names(streets_df))
.name_col   <- .detect_col(.col, c("streetname", "street_name", "fullstreetname", "name"))
.length_col <- .detect_col(.col, c("shape_leng", "shape__len", "shape_len", "length"))

# Build curriculum: 10 step-by-step SQL lessons about SF streets
sql_curriculum <- list(

  list(
    title     = "Welcome to SF Streets SQL! \U0001f6a7",
    narrative = paste0(
      "Hi! I'm Digger the Excavator! \U0001f69c  Let's explore San Francisco's streets ",
      "using SQL — Structured Query Language. The streets data is loaded into a table ",
      "called 'streets_df'. Run this query to take your first look!"
    ),
    sql = "SELECT * FROM streets_df LIMIT 5"
  ),

  list(
    title     = "How many street segments?",
    narrative = paste0(
      "There are thousands of records! Before showing them all (don't — it would be ",
      "overwhelming!), let's COUNT how many there are. COUNT(*) counts every row."
    ),
    sql = "SELECT COUNT(*) AS total_segments FROM streets_df"
  ),

  list(
    title     = "What columns do we have?",
    narrative = paste0(
      "Each row is one street segment. This query shows one complete row so you can ",
      "see every column available. With sqldf, the table name matches the R data ",
      "frame name — 'streets_df' — making it easy to jump between SQL and R!"
    ),
    sql = "SELECT * FROM streets_df LIMIT 1"
  ),

  list(
    title     = "Unique street names",
    narrative = paste0(
      "One street can have many segments. DISTINCT returns each name only once. ",
      "How many unique streets are in this arterial streets dataset?"
    ),
    sql = sprintf(
      "SELECT COUNT(DISTINCT %s) AS unique_streets\nFROM streets_df",
      .name_col
    )
  ),

  list(
    title     = "Street with the longest total length \U0001f3c6",
    narrative = paste0(
      "Which street stretches farthest across San Francisco? We GROUP BY street name, ",
      "SUM all segment lengths, convert feet to miles, then ORDER from longest to shortest."
    ),
    sql = sprintf(
      paste0(
        "SELECT %s,\n",
        "  ROUND(SUM(%s) / 5280.0, 2) AS total_miles\n",
        "FROM streets_df\n",
        "GROUP BY %s\n",
        "ORDER BY total_miles DESC\n",
        "LIMIT 10"
      ),
      .name_col, .length_col, .name_col
    )
  ),

  list(
    title     = "Longest street name \U0001f4cf",
    narrative = paste0(
      "Which street has the LONGEST NAME? The LENGTH() function counts the characters ",
      "in a text value. San Francisco has some creatively named streets!"
    ),
    sql = sprintf(
      paste0(
        "SELECT %s,\n",
        "  LENGTH(%s) AS name_length\n",
        "FROM streets_df\n",
        "ORDER BY name_length DESC\n",
        "LIMIT 10"
      ),
      .name_col, .name_col
    )
  ),

  list(
    title     = "Longest street segment (block) \U0001f5fa\ufe0f",
    narrative = paste0(
      "Each row is ONE segment — typically one block between two intersections. ",
      "Which single block is the longest in San Francisco? No GROUP BY needed — ",
      "we look at individual rows!"
    ),
    sql = sprintf(
      paste0(
        "SELECT %s,\n",
        "  ROUND(%s, 0) AS length_ft\n",
        "FROM streets_df\n",
        "ORDER BY %s DESC\n",
        "LIMIT 10"
      ),
      .name_col, .length_col, .length_col
    )
  ),

  list(
    title     = "\u26a0\ufe0f The Sausage Problem",
    narrative = paste0(
      "Watch out! Divided roads (boulevards with a raised median) have TWO centerlines ",
      "\u2014 one per direction. Their total length is counted TWICE! Some engineers call ",
      "these 'sausages'. Streets with unusually many segments may be divided roads."
    ),
    sql = sprintf(
      paste0(
        "SELECT %s,\n",
        "  COUNT(*) AS num_segments,\n",
        "  ROUND(SUM(%s) / 5280.0, 2) AS total_miles\n",
        "FROM streets_df\n",
        "GROUP BY %s\n",
        "HAVING num_segments > 20\n",
        "ORDER BY total_miles DESC\n",
        "LIMIT 15"
      ),
      .name_col, .length_col, .name_col
    )
  ),

  list(
    title     = "\U0001f50d The Missing Block",
    narrative = paste0(
      "This dataset covers only ARTERIAL streets. Mission Street should appear \u2014 ",
      "but the block BETWEEN 20TH and 21ST STREET is MISSING from this dataset! ",
      "Query Mission Street and see what you can discover."
    ),
    sql = sprintf(
      paste0(
        "SELECT %s,\n",
        "  COUNT(*) AS segments,\n",
        "  ROUND(SUM(%s) / 5280.0, 2) AS miles\n",
        "FROM streets_df\n",
        "WHERE UPPER(%s) LIKE '%%MISSION%%'\n",
        "GROUP BY %s"
      ),
      .name_col, .length_col, .name_col, .name_col
    )
  ),

  list(
    title     = "\U0001f389 You're a SQL Explorer!",
    narrative = paste0(
      "Congratulations! You've used SELECT, COUNT, SUM, GROUP BY, ORDER BY, HAVING, ",
      "and LIKE \u2014 and spotted real data quality issues. ",
      "Keep exploring by modifying the query below. The table is yours!"
    ),
    sql = sprintf(
      paste0(
        "SELECT %s,\n",
        "  COUNT(*) AS segments,\n",
        "  ROUND(SUM(%s) / 5280.0, 2) AS miles\n",
        "FROM streets_df\n",
        "GROUP BY %s\n",
        "ORDER BY miles DESC\n",
        "LIMIT 20"
      ),
      .name_col, .length_col, .name_col
    )
  )
)

.n_steps <- length(sql_curriculum)


server <- function(input, output, session) {  #errors line numbers start from here

  # ── Map tab ───────────────────────────────────────────────────────────────
  url <- a("DataSF Arterial Streets View",
           href = "https://data.sfgov.org/-/Arterial-Streets-of-San-Francisco/3wks-ifmi/about_data")
  output$tab <- renderUI({
    tagList("Source:", url)
  })
  output$map <- renderLeaflet({
    m <- mapview(streets, legend = FALSE)
    m@map
  })

  # ── SQL Curriculum ────────────────────────────────────────────────────────

  current_step <- reactiveVal(1)

  # Update SQL text area whenever the step changes
  observe({
    step <- current_step()
    updateTextAreaInput(session, "sql_input",
                        value = sql_curriculum[[step]]$sql)
  })

  # Step counter label
  output$step_counter <- renderText({
    paste("Step", current_step(), "of", .n_steps)
  })

  # Step title
  output$step_title <- renderText({
    sql_curriculum[[current_step()]]$title
  })

  # Narrative text (Digger speaks)
  output$step_narrative <- renderText({
    sql_curriculum[[current_step()]]$narrative
  })

  # Progress dots
  output$step_progress <- renderUI({
    step <- current_step()
    dots <- lapply(seq_len(.n_steps), function(i) {
      cls <- if (i == step) "step-dot active" else if (i < step) "step-dot completed" else "step-dot"
      tags$span(class = cls)
    })
    div(class = "step-progress", dots)
  })

  # Navigation buttons
  observeEvent(input$next_step, {
    step <- current_step()
    if (step < .n_steps) current_step(step + 1L)
  })

  observeEvent(input$prev_step, {
    step <- current_step()
    if (step > 1L) current_step(step - 1L)
  })

  # SQL execution results (stored reactively so they clear on step change)
  sql_results <- reactiveValues(data = NULL, error = NULL)

  # Clear results when the step changes
  observeEvent(current_step(), {
    sql_results$data  <- NULL
    sql_results$error <- NULL
  })

  # Run query when button is clicked
  observeEvent(input$run_sql, {
    sql <- trimws(input$sql_input)
    if (nchar(sql) == 0L) return()

    # Only allow read-only statement types
    if (!grepl("^(SELECT|WITH)\\b", toupper(sql))) {
      sql_results$data  <- NULL
      sql_results$error <- "Only SELECT / WITH queries are allowed in this curriculum."
      return()
    }

    # Block multi-statement injection (semicolons)
    if (grepl(";", sql, fixed = TRUE)) {
      sql_results$data  <- NULL
      sql_results$error <- "Multiple statements are not allowed. Please enter one query at a time."
      return()
    }

    tryCatch({
      # sqldf resolves 'streets_df' from the global environment
      res <- sqldf::sqldf(sql)
      # Cap to 1000 rows to avoid excessive memory use
      if (nrow(res) > 1000L) res <- res[seq_len(1000L), , drop = FALSE]
      sql_results$data  <- res
      sql_results$error <- NULL
    }, error = function(e) {
      sql_results$data  <- NULL
      sql_results$error <- conditionMessage(e)
    })
  })

  # Render results table
  output$sql_output <- renderTable({
    if (is.null(sql_results$data)) return(NULL)
    df <- sql_results$data
    if (nrow(df) == 0L) return(data.frame(Result = "(query returned no rows)"))
    df
  })

  # Render error message
  output$sql_error <- renderText({
    if (!is.null(sql_results$error)) paste("Error:", sql_results$error) else ""
  })

} #End of server

