library(sf)
library(maps)
library(tidyverse)
library(leaflet)
library(leafgl)
library(rmapshaper)
library(mapview)
library(htmlwidgets)
library(httpuv)

#-------------------------------------------------------------------------------
# READ IN FIRE DATA
#-------------------------------------------------------------------------------

# Load the data files
fire <- st_read("./data/fdr_scribe.shp")

# Change fire risk data's crs
fire <- st_transform(fire, crs = '+proj=longlat +datum=WGS84')


#-------------------------------------------------------------------------------
# READ IN VULNERBILITY DATA
#-------------------------------------------------------------------------------

file_name = "./data/VULNERBILITY_DA_2021.gdb.zip"

layers <- st_layers(dsn=file_name)

canq <- st_read(file_name, layer="CAN_SCORES_QUNTILE_DA_2021")

vindx <- st_read(file_name, layer="VUN_INDEX_EN_DA_2021")

# using all data here
subset_data <- vindx

subset_data <- st_cast(subset_data, "POLYGON")

subset_data <- st_transform(subset_data, crs=st_crs("+proj=longlat +datumWGS84"))


#-------------------------------------------------------------------------------
# DATA PROCESSING
#-------------------------------------------------------------------------------

filtered_data <- subset_data
# filtered_data <- subset_data[subset_data$Ethnocultural_Composition_Quintiles >= 4,]
filtered_fire <- fire[fire$GRIDCODE >= 4,]

# make all fire locations larger by tolerance
# this makes the small regions in the cities connect together
tol <- 10000 # meters
filtered_fire <- st_make_valid(filtered_fire)
filtered_fire <- st_buffer(filtered_fire, dist=tol)

# join together connected polygons and simplify
filtered_fire <- st_union(filtered_fire)
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

write_rds(filtered_data, "./data/filtered_data.shp")
write_rds(filtered_fire, "./data/filtered_fire.shp")