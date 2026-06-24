# cod_groups.R
# ============
# ICD-10 cause-of-death prefix lists for use with apply_cod_filter().
#
# SOURCE: Groups are based on the SEER Cause-of-Death Recode (verified against
#   Jay_ICD_Table.numbers, which contains the SEER recode lookup used in the
#   parallel analysis), cross-referenced with Afifi et al. (2020) Supporting
#   Table 1 (Afifi_SEER_ICD_Table.pages). Where SEER and Afifi diverged, the
#   SEER recode was followed for consistency with the parallel SEER analysis.
#
# KEY DECISION — hypertension vs. diseases of heart (I10-I15):
#   Afifi et al. placed I11 (hypertensive heart disease) and I13 (hypertensive
#   heart and renal disease) under "Diseases of Heart" and reserved I10 and I12
#   for "Hypertension without heart disease." The SEER COD recode groups all of
#   I10-I15 together as "Hypertensive disease," keeping heart codes (I00-I09,
#   I20-I51, I80-I99) separate. We follow the SEER recode. This decision is
#   documented in docs/METHODS.md §5.
#
# CHANGES FROM PRIOR VERSION (2026-06-23):
#   1. diseases_of_heart: Prior code enumerated individual rheumatic codes
#      (I00-I09) but omitted I03 and I04. Now uses the full 3-digit prefix list
#      I00-I09. Also expands I80-I99 to full SEER range (prior code omitted I84
#      and I90-I94). Hypertensive codes I10-I15 remain in `hypertension` per
#      SEER recode (not moved to diseases_of_heart as in Afifi).
#   2. hypertension: Unchanged in codes (I10-I11-I12-I13-I15). Comment updated
#      to clarify SEER recode basis and document that I14 does not exist in
#      ICD-10 (gap between I13 and I15).
#   3. atherosclerosis: Expanded from I70 only to I70-I78 to match SEER COD
#      recode "Atherosclerosis and other arterial diseases." I71 (aortic
#      aneurysm), listed as a standalone category in Afifi, is now covered here.
#   4. other_arterial: REMOVED. It was I70-I78 — now redundant with the
#      expanded atherosclerosis group. Removing prevents accidental double-
#      counting if both groups were ever requested together.
#   5. septicemia: Retained as-is (A40-A41). Name unchanged for backward
#      compatibility. SEER combines septicemia with HIV/other infectious
#      diseases; the two sub-groups are kept separate here to allow independent
#      analysis of each.
#   6. other_infectious: NEW. HIV disease (B20-B24). SEER combines this with
#      septicemia under "Other Infectious and Parasitic Diseases" for
#      confidentiality; listed separately here since we are working with NCHS
#      death records (not SEER incidence data).
#   7. in_situ_benign: NEW. In situ (D00-D09), benign (D10-D36), and uncertain-
#      behavior neoplasms (D37-D48), per Afifi Supporting Table 1. Prefixes
#      "D0"-"D4" also capture D49 (unspecified behavior), which is a reasonable
#      inclusion.
#   8. symptoms_signs: NEW. Symptoms, signs, and abnormal clinical/laboratory
#      findings (R00-R99). Corresponds to SEER "Symptoms, Signs and Ill-Defined
#      Conditions" and Afifi "Symptoms, signs, and abnormal clinical and
#      laboratory findings." Single prefix "R" captures the full chapter.
#
# HOW MATCHING WORKS:
#   Each group is a character vector of ICD-10 prefix strings. apply_cod_filter()
#   in scripts/filters.R retains a record if its 4-character ICD-10 underlying-
#   cause field (trailing spaces stripped) starts with any prefix in the list.
#   Prefixes may be 1-4 characters; shorter prefixes capture broader ranges
#   (e.g., "R" captures all of R00-R99; "I50" captures only I500-I509).
#
# SPECIAL CASES (not in this list, handled by apply_cod_filter directly):
#   "other_nonbreast_cancers" — all ICD-10 codes beginning with "C" that are
#      not in breast_cancer. Defined by exclusion; cannot be expressed as a
#      prefix list. apply_cod_filter() handles it explicitly.
#   "all_cause" / NULL — no filtering; apply_cod_filter() returns df unchanged.

COD_GROUPS <- list(

  # ---------------------------------------------------------------------------
  # Neoplasms
  # ---------------------------------------------------------------------------

  # Female breast cancer (C50.0-C50.6, C50.8-C50.9).
  # C50.7 (nipple and areola) excluded per standard SEER breast cancer
  # definition. Source: SEER COD recode 039.
  breast_cancer = c("C500", "C501", "C502", "C503", "C504",
                    "C505", "C506", "C508", "C509"),

  # "other_nonbreast_cancers" is a special case handled in apply_cod_filter()
  # (all ICD-10 codes beginning with "C" that are not in breast_cancer).

  # In situ, benign, and uncertain-behavior neoplasms (D00-D48).
  # Prefixes "D0"-"D4" capture D00-D49; D49 (unspecified behavior) is also
  # included. Source: Afifi Supporting Table 1 (D00-D09, D10-D36, D37-D48).
  in_situ_benign = c("D0", "D1", "D2", "D3", "D4"),

  # ---------------------------------------------------------------------------
  # Infectious / endocrine
  # ---------------------------------------------------------------------------

  # Septicemia (A40-A41). Source: SEER COD recode; Afifi Supporting Table 1.
  septicemia = c("A40", "A41"),

  # HIV disease (B20-B24). SEER groups this with septicemia as "Other
  # Infectious and Parasitic Diseases" for confidentiality in incidence data.
  # Kept separate here since NCHS death records carry no confidentiality
  # restriction at this level.
  other_infectious = c("B20", "B21", "B22", "B23", "B24"),

  # Diabetes mellitus (E10-E14). Source: SEER COD recode; Afifi Table 1.
  diabetes = c("E10", "E11", "E12", "E13", "E14"),

  # ---------------------------------------------------------------------------
  # Neurological
  # ---------------------------------------------------------------------------

  # Alzheimer disease (G30). Source: SEER COD recode; Afifi Supporting Table 1.
  alzheimer = c("G30"),

  # ---------------------------------------------------------------------------
  # Circulatory — heart
  # ---------------------------------------------------------------------------

  # "Diseases of heart" — SEER COD recode umbrella covering:
  #   Rheumatic heart disease     I00-I09  (full range; prior code omitted I03-I04)
  #   Ischemic heart disease      I20-I25
  #   Pulmonary heart disease     I26-I28
  #   Other forms of heart dis.   I30-I51
  #   Other circulatory dis.      I80-I99  (full range; prior code omitted I84, I90-I94)
  #
  # Hypertensive codes I10-I15 are NOT included here; they are in `hypertension`
  # below. Cerebrovascular/arterial I60-I78 are also excluded (separate groups).
  # This assignment follows the SEER COD recode. Afifi et al. moved I11 and I13
  # into this group and restricted hypertension to I10+I12 only; we follow SEER
  # instead for consistency with the parallel SEER*Stat analysis.
  # Source: SEER COD recode (Jay_ICD_Table.numbers); Afifi Supporting Table 1.
  diseases_of_heart = c(
    # Rheumatic heart diseases (I00-I09)
    "I00", "I01", "I02", "I03", "I04", "I05", "I06", "I07", "I08", "I09",
    # Ischemic heart diseases (I20-I25)
    "I20", "I21", "I22", "I23", "I24", "I25",
    # Pulmonary heart disease and diseases of pulmonary circulation (I26-I28)
    "I26", "I27", "I28",
    # Other forms of heart disease (I30-I51)
    "I30", "I31", "I32", "I33", "I34", "I35", "I36", "I37", "I38", "I39",
    "I40", "I41", "I42", "I43", "I44", "I45", "I46", "I47", "I48", "I49",
    "I50", "I51",
    # Other diseases of circulatory system (I80-I99)
    "I80", "I81", "I82", "I83", "I84", "I85", "I86", "I87", "I88", "I89",
    "I90", "I91", "I92", "I93", "I94", "I95", "I96", "I97", "I98", "I99"
  ),

  # Hypertensive disease (I10-I15). Note: I14 does not exist in ICD-10
  # (the code space jumps from I13 to I15), so the effective range is
  # I10, I11, I12, I13, I15. Per SEER COD recode. Afifi restricts hypertension
  # to I10+I12 only (moving I11+I13 to diseases_of_heart); we follow SEER.
  hypertension = c("I10", "I11", "I12", "I13", "I15"),

  # ---------------------------------------------------------------------------
  # Circulatory — cerebrovascular / arterial
  # ---------------------------------------------------------------------------

  # Cerebrovascular diseases (I60-I69). Source: SEER COD recode; Afifi Table 1.
  cerebrovascular = c("I60", "I61", "I62", "I63", "I64",
                      "I65", "I66", "I67", "I68", "I69"),

  # Atherosclerosis and other arterial diseases (I70-I78).
  # Per SEER COD recode, I70-I78 form a single arterial disease category.
  # I71 (aortic aneurysm and dissection), listed as a standalone category in
  # Afifi Table 2, is covered by this group.
  # CHANGE: Prior code had atherosclerosis = c("I70") only, and a separate
  # other_arterial = c("I70"-"I78") that overlapped it. Now consolidated into
  # one group matching the SEER recode range. other_arterial is removed.
  atherosclerosis = c("I70", "I71", "I72", "I73", "I74", "I75", "I76",
                      "I77", "I78"),

  # ---------------------------------------------------------------------------
  # Respiratory
  # ---------------------------------------------------------------------------

  # Pneumonia and influenza (J09-J18). Source: SEER COD recode; Afifi Table 1.
  pneumonia_influenza = c("J09", "J10", "J11", "J12", "J13", "J14",
                          "J15", "J16", "J17", "J18"),

  # Chronic obstructive pulmonary disease and allied conditions (J40-J47).
  # Source: SEER COD recode; Afifi Supporting Table 1.
  copd = c("J40", "J41", "J42", "J43", "J44", "J45", "J46", "J47"),

  # ---------------------------------------------------------------------------
  # Digestive / renal
  # ---------------------------------------------------------------------------

  # Chronic liver disease and cirrhosis (K70, K73, K74).
  # Source: SEER COD recode; Afifi Supporting Table 1.
  chronic_liver_disease = c("K70", "K73", "K74"),

  # Nephritis, nephrotic syndrome, and nephrosis.
  # Source: SEER COD recode; Afifi Supporting Table 1.
  nephritis = c("N00", "N01", "N02", "N03", "N04", "N05", "N06", "N07",
                "N17", "N18", "N19",
                "N25", "N26", "N27"),

  # ---------------------------------------------------------------------------
  # Symptoms and ill-defined
  # ---------------------------------------------------------------------------

  # Symptoms, signs, and abnormal clinical/laboratory findings (R00-R99).
  # Single prefix "R" captures the entire chapter.
  # Source: SEER "Symptoms, Signs and Ill-Defined Conditions";
  #   Afifi "Symptoms, signs, and abnormal clinical and laboratory findings."
  symptoms_signs = c("R"),

  # ---------------------------------------------------------------------------
  # External causes
  # ---------------------------------------------------------------------------

  # Accidents and adverse effects (V01-X59, Y85-Y86).
  # Per SEER COD recode these are one combined category. "V" and "W" capture
  # entire chapters; "X0"-"X5" capture X00-X59. Y85-Y86 are sequelae of
  # accidents. Source: SEER COD recode (Jay_ICD_Table.numbers).
  accidents = c("V", "W", "X0", "X1", "X2", "X3", "X4", "X5", "Y85", "Y86"),

  # Intentional self-harm / suicide (X60-X84, Y87.0, U03).
  # Source: SEER COD recode; Afifi Supporting Table 1.
  suicide = c("U03",
              "X60", "X61", "X62", "X63", "X64", "X65", "X66", "X67", "X68", "X69",
              "X70", "X71", "X72", "X73", "X74", "X75", "X76", "X77", "X78", "X79",
              "X80", "X81", "X82", "X83", "X84", "Y870"),

  # ---------------------------------------------------------------------------
  # Sentinel — no filtering
  # ---------------------------------------------------------------------------

  all_cause = NULL
)
