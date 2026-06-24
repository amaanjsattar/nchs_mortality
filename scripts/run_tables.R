# run_tables.R
# ============
# Generates combined deaths + population tables for all cause-of-death groups.
#
# For each COD group defined in configs/cod_groups.R (plus all-cause),
# this script counts deaths from the NCHS files, computes population
# denominators from Census intercensal/postcensal data, and joins them.
#
# Output: outputs/nchs_smr_table.csv
#   Columns: cod_group, year, age_group, lag, age_low, age_high, deaths, population
#   Rows: n_cod_groups × 840  (840 = 4 age groups × 210 valid year-lag pairs)
#
# Usage:
#   Rscript scripts/run_tables.R
#   or source("scripts/run_tables.R") from an R session at project root
#
# Runtime: ~5-10 minutes (reads 21 NCHS files once per COD group would be
#   slow; this script reads each year's file ONCE and counts all COD groups
#   simultaneously, then joins with pre-computed denominators).

# ---------------------------------------------------------------------------
# Source modules
# ---------------------------------------------------------------------------
this_file <- tryCatch(
  normalizePath(sys.frame(1)$ofile),
  error = function(e) {
    args  <- commandArgs(trailingOnly = FALSE)
    match <- grep("--file=", args, value = TRUE)
    if (length(match)) normalizePath(sub("--file=", "", match[1])) else NA_character_
  }
)

script_dir <- if (!is.na(this_file)) {
  dirname(this_file)
} else {
  file.path(getwd(), "scripts")
}

source(file.path(script_dir, "config.R"))
source(file.path(script_dir, "readers.R"))
source(file.path(script_dir, "filters.R"))
source(file.path(script_dir, "count_deaths.R"))
source(file.path(script_dir, "get_population.R"))

project_dir <- dirname(script_dir)
source(file.path(project_dir, "configs", "cod_groups.R"))

# ---------------------------------------------------------------------------
# Determine COD groups to run
# ---------------------------------------------------------------------------
# Run all named groups plus all-cause (NULL).
# "other_nonbreast_cancers" is handled specially by apply_cod_filter().
cod_group_names <- c(names(COD_GROUPS), "other_nonbreast_cancers")
# all_cause is already in COD_GROUPS with value NULL; remove the
# separately-named entry to avoid running it twice.
cod_group_names <- unique(cod_group_names)

cat(sprintf("COD groups to run: %d\n", length(cod_group_names)))
cat(paste(" ", cod_group_names, collapse = "\n"), "\n\n")

# ---------------------------------------------------------------------------
# Pre-compute population denominators (done once, shared across all COD groups)
# ---------------------------------------------------------------------------
cat("Computing population denominators...\n")
pop_tbl <- get_seer_population(POP_DIR, REGISTRIES, YEARS)
den_tbl <- compute_denominators(pop_tbl, BASELINE_GROUPS, LAGS, YEARS)
cat(sprintf("Denominators: %d rows\n\n", nrow(den_tbl)))

# ---------------------------------------------------------------------------
# Loop: one pass over NCHS files per year, counting all COD groups at once
# ---------------------------------------------------------------------------
# Strategy: for each year, read the file once, then for each COD group
# apply the filter and count deaths. This avoids re-reading 21 large files
# 18+ times.

all_death_counts <- vector("list", length(YEARS))

for (i in seq_along(YEARS)) {
  yr <- YEARS[i]
  cat(sprintf("[%d/%d] Processing year %d\n", i, length(YEARS), yr))

  filepath <- get_filepath(yr, BASE_DIR)

  df_raw <- if (yr <= 2002) {
    read_nchs_year_historical(filepath)
  } else {
    read_nchs_year_standard(filepath)
  }

  # Apply sex and geography filters (same for all COD groups)
  df_sex <- apply_sex_filter(df_raw, yr)
  df_geo <- apply_geo_filter(df_sex, REGISTRIES, yr)

  # Count deaths for each COD group
  year_counts <- vector("list", length(cod_group_names))
  for (j in seq_along(cod_group_names)) {
    grp_name <- cod_group_names[j]
    df_cod   <- apply_cod_filter(df_geo, grp_name)
    counts   <- count_deaths(df_cod, yr)
    if (!is.null(counts) && nrow(counts) > 0) {
      counts$cod_group <- grp_name
      year_counts[[j]] <- counts
    }
  }

  all_death_counts[[i]] <- do.call(rbind, Filter(Negate(is.null), year_counts))
}

deaths_tbl <- do.call(rbind, Filter(Negate(is.null), all_death_counts))
rownames(deaths_tbl) <- NULL
cat(sprintf("\nTotal death count rows: %d\n", nrow(deaths_tbl)))

# ---------------------------------------------------------------------------
# Join deaths with denominators
# ---------------------------------------------------------------------------
cat("Joining deaths with denominators...\n")

# den_tbl has no cod_group column; join on year, age_group, lag
merged <- merge(
  deaths_tbl,
  den_tbl[, c("year", "age_group", "lag", "population")],
  by  = c("year", "age_group", "lag"),
  all.x = TRUE
)

# Reorder columns
merged <- merged[, c("cod_group", "year", "age_group", "lag",
                     "age_low", "age_high", "deaths", "population")]
merged <- merged[order(merged$cod_group, merged$year,
                       merged$age_group, merged$lag), ]
rownames(merged) <- NULL

# ---------------------------------------------------------------------------
# Write output
# ---------------------------------------------------------------------------
output_path <- file.path(OUTPUT_DIR, "nchs_smr_table.csv")
write.csv(merged, output_path, row.names = FALSE)
cat(sprintf("Output written to: %s\n", output_path))

# ---------------------------------------------------------------------------
# Sanity checks
# ---------------------------------------------------------------------------
n_groups <- length(cod_group_names)
expected_rows <- n_groups * 840

cat(sprintf("\nTotal rows:    %d  (expected %d = %d groups x 840)\n",
            nrow(merged), expected_rows, n_groups))
cat(sprintf("NA deaths:     %d  (expected 0)\n", sum(is.na(merged$deaths))))
cat(sprintf("NA population: %d  (expected 0)\n", sum(is.na(merged$population))))
cat(sprintf("COD groups:    %s\n",
            paste(sort(unique(merged$cod_group)), collapse = ", ")))

cat("\nRow counts per COD group (all should be 840):\n")
print(table(merged$cod_group))

cat("\nSample rows (all_cause):\n")
print(head(merged[merged$cod_group == "all_cause", ], 8))
