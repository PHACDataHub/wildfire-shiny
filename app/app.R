library(shiny)
library(shinydashboard)
library(shiny.i18n)
library(sf)
library(maps)
library(dplyr)
library(leaflet)
library(DT)
library(leafgl)



### PREP ###


# Load the data files
fire <- st_read("./data/fdr_scribe.shp")
cities <- canada.cities[1:5]


# Transform data to get fire risk level for each city
city_points <- st_as_sf(cities, coords = c("long", "lat"), crs = 4326)

city_points <- st_transform(city_points, crs = st_crs(fire))

cities <- st_join(city_points, fire)


# Remove province codes from city names
cities$name <- substr(cities$name, 1, nchar(cities$name) - 3)


# Transform GRIDCODE into fire danger level labels
code_labels_en <- case_when(
  is.na(cities$GRIDCODE) ~ "NA",
  cities$GRIDCODE == 0 ~ "low",
  cities$GRIDCODE == 1 ~ "moderate",
  cities$GRIDCODE == 2 ~ "high",
  cities$GRIDCODE == 3 ~ "very high",
  cities$GRIDCODE == 4 ~ "extreme",
  TRUE ~ "unknown"
)

code_labels_fr <- case_when(
  is.na(cities$GRIDCODE) ~ "NA",
  cities$GRIDCODE == 0 ~ "faible",
  cities$GRIDCODE == 1 ~ "modéré",
  cities$GRIDCODE == 2 ~ "élevé",
  cities$GRIDCODE == 3 ~ "très élevé",
  cities$GRIDCODE == 4 ~ "extrême",
  TRUE ~ "inconnu"
)

cities <- cities %>%
  mutate(danger_level = code_labels_en) %>%
  mutate(danger_level_fr = code_labels_fr) %>%
  rename(pt = country.etc)


# Create cities table for display
cities_table <- cities %>%
  as.data.frame() %>%
  dplyr::select(name, pt, pop, danger_level, danger_level_fr)


# Change fire risk data's crs
fire <- st_transform(fire, crs = '+proj=longlat +datum=WGS84')


# Point to a translation file
i18n <- Translator$new(translation_json_path = "translation.json")
i18n$set_translation_language("English")
i18n$use_js()



### APP ###


ui <- dashboardPage(
  dashboardHeader(title = i18n$t("Fire Risk")),
  
  dashboardSidebar(sidebarMenu(
    menuItem(
      i18n$t("Language"),
      icon = icon("language"),
      shiny.i18n::usei18n(i18n),
      selectInput(
        'selected_language',
        i18n$t("Select language"),
        choices = i18n$get_languages(),
        selected = i18n$get_key_translation()
      )
    ),
    menuItem(
      i18n$t("Fire Risk"),
      tabName = "fire_risk",
      icon = icon("fire")
    )
  )),
  
  dashboardBody(fluidRow(
    box(
      title = i18n$t("Filters"),
      status = "primary",
      solidHeader = TRUE,
      width = 3,
      
      checkboxGroupInput(
        "danger_checkbox",
        i18n$t("Select fire danger level"),
        choices = c("low", "moderate", "high", "very high", "extreme"),
        selected = "extreme"
      ),
      
      sliderInput(
        inputId = "n_cities",
        label = i18n$t("Select number of cities at risk (by population)"),
        min = 1,
        max = cities %>%
          filter(GRIDCODE == 4) %>%
          nrow(),
        value = 10,
        step = 1
      )
    ),
    
    column(width = 9,
           fluidRow(
             column(width = 12, leafletOutput("plot_leaf")),
             column(width = 12, dataTableOutput("table_city"))
           ))
  ))
)

server <- function(input, output, session) {
  
  # Update language in session
  observeEvent(input$selected_language, {
    shiny.i18n::update_lang(input$selected_language, session)
  })
  
  # Filter cities based on user selection
  cities_filtered <- reactive({
    cities[cities$danger_level %in% input$danger_checkbox,]
  })
  
  # Update slider
  observeEvent(input$danger_checkbox, {
    updateSliderInput(session, "n_cities", max = nrow(cities_filtered()))
  })
  
  # Update checkbox
  observe({
    if (input$selected_language == "Français") {
      updateCheckboxGroupInput(
        session,
        "danger_checkbox",
        choices = c(
          "faible" = "low",
          "modéré" = "moderate",
          "élevé" =  "high",
          "très élevé" = "very high",
          "extrême" = "extreme"
        ),
        selected = "extreme"
      )
    } else {
      updateCheckboxGroupInput(
        session,
        "danger_checkbox",
        choices = c(
          "low" = "low",
          "moderate" = "moderate",
          "high" = "high",
          "very high" = "very high",
          "extreme" = "extreme"
        ),
        selected = "extreme"
      )
    }
  })
  
  
  ## MAP ##
  
  
  output$plot_leaf <- renderLeaflet({
    
    color_palette <- colorFactor(
      palette = c("blue", "green", "yellow", "orange", "red"),
      domain = fire$GRIDCODE
    )
    
    leaflet() %>%
      setView(lng = -95.0,
              lat = 60.0,
              zoom = 3) %>%
      addProviderTiles(providers$CartoDB.Positron) %>%
      addGlPolygons(
        data = fire,
        fillColor = ~ color_palette(GRIDCODE),
        fillOpacity = 0.7
      ) %>%
      addLegend(
        "bottomright",
        title = i18n$t("Fire danger"),
        colors = c("blue", "green", "yellow", "orange", "red"),
        labels = c(
          i18n$t("low"),
          i18n$t("moderate"),
          i18n$t("high"),
          i18n$t("very high"),
          i18n$t("extreme")
        ),
        opacity = 0.7
      )
  })
  
  
  # Update circles based on filter selection
  
  observe({
    top_cities <- cities_filtered() %>%
      st_as_sf() %>%
      arrange(desc(pop)) %>%
      top_n(input$n_cities, wt = pop) %>%
      st_transform(crs = '+proj=longlat +datum=WGS84')
    
    leafletProxy("plot_leaf") %>%
      clearGroup("cities_group") %>%
      addCircles(
        data = top_cities,
        color = "black",
        group = "cities_group",
        weight = 5,
        radius = 1000,
        fillOpacity = 0.7,
        label = ~ paste0(name),
        labelOptions = labelOptions(
          style = list(padding = "3px 8px"),
          textsize = "14px", 
          distance = 50
        )
      )
  })
  
  
  ## TABLE ##
  
  
  observe({
    if (input$selected_language == "English") {
      output$table_city <- renderDataTable({
        datatable(
          data = cities_table[1:4],
          options = list(
            order = list(list(4, 'desc'), list(3, 'desc')),
            columnDefs = list(
              list(targets = 0, visible = FALSE),
              list(targets = 1, title = i18n$t("City")),
              list(
                targets = 2,
                title = i18n$t("Province/territory")
              ),
              list(
                targets = 3,
                title = i18n$t("Population")
              ),
              list(
                targets = 4,
                title = i18n$t("Fire danger level")
              )
            ),
            scrollX = TRUE
          )
        )
      })
    } else {
      output$table_city <- renderDataTable({
        datatable(
          data = cities_table[, c(1:3, 5)],
          options = list(
            order = list(list(4, 'desc'), list(3, 'desc')),
            columnDefs = list(
              list(targets = 0, visible = FALSE),
              list(targets = 1, title = i18n$t("City")),
              list(
                targets = 2,
                title = i18n$t("Province/territory")
              ),
              list(
                targets = 3,
                title = i18n$t("Population")
              ),
              list(
                targets = 4,
                title = i18n$t("Fire danger level")
              )
            ),
            scrollX = TRUE,
            language = list(url = 'https://cdn.datatables.net/plug-ins/1.10.11/i18n/French.json')
          )
        )
      })
    }
  })
  
  
  
  
}

shinyApp(ui, server)