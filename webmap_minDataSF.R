# SO_question_addStarsImage14. saved as webmap_minDataSF.R

library(rsconnect)
library(sf)
library(shiny)
# library(leafem)
library(leaflet)
library(mapview)

# streets <-  read_sf("K:\\sfbase\\arcview\\SFCity\\ACTIVESTREETS\\activestreets.shp")
# source("R:\\Modeling Work\\oracle_sql\\Ruby\\ScorecardExport\\sfrb.datasf\\R\\datasf.R")
source("datasf.R")


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
    h4("SQL Example: Arterial Streets from DataSF"),
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
