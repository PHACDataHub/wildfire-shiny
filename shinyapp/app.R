library(shiny)
library(shinyWidgets)
library(shinythemes)
library(tidyverse)
library(shinyjs)
library(sf)
library(data.table)
library(fresh)
library(sf)
library(maps)
library(leaflet)
library(DT)
library(leafgl)
library(rmapshaper)
library(mapview)
library(httpuv)
library(htmlwidgets)

#setup app reload
jscode <- "shinyjs.reload = function() { location.reload(); }"

js <- HTML("
           function doReload(tab_index) {
              let loc = window.location;
              let params = new URLSearchParams(loc.search);
              params.set('tab_index', tab_index);
              loc.replace(loc.origin + loc.pathname + '?' + params.toString());
           }")


# Read in pre-processed data
filtered_data <- read_rds("./data/filtered_data.shp")
filtered_fire <- read_rds("./data/filtered_fire.shp")


### Plotting function

generate_map <- function(data, risk_data, column, filter=4) {
  # 1 is least deprived, 5 is most deprived
  color_palette <- colorFactor(
    palette = c("blue", "green", "yellow", "orange", "red"),
    domain = data[[column]])

  data <- data[data[[column]] >= filter,]

  leaflet_data <- leaflet(data=data, options=leafletOptions(preferCanvas=TRUE)) %>%
    addProviderTiles("OpenStreetMap.Mapnik", options=providerTileOptions(updateWhenZooming=FALSE, updateWhenIdle = TRUE)) %>%
    addPolygons(
      data = risk_data,
      fillOpacity = 0.7,
      color="black",
      weight=1,
      label="Smoke (placeholder)"
    )%>%
    addPolygons(data=data, fillColor=~color_palette(data[[column]]),
                fillOpacity=0.7,
                color="white",
                weight=1) %>%
    addLegend(position="bottomright",
              values=~data[[column]],
              title=column,
              colors = c("black", "blue", "green", "yellow", "orange", "red"),
              labels=c("Smoke (placeholder)", 
                       "1 - Least Deprived", "2", "3", "4", "5 - Most Deprived"))
}

var1 <- "Residential_Instability_Quintiles"
var2 <- "Economic_Dependency_Quintiles"
var3 <- "Ethnocultural_Composition_Quintiles"
var4 <- "SituationalVulnerability_Quintiles"





#-------------------------------------------------------------------------------
# UI
#-------------------------------------------------------------------------------

# User interface
ui <- fluidPage(
  tags$head(tags$script(js, type ="text/javascript")),
  
  useShinyjs(),
  extendShinyjs(text = jscode, functions = "reload"),
  #theme = shinytheme("sandstone"), titlePanel(" "),    
  
  #format error messages in bold red font
  tags$head(
    tags$style(HTML("
      .shiny-output-error-validation {
        color: #ff0000;
        font-weight: bold;
      }
    "))
  ),
  useShinyjs(),
  tags$head(
    tags$style(HTML("hr {border-top: 1px solid #000000;}"))
  ),
  
  tags$head(tags$link(rel = "stylesheet", type = "text/css", 
                      href = "https://www150.statcan.gc.ca/wet-boew4b/css/theme.min.css")),
  tags$head(tags$link(rel = "stylesheet", type = "text/css", 
                      href = "https://infobase-dev.com/src/css/global.css")),	
  
  tabsetPanel(
    id = "alltabpanel",
    tabPanel("Maps", 
             br(),
             tabsetPanel(   
               tabPanel("Map 1", 
                        hr(),
                        useShinyjs(),
                        div(
                          id="formthreshold",
                          
                          # br(),
                          # hr(),
                          
                          fluidRow(
                            column(4, pickerInput(inputId = "vulnerability_type", 
                                                  "Vulnerability type", 
                                                  choices = c(var1, var2, var3, var4))),
                            column(4, pickerInput(inputId = "deprivation_level", 
                                                  "Level of deprivation (Cumulative)", 
                                                  choices = c(1,2,3,4,5), 
                                                  selected = 4)),
                            column(4, pickerInput(inputId = "filter3", 
                                                  "Filter 3", 
                                                  choices = c("Choice 1", "Choice 2", "Choice 3")))
                          ),
                          
                          br(),
                          
                          fluidRow(
                            column(width = 12, leafletOutput("plot_leaf"))
                          )
                          
                          # hr(),

                          ),#div
               ),
               
               tabPanel("Map 2")
             )
             
    ),
    
    tabPanel("Tables", 
             br(),
             tabsetPanel(   
               tabPanel("Table 1"),
               tabPanel("Table 2")
             )
    )
  )
)



#-------------------------------------------------------------------------------
# SERVER
#-------------------------------------------------------------------------------

# Server
server <- function(input, output, session)   {
  
  
  ## MAP ##
  
  
  output$plot_leaf <- renderLeaflet({
    
    generate_map(filtered_data, filtered_fire, input$vulnerability_type, input$deprivation_level)
    
  })
  
  
  
}

# Run the application
shinyApp(ui = ui,server = server)