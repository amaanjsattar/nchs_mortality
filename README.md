# NCHS Mortality Analysis for SEER SMR Calculations

Analysis of CDC NCHS Detailed Mortality data (2000-2020) to generate reference population death counts for standardized mortality ratio (SMR) calculations with SEER breast cancer registry data.

## Overview

This repository contains R code to process restricted-use NCHS mortality files, applying geographic and demographic filters to match SEER cancer registry coverage, and calculating death counts by age group and follow-up period.

## Requirements

- R (version 3.6+)
- Access to NCHS Detailed Mortality restricted-use files (2000-2020)
- Packages: none (base R only)

## Project Structure

nchs_mortality/
├── configs/          # Configuration files
├── scripts/          # R analysis scripts
├── outputs/          # Analysis results
└── docs/             # Documentation

## Usage

1. Place NCHS mortality data files in data_raw/ directory
2. Adjust parameters in configs/config.R if needed
3. Run: Rscript scripts/run_analysis.R
4. Output appears in outputs/nchs_death_counts.csv

## Data

NCHS Detailed Mortality Files are restricted-use and not included in this repository.

## Output

Generates death counts for females in SEER registry areas (2000-2020), by age group and lag period.

## Documentation

See docs/METHODS.md for detailed methodology.

## Author

Amaan Jogia-Sattar
