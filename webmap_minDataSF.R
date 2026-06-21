# SO_question_addStarsImage14. saved as webmap_minDataSF.R

library(rsconnect)
library(sf)
library(shiny)
# library(leafem)
library(leaflet)
library(mapview)

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


#Was using https://data.sfgov.org/Geographic-Locations-and-Boundaries/Streets-Active-and-Retired/3psu-pn9h/about_data
#Active and Retired was too large for default shinyapps.io upload
#Also caused intermittent error:  Error in data.matrix(data) 'list' object cannot be coerced to type 'double'
# options(shiny.maxRequestSize = 25000000) #25,000,000 bytes > 18.2 Mb
# > format(object.size(streets_all), units = "MB")
# [1] "18.2 Mb"
# streets <- filter(streets_all,  `%in%` (classcode, c(1,2,3,4)))

mapview(streets)


ui <- fluidPage(
  div(
    h4("SQL Example GithubCloudConnect: Arterial Streets from DataSF"),
    uiOutput("tab")
  ),
  leafletOutput("map", width = 600, height = 800)
)

server <- function(input, output, session) {  #errors line numbers start from here
  
  url <- a("DataSF Arterial Streets View", href="https://data.sfgov.org/-/Arterial-Streets-of-San-Francisco/3wks-ifmi/about_data")
  output$tab <- renderUI({
    tagList("Source:", url)
  })
  output$map <- renderLeaflet({
    m <- mapview(streets, legend = FALSE) #, native.crs = TRUE) #project = FALSE) #%>%
    m@map
  })
} #End of server

options(shiny.port = 7772)
options(shiny.host = "0.0.0.0") #Replace with your server address  #use 0.0.0.0 for Shinyapps.io  

shinyApp(ui, server)
