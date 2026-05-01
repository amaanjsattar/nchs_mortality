# NCHS Mortality Reference Counts: Methods Documentation

**Project:** SMR Analysis — NCHS Reference Population Death Counts  
**Author:** Amaan Jogia-Sattar  
**Last updated:** 2026-04-29

---

## 1. Data Source and Year Range

### 1.1 NCHS Detailed Mortality Files

Death counts are drawn from the National Center for Health Statistics (NCHS) Detailed
Mortality — All Counties restricted-use files, covering calendar years **2000–2020**.
These files are disseminated by the Division of Vital Statistics (DVS) to approved
researchers and contain one record per death registered in the United States, including
full geographic detail (state and county of residence) not available in the public-use
files.

All deaths in these files are coded to the 10th revision of the International
Classification of Diseases (ICD-10), which was implemented in the United States in 1999.
The files cover US occurrences (file suffix `USAllCnty`) only; territory files
(`PSAllCnty`) are excluded throughout.

### 1.2 Analysis Year Range: 2000–2020

The analysis covers 2000–2020 only. The 2021 NCHS file exists and was examined during
data validation but is excluded for methodological reasons (see Section 8.1). The year
range is configured as a single parameter (`YEARS`) in `scripts/config.R` and can be
extended without modifying analysis code, subject to the constraints described in Section 8.1.

### 1.3 File Format Eras

The NCHS mortality files span three distinct fixed-width text formats across 2000–2020.
All field positions are 1-indexed (i.e., the first character of a record is position 1),
consistent with R's `substr()` convention.

| Era | Years | Record length | Key differences from adjacent era |
|-----|-------|---------------|-----------------------------------|
| Historical | 2000–2002 | 440 characters | State as numeric FIPS; 2-digit age; sex coded `"1"`/`"2"`; Hispanic at pos 80–81; ICD-10 at pos 142–145 |
| Standard | 2003–2019 | 490 characters | State as 2-letter postal code; 3-digit age; sex coded `"M"`/`"F"`; Hispanic at pos 484–486; ICD-10 at pos 146–149 |
| Standard extended | 2020 | 817 characters | Positions 1–490 **identical** to 2003–2019; positions 806–817 are occupation/industry fields appended at end |

The identity of field positions between the 490- and 817-character formats was confirmed
against the official layout document and verified empirically. The extra characters in 2020
records do not shift any existing field.

---

## 2. Field Position Verification

### 2.1 Verification Approach

Field positions were verified through two independent methods:

1. **Layout documentation.** The primary reference is the PDF layout document
   `RecordLayout_RestrictedUse_DetailedMortAllCounties_2003-latest_03-13-2024_annotated.pdf`
   (stored in each year's data folder), covering 2003 onward. For 2000–2002, the layout is
   documented in year-specific `.doc` files (`Mort2000HistRecLayout.doc`, etc.), which are
   binary and not machine-readable; positions for that era were verified empirically.

2. **Empirical spot-check.** The first 5 records of `MULT2000.USAllCnty.txt` were extracted
   using `readLines()` and inspected character-by-character. ICD-10 codes were cross-checked
   against known disease classifications. Additionally, `scripts/validate_positions.R` drew
   100 random records from each of six key years (2000, 2005, 2010, 2015, 2018, 2021) and
   tabulated every field of interest.

### 2.2 Verified Field Positions

#### Historical format (2000–2002) — 440-character records

| Field | Positions | Size | Notes |
|-------|-----------|------|-------|
| Year of death | 115–118 | 4 | Calendar year |
| State of residence (FIPS) | 44–45 | 2 | Numeric FIPS code; converted to postal via crosswalk |
| County of residence (FIPS) | 33–35 | 3 | 3-digit numeric |
| Sex | 59 | 1 | `"1"` = Male, `"2"` = Female |
| Age unit | 64 | 1 | `"0"` = years (< 100); `"1"` = years (≥ 100) |
| Age value | 65–66 | 2 | Integer; valid when age unit = `"0"` |
| Race (detail) | 60–61 | 2 | `"03"` = American Indian/Alaska Native (incl. Aleuts, Eskimos) |
| Hispanic origin | 80–81 | 2 | `"00"` = Non-Hispanic; `"01"`–`"05"` = Hispanic subtypes; `"99"` = Unknown |
| ICD-10 underlying cause | 142–145 | 4 | 3-character codes right-padded with a space |

**Corrections from initial assumptions:**

- *ICD-10 position:* Initially assumed 145–148 by analogy with the standard format.
  Empirical verification confirmed the correct position is 142–145. Codes at 145–148
  (e.g., `"1320"`, `" 278"`) did not correspond to any ICD-10 pattern, while codes at
  142–145 (C900, J81, I219, I64, C349) are all valid underlying causes.

- *Hispanic origin position:* Position 63 was initially hypothesized due to proximity to
  the race field at 60–61. Manual inspection showed position 63 contains an unrelated
  coded variable. The `.doc` layout document specifies positions 80–81; confirmed by `"00"`
  dominance (98/100 records) consistent with Alabama county demographics in the sample.

#### Standard format (2003–2020) — 490-character (2003–2019) or 817-character (2020) records

| Field | Positions | Size | Notes |
|-------|-----------|------|-------|
| Year of death | 102–105 | 4 | Calendar year |
| State of residence (postal) | 29–30 | 2 | 2-letter postal code; no crosswalk needed |
| County of residence (FIPS) | 35–37 | 3 | 3-digit numeric |
| Sex | 69 | 1 | `"M"` = Male, `"F"` = Female (differs from historical) |
| Age unit | 70 | 1 | `"1"` = years (differs from historical `"0"`) |
| Age value | 71–73 | 3 | Integer; valid when age unit = `"1"` |
| Race (detail, bridged) | 445–446 | 2 | `"03"` = AIAN. Fully populated 2003–2020 (100%). |
| Hispanic origin | 484–486 | 3 | Integer: 100–199 = Non-Hispanic; 200–299 = Hispanic subtypes; 996–999 = Unknown |
| ICD-10 underlying cause | 146–149 | 4 | 3-character codes right-padded with a space |

Race Recode 40 at positions 489–490 is present in the files but **not used** in this
analysis. See Section 3 for full rationale.

**Correction from initial assumption:**

- *ICD-10 position:* An initial assumption of positions 161–164 was incorrect. The layout
  document shows 161–164 contains the "Number of Entity-Axis Conditions" (163–164) and
  end of the 39-cause recode (160–161). The correct position, 146–149, was confirmed from
  the layout document and consistent with observed codes (C349, I251, G309, F03, I500) in
  the validation sample.

---

## 3. Race Field Decision

### 3.1 Two Available Race Fields in the Standard Format

For the standard format (2003–2020), two race fields are present in the files:

- **Detail race (positions 445–446):** Based on bridged-race methodology (see Section 3.2).
  Code `"03"` = American Indian (includes Aleuts and Eskimos). Fully populated (100%) for
  all years 2003–2020; blank in 2021.

- **Race Recode 40 (positions 489–490):** Based on single-race or multiple-race
  combinations as reported on the 2003 revision of the U.S. Standard Certificate of Death.
  Code `"03"` = American Indian or Alaska Native **alone** (excludes mixed-race AIAN
  individuals). The official NCHS layout documentation states "available starting data year
  2018," which refers to universal state-level coverage; full-file scans confirmed it was
  100% populated as early as 2012.

### 3.2 Bridged-Race Methodology

The United States transitioned from the 1977 OMB race standards (single race only) to the
1997 OMB standards (multiple races allowed) with the 2003 revision of the death
certificate. States adopted the new format gradually between 2003 and 2017; by 2018 all
reporting areas had completed the transition.

During the transition, NCHS produced "bridged-race" data by assigning individuals who
reported multiple races to a single race category using a probabilistic algorithm. This
bridged-race assignment populates the detail race field (445–446), ensuring consistent
single-race classification for all years 2003–2020 regardless of which certificate format
a given state was using.

SEER cancer registry data used bridged-race population denominators for rate calculations
and cohort definitions through 2020. The detail race field in NCHS (also bridged) is
therefore the correct counterpart for maintaining consistency between NCHS death counts
and the SEER analytical framework.

Race Recode 40 does not use bridging: it reports the actual race combination as recorded
on the certificate, with code `"03"` reserved for individuals who identified as AIAN and
**only** AIAN. A person who identified as AIAN and White would appear as code `"19"` (AIAN
and White), not `"03"`.

### 3.3 Why We Use Detail Race (445–446) for 2003–2020

Three considerations favor the detail race field over Race Recode 40:

1. **Consistency with SEER.** SEER's bridged-race population denominators and the NCHS
   bridged detail race field were constructed under the same methodology. Using Race
   Recode 40 (non-bridged) in NCHS against SEER's bridged-race framework would introduce
   a systematic mismatch.

2. **Consistency across years.** The detail race field uses the same bridged definition
   for all years 2000–2020. Race Recode 40 was partially populated before 2018 and was not
   yet available in earlier years; the bridged field provides uniform coverage throughout.

3. **Empirically larger AIAN capture.** Bridging assigns mixed-race AIAN individuals to
   the AIAN category, consistent with how SEER historically counted them. Race Recode 40
   code `"03"` misses these individuals. Quantified from full-file scans:

| Year | Detail race AIAN (445–446) | Race Recode 40 AIAN (489–490) | Difference |
|------|---------------------------|-------------------------------|------------|
| 2012 | 16,556 | 15,466 | −1,090 (−6.6%) |
| 2017 | 20,425 | 18,618 | −1,807 (−8.9%) |

### 3.4 Why the Analysis Stops at 2020

Starting with the 2021 data file, the detail race field (445–446) is entirely blank
(confirmed: 0 of 3,472,120 records populated). NCHS discontinued bridged-race data after
2020 because all states had adopted the 2003 certificate format, making bridging
unnecessary. The only available race field for 2021 and later is Race Recode 40 (489–490),
which uses the race-alone definition.

Including 2021 under Race Recode 40 would introduce a definitional discontinuity in the
AIAN group: years 2000–2020 would include mixed-race AIAN (via bridging), while 2021
would include only AIAN-alone individuals — an estimated undercount of 8–10% based on the
2012 and 2017 comparisons above. For the three AIAN-only registries, where race is the
primary inclusion criterion, this discontinuity is unacceptable without additional
methodological work.

### 3.5 Summary: Race Field Routing by Era

| Era | Field | Positions | AIAN code | Rationale |
|-----|-------|-----------|-----------|-----------|
| 2000–2002 | Detail race (historical) | 60–61 | `"03"` | Only race field available |
| 2003–2020 | Detail race (standard, bridged) | 445–446 | `"03"` | Consistent with SEER; fully populated; bridged |

---

## 4. Filter Specifications

### 4.1 Sex Filter

All analysis is restricted to **female deaths only**, to match the breast cancer patient
population in the SEER data. The sex filter is applied first, before geographic or cause
filters, to reduce data volume.

| Era | Field position | Female code |
|-----|---------------|-------------|
| Historical (2000–2002) | Position 59 | `"2"` |
| Standard (2003–2020) | Position 69 | `"F"` |

Sex codes differ between eras: historical uses numeric `"1"`/`"2"`, standard uses
alphabetic `"M"`/`"F"`. Records with any other value are treated as non-female and excluded.

### 4.2 Geographic Filter

Death records are filtered to the geographic footprint of SEER cancer registries
contributing to the analysis. The filter uses **state and county of residence** (not state
of occurrence), consistent with SEER's population-based catchment area definitions.

Registries fall into two geographic types:

**Whole-state registries** — all deaths in the state are included:
Connecticut, Hawaii, Iowa, New Jersey, New Mexico, New York, Utah, Kentucky, Louisiana,
Illinois, Idaho, Texas, Georgia, California, Alaska, Arizona

**County-specific registries** — only deaths in the listed counties are included:

- **Seattle–Puget Sound** (13 Washington counties): Clallam (009), Grays Harbor (027),
  Island (029), Jefferson (031), King (033), Kitsap (035), Mason (045), Pierce (053),
  San Juan (055), Skagit (057), Snohomish (061), Thurston (067), Whatcom (073)
- **Detroit** (3 Michigan counties): Macomb (099), Oakland (125), Wayne (163).
  Active 2000–2018 only; Detroit ceased contributing to SEER after 2018.
- **Cherokee Nation** (14 Oklahoma counties): Adair (001), Cherokee (021), Craig (035),
  Delaware (041), Mayes (091), McIntosh (097), Muskogee (101), Nowata (105),
  Ottawa (115), Rogers (131), Sequoyah (135), Tulsa (143), Wagoner (145), Washington (147)

Each registry entry in `config.R` specifies its active year range (`start`, `end`), so
registries that end before 2020 automatically drop out of the filter without code changes.

### 4.3 AIAN-Only Registry Filter

Three SEER registries observe only American Indian/Alaska Native (AIAN) individuals:
Alaska Native Tumor Registry (entire state of AK), Arizona Indians (entire state of AZ),
and Cherokee Nation (14 OK counties). For deaths in these geographies, an additional race
filter is applied: the record must have race code `"03"` in the detail race field **AND**
non-Hispanic ethnicity (see Section 4.4).

This conjunction was added per advisor guidance. The prior implementation used race `"03"`
alone, which captured a slightly broader group including Hispanic AIAN individuals.
The non-Hispanic restriction applies only to these three registries; all other registries
do not apply a race filter.

### 4.4 Hispanic Origin Filter (AIAN Registries Only)

The non-Hispanic restriction applies **only** within the AIAN-only registry filter
(Section 4.3). It is not applied to any other registry.

| Era | Field positions | Non-Hispanic definition |
|-----|----------------|------------------------|
| Historical (2000–2002) | 80–81 (2-char) | Code `"00"` |
| Standard (2003–2020) | 484–486 (3-char integer) | 100–199 (i.e., `as.integer(field) %in% 100:199`) |

The 3-character standard-format field encodes specific Hispanic origins numerically:
100–199 = Non-Hispanic, 200–209 = Spaniard, 210–219 = Mexican, 220–230 = Central
American, 260–269 = Puerto Rican, 270–274 = Cuban, etc.

Records with unknown Hispanic origin (`"99"` historical; 996–999 standard) in AIAN
geographies are excluded, as non-Hispanic status cannot be confirmed.

### 4.5 Age Filter

Only records with age expressed in completed years are included. Records for infants,
newborns, and deaths with unknown age are excluded by the age unit filter.

| Era | Age unit position | Code for years |
|-----|-------------------|----------------|
| Historical (2000–2002) | Position 64 | `"0"` (years < 100); `"1"` = years ≥ 100 |
| Standard (2003–2020) | Position 70 | `"1"` (years); other codes = months, days, hours, unknown |

Age values are extracted from positions 65–66 (historical, 2-digit integer) or 71–73
(standard, 3-digit integer).

### 4.6 Cause-of-Death Filter

The pipeline supports optional filtering by underlying cause of death (ICD-10). The filter
is controlled by the `COD_FILTER` parameter in `scripts/config.R`.

```r
COD_FILTER <- NULL              # all-cause (default; no filtering applied)
COD_FILTER <- "breast_cancer"  # breast cancer deaths only
COD_FILTER <- c("breast_cancer", "diseases_of_heart")  # either cause (OR logic)
COD_FILTER <- "other_nonbreast_cancers"                 # exclusion-based (see below)
```

When `COD_FILTER` is `NULL` or `"all_cause"`, no filtering is applied. When one or more
cause group names are specified, only records whose ICD-10 underlying-cause field matches
are retained. Multiple groups are combined with OR logic (a death matching any listed
group is kept).

The filter is applied after the sex and geography filters and before death counting.
Cause group definitions are in `configs/cod_groups.R`. Matching is prefix-based: a
4-character ICD-10 code is retained if it starts with any prefix string in the group's
definition (see Section 5 for the complete code mappings).

**Special case — `"other_nonbreast_cancers"`:** This group is defined by exclusion (all
ICD-10 codes beginning with `"C"` that are not breast cancer codes), so it cannot be
expressed as a simple prefix list. It is handled as a named special case in
`apply_cod_filter()`.

---

## 5. ICD-10 Cause-of-Death Groups

All cause group names referenced in `COD_FILTER` are defined in `configs/cod_groups.R`.
Matching is prefix-based against the 4-character ICD-10 underlying-cause field (trailing
spaces stripped). A prefix of length 1–4 is accepted; shorter prefixes capture entire
ICD-10 chapters or ranges.

### 5.0 Classification Source and ICD-10 Stability

Cause-of-death categories are based on the SEER Cause-of-Death Recode, matched to the
groupings in Afifi et al. Table 2. ICD-10 was implemented in the United States in 1999
and applies uniformly to all records in the 2000–2020 analysis period; there is no
ICD revision discontinuity within this range.

### 5.1 Neoplasms

#### `breast_cancer`

Female breast cancer, subsites C50.0–C50.6, C50.8–C50.9. Code C50.7 (nipple and areola)
is excluded per the standard SEER breast cancer definition.

```
C500  C501  C502  C503  C504  C505  C506  C508  C509
```

#### `other_nonbreast_cancers` (special case)

All ICD-10 codes beginning with `"C"` except those in `breast_cancer`. Handled
programmatically in `apply_cod_filter()` rather than as a prefix list.

### 5.2 Infectious and Endocrine

#### `septicemia`

```
A40  A41
```

#### `diabetes`

```
E10  E11  E12  E13  E14
```

### 5.3 Neurological

#### `alzheimer`

```
G30
```

### 5.4 Circulatory — Heart

#### `diseases_of_heart`

Mirrors the broad SEER Cause-of-Death Recode "Diseases of Heart" category, which
encompasses four ICD-10 sub-ranges:

| Sub-group | ICD-10 range | Codes used |
|-----------|-------------|------------|
| Rheumatic heart disease | I00–I09 | I00 I01 I02 I05 I06 I07 I08 I09 |
| Ischemic heart disease | I20–I25 | I20 I21 I22 I23 I24 I25 |
| Pulmonary heart disease | I26–I28 | I26 I27 I28 |
| Other forms of heart disease | I30–I51 | I30–I51 (full range) |
| Other circulatory | I80–I99 | I80 I81 I82 I83 I85 I86 I87 I88 I89 I95 I96 I97 I98 I99 |

Note: I10–I15 (hypertension) and I60–I79 (cerebrovascular/vascular) are **not** included
in `diseases_of_heart`; they are separate groups below.

#### `hypertension`

```
I10  I11  I12  I13  I15
```

### 5.5 Circulatory — Cerebrovascular and Vascular

#### `cerebrovascular`

```
I60  I61  I62  I63  I64  I65  I66  I67  I68  I69
```

#### `atherosclerosis`

```
I70
```

#### `other_arterial`

Broader arterial disease group including atherosclerosis and related conditions:

```
I70  I71  I72  I73  I74  I75  I76  I77  I78
```

Note: `I70` appears in both `atherosclerosis` and `other_arterial`. When both are
requested together, affected records are counted only once (OR logic in the filter).

### 5.6 Respiratory

#### `pneumonia_influenza`

```
J09  J10  J11  J12  J13  J14  J15  J16  J17  J18
```

#### `copd`

Chronic obstructive pulmonary disease and allied conditions:

```
J40  J41  J42  J43  J44  J45  J46  J47
```

### 5.7 Digestive and Renal

#### `chronic_liver_disease`

```
K70  K73  K74
```

#### `nephritis`

Includes acute/chronic nephritis syndromes, renal failure, and other tubulo-interstitial
kidney conditions:

```
N00  N01  N02  N03  N04  N05  N06  N07
N17  N18  N19
N25  N26  N27
```

### 5.8 External Causes

#### `accidents`

Unintentional injuries corresponding to V01–X59 and Y85–Y86. Captured via short
prefixes that span entire chapter or sub-chapter ranges:

```
V   (V01–V99, transport accidents)
W   (W00–W99, falls and other accidental causes)
X0  (X00–X09)
X1  (X10–X19)
X2  (X20–X29)
X3  (X30–X39)
X4  (X40–X49)
X5  (X50–X59)
Y85 Y86
```

#### `suicide`

Intentional self-harm (X60–X84, Y87.0) plus U03 (terrorism-related suicide):

```
U03
X60  X61  X62  X63  X64  X65  X66  X67  X68  X69
X70  X71  X72  X73  X74  X75  X76  X77  X78  X79
X80  X81  X82  X83  X84
Y870
```

### 5.9 Sentinel

#### `all_cause`

`NULL` in `COD_GROUPS`. When `COD_FILTER <- "all_cause"` or `COD_FILTER <- NULL`,
`apply_cod_filter()` returns the data frame unchanged.

---

## 6. Age Window Logic

### 6.1 Baseline Age Groups and Lag Windows

The analysis produces death counts for each combination of:
- **Baseline age group** at breast cancer diagnosis: 50–54, 55–59, 60–64, 65–69
- **Lag** (years of follow-up post-diagnosis): 1 through 15

This produces 4 × 15 = 60 cells per calendar year (before the year-lag constraint).

### 6.2 Age Window Construction

For a patient diagnosed at baseline age group starting at age *a* and surviving *k* years,
their current age is in the range [*a* + (*k* − 1), *a* + (*k* − 1) + 4], spanning the
5-year width of the baseline group. The upper bound is extended by one year to account for
a patient diagnosed near the top of their baseline band (e.g., age 54) dying within their
first lag year at age 55.

**Formula:** For baseline group starting at age *a*, lag *k*:

```
age_low  = a + (k - 1)
age_high = a + (k - 1) + 5
```

This produces a **6-year inclusive window** covering ages [age\_low, age\_high].

**Verified example — baseline 50–54, lag 1:**
```
age_low  = 50 + (1-1) = 50
age_high = 50 + (1-1) + 5 = 55
Window: ages 50, 51, 52, 53, 54, 55  (inclusive, 6 ages)
```

Confirmed against the study specification: "50–54: look at deaths aged 50–55 for lag 1."

**Reference table:**

| Baseline | Lag | age\_low | age\_high | Window |
|----------|-----|----------|-----------|--------|
| 50–54 | 1 | 50 | 55 | 50–55 |
| 50–54 | 2 | 51 | 56 | 51–56 |
| 50–54 | 15 | 64 | 69 | 64–69 |
| 55–59 | 1 | 55 | 60 | 55–60 |
| 60–64 | 1 | 60 | 65 | 60–65 |
| 65–69 | 1 | 65 | 70 | 65–70 |
| 65–69 | 15 | 79 | 84 | 79–84 |

**Internal consistency check:** Baseline 50–54 lag 6 and baseline 55–59 lag 1 both produce
window 55–60. Death counts in these two cells must be identical, providing a direct
verification that the age window formula is applied correctly.

---

## 7. Year–Lag Constraint

### 7.1 Rationale

For an *n*-year mortality rate, SEER follow-up data are only available for patients
diagnosed at least *n* years before the end of the study period. Correspondingly, NCHS
reference death counts for lag *n* should only incorporate years in which *n*-year
follow-up events could have occurred.

Given SEER diagnosis years begin in 2000 and NCHS data extend through 2020, the
constraint is:

> **For lag *n*, include only NCHS calendar years from (1999 + *n*) through 2020.**

A year-lag combination that does not satisfy this constraint is **omitted from the output**
entirely (not set to zero), so the output is a triangular structure rather than a
complete rectangle.

### 7.2 Constraint Table

| Lag (*n*) | First valid NCHS year | Last NCHS year | Years included |
|-----------|----------------------|----------------|----------------|
| 1 | 2000 | 2020 | 21 |
| 2 | 2001 | 2020 | 20 |
| 5 | 2004 | 2020 | 17 |
| 10 | 2009 | 2020 | 12 |
| 14 | 2013 | 2020 | 8 |
| 15 | 2014 | 2020 | 7 |

### 7.3 Implementation

In `scripts/count_deaths.R`, the check `if (year < 1999 + lag) next` skips the
year-lag combination and produces no output row. This logic is inside the function, so
the main loop in `run_analysis.R` does not need to be modified if the year range changes.

---

## 8. Known Limitations and Methodological Decisions

### 8.1 Analysis Stops at 2020: Bridged-Race Discontinuation

The most consequential methodological decision is the 2020 endpoint. NCHS discontinued
bridged-race data after 2020 because all states had adopted the 2003 death certificate.
As a result:

- The detail race field (positions 445–446) is entirely blank in 2021 and later files
  (confirmed: 0 of 3,472,120 records populated in 2021).
- The only race field available for 2021+ is Race Recode 40 (489–490), which uses
  race-alone definitions incompatible with the bridged-race approach used for 2000–2020.

Mixing bridged-race years (2000–2020) with race-alone years (2021+) would introduce an
estimated 8–10% AIAN undercount discontinuity in the three AIAN-only registries, where
race is the primary inclusion criterion. Stopping at 2020 maintains a consistent AIAN
definition across all analysis years.

If future analyses require 2021+ data, two options exist: (a) accept and document the
definitional discontinuity, or (b) reconstruct a bridged-race-equivalent AIAN population
for 2021+ using Race Recode 40 multi-race codes (16, 19, 20, 25–27, 31–33, 35–37, 39–40)
in addition to code 03. The `YEARS` parameter in `config.R` makes the year range easy to
change; the race routing in `readers.R` would also need to be updated.

### 8.2 Mixed-Race AIAN Definition

The bridged-race methodology assigns some mixed-race individuals to AIAN based on
probabilistic algorithms. The AIAN group in this analysis therefore includes individuals
who identified as AIAN plus another race. Whether SEER's AIAN-only registries observe
these individuals in the same way is an open question affecting the precision of the
NCHS–SEER match. The current implementation uses all records with bridged race code `"03"`,
consistent with how SEER has historically defined its AIAN populations.

### 8.3 State-by-State Adoption of the 2003 Death Certificate

Between 2003 and 2017, states transitioned gradually from the 1989 to the 2003 revision
of the death certificate. The detail race field (bridged) provides complete national
coverage regardless of which certificate format a state was using. Race Recode 40, by
contrast, was only populated for states already using the 2003 certificate. This is a
primary reason for preferring the bridged field for 2003–2020.

### 8.4 Detroit Registry End Date

The Detroit metropolitan area registry ceased contributing to SEER after 2018. Death
records from Macomb (099), Oakland (125), and Wayne (163) counties in Michigan are
included for 2000–2018 and excluded for 2019–2020. This is enforced by the `end = 2018`
field in Detroit's registry definition in `config.R`.

### 8.5 Geographic Coverage: County of Residence

NCHS records use county of **residence**, which is the correct unit for matching SEER's
population-based catchment areas. Records with county coded as "000" (foreign residents
with no US county of residence) do not match any registry definition and are automatically
excluded by the geography filter.

### 8.6 Unknown Hispanic Origin in AIAN Geographies

Records with unknown Hispanic origin (`"99"` historical; 996–999 standard) in AIAN
geographies are excluded from AIAN-only registries because non-Hispanic status cannot be
confirmed. The prevalence of unknown Hispanic origin in these geographies was not formally
quantified but is expected to be small.

### 8.7 Unknown or Missing Values for Sex and Race

Records with sex codes other than the expected female code (`"2"` historical, `"F"`
standard) are excluded by the sex filter. Records whose state cannot be matched via the
FIPS crosswalk (e.g., territories not in the crosswalk) receive `NA` for state and are
excluded by the geography filter. These edge cases are expected to be rare and do not
affect the primary analysis populations.

### 8.8 County Boundary Definitions Assumed Stable

County FIPS codes used for the Seattle–Puget Sound, Detroit, and Cherokee Nation
registry definitions are treated as fixed throughout 2000–2020. County boundary changes
or FIPS reassignments that occurred during this period are not accounted for. FIPS
boundary changes are infrequent and unlikely to materially affect counts in these
well-established metropolitan or tribal areas.

---

## 9. Expected Output

### 9.1 Row Count

The output file (`outputs/nchs_death_counts.csv`) should contain exactly **840 rows**,
one per valid (year, age\_group, lag) combination after applying the year-lag constraint.

The structure is triangular: larger lags use fewer years.

| Lag | Years included | Rows (× 4 age groups) |
|-----|---------------|-----------------------|
| 1 | 21 (2000–2020) | 84 |
| 2 | 20 (2001–2020) | 80 |
| 3 | 19 (2002–2020) | 76 |
| 4 | 18 (2003–2020) | 72 |
| 5 | 17 (2004–2020) | 68 |
| 6 | 16 (2005–2020) | 64 |
| 7 | 15 (2006–2020) | 60 |
| 8 | 14 (2007–2020) | 56 |
| 9 | 13 (2008–2020) | 52 |
| 10 | 12 (2009–2020) | 48 |
| 11 | 11 (2010–2020) | 44 |
| 12 | 10 (2011–2020) | 40 |
| 13 | 9 (2012–2020) | 36 |
| 14 | 8 (2013–2020) | 32 |
| 15 | 7 (2014–2020) | 28 |
| **Total** | | **840** |

**Derivation:** 4 × Σ(k=1 to 15)[21 − (k−1)] = 4 × (21 + 20 + … + 7) = 4 × 210 = 840

### 9.2 Column Definitions

| Column | Type | Description |
|--------|------|-------------|
| `year` | integer | NCHS calendar year of death (2000–2020) |
| `age_group` | character | Baseline age group label: `"50-54"`, `"55-59"`, `"60-64"`, `"65-69"` |
| `lag` | integer | Follow-up lag in years (1–15) |
| `age_low` | integer | Lower bound of age window (inclusive) |
| `age_high` | integer | Upper bound of age window (inclusive) |
| `deaths` | integer | Count of female deaths meeting all filter criteria |

### 9.3 Post-Run Verification Checklist

After running `scripts/run_analysis.R`, verify:

```r
nrow(final_table) == 840          # correct row count
sum(is.na(final_table)) == 0      # no missing values

# Year-lag constraint: lag 1 has 21 rows per age group, lag 15 has 7
table(final_table$lag) / 4        # should be 21, 20, 19, ..., 7

# Registry checks
# AK, AZ, OK deaths should be non-zero but small (AIAN + non-Hispanic filter)
# MI deaths should be zero for 2019-2020 (Detroit ended 2018)
# No unexpected state codes (ZZ, GU, AS, PR, etc.)

# Age window internal consistency check
# These two cells must have identical death counts:
final_table[final_table$age_group == "50-54" & final_table$lag == 6, "deaths"] ==
final_table[final_table$age_group == "55-59" & final_table$lag == 1, "deaths"]
```

---

## 10. Data Quality Checks Performed

### 10.1 Validation Script Results

`scripts/validate_positions.R` sampled 100 random records from 2000, 2005, 2010, 2015,
2018, and 2021, tabulating all key fields. Key findings:

| Check | Year(s) | Result |
|-------|---------|--------|
| Record length | 2000 | 440 ✓ |
| Record length | 2005–2018 | 490 ✓ |
| Record length | 2021 | 817 ✓ (validation only; excluded from analysis) |
| Sex codes | 2000 | Only `"1"` and `"2"` ✓ |
| Sex codes | 2005–2021 | Only `"M"` and `"F"` ✓ |
| Age unit | 2000 | 99/100 = `"0"` (years); 1/100 = `"2"` (months, infant) ✓ |
| Age unit | 2003+ | Near-universal `"1"`; rare non-year codes for infants ✓ |
| Race detail 445–446 | 2021 | 100/100 blank — confirms 2020 endpoint decision |
| Race Recode 40 489–490 | 2010 | 100/100 blank |
| Race Recode 40 489–490 | 2015 | Clean values consistent with Race Recode 40 ✓ |
| ICD-10 pos 142–145 | 2000 | C900, J81, I219, I64, C349 — all valid ✓ |
| ICD-10 pos 146–149 | 2005–2018 | C349, I251, G309, F03, I500 — all valid ✓ |
| ICD-10 pos 146–149 | 2021 | U071 (COVID-19) present — correct for that year ✓ |
| Hispanic pos 80–81 | 2000 | 98/100 = `"00"` (Non-Hispanic) — consistent with Alabama demographics ✓ |
| Hispanic pos 484–486 | 2005–2021 | 89–98% Non-Hispanic (100–199) — plausible ✓ |

### 10.2 Full-File Race Field Population Check

To resolve uncertainty about the Race Recode 40 availability boundary and confirm the
2020 endpoint decision, all records in three critical years were scanned:

| Year | Total records | Detail race 445–446 populated | Race Recode 40 489–490 populated |
|------|---------------|-------------------------------|----------------------------------|
| 2012 | 2,547,864 | 2,547,864 (100%) | 2,547,864 (100%) |
| 2017 | 2,820,034 | 2,820,034 (100%) | 2,820,034 (100%) |
| 2021 | 3,472,120 | 0 (0%) | 3,472,120 (100%) |

Findings: (a) detail race is fully populated through at least 2017, supporting its use
through 2020; (b) Race Recode 40 was also fully populated in 2012 and 2017, meaning both
fields coexisted during those years; (c) detail race is completely absent in 2021,
confirming that 2020 is the last year the bridged race field can be used.

### 10.3 AIAN Count Comparison: Detail Race vs Race Recode 40

Full-file scans quantified the difference between race field definitions:

| Year | AIAN via detail race (445–446) | AIAN via Race Recode 40 (489–490) | Difference |
|------|-------------------------------|-----------------------------------|------------|
| 2012 | 16,556 | 15,466 | −1,090 (−6.6%) |
| 2017 | 20,425 | 18,618 | −1,807 (−8.9%) |
| 2021 | 0 (field blank) | 28,984 | — |

The growing gap from 6.6% to 8.9% reflects increasing multi-race reporting as more states
adopted the 2003 death certificate. These multi-race AIAN individuals are captured by
bridging (detail race) but not by Race Recode 40 code `"03"`. The 2021 count of 28,984
under Race Recode 40 cannot be directly compared to prior years under either field,
reflecting both real population change and the definitional shift.
