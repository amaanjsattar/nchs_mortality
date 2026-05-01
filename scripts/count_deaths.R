# count_deaths.R
# ==============
# Death counting function with age-window logic and year-lag constraint.
# Expects config.R to have been sourced (BASELINE_GROUPS, LAGS).
#
# Age window formula:
#   For baseline group starting at age `a` and lag `k`:
#     age_low  = a + (k - 1)
#     age_high = a + (k - 1) + 5
#   This is a 6-integer-age inclusive window that shifts up 1 year per lag.
#
#   Example (50-54 baseline):
#     Lag 1:  50-55   Lag 2:  51-56  ...  Lag 15: 64-69
#
# Year-lag constraint:
#   For lag k, only years >= (1999 + k) are valid. A death in year Y at lag k
#   corresponds to a cancer diagnosis in year Y - k + 1; diagnoses before 2000
#   are out of scope. Rows that do not satisfy this constraint are omitted from
#   the output entirely (not set to zero).
#
#   Constraint: year >= 1999 + lag
#   - Lag 1:  all years qualify   (2000 >= 2000)
#   - Lag 2:  year >= 2001        (19 years: 2001-2020)
#   - Lag 15: year >= 2014        ( 7 years: 2014-2020)
#   Total rows = 4 groups × Σ(k=1..15)(21-k+1) = 4 × 210 = 840
#
# Age unit filtering:
#   Historical (2000-2002): age_unit "0" = years
#   Standard   (2003-2020): age_unit "1" = years
#   Records not in years are excluded before counting.

count_deaths <- function(df, year) {
  # Keep only records where age is expressed in whole years
  year_unit <- if (year <= 2002) "0" else "1"
  df <- df[!is.na(df$age_unit) & df$age_unit == year_unit, ]

  results <- list()
  for (grp in BASELINE_GROUPS) {
    for (lag in LAGS) {
      # Year-lag constraint: skip if this year is too early for this lag
      if (year < 1999 + lag) next

      age_low  <- grp$low + (lag - 1)
      age_high <- grp$low + (lag - 1) + 5
      count    <- sum(!is.na(df$age_val) &
                        df$age_val >= age_low &
                        df$age_val <= age_high)

      results[[length(results) + 1]] <- data.frame(
        year      = year,
        age_group = grp$label,
        lag       = lag,
        age_low   = age_low,
        age_high  = age_high,
        deaths    = count,
        stringsAsFactors = FALSE
      )
    }
  }

  if (length(results) == 0) return(NULL)
  do.call(rbind, results)
}
