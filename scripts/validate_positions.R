# validate_positions.R
# ====================
# Reads a small random sample of records from key years and extracts all
# verified field positions so we can visually confirm they look correct
# before committing to the full refactor.
#
# Years sampled: 2000 (historical), 2005, 2010, 2015, 2018, 2021 (standard)
# Records per year: 100 (randomly sampled)
#
# Run this script and inspect the printed tables. Things to check:
#   - Sex: only "1"/"2" in 2000, only "M"/"F" in 2003+
#   - Race: plausible 2-digit codes; "03" present but rare
#   - Hispanic (historical): "00" dominant, occasional "01"-"05"
#   - Hispanic (standard): 3-digit numeric; "100"-"199" dominant
#   - ICD-10: looks like valid ICD-10 codes (letter + digits), not garbage
#   - Age: plausible integers; no 000 or 999 for adult records
#   - Race field boundary: check 2017 vs 2018 — both should show plausible "03" counts

BASE_DIR <- "/Users/amaanjsattar/nchs_mortality/data_raw"
N_SAMPLE  <- 100
set.seed(42)

# ---------------------------------------------------------------------------
# File path helper (copied from main script)
# ---------------------------------------------------------------------------
get_filepath <- function(year, base_dir) {
  all_items <- list.files(base_dir, pattern = as.character(year), full.names = TRUE)
  folders   <- all_items[file.info(all_items)$isdir]
  folders   <- folders[!grepl("\\.zip$", folders)]
  if (length(folders) == 0) stop(paste("No folder found for year", year))
  files <- list.files(folders[1], pattern = "US.*\\.txt$", full.names = TRUE)
  if (length(files) == 0) stop(paste("No US txt file found for year", year))
  files[1]
}

# ---------------------------------------------------------------------------
# Samplers — one per format era
# ---------------------------------------------------------------------------

# Historical format (2000-2002): 441-char records
sample_historical <- function(filepath, n) {
  lines <- readLines(filepath, warn = FALSE)
  idx   <- sample(seq_along(lines), min(n, length(lines)))
  lines <- lines[idx]

  data.frame(
    year       = substr(lines, 115, 118),
    state_fips = substr(lines, 44, 45),
    county     = substr(lines, 33, 35),
    sex        = substr(lines, 59, 59),
    age_unit   = substr(lines, 64, 64),
    age_val    = substr(lines, 65, 66),
    race       = substr(lines, 60, 61),
    hispanic   = substr(lines, 80, 81),
    icd10      = substr(lines, 142, 145),
    rec_len    = nchar(lines),
    stringsAsFactors = FALSE
  )
}

# Standard format (2003-2021): 490 or 817-char records
# Race field: 445-446 for 2003-2017, 489-490 for 2018-2021
sample_standard <- function(filepath, year, n) {
  lines <- readLines(filepath, warn = FALSE)
  idx   <- sample(seq_along(lines), min(n, length(lines)))
  lines <- lines[idx]

  race_detail  <- substr(lines, 445, 446)
  race_recode40 <- substr(lines, 489, 490)

  data.frame(
    year          = substr(lines, 102, 105),
    state         = substr(lines, 29, 30),
    county        = substr(lines, 35, 37),
    sex           = substr(lines, 69, 69),
    age_unit      = substr(lines, 70, 70),
    age_val       = substr(lines, 71, 73),
    race_detail   = race_detail,
    race_recode40 = race_recode40,
    hispanic_raw  = substr(lines, 484, 486),
    icd10         = substr(lines, 146, 149),
    rec_len       = nchar(lines),
    stringsAsFactors = FALSE
  )
}

# ---------------------------------------------------------------------------
# Main validation loop
# ---------------------------------------------------------------------------

years_to_check <- c(2000, 2005, 2010, 2015, 2018, 2021)

for (yr in years_to_check) {
  cat("\n")
  cat(strrep("=", 70), "\n")
  cat(sprintf("YEAR %d\n", yr))
  cat(strrep("=", 70), "\n")

  filepath <- get_filepath(yr, BASE_DIR)
  cat("File:", basename(filepath), "\n\n")

  if (yr <= 2002) {
    df <- sample_historical(filepath, N_SAMPLE)

    cat("--- Record length distribution ---\n")
    print(table(df$rec_len))

    cat("\n--- Sex (pos 59): expect '1'=Male, '2'=Female ---\n")
    print(table(df$sex, useNA = "ifany"))

    cat("\n--- Age unit (pos 64): expect '0'=years ---\n")
    print(table(df$age_unit, useNA = "ifany"))

    cat("\n--- Age value (pos 65-66): sample of adults ---\n")
    adult_ages <- df$age_val[df$age_unit == "0"]
    cat(sprintf("  Range: %s – %s  |  Mean: %.1f\n",
                min(adult_ages, na.rm = TRUE),
                max(adult_ages, na.rm = TRUE),
                mean(as.integer(adult_ages), na.rm = TRUE)))

    cat("\n--- Race (pos 60-61): expect 2-digit codes; '03'=AIAN ---\n")
    print(sort(table(df$race, useNA = "ifany"), decreasing = TRUE))

    cat("\n--- Hispanic origin (pos 80-81): expect '00'=Non-Hisp dominant ---\n")
    print(sort(table(df$hispanic, useNA = "ifany"), decreasing = TRUE))

    cat("\n--- ICD-10 (pos 142-145): sample of 10 codes ---\n")
    cat(" ", paste(trimws(sample(df$icd10, min(10, nrow(df)))), collapse = "  "), "\n")

  } else {
    df <- sample_standard(filepath, yr, N_SAMPLE)

    cat("--- Record length distribution ---\n")
    print(table(df$rec_len))

    cat("\n--- Sex (pos 69): expect 'M'=Male, 'F'=Female ---\n")
    print(table(df$sex, useNA = "ifany"))

    cat("\n--- Age unit (pos 70): expect '1'=years ---\n")
    print(table(df$age_unit, useNA = "ifany"))

    cat("\n--- Age value (pos 71-73): sample of adults ---\n")
    adult_ages <- df$age_val[df$age_unit == "1"]
    cat(sprintf("  Range: %s – %s  |  Mean: %.1f\n",
                min(adult_ages, na.rm = TRUE),
                max(adult_ages, na.rm = TRUE),
                mean(as.integer(adult_ages), na.rm = TRUE)))

    cat("\n--- Race (detail, pos 445-446): expect 2-digit codes; '03'=AIAN ---\n")
    print(sort(table(df$race_detail, useNA = "ifany"), decreasing = TRUE))

    cat("\n--- Race Recode 40 (pos 489-490): blank pre-2018, '03'=AIAN from 2018 ---\n")
    print(sort(table(df$race_recode40, useNA = "ifany"), decreasing = TRUE))

    cat("\n--- Hispanic origin (pos 484-486): expect 3-digit; '100'-'199'=Non-Hisp ---\n")
    hisp_int <- as.integer(df$hispanic_raw)
    cat(sprintf("  Non-Hispanic (100-199): %d / %d\n",
                sum(hisp_int >= 100 & hisp_int <= 199, na.rm = TRUE), nrow(df)))
    cat(sprintf("  Hispanic     (200-299): %d / %d\n",
                sum(hisp_int >= 200 & hisp_int <= 299, na.rm = TRUE), nrow(df)))
    cat(sprintf("  Unknown      (996-999): %d / %d\n",
                sum(hisp_int >= 996, na.rm = TRUE), nrow(df)))
    cat(sprintf("  Other/NA:               %d / %d\n",
                sum(is.na(hisp_int) | hisp_int < 100 | (hisp_int > 299 & hisp_int < 996), na.rm = FALSE), nrow(df)))

    cat("\n--- ICD-10 (pos 146-149): sample of 10 codes ---\n")
    cat(" ", paste(trimws(sample(df$icd10, min(10, nrow(df)))), collapse = "  "), "\n")
  }
}

cat("\n")
cat(strrep("=", 70), "\n")
cat("VALIDATION COMPLETE\n")
cat("Review each section above before proceeding with refactor.\n")
cat(strrep("=", 70), "\n")
