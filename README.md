# NCHS Mortality Reference Counts for SEER SMR Analysis

R pipeline to generate female death counts and population denominators from NCHS
Detailed Mortality restricted-use data (2000–2020), matched to the SEER cancer registry
geographic footprint. Outputs are used as reference values for standardized mortality
ratio (SMR) calculations in the SEER breast cancer cohort study.

## Requirements

- R (base R only — no external packages)
- NCHS Detailed Mortality restricted-use files, 2000–2020 (`USAllCnty` format)
- Census Bureau population estimate CSVs (see **Data** section below)

## Directory Structure

```
nchs_mortality_clean/
├── configs/
│   └── cod_groups.R          # ICD-10 cause-of-death group definitions
├── scripts/
│   ├── config.R              # Central parameters (year range, paths, registries)
│   ├── readers.R             # Fixed-width file readers (historical + standard formats)
│   ├── filters.R             # Sex, geography, and COD filter functions
│   ├── count_deaths.R        # Age-window and lag counting logic
│   ├── get_population.R      # Census population loading and interpolation
│   ├── run_analysis.R        # Entry point: all-cause death counts
│   └── run_tables.R          # Entry point: deaths + denominators, all COD groups
├── docs/
│   ├── METHODS.md            # Full methodology documentation
│   └── VALIDATION_REPORT.md  # Field position and output verification results
├── outputs/                  # Generated CSVs (committed)
│   ├── nchs_death_counts.csv # All-cause death counts (840 rows)
│   └── nchs_smr_table.csv   # Deaths + population by COD group (15,960 rows)
├── data_raw/                 # NCHS restricted-use files (gitignored; not included)
└── pop_data/                 # Census population CSVs (gitignored; see below)
```

## Setup

### 1. NCHS mortality data

Place the NCHS Detailed Mortality files in `data_raw/`. The pipeline expects one
subdirectory per year (`MULT2000.USAllCnty/`, `MULT2001.USAllCnty/`, …), each
containing a `*US*.txt` fixed-width file. Territory files (`PS*`) are ignored.

### 2. Census population data

Place the following Census Bureau CSVs in `pop_data/`. All files are publicly available
from the U.S. Census Bureau (census.gov).

**State-level intercensal/postcensal estimates:**
- `st-est00int-alldata.csv` — 2000–2009 intercensal by age, sex, race, origin
- `sc-est2020int-alldata6.csv` — 2010–2019 intercensal
- `sc-est2024-alldata6.csv` — 2020 postcensal (Vintage 2024)

**County-level estimates for MI (26), OK (40), WA (53):**
- `co-est00int-alldata-{26,40,53}.csv` — 2000–2009 intercensal
- `cc-est2020int-alldata-{26,40,53}.csv` — 2010–2019 intercensal
- `cc-est2024-alldata-{26,40,53}.csv` — 2020 postcensal (Vintage 2024)

### 3. Run scripts from the project root

```bash
# All-cause death counts only
Rscript scripts/run_analysis.R

# Deaths + population denominators for all 19 COD groups
Rscript scripts/run_tables.R
```

Outputs are written to `outputs/`.

## Outputs

### `outputs/nchs_death_counts.csv`

All-cause female death counts in the SEER footprint, 2000–2020.

**840 rows** = 4 baseline age groups × 210 valid (year, lag) combinations.

| Column | Description |
|--------|-------------|
| `year` | Calendar year of death (2000–2020) |
| `age_group` | Baseline age at diagnosis: `"50-54"`, `"55-59"`, `"60-64"`, `"65-69"` |
| `lag` | Years of follow-up (1–15) |
| `age_low` | Lower bound of current age window |
| `age_high` | Upper bound of current age window |
| `deaths` | Female death count |

### `outputs/nchs_smr_table.csv`

Deaths and Census population denominators for 19 cause-of-death groups.

**15,960 rows** = 19 COD groups × 840 cells.

Adds columns `cod_group` and `population` to the structure above. Population is
interpolated from 5-year Census age bands using a uniform within-band assumption
(see `docs/METHODS.md` Section 8).

## Key Design Decisions

- **Year range 2000–2020:** NCHS discontinued bridged-race data after 2020. The detail
  race field (used for AIAN identification) is blank in 2021. Extending coverage requires
  switching to Race Recode 40, which undercounts AIAN by ~9%. See `docs/METHODS.md` §3.
- **Females only:** Matches the SEER breast cancer cohort.
- **AIAN registries (AK, AZ, OK):** Filtered to AIAN + non-Hispanic deaths and
  population to match SEER's denominator methodology.
- **ICD-10 groups:** Follow SEER Cause-of-Death Recode, cross-referenced with Afifi
  et al. (2020). Groups defined in `configs/cod_groups.R`.

## Documentation

`docs/METHODS.md` — complete methodology: file formats, field positions, filter logic,
age windows, year-lag constraint, Census population methodology, and limitations.

`docs/VALIDATION_REPORT.md` — empirical verification of field positions, filter
behavior, and output structure.

## Authors

Amaan Jogia-Sattar, University of California, Los Angeles 
Department of Biostatistics, Fielding School of Public Health

Dr. Jay Xu, University of Toronto
Institute of Health Emergencies and Pandemics
