# kc_food_access

**[Live Map →](https://matthewong01.github.io/kc-food-access-map)**

**[Map Repository →](https://github.com/MatthewOng01/kc-food-access-map)**

**[Project Website →](https://MatthewOng01.github.io)**


## Data Dictionary

| Variable | Type | Description | Source |
|---|---|---|---|
| `pop` | integer | Total population | ACS 2019 5-Year Estimates |
| `income` | integer | Median household income (USD) | ACS 2019 5-Year Estimates |
| `rent` | integer | Median gross rent (USD) | ACS 2019 5-Year Estimates |
| `home_value` | integer | Median owner-occupied home value (USD) | ACS 2019 5-Year Estimates |
| `vacancy_rate` | rate | Share of housing units vacant (0–1) | ACS 2019 5-Year Estimates |
| `ami_60` | integer | 60% Area Median Income threshold (USD); fixed at $49,620 for Kansas City MSA | HUD FY2019 Income Limits |
| `below_60_ami` | binary | 1 if tract median household income falls below 60% AMI, 0 otherwise | Derived |
| `PovertyRate` | rate | Share of population below federal poverty line (0–1) | ACS 2019 5-Year Estimates |
| `LILATracts_1And10` | binary | 1 if tract qualifies as Low Income, Low Access at 1-mile (urban) and 10-mile (rural) thresholds | USDA Food Access Research Atlas 2019 |
| `LILATracts_halfAnd10` | binary | 1 if tract qualifies as Low Income, Low Access at 0.5-mile (urban) and 10-mile (rural) thresholds | USDA Food Access Research Atlas 2019 |
| `TractHUNV` | integer | Total count of households without a vehicle | ACS 2019 5-Year Estimates |
| `TractSNAP` | integer | Total count of households receiving SNAP benefits | ACS 2019 5-Year Estimates |
| `snap_pct` | percent | Share of households receiving SNAP benefits (0–100) | Derived from TractSNAP / occupied housing units |
| `hunv_pct` | percent | Share of households without a vehicle (0–100) | Derived from TractHUNV / occupied housing units |
