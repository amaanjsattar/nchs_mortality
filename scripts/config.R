# config.R
# ========
# Central configuration for the NCHS mortality analysis pipeline.
# All parameters that may need adjustment live here. Other scripts
# source() this file and rely on these objects being defined.
#
# Key decisions documented here:
#   - YEARS stops at 2020 because NCHS bridged-race data (detail race field
#     445-446) is entirely blank in 2021. Extending to 2021 would require
#     switching to Race Recode 40 (489-490), which undercounts AIAN by ~9%
#     and is inconsistent with the bridged-race denominators used in SEER.
#     See docs/METHODS.md Section 3.4 for full rationale.
#   - Analysis is restricted to FEMALE deaths only (to match the SEER
#     breast cancer cohort).

# ---------------------------------------------------------------------------
# Year range
# ---------------------------------------------------------------------------
# To extend the analysis, change the upper bound here. Before doing so,
# verify that the detail race field (445-446) is populated in the new years.
YEARS <- 2000:2020

# ---------------------------------------------------------------------------
# File system
# ---------------------------------------------------------------------------
BASE_DIR   <- "/Users/amaanjsattar/nchs_mortality/data_raw"
OUTPUT_DIR <- "/Users/amaanjsattar/nchs_mortality/outputs"

# ---------------------------------------------------------------------------
# Sex filter — females only
# Field positions and codes differ by era:
#   Historical (2000-2002): position 59, code "2" = Female
#   Standard   (2003-2020): position 69, code "F" = Female
# ---------------------------------------------------------------------------
SEX_CODE_HISTORICAL <- "2"
SEX_CODE_STANDARD   <- "F"

# ---------------------------------------------------------------------------
# Race — AIAN identification
# Code "03" = American Indian / Alaska Native across ALL eras.
# Detail race field (60-61 historical; 445-446 standard) is used throughout.
# Race Recode 40 (489-490) is NOT used in this analysis.
# ---------------------------------------------------------------------------
AIAN_CODES <- c("03")

# ---------------------------------------------------------------------------
# Hispanic origin — non-Hispanic codes
# Used only for AIAN-only registries (AK, AZ, OK Cherokee Nation):
# those registries require race "03" AND non-Hispanic.
#
#   Historical (2000-2002): positions 80-81, "00" = Non-Hispanic
#   Standard   (2003-2020): positions 484-486, integer 100-199 = Non-Hispanic
# ---------------------------------------------------------------------------
NON_HISP_HISTORICAL <- "00"
NON_HISP_STD_LOW    <- 100L
NON_HISP_STD_HIGH   <- 199L

# ---------------------------------------------------------------------------
# Baseline age groups
# ---------------------------------------------------------------------------
BASELINE_GROUPS <- list(
  list(label = "50-54", low = 50),
  list(label = "55-59", low = 55),
  list(label = "60-64", low = 60),
  list(label = "65-69", low = 65)
)

# ---------------------------------------------------------------------------
# Lag windows
# ---------------------------------------------------------------------------
LAGS <- 1:15

# ---------------------------------------------------------------------------
# Cause-of-death (COD) filter
# ---------------------------------------------------------------------------
# Controls which deaths are counted. Set to NULL (or "all_cause") to include
# all causes. Set to a named group from configs/cod_groups.R, or a character
# vector of multiple group names whose deaths will be combined (OR logic).
#
# Examples:
#   COD_FILTER <- NULL                            # all-cause (default)
#   COD_FILTER <- "breast_cancer"                 # breast cancer deaths only
#   COD_FILTER <- c("breast_cancer", "diabetes")  # breast cancer OR diabetes
#   COD_FILTER <- "other_nonbreast_cancers"       # all C-codes except breast
#
# COD_GROUPS is defined in configs/cod_groups.R, which is sourced by run_analysis.R.
COD_FILTER <- NULL

# ---------------------------------------------------------------------------
# FIPS-to-postal crosswalk for historical files (2000-2002)
# ---------------------------------------------------------------------------
FIPS_TO_POSTAL <- c(
  "01"="AL","02"="AK","04"="AZ","05"="AR","06"="CA",
  "08"="CO","09"="CT","10"="DE","11"="DC","12"="FL",
  "13"="GA","15"="HI","16"="ID","17"="IL","18"="IN",
  "19"="IA","20"="KS","21"="KY","22"="LA","23"="ME",
  "24"="MD","25"="MA","26"="MI","27"="MN","28"="MS",
  "29"="MO","30"="MT","31"="NE","32"="NV","33"="NH",
  "34"="NJ","35"="NM","36"="NY","37"="NC","38"="ND",
  "39"="OH","40"="OK","41"="OR","42"="PA","44"="RI",
  "45"="SC","46"="SD","47"="TN","48"="TX","49"="UT",
  "50"="VT","51"="VA","53"="WA","54"="WV","55"="WI",
  "56"="WY"
)

# ---------------------------------------------------------------------------
# Registry definitions
# =====================
# Each registry entry defines:
#   state     : 2-letter postal code as it appears in NCHS files
#   counties  : 3-digit FIPS county codes; NULL = entire state
#   start/end : years this registry actively contributed to SEER
#   aian_only : if TRUE, filter to AIAN AND non-Hispanic deaths only
#
# Notes:
#   - GA, CA: multiple sub-registries tile the full state; treated as one entry
#   - Detroit (MI) ended SEER contribution in 2018
#   - AK, AZ, OK Cherokee Nation: SEER observes AIAN population only;
#     non-Hispanic filter added per advisor guidance
#   - State of RESIDENCE is used throughout (not state of occurrence)
# ---------------------------------------------------------------------------
REGISTRIES <- list(
  list(state = "CT", counties = NULL, start = 2000, end = 2020, aian_only = FALSE),
  list(state = "HI", counties = NULL, start = 2000, end = 2020, aian_only = FALSE),
  list(state = "IA", counties = NULL, start = 2000, end = 2020, aian_only = FALSE),
  list(state = "NJ", counties = NULL, start = 2000, end = 2020, aian_only = FALSE),
  list(state = "NM", counties = NULL, start = 2000, end = 2020, aian_only = FALSE),
  list(state = "NY", counties = NULL, start = 2000, end = 2020, aian_only = FALSE),
  list(state = "UT", counties = NULL, start = 2000, end = 2020, aian_only = FALSE),
  list(state = "KY", counties = NULL, start = 2000, end = 2020, aian_only = FALSE),
  list(state = "LA", counties = NULL, start = 2000, end = 2020, aian_only = FALSE),
  list(state = "IL", counties = NULL, start = 2000, end = 2020, aian_only = FALSE),
  list(state = "ID", counties = NULL, start = 2000, end = 2020, aian_only = FALSE),
  list(state = "TX", counties = NULL, start = 2000, end = 2020, aian_only = FALSE),
  list(state = "GA", counties = NULL, start = 2000, end = 2020, aian_only = FALSE),
  list(state = "CA", counties = NULL, start = 2000, end = 2020, aian_only = FALSE),

  # Seattle-Puget Sound: 13 specific Washington counties
  # Clallam, Grays Harbor, Island, Jefferson, King, Kitsap, Mason,
  # Pierce, San Juan, Skagit, Snohomish, Thurston, Whatcom
  list(state = "WA",
       counties = c("009","027","029","031","033","035","045",
                    "053","055","057","061","067","073"),
       start = 2000, end = 2020, aian_only = FALSE),

  # Detroit: 3 specific Michigan counties (Macomb, Oakland, Wayne)
  # Ended SEER contribution in 2018
  list(state = "MI",
       counties = c("099","125","163"),
       start = 2000, end = 2018, aian_only = FALSE),

  # Alaska: entire state, AIAN + non-Hispanic only
  list(state = "AK", counties = NULL, start = 2000, end = 2020, aian_only = TRUE),

  # Arizona Indians: entire state, AIAN + non-Hispanic only
  list(state = "AZ", counties = NULL, start = 2000, end = 2020, aian_only = TRUE),

  # Cherokee Nation: 14 specific Oklahoma counties, AIAN + non-Hispanic only
  # Adair, Cherokee, Craig, Delaware, Mayes, McIntosh, Muskogee,
  # Nowata, Ottawa, Rogers, Sequoyah, Tulsa, Wagoner, Washington
  list(state = "OK",
       counties = c("001","021","035","041","091","097","101",
                    "105","115","131","135","143","145","147"),
       start = 2000, end = 2020, aian_only = TRUE)
)
