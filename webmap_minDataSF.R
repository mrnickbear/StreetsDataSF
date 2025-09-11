# SO_question_addStarsImage14. saved as webmap_minDataSF.R

library(sf)
library(shiny)
# library(leafem)
library(leaflet)
library(mapview)

# streets <-  read_sf("K:\\sfbase\\arcview\\SFCity\\ACTIVESTREETS\\activestreets.shp")
# source("R:\\Modeling Work\\oracle_sql\\Ruby\\ScorecardExport\\sfrb.datasf\\R\\datasf.R")
source("datasf.R")


# cultural.df <- load.dataset("5xmc-5bjj")
streets_all <- load.dataset.geojson("3psu-pn9h")
streets <- filter(streets_all,  `%in%` (classcode, c(1,2,3,4)))

mapview(streets)


ui <- fluidPage(
  div(
    h4("Streets from DataSF")
    ),
  leafletOutput("map", width = 600, height = 800)
)

server <- function(input, output, session) {  #errors line numbers start from here
  
  output$map <- renderLeaflet({
    m <- mapview(streets, legend = FALSE) #, native.crs = TRUE) #project = FALSE) #%>%
    m@map
  })
} #End of server

options(shiny.port = 7772)
options(shiny.host = "0.0.0.0") #Replace with your server address  #use 0.0.0.0 for Shinyapps.io  

shinyApp(ui, server)
