library(shiny)
library(leaflet)
library(mapview)

ui <- fluidPage(
  div(
    h4("SQL Example GithubCloudConnect2: Arterial Streets from DataSF"),
    uiOutput("tab")
  ),
  leafletOutput("map", width = 600, height = 800)
)