# NCHS Mortality Reference Counts: Methods

**Project:** SMR Analysis — NCHS Reference Population Death Counts  
**Author:** Amaan Jogia-Sattar  
**Last updated:** 2026-06-23

---

## 1. Data Source and Year Range

Death counts come from the NCHS Detailed Mortality — All Counties restricted-use files,
2000–2020. These files contain one record per U.S. death, including full state and county
of residence not available in the public-use files. All deaths are coded to ICD-10.

**Year range (2000–2020 only):** The 2021 file is excluded because NCHS discontinued
bridged-race data after 2020. The detail race field (positions 445–446), used throughout
this analysis, is entirely blank in 2021 (0 of 3,472,120 records populated). Extending to
2021 would require switching to Race Recode 40 (489–490), which uses a narrower AIAN
definition inconsistent with SEER's bridged-race denominators. See Section 3.

Territory files (`PSAllCnty`) are excluded; only US files (`USAllCnty`) are used.

---

## 2. File Format Eras and Field Positions

The NCHS files span three fixed-width text formats. All positions are 1-indexed
(R `substr` convention).

### Historical format (2000–2002) — 440-character records

| Field | Positions | Notes |
|-------|-----------|-------|
| Year | 115–118 | Calendar year |
| State (FIPS) | 44–45 | Numeric FIPS; converted to postal via crosswalk |
| County | 33–35 | 3-digit numeric FIPS |
| Sex | 59 | `"1"` = Male, `"2"` = Female |
| Age unit | 64 | `"0"` = years |
| Age value | 65–66 | 2-digit integer |
| Race (detail) | 60–61 | `"03"` = AIAN |
| Hispanic origin | 80–81 | `"00"` = Non-Hispanic |
| ICD-10 | 142–145 | 3-char codes right-padded with space |

### Standard format (2003–2020) — 490-char (2003–2019) or 817-char (2020) records

Field positions are **identical** between 490- and 817-character records. The 2020 file
appends occupation/industry fields at positions 806–817; no existing field is shifted.

| Field | Positions | Notes |
|-------|-----------|-------|
| Year | 102–105 | Calendar year |
| State (postal) | 29–30 | 2-letter postal code |
| County | 35–37 | 3-digit numeric FIPS |
| Sex | 69 | `"M"` = Male, `"F"` = Female |
| Age unit | 70 | `"1"` = years |
| Age value | 71–73 | 3-digit integer |
| Race (detail, bridged) | 445–446 | `"03"` = AIAN. Fully populated 2003–2020. |
| Hispanic origin | 484–486 | Integer: 100–199 = Non-Hispanic |
| ICD-10 | 146–149 | 3-char codes right-padded with space |

Race Recode 40 at positions 489–490 is **not used**. See Section 3.

All positions were verified against the official PDF layout document and spot-checked
empirically. See `docs/VALIDATION_REPORT.md` for details.

---

## 3. Race Field Decision

### Why detail race (445–446) and not Race Recode 40 (489–490)

SEER's population denominators use bridged-race methodology, which assigns multi-race
individuals to a single race category. The NCHS detail race field (445–446) uses the same
bridging, making it the correct counterpart for NCHS–SEER comparisons. Race Recode 40
reports race as recorded on the death certificate (AIAN-alone, code `"03"` only), missing
mixed-race AIAN individuals.

Empirically, Race Recode 40 undercounts AIAN deaths by 6.6% (2012) and 8.9% (2017)
relative to the bridged field, with the gap growing as multi-race reporting expanded.
In 2021, the bridged field is completely absent; mixing definitions across years would
create a systematic AIAN discontinuity in the three AIAN-only registries. The analysis
therefore stops at 2020.

### Race field routing by era

| Era | Field | Positions | AIAN code |
|-----|-------|-----------|-----------|
| 2000–2002 | Detail race (historical) | 60–61 | `"03"` |
| 2003–2020 | Detail race (standard, bridged) | 445–446 | `"03"` |

---

## 4. Filters Applied

Filters are applied in this order: sex → geography → cause of death.

### 4.1 Sex

Restricted to **female deaths only**, matching the breast cancer cohort in SEER.

| Era | Position | Female code |
|-----|----------|-------------|
| 2000–2002 | 59 | `"2"` |
| 2003–2020 | 69 | `"F"` |

### 4.2 Geography

Records are filtered to the SEER registry footprint using **state and county of residence**.

**Whole-state registries** (all deaths in the state):
CT, HI, IA, NJ, NM, NY, UT, KY, LA, IL, ID, TX, GA, CA, AK, AZ

**County-specific registries:**
- **Seattle–Puget Sound** (13 WA counties): Clallam (009), Grays Harbor (027), Island (029), Jefferson (031), King (033), Kitsap (035), Mason (045), Pierce (053), San Juan (055), Skagit (057), Snohomish (061), Thurston (067), Whatcom (073)
- **Detroit** (3 MI counties): Macomb (099), Oakland (125), Wayne (163). Active 2000–2018 only.
- **Cherokee Nation** (14 OK counties): Adair (001), Cherokee (021), Craig (035), Delaware (041), Mayes (091), McIntosh (097), Muskogee (101), Nowata (105), Ottawa (115), Rogers (131), Sequoyah (135), Tulsa (143), Wagoner (145), Washington (147)

### 4.3 AIAN-Only Registries

Three registries observe AIAN populations only: Alaska (entire state), Arizona Indians
(entire state), Cherokee Nation (14 OK counties). For these, the filter requires race
`"03"` **AND** non-Hispanic ethnicity.

The non-Hispanic restriction matches SEER's population denominators, which use non-Hispanic
AIAN denominators for these registries to prevent overcounting from Hispanic AIAN bridging.

| Era | Hispanic field | Non-Hispanic definition |
|-----|----------------|-------------------------|
| 2000–2002 | Positions 80–81 | `"00"` |
| 2003–2020 | Positions 484–486 | Integer 100–199 |

Records with unknown Hispanic origin (`"99"` / 996–999) in AIAN geographies are excluded.

### 4.4 Age

Only records with age in completed years are included. Age unit `"0"` (historical) or
`"1"` (standard) indicates whole years; other codes are excluded.

### 4.5 Cause of Death

Optional filter controlled by `COD_FILTER` in `scripts/config.R`. Default is `NULL`
(all-cause). Matching is prefix-based against the 4-character ICD-10 underlying-cause
field (trailing spaces stripped). See Section 5 for all defined cause groups.

---

## 5. ICD-10 Cause-of-Death Groups

All groups are defined in `configs/cod_groups.R`. Primary source: SEER Cause-of-Death
Recode. Cross-reference: Afifi et al. (2020) Supporting Table 1. Where sources diverged,
the SEER recode was followed for consistency with the parallel SEER\*Stat analysis.

**Updated 2026-06-23:** 8 changes from the prior version (see `configs/cod_groups.R`
header for full changelog). Substantive changes: `diseases_of_heart` expanded to full
SEER range; `atherosclerosis` expanded from I70 to I70–I78; `other_arterial` removed
(overlap with expanded `atherosclerosis`); added `other_infectious`, `in_situ_benign`,
`symptoms_signs`.

### Neoplasms

| Group | Codes | Notes |
|-------|-------|-------|
| `breast_cancer` | C500–C506, C508–C509 | C507 (nipple/areola) excluded per SEER |
| `other_nonbreast_cancers` | All `C*` except breast | Exclusion-based; see `apply_cod_filter()` |
| `in_situ_benign` | D0–D4 | D00–D49: in situ, benign, uncertain-behavior neoplasms |

### Infectious and Endocrine

| Group | Codes |
|-------|-------|
| `septicemia` | A40–A41 |
| `other_infectious` | B20–B24 (HIV disease) |
| `diabetes` | E10–E14 |

### Neurological

| Group | Codes |
|-------|-------|
| `alzheimer` | G30 |

### Circulatory — Heart

| Group | Codes | Notes |
|-------|-------|-------|
| `diseases_of_heart` | I00–I09, I20–I28, I30–I51, I80–I99 | Full SEER recode range |
| `hypertension` | I10–I13, I15 | I14 does not exist in ICD-10 |

**I11/I13 decision:** Afifi et al. placed I11 (hypertensive heart disease) and I13
(hypertensive heart and renal disease) under `diseases_of_heart`. The SEER recode groups
all of I10–I15 under hypertension. We follow SEER so categories match the parallel
SEER\*Stat analysis. I11 and I13 are in `hypertension`.

### Circulatory — Cerebrovascular and Arterial

| Group | Codes | Notes |
|-------|-------|-------|
| `cerebrovascular` | I60–I69 | |
| `atherosclerosis` | I70–I78 | Covers aortic aneurysm (I71) |

### Respiratory

| Group | Codes |
|-------|-------|
| `pneumonia_influenza` | J09–J18 |
| `copd` | J40–J47 |

### Digestive and Renal

| Group | Codes |
|-------|-------|
| `chronic_liver_disease` | K70, K73, K74 |
| `nephritis` | N00–N07, N17–N19, N25–N27 |

### Symptoms and Ill-Defined

| Group | Codes | Notes |
|-------|-------|-------|
| `symptoms_signs` | R | Single prefix captures all of R00–R99 |

### External Causes

| Group | Codes |
|-------|-------|
| `accidents` | V, W, X0–X5, Y85, Y86 |
| `suicide` | U03, X60–X84, Y870 |

### Sentinel

| Group | Value | Behavior |
|-------|-------|----------|
| `all_cause` | NULL | No filtering applied |

---

## 6. Age Window Logic

For baseline age group starting at age *a*, lag *k*:

```
age_low  = a + (k − 1)
age_high = a + (k − 1) + 5
```

This is a **6-year inclusive window** that shifts up one year per lag. The upper bound
extends one year beyond the 5-year baseline width to capture patients at the top of their
age band (e.g., age 54) who age into 55 during their first lag year.

| Baseline | Lag | age\_low | age\_high |
|----------|-----|----------|-----------|
| 50–54 | 1 | 50 | 55 |
| 50–54 | 6 | 55 | 60 |
| 50–54 | 15 | 64 | 69 |
| 65–69 | 15 | 79 | 84 |

**Consistency check:** Baseline 50–54 lag 6 and baseline 55–59 lag 1 both produce window
55–60. Death counts and population denominators in these cells must be identical; confirmed
in `docs/VALIDATION_REPORT.md`.

---

## 7. Year–Lag Constraint

For lag *k*, only calendar years ≥ (1999 + *k*) are valid. This ensures lag-*k* deaths
are counted only in years when a *k*-year follow-up from a 2000+ diagnosis could occur.

Rows violating the constraint are **omitted** (not zeroed) — the output is triangular.

| Lag | First valid year | Years included |
|-----|-----------------|----------------|
| 1 | 2000 | 21 |
| 5 | 2004 | 17 |
| 10 | 2009 | 12 |
| 15 | 2014 | 7 |

Total rows = 4 age groups × Σ(k=1..15)(21−k+1) = 4 × 210 = **840**.

---

## 8. Population Denominators

### 8.1 Census Data Sources

Population denominators come from three Census Bureau series in `pop_data/`:

**State-level files (wide format — year in column names):**

| File | Series | Years |
|------|--------|-------|
| `st-est00int-alldata.csv` | 2000–2010 Intercensal | 2000–2009 |
| `sc-est2020int-alldata6.csv` | 2010–2020 Intercensal | 2010–2019 |
| `sc-est2024-alldata6.csv` | Vintage 2024 Postcensal | 2020 |

**County-level files (long format — `YEAR` code → calendar year):**

| Files (suffix = state FIPS) | YEAR codes | Calendar years |
|-----------------------------|------------|----------------|
| `co-est00int-alldata-{26,40,53}.csv` | 2–11 | 2000–2009 |
| `cc-est2020int-alldata-{26,40,53}.csv` | 2–11 | 2010–2019 |
| `cc-est2024-alldata-{26,40,53}.csv` | 2 | 2020 |

State FIPS: 26 = Michigan, 40 = Oklahoma, 53 = Washington.

**Year 2020 source:** The 2010–2020 intercensal `CENSUS2020POP` column is April 1, not
July 1. Year 2020 uses `POPESTIMATE2020` from the Vintage 2024 postcensal file.

### 8.2 Population Filter by Registry Type

| Registry type | Population filter |
|---------------|------------------|
| Non-AIAN whole-state (14 states) | `SEX=2, RACE=0, ORIGIN=0` (total female) |
| AIAN whole-state (AK, AZ) | `SEX=2, RACE=3, ORIGIN=1` (NH AIAN female) |
| Non-AIAN county (WA 13 counties, MI 3 counties) | `TOT_FEMALE` |
| AIAN county (OK 14 counties) | `NHIA_FEMALE` |

Michigan included for 2000–2018 only (Detroit registry end date).

### 8.3 Age-Band Interpolation

Census estimates use 5-year age bands (AGEGRP 11=50–54 through 17=80–84). The 6-year
analysis windows do not align with these bands; within-band interpolation is applied
under a uniform within-band assumption.

Every 6-year window overlaps exactly two consecutive 5-year bands:

```
j          = (k − 1) mod 5
N(a, k, t) = ((5 − j) / 5) × B_low(t) + ((j + 1) / 5) × B_high(t)
```

where *B_low* and *B_high* are the populations of the lower and upper 5-year bands.
The window contains (5−j) ages from the lower band and (j+1) from the upper.

---

## 9. Outputs

### `outputs/nchs_death_counts.csv` — all-cause death counts (run\_analysis.R)

840 rows (4 age groups × 210 valid year-lag pairs). Columns: `year`, `age_group`, `lag`,
`age_low`, `age_high`, `deaths`.

### `outputs/nchs_smr_table.csv` — deaths + denominators by COD group (run\_tables.R)

15,960 rows (19 COD groups × 840 cells). Columns: `cod_group`, `year`, `age_group`,
`lag`, `age_low`, `age_high`, `deaths`, `population`.

---

## 10. Limitations

- **2020 endpoint.** Cannot extend to 2021+ without a definitional discontinuity in the
  AIAN group. The `YEARS` parameter in `config.R` makes the range easy to change; the
  race routing in `readers.R` would also need updating.
- **Mixed-race AIAN.** Bridging assigns some multi-race individuals to AIAN. Consistency
  with SEER's AIAN definition is assumed but not independently verified.
- **Detroit end date.** Michigan counties excluded for 2019–2020 (enforced by
  `end = 2018` in the registry definition).
- **County boundaries.** FIPS changes during 2000–2020 are not accounted for.
- **Unknown Hispanic origin.** Records with unknown ethnicity in AIAN geographies are
  excluded (prevalence expected to be small).
- **Uniform within-band assumption.** The interpolation formula distributes population
  evenly within 5-year Census bands; deviations affect precision but not systematic bias.
