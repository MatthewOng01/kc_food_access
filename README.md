# Kansas City Food Access & Neighborhood Conditions

**[Live Map →](https://matthewong01.github.io/kc-food-access-map)**
**[Map Repository →](https://github.com/MatthewOng01/kc-food-access-map)**
**[Portfolio →](https://MatthewOng01.github.io)**

An interactive GIS analysis of food access, housing conditions, and neighborhood economic characteristics across Census tracts in Jackson County, Missouri. Built as part of a broader research interest in urban amenity gaps and their relationship to real estate market conditions in Kansas City.

---

## Overview

This project combines data from the U.S. Census Bureau, USDA Economic Research Service, USDA Food and Nutrition Service, and Kansas City Area Transportation Authority (KCATA) to map food access conditions at the Census tract level across Jackson County, MO.

The central analytical question is whether food access gaps cluster spatially with low-income tracts, high SNAP utilization, and low transit access — and what that pattern implies for neighborhood trajectory and real estate development feasibility.

Troost Avenue, historically Kansas City's racial and economic dividing line, serves as a geographic reference throughout the analysis. The east-west pattern visible in the data reflects decades of disinvestment that continue to shape neighborhood conditions today.

---

## Methodology Notes

**Why 2019 ACS data?**
The 2015–2019 ACS 5-Year Estimates use 2010 Census tract boundaries, which are consistent with the USDA Food Access Research Atlas (2019). Using a more recent ACS vintage would require crosswalking between 2010 and 2020 tract boundaries — a technically valid but complex operation that introduces interpolation error. The 2019 vintage also avoids COVID-related disruptions present in 2020–2022 ACS estimates.

**Geographic scope**
Analysis is limited to Jackson County, MO. The Kansas City MSA spans multiple counties across Missouri and Kansas; Jackson County captures the urban core of KCMO including the neighborhoods most relevant to the food access question. Rural fringe tracts in the eastern portion of the county (Lee's Summit, Grain Valley) are included in the dataset but behave differently from urban tracts and should be interpreted with that in mind.

**AMI threshold**
The 60% Area Median Income threshold ($49,620) uses the HUD FY2019 Kansas City MSA figure as a flat area-wide number. HUD publishes household-size-adjusted AMI figures for more precise affordability analysis; the flat threshold used here is a simplification noted accordingly. 60% AMI is the standard affordability benchmark in affordable housing finance and the federal LIHTC (Low Income Housing Tax Credit) eligibility ceiling.

**Food access thresholds**
The USDA Food Access Research Atlas uses a 1-mile distance threshold for urban tracts and a 10-mile threshold for rural tracts. The 10-mile variable (`lapop10share`) is null for all Jackson County tracts because urban tracts are evaluated at the 1-mile threshold only. Distance rings (0.5 mile and 1 mile) are constructed from SNAP-authorized grocery store locations rather than USDA-calculated distances.

**SNAP Grocery Store Locations**
USDA provides a dataset of all retail locations that accept SNAP, found in `SNAP_Retailer_Data.csv.zip`. This dataset was filtered to only include Jackson County. Furthermore, only grocery stores, farmer markets, bakeries, and butcher shops were included for final analysis. This removes convenience stores and gas stations. 

**Transit data vintage**
The KCATA GTFS feed used for bus routes and stops is from April 2026. A 2019-vintage feed was not available. Transit network structure is used here as a contextual spatial layer rather than a modeled variable; the 2026 feed is considered sufficiently representative for this purpose.

---

## Repository Structure

```
kc_food_access/
├── data/
│   ├── clean_data/
│   │   └── kc_tracts.csv          # Final analysis dataset
│   └── raw_data/
│       ├── FoodAccessAtlas2019.csv.zip
│       ├── SNAP_Retailer_Data.csv.zip
│       ├── routes.txt             # KCATA GTFS
│       ├── stops.txt              # KCATA GTFS
│       └── data.md                # Data source documentation
├── gis/
│   ├── kc_tracts.geojson          # Census tracts with all variables
│   ├── snap_grocery_stores.geojson
│   ├── buffer_half_mile.geojson   # 0.5 mile grocery store rings
│   ├── buffer_one_mile.geojson    # 1.0 mile grocery store rings
│   ├── kcata_routes.geojson
│   ├── kcata_stops.geojson
│   └── troost.geojson
└── kc_food_access.R               # Full analysis pipeline
```

---

## Data Pipeline

All data acquisition, cleaning, and spatial processing is performed in a single reproducible R script (`kc_food_access.R`). The pipeline proceeds in the following order:

1. Pull Census tract boundaries and ACS variables via `tidycensus` API
2. Derive housing variables (vacancy rate, AMI thresholds)
3. Join USDA Food Access Research Atlas variables by Census tract GEOID
4. Derive SNAP and no-vehicle rate variables
5. Filter and geocode SNAP-authorized grocery store locations
6. Build 0.5 and 1 mile buffer rings around grocery store points
7. Process KCATA GTFS feed into route line and stop point layers
8. Export all layers as GeoJSON for use in Leaflet web map

---

## Data Dictionary

| Variable | Type | Description | Source |
|---|---|---|---|
| `GEOID` | string | 11-digit Census tract FIPS code | Census TIGER |
| `pop` | integer | Total population | ACS 2019 5-Year, B01003 |
| `income` | integer | Median household income (USD) | ACS 2019 5-Year, B19013 |
| `rent` | integer | Median gross rent (USD) | ACS 2019 5-Year, B25064 |
| `home_value` | integer | Median owner-occupied home value (USD) | ACS 2019 5-Year, B25077 |
| `vacancy_rate` | rate | Share of housing units vacant (0–1) | Derived: B25002_003 / B25002_001 |
| `ami_60` | integer | 60% AMI threshold (USD); fixed at $49,620 | HUD FY2019 Income Limits |
| `below_60_ami` | binary | 1 if tract median income < 60% AMI, 0 otherwise | Derived |
| `PovertyRate` | percent | Share of population below federal poverty line (0–100) | USDA Food Access Research Atlas 2019 |
| `LILATracts_1And10` | binary | 1 if tract is Low Income & Low Access at 1-mile urban / 10-mile rural thresholds | USDA Food Access Research Atlas 2019 |
| `LATracts_half` | binary | 1 if tract is Low Access at 0.5-mile threshold | USDA Food Access Research Atlas 2019 |
| `TractHUNV` | integer | Households without a vehicle (count) | ACS 2019 5-Year via USDA Atlas |
| `TractSNAP` | integer | Households receiving SNAP benefits (count) | ACS 2019 5-Year via USDA Atlas |
| `snap_pct` | rate | Share of population receiving SNAP benefits (0–1) | Derived: TractSNAP / pop |
| `hunv_pct` | rate | Share of population in households without a vehicle (0–1) | Derived: TractHUNV / pop |

---

## Data Sources

| Dataset | Source | Year | URL |
|---|---|---|---|
| ACS 5-Year Estimates | U.S. Census Bureau | 2019 | [census.gov](https://www.census.gov) |
| Food Access Research Atlas | USDA Economic Research Service | 2019 | [ers.usda.gov](https://www.ers.usda.gov/data-products/food-access-research-atlas/) |
| SNAP Retailer Locator | USDA Food and Nutrition Service | Current | [fns.usda.gov](https://www.fns.usda.gov/snap/retailer-locator) |
| GTFS Feed | Kansas City Area Transportation Authority | April 2026 | [kcata.org](https://www.kcata.org) |
| Census Tract Boundaries | Census TIGER/Line via `tigris` | 2010 | [census.gov](https://www.census.gov/geo/maps-data/data/tiger.html) |

---

## Tools

| Tool | Purpose |
|---|---|
| R / tidycensus | Census data acquisition |
| R / sf | Spatial data processing and export |
| R / tidyverse | Data wrangling |
| QGIS | Spatial visualization and layer QA |
| Leaflet.js | Interactive web map |
| GitHub Pages | Map hosting |

---

*Matthew Ong · Master's Student, Economics · 2026*
