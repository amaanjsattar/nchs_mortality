# get_population.R
# ================
# Loads Census Bureau intercensal/postcensal population estimates and
# computes SEER-footprint denominators for the SMR analysis.
#
# Census sources (all in POP_DIR / pop_data/):
#   State-level — wide format (AGEGRP / AGE columns, year in column names):
#     st-est00int-alldata.csv        : 2000-2009 intercensal  (col: AGEGRP)
#     sc-est2020int-alldata6.csv     : 2010-2019 intercensal  (col: AGE)
#     sc-est2024-alldata6.csv        : 2020 postcensal        (col: AGE)
#
#   County-level — long format (YEAR code column, AGEGRP column):
#     co-est00int-alldata-{26,40,53}.csv   : 2000-2009 county intercensal
#     cc-est2020int-alldata-{26,40,53}.csv : 2010-2019 county intercensal
#     cc-est2024-alldata-{26,40,53}.csv    : 2020 county postcensal
#   State FIPS: 26=MI, 40=OK, 53=WA
#
# Registry population rules:
#   Non-AIAN state registries (14 states): total female (SEX=2, RACE=0, ORIGIN=0)
#   AIAN state registries (AK, AZ):        NH AIAN female (SEX=2, RACE=3, ORIGIN=1)
#   Non-AIAN county registries (WA, MI):   TOT_FEMALE column
#   AIAN county registry (OK):             NHIA_FEMALE column
#
# Two exported functions:
#   get_seer_population(pop_dir, registries, years)
#     Returns data.frame(year, agegrp, population)
#     agegrp: 11=50-54, 12=55-59, ..., 17=80-84
#
#   compute_denominators(pop_tbl, baseline_groups, lags, years)
#     Applies within-band linear interpolation to convert 5-year Census bands
#     into 6-year age-window denominators for each (year, age_group, lag).
#     Returns data.frame(year, age_group, lag, age_low, age_high, population)
#
# Interpolation formula:
#   For lag k in baseline group starting at age a_low:
#     j = (k-1) mod 5
#     L = a_low + k - 1   (first age in the 6-year window)
#     band_start = floor(L/5)*5   (first age in the lower Census band)
#     agegrp_low = (band_start - 50)/5 + 11
#     N(a,k,t) = ((5-j)/5) * B_low(t) + ((j+1)/5) * B_high(t)
#   where B_low and B_high are the populations of agegrp_low and agegrp_low+1
#   in year t.  This is exact under the uniform within-band assumption.

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------

# 2-digit zero-padded state FIPS codes
.POSTAL_TO_FIPS <- c(
  AK="02", AZ="04", CA="06", CT="09", GA="13",
  HI="15", IA="19", ID="16", IL="17", KY="21",
  LA="22", MI="26", NJ="34", NM="35", NY="36",
  OK="40", TX="48", UT="49", WA="53"
)

# Age groups we care about: 11=50-54, 12=55-59, ..., 17=80-84
.TARGET_AGEGRP <- 11:17

# ---------------------------------------------------------------------------
# Internal: state-level helpers
# ---------------------------------------------------------------------------

# Read one state-level Census CSV (wide format) and return a long data.frame
# with columns: STATE (2-char FIPS), SEX, ORIGIN, RACE, agegrp, year, population.
#
# age_col  : name of the age-group column ("AGEGRP" or "AGE")
# year_cols: named character vector, names=calendar year, values=column name
#            e.g. c("2000"="POPESTIMATE2000", "2001"="POPESTIMATE2001")
.read_state_wide <- function(filepath, age_col, year_cols) {
  df <- read.csv(filepath, stringsAsFactors = FALSE,
                 colClasses = c(STATE = "character"))
  df$STATE <- sprintf("%02d", as.integer(df$STATE))

  # Rename age column to a canonical name
  names(df)[names(df) == age_col] <- "agegrp"

  # Keep only target age groups
  df <- df[df$agegrp %in% .TARGET_AGEGRP, ]

  result <- vector("list", length(year_cols))
  for (i in seq_along(year_cols)) {
    col  <- year_cols[i]
    yr   <- as.integer(names(year_cols)[i])
    if (!col %in% names(df)) next
    tmp <- df[, c("STATE", "SEX", "ORIGIN", "RACE", "agegrp", col)]
    names(tmp)[6] <- "population"
    tmp$year <- yr
    result[[i]] <- tmp
  }
  do.call(rbind, Filter(Negate(is.null), result))
}

# Extract total-female (SEX=2, RACE=0, ORIGIN=0) population for a set of states.
# Returns data.frame(year, agegrp, population) summed across those states.
.state_total_female <- function(state_long, fips_codes) {
  sub <- state_long[state_long$STATE  %in% fips_codes &
                      state_long$SEX    == 2 &
                      state_long$RACE   == 0 &
                      state_long$ORIGIN == 0, ]
  agg <- aggregate(population ~ year + agegrp, data = sub, FUN = sum)
  agg
}

# Extract NH-AIAN female (SEX=2, RACE=3, ORIGIN=1) population for a set of states.
# Returns data.frame(year, agegrp, population) summed across those states.
.state_nhia_female <- function(state_long, fips_codes) {
  sub <- state_long[state_long$STATE  %in% fips_codes &
                      state_long$SEX    == 2 &
                      state_long$RACE   == 3 &
                      state_long$ORIGIN == 1, ]
  agg <- aggregate(population ~ year + agegrp, data = sub, FUN = sum)
  agg
}

# ---------------------------------------------------------------------------
# Internal: county-level helpers
# ---------------------------------------------------------------------------

# Read one county-level Census CSV (long format) and return a long data.frame
# with columns: COUNTY (3-char FIPS), AGEGRP, year, TOT_FEMALE, NHIA_FEMALE.
#
# state_fips : 2-digit FIPS string (e.g. "26" for MI)
# year_map   : named integer vector, names=YEAR code, values=calendar year
#              e.g. c("2"=2000L, "3"=2001L, ..., "11"=2009L)
.read_county_long <- function(filepath, state_fips, year_map) {
  df <- read.csv(filepath, stringsAsFactors = FALSE,
                 colClasses = c(STATE  = "integer",
                                COUNTY = "character"))
  df$COUNTY <- sprintf("%03d", as.integer(df$COUNTY))

  df <- df[df$STATE == as.integer(state_fips) &
             df$YEAR  %in% as.integer(names(year_map)) &
             df$AGEGRP %in% .TARGET_AGEGRP, ]

  df$year <- year_map[as.character(df$YEAR)]

  keep_cols <- c("COUNTY", "AGEGRP", "year", "TOT_FEMALE")
  if ("NHIA_FEMALE" %in% names(df)) keep_cols <- c(keep_cols, "NHIA_FEMALE")

  df[, keep_cols]
}

# Sum a column across selected counties. Returns data.frame(year, agegrp, population).
.county_sum <- function(county_long, county_fips, pop_col) {
  sub <- county_long[county_long$COUNTY %in% county_fips, ]
  names(sub)[names(sub) == pop_col]  <- "population"
  names(sub)[names(sub) == "AGEGRP"] <- "agegrp"
  agg <- aggregate(population ~ year + agegrp, data = sub, FUN = sum)
  agg
}

# ---------------------------------------------------------------------------
# Internal: combine population across registries for one time slice
# ---------------------------------------------------------------------------

# Combine a list of (year, agegrp, population) data.frames by summing.
.sum_registries <- function(lst) {
  combined <- do.call(rbind, Filter(Negate(is.null), lst))
  agg <- aggregate(population ~ year + agegrp, data = combined, FUN = sum)
  agg
}

# ---------------------------------------------------------------------------
# Public: get_seer_population
# ---------------------------------------------------------------------------

#' Load and aggregate SEER-footprint population denominators.
#'
#' @param pop_dir  Path to the directory containing Census CSV files (POP_DIR).
#' @param registries  REGISTRIES list from config.R (used to determine active
#'   years for Detroit and to validate registry types).
#' @param years  Integer vector of calendar years (YEARS from config.R).
#' @return data.frame with columns year, agegrp, population.
#'   agegrp: 11=50-54, 12=55-59, 13=60-64, 14=65-69, 15=70-74, 16=75-79, 17=80-84.
#'   One row per (year, agegrp) combination; population is summed across all
#'   active SEER registries for that year.
get_seer_population <- function(pop_dir, registries, years) {

  # ---- State FIPS sets ------------------------------------------------
  # Non-AIAN whole-state registries: total female
  non_aian_state_fips <- .POSTAL_TO_FIPS[c(
    "CT","HI","IA","NJ","NM","NY","UT","KY","LA","IL","ID","TX","GA","CA"
  )]
  # AIAN whole-state registries: NH AIAN female
  aian_state_fips <- .POSTAL_TO_FIPS[c("AK","AZ")]

  # County registries
  wa_counties <- c("009","027","029","031","033","035","045",
                   "053","055","057","061","067","073")
  mi_counties <- c("099","125","163")
  ok_counties <- c("001","021","035","041","091","097","101",
                   "105","115","131","135","143","145","147")

  # Detroit (MI) registry end year
  mi_end <- 2018L

  # ---- Load state files -----------------------------------------------
  cat("  Loading state population files...\n")

  # 2000-2009 intercensal
  st00_cols <- setNames(
    paste0("POPESTIMATE", 2000:2009),
    as.character(2000:2009)
  )
  st00 <- .read_state_wide(
    file.path(pop_dir, "st-est00int-alldata.csv"),
    age_col   = "AGEGRP",
    year_cols = st00_cols
  )

  # 2010-2019 intercensal
  st1019_cols <- setNames(
    paste0("POPESTIMATE", 2010:2019),
    as.character(2010:2019)
  )
  st1019 <- .read_state_wide(
    file.path(pop_dir, "sc-est2020int-alldata6.csv"),
    age_col   = "AGE",
    year_cols = st1019_cols
  )

  # 2020 postcensal (Vintage 2024; POPESTIMATE2020 = July 1, 2020)
  st20_cols <- c("2020" = "POPESTIMATE2020")
  st20 <- .read_state_wide(
    file.path(pop_dir, "sc-est2024-alldata6.csv"),
    age_col   = "AGE",
    year_cols = st20_cols
  )

  # Combine all years into one state long table
  state_long <- rbind(st00, st1019, st20)
  # Restrict to requested years
  state_long <- state_long[state_long$year %in% years, ]

  # ---- State registry populations ------------------------------------
  non_aian_state_pop <- .state_total_female(state_long, non_aian_state_fips)
  aian_state_pop     <- .state_nhia_female(state_long, aian_state_fips)

  # ---- Load county files ---------------------------------------------
  cat("  Loading county population files...\n")

  # Year mappings for county long files
  # co-est00int: YEAR 2=2000, 3=2001, ..., 11=2009  (skip 1, 12, 13)
  yr_map_00 <- setNames(2000:2009, as.character(2:11))
  # cc-est2020int: YEAR 2=2010, 3=2011, ..., 11=2019  (skip 1, 12)
  yr_map_10 <- setNames(2010:2019, as.character(2:11))
  # cc-est2024: YEAR 2=2020  (skip 1)
  yr_map_20 <- c("2" = 2020L)

  # WA (non-AIAN counties) — 3 time slices
  wa00   <- .read_county_long(file.path(pop_dir, "co-est00int-alldata-53.csv"), "53", yr_map_00)
  wa1019 <- .read_county_long(file.path(pop_dir, "cc-est2020int-alldata-53.csv"), "53", yr_map_10)
  wa20   <- .read_county_long(file.path(pop_dir, "cc-est2024-alldata-53.csv"), "53", yr_map_20)
  wa_all <- rbind(wa00, wa1019, wa20)
  wa_all <- wa_all[wa_all$year %in% years, ]
  wa_pop <- .county_sum(wa_all, wa_counties, "TOT_FEMALE")

  # MI (non-AIAN counties, end 2018) — 3 time slices
  mi00   <- .read_county_long(file.path(pop_dir, "co-est00int-alldata-26.csv"), "26", yr_map_00)
  mi1019 <- .read_county_long(file.path(pop_dir, "cc-est2020int-alldata-26.csv"), "26", yr_map_10)
  # 2020 postcensal for MI not needed since registry ended 2018, but read anyway for consistency
  mi20   <- .read_county_long(file.path(pop_dir, "cc-est2024-alldata-26.csv"), "26", yr_map_20)
  mi_all <- rbind(mi00, mi1019, mi20)
  # Apply registry end-year constraint
  mi_all <- mi_all[mi_all$year %in% years & mi_all$year <= mi_end, ]
  mi_pop <- .county_sum(mi_all, mi_counties, "TOT_FEMALE")

  # OK (AIAN counties) — 3 time slices
  ok00   <- .read_county_long(file.path(pop_dir, "co-est00int-alldata-40.csv"), "40", yr_map_00)
  ok1019 <- .read_county_long(file.path(pop_dir, "cc-est2020int-alldata-40.csv"), "40", yr_map_10)
  ok20   <- .read_county_long(file.path(pop_dir, "cc-est2024-alldata-40.csv"), "40", yr_map_20)
  ok_all <- rbind(ok00, ok1019, ok20)
  ok_all <- ok_all[ok_all$year %in% years, ]
  ok_pop <- .county_sum(ok_all, ok_counties, "NHIA_FEMALE")

  # ---- Combine all registries ----------------------------------------
  cat("  Aggregating across registries...\n")
  pop <- .sum_registries(list(
    non_aian_state_pop,
    aian_state_pop,
    wa_pop,
    mi_pop,
    ok_pop
  ))

  # Ensure sorted output
  pop <- pop[order(pop$year, pop$agegrp), ]
  rownames(pop) <- NULL
  pop
}

# ---------------------------------------------------------------------------
# Public: compute_denominators
# ---------------------------------------------------------------------------

#' Convert 5-year Census band populations into 6-year window denominators.
#'
#' Uses a uniform within-band assumption to interpolate.  For lag k in
#' baseline group starting at age a_low, the 6-year window [a_low+k-1,
#' a_low+k+4] overlaps two consecutive 5-year Census bands B_low and B_high.
#'
#'   j          = (k - 1) mod 5
#'   N(a,k,t)   = ((5-j)/5) * B_low(t) + ((j+1)/5) * B_high(t)
#'
#' @param pop_tbl       Output of get_seer_population(): data.frame(year, agegrp, population).
#' @param baseline_groups  BASELINE_GROUPS from config.R.
#' @param lags          LAGS from config.R.
#' @param years         YEARS from config.R (used only to enforce year-lag constraint).
#' @return data.frame with columns:
#'   year, age_group (label), lag, age_low, age_high, population
#'   Rows satisfy the same year-lag constraint as the death counts:
#'   year >= 1999 + lag.
compute_denominators <- function(pop_tbl, baseline_groups, lags, years) {

  # Index pop_tbl for fast lookup: list keyed by year, then agegrp -> pop
  pop_index <- list()
  for (yr in unique(pop_tbl$year)) {
    sub <- pop_tbl[pop_tbl$year == yr, ]
    pop_index[[as.character(yr)]] <- setNames(sub$population, as.character(sub$agegrp))
  }

  results <- list()
  for (grp in baseline_groups) {
    a_low <- grp$low
    for (lag in lags) {
      for (yr in years) {
        # Year-lag constraint (matches count_deaths.R)
        if (yr < 1999 + lag) next

        j         <- (lag - 1) %% 5
        L         <- a_low + lag - 1          # first age in the 6-year window
        band_start <- floor(L / 5) * 5        # start age of lower Census band
        agegrp_lo  <- as.integer((band_start - 50) / 5 + 11)
        agegrp_hi  <- agegrp_lo + 1L

        yr_key <- as.character(yr)
        if (!yr_key %in% names(pop_index)) {
          warning(sprintf("No population data for year %d", yr))
          next
        }

        yr_pops  <- pop_index[[yr_key]]
        B_low    <- as.numeric(yr_pops[as.character(agegrp_lo)])
        B_high   <- as.numeric(yr_pops[as.character(agegrp_hi)])

        if (is.na(B_low) || is.na(B_high)) {
          warning(sprintf(
            "Missing AGEGRP %d or %d for year %d (a_low=%d, lag=%d)",
            agegrp_lo, agegrp_hi, yr, a_low, lag
          ))
          next
        }

        pop_val <- ((5 - j) / 5) * B_low + ((j + 1) / 5) * B_high

        results[[length(results) + 1]] <- data.frame(
          year       = yr,
          age_group  = grp$label,
          lag        = lag,
          age_low    = a_low + lag - 1,
          age_high   = a_low + lag + 4,
          population = pop_val,
          stringsAsFactors = FALSE
        )
      }
    }
  }

  out <- do.call(rbind, results)
  out <- out[order(out$year, out$age_group, out$lag), ]
  rownames(out) <- NULL
  out
}
