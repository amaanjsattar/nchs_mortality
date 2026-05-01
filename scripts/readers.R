# readers.R
# =========
# File-reading functions for NCHS Detailed Mortality fixed-width files.
# Expects config.R to have been sourced (uses FIPS_TO_POSTAL).
#
# Two format eras:
#   Historical (2000-2002): 440-character records
#   Standard   (2003-2020): 490-character records (2003-2019)
#                           817-character records (2020)
#                           Field positions are IDENTICAL in both; the extra
#                           characters in 2020 are appended fields and do not
#                           shift anything in positions 1-490.
#
# Verified field positions — see docs/METHODS.md Section 2 for full evidence.

# ---------------------------------------------------------------------------
# File path helper
# ---------------------------------------------------------------------------
# Locates the US mortality txt file for a given year.
# Skips PS (Puerto Rico/territories) file and zip archives.

get_filepath <- function(year, base_dir) {
  all_items <- list.files(base_dir, pattern = as.character(year),
                          full.names = TRUE)
  folders   <- all_items[file.info(all_items)$isdir]
  folders   <- folders[!grepl("\\.zip$", folders)]
  if (length(folders) == 0) stop(paste("No folder found for year", year))
  files <- list.files(folders[1], pattern = "US.*\\.txt$", full.names = TRUE)
  if (length(files) == 0) stop(paste("No US txt file found for year", year))
  files[1]
}

# ---------------------------------------------------------------------------
# Historical format reader (2000-2002)
# ---------------------------------------------------------------------------
# Verified positions:
#   Year:             115-118
#   State FIPS:        44-45  (numeric; converted to postal via FIPS_TO_POSTAL)
#   County:            33-35
#   Sex:               59     ("1"=Male, "2"=Female)
#   Age unit:          64     ("0"=years <100)
#   Age value:         65-66  (2-digit integer)
#   Race (detail):     60-61  ("03"=AIAN)
#   Hispanic origin:   80-81  ("00"=Non-Hispanic)
#   ICD-10 (UCOD):    142-145

read_nchs_year_historical <- function(filepath) {
  lines      <- readLines(filepath, warn = FALSE)
  state_fips <- substr(lines, 44, 45)
  data.frame(
    year          = as.integer(substr(lines, 115, 118)),
    state         = FIPS_TO_POSTAL[state_fips],
    county        = substr(lines, 33, 35),
    sex           = substr(lines, 59, 59),
    age_unit      = substr(lines, 64, 64),
    age_val       = as.integer(substr(lines, 65, 66)),
    race_field    = substr(lines, 60, 61),
    hispanic_raw  = substr(lines, 80, 81),
    icd10         = substr(lines, 142, 145),
    stringsAsFactors = FALSE
  )
}

# ---------------------------------------------------------------------------
# Standard format reader (2003-2020)
# ---------------------------------------------------------------------------
# Verified positions:
#   Year:                102-105
#   State:                29-30  (2-letter postal code)
#   County:               35-37
#   Sex:                  69     ("M"=Male, "F"=Female)
#   Age unit:             70     ("1"=years)
#   Age value:            71-73  (3-digit integer)
#   Race (detail):       445-446 ("03"=AIAN; bridged-race, available 2003-2020)
#   Hispanic origin:     484-486 (3-digit integer; 100-199 = Non-Hispanic)
#   ICD-10 (UCOD):       146-149
#
# NOTE: Race Recode 40 (positions 489-490) is NOT read here.
# The detail race field (445-446) is used for ALL years 2003-2020 to maintain
# consistency with the bridged-race denominators used in SEER population data.
# See docs/METHODS.md Section 3 for rationale.

read_nchs_year_standard <- function(filepath) {
  lines <- readLines(filepath, warn = FALSE)
  data.frame(
    year          = as.integer(substr(lines, 102, 105)),
    state         = substr(lines, 29, 30),
    county        = substr(lines, 35, 37),
    sex           = substr(lines, 69, 69),
    age_unit      = substr(lines, 70, 70),
    age_val       = as.integer(substr(lines, 71, 73)),
    race_field    = substr(lines, 445, 446),
    hispanic_raw  = substr(lines, 484, 486),
    icd10         = substr(lines, 146, 149),
    stringsAsFactors = FALSE
  )
}
