# run_analysis.R
# ==============
# Main pipeline: reads NCHS mortality files, applies filters, counts deaths.
#
# Output: outputs/nchs_death_counts.csv
#   Columns: year, age_group, lag, age_low, age_high, deaths
#   Expected rows: 840  (4 age groups × 210 valid year-lag combinations)
#
# Usage:
#   Rscript scripts/run_analysis.R
#   or source("scripts/run_analysis.R") from an R session
#
# After running, check:
#   - nrow(final_table) == 840
#   - sum(is.na(final_table)) == 0
#   - Death counts for 2000-2002 are in the same ballpark as adjacent years
#   - AK, AZ, OK counts are non-zero (AIAN filter working)
#   - Michigan disappears after 2018 (registry end date)

# ---------------------------------------------------------------------------
# Source modules
# ---------------------------------------------------------------------------
# Locate the scripts/ directory regardless of how this file is invoked.
# Works with: Rscript scripts/run_analysis.R  (from project root)
#             source("scripts/run_analysis.R") (from an R session at project root)
#             source() from within the scripts/ directory

this_file <- tryCatch(
  normalizePath(sys.frame(1)$ofile),
  error = function(e) {
    # Rscript sets --file= in commandArgs
    args <- commandArgs(trailingOnly = FALSE)
    match <- grep("--file=", args, value = TRUE)
    if (length(match)) normalizePath(sub("--file=", "", match[1])) else NA_character_
  }
)

script_dir <- if (!is.na(this_file)) {
  dirname(this_file)
} else {
  # Fall back: assume working directory is the project root
  file.path(getwd(), "scripts")
}

source(file.path(script_dir, "config.R"))
source(file.path(script_dir, "readers.R"))
source(file.path(script_dir, "filters.R"))
source(file.path(script_dir, "count_deaths.R"))

project_dir <- dirname(script_dir)
source(file.path(project_dir, "configs", "cod_groups.R"))

# ---------------------------------------------------------------------------
# Main loop
# ---------------------------------------------------------------------------
all_counts <- vector("list", length(YEARS))

for (i in seq_along(YEARS)) {
  yr <- YEARS[i]
  cat(sprintf("[%d/%d] Processing %d\n", i, length(YEARS), yr))

  filepath <- get_filepath(yr, BASE_DIR)

  # Read raw records
  df <- if (yr <= 2002) {
    read_nchs_year_historical(filepath)
  } else {
    read_nchs_year_standard(filepath)
  }

  # Filter: females only
  df <- apply_sex_filter(df, yr)

  # Filter: SEER registry geographies (AIAN-only registries also filter race + ethnicity)
  df <- apply_geo_filter(df, REGISTRIES, yr)

  # Filter: cause of death (COD_FILTER = NULL means all-cause, no filtering)
  df <- apply_cod_filter(df, COD_FILTER)

  # Count deaths by age window and lag
  all_counts[[i]] <- count_deaths(df, yr)
}

# ---------------------------------------------------------------------------
# Assemble and write output
# ---------------------------------------------------------------------------
final_table <- do.call(rbind, Filter(Negate(is.null), all_counts))
rownames(final_table) <- NULL

output_path <- file.path(OUTPUT_DIR, "nchs_death_counts.csv")
write.csv(final_table, output_path, row.names = FALSE)
cat(sprintf("\nOutput written to: %s\n", output_path))

# ---------------------------------------------------------------------------
# Sanity checks
# ---------------------------------------------------------------------------
cat(sprintf("Total rows:    %d  (expected 840)\n", nrow(final_table)))
cat(sprintf("NA values:     %d  (expected 0)\n",  sum(is.na(final_table))))
cat(sprintf("Years covered: %d  (%d to %d)\n",
            length(unique(final_table$year)),
            min(final_table$year),
            max(final_table$year)))
cat(sprintf("Age groups:    %s\n",
            paste(unique(final_table$age_group), collapse = ", ")))
cat(sprintf("Lags:          %d to %d\n",
            min(final_table$lag), max(final_table$lag)))

cat("\nRows per lag (year-lag constraint — should decrease from 21 to 7):\n")
print(table(final_table$lag))

cat("\nSample rows:\n")
print(head(final_table, 12))
