# filters.R
# =========
# Filtering functions applied to NCHS records after reading.
# Expects config.R to have been sourced.
#
# Filter order in the pipeline:
#   1. apply_sex_filter()  — keep females only
#   2. apply_geo_filter()  — keep records in active SEER registries
#                            (AIAN-only registries also apply race + ethnicity filter)
#
# Both functions return a subset of the input data frame.

# ---------------------------------------------------------------------------
# Sex filter — females only
# ---------------------------------------------------------------------------
# Sex coding differs by era:
#   Historical (2000-2002): "2" = Female  (position 59)
#   Standard   (2003-2020): "F" = Female  (position 69)
# The reader stores the sex character in column `sex` regardless of era.

apply_sex_filter <- function(df, year) {
  female_code <- if (year <= 2002) SEX_CODE_HISTORICAL else SEX_CODE_STANDARD
  df[!is.na(df$sex) & df$sex == female_code, ]
}

# ---------------------------------------------------------------------------
# Non-Hispanic helper
# ---------------------------------------------------------------------------
# Returns a logical vector: TRUE where the record is non-Hispanic.
# Used internally by apply_geo_filter for AIAN-only registries.
#
# Hispanic coding differs by era:
#   Historical (2000-2002): 2-char field, "00" = Non-Hispanic
#   Standard   (2003-2020): 3-char numeric field, 100-199 = Non-Hispanic

is_non_hispanic <- function(df, year) {
  if (year <= 2002) {
    df$hispanic_raw == NON_HISP_HISTORICAL
  } else {
    hisp_int <- suppressWarnings(as.integer(df$hispanic_raw))
    !is.na(hisp_int) & hisp_int >= NON_HISP_STD_LOW & hisp_int <= NON_HISP_STD_HIGH
  }
}

# ---------------------------------------------------------------------------
# Geography filter
# ---------------------------------------------------------------------------
# For each record, checks whether it falls within any active SEER registry
# for the given year. A record matches a registry if:
#   1. State matches
#   2. County matches (or registry covers all counties)
#   3. If aian_only = TRUE: race is AIAN ("03") AND ethnicity is non-Hispanic
#
# Records with NA state (territory records not in FIPS crosswalk) never match.

apply_geo_filter <- function(df, registries, year) {
  active <- Filter(function(r) year >= r$start & year <= r$end, registries)
  non_hisp <- is_non_hispanic(df, year)
  in_seer  <- rep(FALSE, nrow(df))

  for (reg in active) {
    state_match  <- !is.na(df$state) & df$state == reg$state
    county_match <- if (is.null(reg$counties)) {
      rep(TRUE, nrow(df))
    } else {
      df$county %in% reg$counties
    }
    aian_match <- if (reg$aian_only) {
      df$race_field %in% AIAN_CODES & non_hisp
    } else {
      rep(TRUE, nrow(df))
    }
    in_seer <- in_seer | (state_match & county_match & aian_match)
  }

  df[in_seer, ]
}

# ---------------------------------------------------------------------------
# ICD-10 prefix matcher
# ---------------------------------------------------------------------------
# Returns a logical vector of length nrow(df): TRUE where df$icd10 starts with
# any prefix in `prefix_list`. Trailing spaces in the 4-character ICD-10 field
# are stripped before comparison, so 3-char codes (e.g. "I70 ") match "I70".
#
# Works with prefixes of any length (1-4 characters), enabling range captures
# like "V" (all V-chapter codes) or "X0" (X00-X09).

icd10_matches_prefix <- function(df_icd10, prefix_list) {
  codes <- trimws(df_icd10)
  Reduce(`|`, lapply(prefix_list, function(p) startsWith(codes, p)))
}

# ---------------------------------------------------------------------------
# Cause-of-death filter
# ---------------------------------------------------------------------------
# Filters df to rows whose underlying-cause ICD-10 code matches the requested
# cause(s). Expects COD_GROUPS to be defined (sourced from configs/cod_groups.R).
#
# Arguments:
#   df          : data frame with column `icd10`
#   filter_names: NULL, "all_cause", a single group name, or a character vector
#                 of group names (deaths matching ANY listed group are kept)
#
# Special group "other_nonbreast_cancers":
#   All ICD-10 codes beginning with "C" that are NOT in breast_cancer.
#   Cannot be expressed as a simple prefix list, so it is handled explicitly.

apply_cod_filter <- function(df, filter_names) {
  # NULL or "all_cause" → no filtering
  if (is.null(filter_names)) return(df)
  filter_names <- filter_names[filter_names != "all_cause"]
  if (length(filter_names) == 0) return(df)

  mask <- rep(FALSE, nrow(df))

  for (fname in filter_names) {
    if (fname == "other_nonbreast_cancers") {
      is_c      <- startsWith(trimws(df$icd10), "C")
      is_breast <- icd10_matches_prefix(df$icd10, COD_GROUPS[["breast_cancer"]])
      mask <- mask | (is_c & !is_breast)
    } else {
      prefixes <- COD_GROUPS[[fname]]
      if (is.null(prefixes)) {
        stop(sprintf("apply_cod_filter: unknown COD group '%s'", fname))
      }
      mask <- mask | icd10_matches_prefix(df$icd10, prefixes)
    }
  }

  df[mask, ]
}
