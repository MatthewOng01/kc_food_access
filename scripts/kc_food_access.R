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


# -----------------------------------------------------------------------------
# 1. Load Libraries
# -----------------------------------------------------------------------------

library(tidycensus)
library(tidyverse)
library(sf)
library(lubridate)
library(readr)


# -----------------------------------------------------------------------------
# 2. Census API Key
# Note: Run census_api_key() once to install permanently.
# Register for a free key at: https://api.census.gov/data/key_signup.html
# -----------------------------------------------------------------------------

# census_api_key("YOUR_KEY_HERE", install = TRUE)


# -----------------------------------------------------------------------------
# 3. Pull Census Data (ACS 2019, Jackson County, MO)
# -----------------------------------------------------------------------------

kc_tracts <- get_acs(
  geography = "tract",
  variables = c(
    pop        = "B01003_001",   # Total population
    income     = "B19013_001",   # Median household income
    rent       = "B25064_001",   # Median gross rent
    home_value = "B25077_001",   # Median home value (owner-occupied)
    vacant_units = "B25002_003", # Vacant housing units
    total_units  = "B25002_001"  # Total housing units
  ),
  state    = "MO",
  county   = "Jackson",
  geometry = TRUE,
  output   = "wide",
  year     = 2019
)

# Drop margin of error columns, rename estimate columns
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


# -----------------------------------------------------------------------------
# 4. Derive Housing Variables
# -----------------------------------------------------------------------------

kc_tracts <- kc_tracts %>%
  mutate(
    vacancy_rate = round(vacant_units / total_units, 4)
  ) %>%
  select(-vacant_units, -total_units)


# -----------------------------------------------------------------------------
# 5. AMI Thresholds
# Note: Using flat area-wide AMI; HUD publishes household-size-adjusted
# figures for more precise analysis.
# -----------------------------------------------------------------------------

ami_2019 <- 82700

kc_tracts <- kc_tracts %>%
  mutate(
    ami_60       = ami_2019 * 0.60,        # $49,620 — LIHTC eligibility ceiling
    below_60_ami = as.integer(income < ami_60)
  )


# -----------------------------------------------------------------------------
# 6. Drop Tracts with Missing Income
# These are typically non-residential tracts (parks, stadiums) with
# insufficient population for Census estimates.
# -----------------------------------------------------------------------------

kc_tracts <- kc_tracts %>%
  filter(!is.na(income))


# -----------------------------------------------------------------------------
# 7. USDA Food Access Research Atlas
# Source: https://www.ers.usda.gov/data-products/food-access-research-atlas/
# Note: Atlas uses 2010 Census tract boundaries, consistent with 2019 ACS.
# lapop10share excluded — USDA uses 1-mile threshold for urban tracts;
# 10-mile threshold applies to rural areas only and is null for KC tracts.
# -----------------------------------------------------------------------------

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

# Inner join — keeps only Jackson County tracts matched in both datasets
kc_tracts <- kc_tracts %>%
  inner_join(food_atlas_slim, by = c("GEOID" = "CensusTract"))


# -----------------------------------------------------------------------------
# 8. Derive SNAP and No-Vehicle Rate Variables
# -----------------------------------------------------------------------------

kc_tracts <- kc_tracts %>%
  mutate(
    snap_pct = round(TractSNAP / pop, 4),  # Share of population on SNAP
    hunv_pct = round(TractHUNV / pop, 4)   # Share of households with no vehicle
  )


# -----------------------------------------------------------------------------
# 9. Export Census / Food Access Data
# -----------------------------------------------------------------------------

st_write(kc_tracts, "kc_tracts.geojson", delete_dsn = TRUE)

kc_tracts %>%
  st_drop_geometry() %>%
  write_csv("kc_tracts.csv")


# -----------------------------------------------------------------------------
# 10. SNAP Retailer Data — Grocery Store Locations
# Source: USDA FNS SNAP Retailer Locator
# https://www.fns.usda.gov/snap/retailer-locator
# Filtered to stores active as of January 1, 2019 to match ACS vintage.
# Blank EndDate = store currently active.
# -----------------------------------------------------------------------------

snap_retailers <- read_csv("SNAP_Retailer_Data.csv")

snap_kc <- snap_retailers %>%
  filter(
    State  == "MO",
    County == "JACKSON"
  )

# Retain stores active during study period
# Blank EndDate indicates currently active; parse as NA and retain
snap_kc <- snap_kc %>%
  mutate(end_date = mdy(EndDate)) %>%
  filter(is.na(end_date) | end_date >= as.Date("2019-01-01"))

# Keep only full-service grocery store types
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


# -----------------------------------------------------------------------------
# 11. KCATA Transit Data — Bus Stops and Routes
# Source: Kansas City Area Transportation Authority GTFS Feed (2026)
# Note: 2026 GTFS feed used for route/stop geometry; transit network
# structure is consistent with study period for spatial analysis purposes.
# GTFS files sourced from: https://www.kcata.org
# -----------------------------------------------------------------------------

stops  <- read_csv("kc_transit/stops.txt")
shapes <- read_csv("kc_transit/shapes.txt")

# Bus stops as point layer
stops_sf <- stops %>%
  st_as_sf(coords = c("stop_lon", "stop_lat"), crs = 4326)

# Bus routes as line layer
# shapes.txt stores routes as ordered point sequences — convert to linestrings
routes_sf <- shapes %>%
  arrange(shape_id, shape_pt_sequence) %>%
  group_by(shape_id) %>%
  summarize(
    geometry = st_linestring(cbind(shape_pt_lon, shape_pt_lat)) %>% st_sfc()
  ) %>%
  st_as_sf(crs = 4326)

st_write(stops_sf,  "kcata_stops.geojson",  delete_dsn = TRUE)
st_write(routes_sf, "kcata_routes.geojson", delete_dsn = TRUE)
