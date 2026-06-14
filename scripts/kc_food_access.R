# =============================================================================
# Kansas City Food Access & Neighborhood Analysis
# Author: Matthew Ong
# Data sources:
#   - U.S. Census Bureau, American Community Survey 5-Year Estimates (2019)
#   - USDA Economic Research Service, Food Access Research Atlas (2019)
#   - USDA Food and Nutrition Service, SNAP Retailer Locator
#   - Kansas City Area Transportation Authority (KCATA), GTFS Feed (2026)
#
# Note: 2019 ACS data used for two reasons:
#   1. Consistent with 2010 tract boundaries used by USDA Food Access Atlas
#   2. Avoids COVID-related disruptions present in 2020-2022 ACS estimates
#
# AMI threshold: $82,700 (Kansas City MSA, 2019, HUD)
#   60% AMI = $49,620 — federal LIHTC eligibility threshold
# =============================================================================

# 1. Load Libraries

library(tidycensus)
library(tidyverse)
library(sf)
library(lubridate)
library(readr)


# 2. Census API Key
# Only run census_api_key() once to install permanently.
# Keys are freely available: https://api.census.gov/data/key_signup.html

# census_api_key("Key", install = TRUE)

# 3. Pull Census Data (ACS 2019, Jackson County, MO)

kc_tracts <- get_acs(
  geography = "tract",
  variables = c(
    pop        = "B01003_001",
    income     = "B19013_001", 
    rent       = "B25064_001",  
    home_value = "B25077_001",   
    vacant_units = "B25002_003", 
    total_units  = "B25002_001" 
  ),
  state    = "MO",
  county   = "Jackson",
  geometry = TRUE,
  output   = "wide",
  year     = 2019
)
kc_tracts <- kc_tracts %>%
  select(-ends_with("_M")) %>%
  rename(
    pop          = pop_E,
    income       = income_E,
    rent         = rent_E,
    home_value   = home_value_E,
    vacant_units = vacant_units_E,
    total_units  = total_units_E
  )

# 4. Derive Housing Variables

kc_tracts <- kc_tracts %>%
  mutate(
    vacancy_rate = round(vacant_units / total_units, 4)
  ) %>%
  select(-vacant_units, -total_units)

# 5. AMI Thresholds

ami_2019 <- 82700

kc_tracts <- kc_tracts %>%
  mutate(
    ami_60       = ami_2019 * 0.60,        # $49,620 — LIHTC eligibility ceiling
    below_60_ami = as.integer(income < ami_60)
  )


# 6. Drop Tracts with Missing Income

kc_tracts <- kc_tracts %>%
  filter(!is.na(income))


# 7. USDA Food Access Research Atlas

food_atlas <- read_csv("FoodAccessAtlas2019.csv")

food_atlas_slim <- food_atlas %>%
  select(
    CensusTract,
    PovertyRate,
    LILATracts_1And10,  # Low income & low access flag (1-mile urban threshold)
    LATracts_half,      # Low access tracts at 1/2 mile
    TractHUNV,          # Households with no vehicle
    TractSNAP           # SNAP participants
  )

# join
kc_tracts <- kc_tracts %>%
  inner_join(food_atlas_slim, by = c("GEOID" = "CensusTract"))


# 8. Derive percent variables

kc_tracts <- kc_tracts %>%
  mutate(
    snap_pct = round(TractSNAP / pop, 4),  # Share of population on SNAP
    hunv_pct = round(TractHUNV / pop, 4)   # Share of households with no vehicle
  )


# 9. Export Census / Food Access Data

st_write(kc_tracts, "kc_tracts.geojson", delete_dsn = TRUE)

kc_tracts %>%
  st_drop_geometry() %>%
  write_csv("kc_tracts.csv")


# 10. SNAP Retailer Data — Grocery Store Locations

snap_retailers <- read_csv("SNAP_Retailer_Data.csv")

snap_kc <- snap_retailers %>%
  filter(
    State  == "MO",
    County == "JACKSON"
  )

# keep only active for 2019
snap_kc <- snap_kc %>%
  mutate(end_date = mdy(EndDate)) %>%
  filter(is.na(end_date) | end_date >= as.Date("2019-01-01"))

# Excludes convenience stores, pharmacies, dollar stores
snap_kc <- snap_kc %>%
  filter(StoreType %in% c(
    "Supermarket",
    "Large Grocery Store",
    "Medium Grocery Store",
    "Small Grocery Store",
    "Farmers' Market"
  ))

# Remove duplicate store records
snap_kc <- snap_kc %>%
  distinct(RecordID, .keep_all = TRUE)

# Convert to spatial points using USDA-provided coordinates
snap_sf <- snap_kc %>%
  filter(!is.na(Longitude) & !is.na(Latitude)) %>%
  select(StoreName, StoreType, Longitude, Latitude) %>%
  st_as_sf(coords = c("Longitude", "Latitude"), crs = 4326)

st_write(snap_sf, "snap_grocery_stores.geojson", delete_dsn = TRUE)


# 11. KCATA Transit Data — Bus Stops and Routes -- spatial for QGIS

stops  <- read_csv("kc_transit/stops.txt")
shapes <- read_csv("kc_transit/shapes.txt")

stops_sf <- stops %>%
  st_as_sf(coords = c("stop_lon", "stop_lat"), crs = 4326)

routes_sf <- shapes %>%
  arrange(shape_id, shape_pt_sequence) %>%
  group_by(shape_id) %>%
  summarize(
    geometry = st_linestring(cbind(shape_pt_lon, shape_pt_lat)) %>% st_sfc()
  ) %>%
  st_as_sf(crs = 4326)

# export
st_write(stops_sf,  "kcata_stops.geojson",  delete_dsn = TRUE)
st_write(routes_sf, "kcata_routes.geojson", delete_dsn = TRUE)
