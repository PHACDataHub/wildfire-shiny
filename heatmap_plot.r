library(sf)
library(maps)
library(dplyr)
library(leaflet)
library(leafgl)
library(rmapshaper)
library(mapview)
library(htmlwidgets)
library(httpuv)
library(shiny)
library(RColorBrewer)
library(ggplot2)

var1 <- "Residential_Instability_Quintiles"
var2 <- "Economic_Dependency_Quintiles"
var3 <- "Ethnocultural_Composition_Quintiles"
var4 <- "SituationalVulnerability_Quintiles"

var <- var3

##### READ IN FIRE DATA
fire <- st_read("C:\\Users\\LMCFADDE\\Documents\\python_test\\fdr_scribe.shp")

cities <- canada.cities[1:5]
city_points <- st_as_sf(cities, coords = c("long", "lat"), crs = 4326)

city_points <- st_transform(city_points, crs = st_crs(fire))

cities <- st_join(city_points, fire)
fire <- st_transform(fire, crs = '+proj=longlat +datum=WGS84')

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

color_palette <- colorFactor(
    palette = c("blue", "green", "yellow", "orange", "red"),
    domain = fire$GRIDCODE
)

#### READ IN VULNERBILITY DATA
file_name = "C:\\Users\\LMCFADDE\\Documents\\python_test\\VULNERBILITY_DA_2021.gdb.zip"

layers <- st_layers(dsn=file_name)

canq <- st_read(file_name, layer="CAN_SCORES_QUNTILE_DA_2021")

vindx <- st_read(file_name, layer="VUN_INDEX_EN_DA_2021")

# using all data here
subset_data <- vindx
subset_data <- st_cast(subset_data, "POLYGON")


subset_data <- st_transform(subset_data, crs=st_crs("+proj=longlat +datumWGS84"))

#### DATA PROCESSING

filtered_data <- subset_data
# filtered_data <- subset_data[subset_data$Ethnocultural_Composition_Quintiles >= 4,]
filtered_fire <- fire#[fire$GRIDCODE >= 1,]

filtered_fire$GRIDCODE <- filtered_fire$GRIDCODE + 1

# make all fire locations larger by tolerance
# this makes the small regions in the cities connect together
tol <- 10000 # meters
filtered_fire <- st_make_valid(filtered_fire)
filtered_fire <- st_buffer(filtered_fire, dist=tol)

# join together connected polygons and simplify
# filtered_fire <- st_union(filtered_fire)
filtered_fire <- filtered_fire %>%
            group_by(GRIDCODE) %>%
            summarize(geometry=st_union(geometry), .groups="drop")
filtered_fire <- st_sf(filtered_fire, drop=FALSE)
filtered_fire <- st_make_valid(filtered_fire)
filtered_fire <- st_simplify(filtered_fire, dTolerance = 100)

filtered_data <- st_make_valid(filtered_data)
# 10 seems to be accurate, 100 looks a bit less accurate for smaller sections
filtered_data <- st_simplify(filtered_data, dTolerance = 100)

# Find places where both polygons are
combined_data <- st_intersects(filtered_data, filtered_fire)
mask <- sapply(combined_data, length) > 0
filtered_data <- filtered_data[mask, ]

### JOIN
filtered_data <- st_cast(filtered_data, "POLYGON")
filtered_fire <- st_cast(filtered_fire, "POLYGON")


joined <- st_join(filtered_data, filtered_fire, join=st_intersects)


joined$danger_scale <- joined[[var]] + joined$GRIDCODE


test_data <- data.frame(
  x=rep(1:5, 5),
  y=rep(1:5, each=5),
)
test_data$z <- test_data$x + test_data$y
test_data$z <- factor(test_data$z)

generate_map <- function(data, column) {

  # 1 is least deprived, 5 is most deprived

  color_palette <- colorFactor(
      palette = "Reds",
      domain = data$danger_scale)

  fire_palette <- colorFactor(
      palette = "Blues",
      domain = data$GRIDCODE)

  data <- data[data$danger_scale >= 6,]
  data <- data[data[[column]] >= 2,]
  data <- data[data$GRIDCODE >= 2,]

  data[is.na(data)] <- 0

  leaflet_data <- leaflet(data=data, options=leafletOptions(preferCanvas=TRUE)) %>%
                  addProviderTiles("OpenStreetMap.Mapnik", options=providerTileOptions(updateWhenZooming=FALSE, updateWhenIdle = TRUE)) %>%
                  addPolygons(data=data, fillColor=rgb(data[[column]]/5, 0, data$GRIDCODE/5),
                  fillOpacity=0.7,
                  color="white",
                  weight=1)
                  
  return (leaflet_data)
}

start_time <- Sys.time()

map <- generate_map(joined, var)
map


ggplot(test_data, aes(x=x, y=y, fill=rgb(x/5, 0, y/5))) +
  geom_tile(color="white") +
  scale_fill_identity() +
  theme_minimal() +
  labs(x=var, y="Smoke Level (Placeholder)")

end_time <- Sys.time()
time_taken <- end_time - start_time
time_taken