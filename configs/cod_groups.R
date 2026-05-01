# cod_groups.R
# ============
# ICD-10 cause-of-death prefix lists for use with apply_cod_filter().
#
# Each entry in COD_GROUPS is a character vector of ICD-10 prefixes.
# Matching is prefix-based: a death record matches if its 4-character ICD-10
# underlying-cause field (trimmed of trailing spaces) starts with any prefix
# in the list. Prefixes can be 1–4 characters long.
#
# Special case: "other_nonbreast_cancers"
#   Not representable as a prefix list because it is defined by exclusion
#   (all C-chapter codes except breast cancer). apply_cod_filter() handles
#   this case directly — do NOT add it to this list.
#
# Special case: "all_cause"
#   Entry is NULL — apply_cod_filter() returns df unchanged when it sees NULL.
#
# Source: Adapted from SEER Cause-of-Death Recode documentation and
#         Afifi et al. Table 2 ICD-10 groupings.

COD_GROUPS <- list(

  # -------------------------------------------------------------------------
  # Neoplasms
  # -------------------------------------------------------------------------

  # Female breast cancer (C50.0–C50.6, C50.8–C50.9)
  # Positions 60-61 in ICD-10 are subsite; "C507" (nipple) is excluded per
  # standard SEER breast cancer definition.
  breast_cancer = c("C500", "C501", "C502", "C503", "C504",
                    "C505", "C506", "C508", "C509"),

  # "other_nonbreast_cancers" is handled as a special case in apply_cod_filter()
  # (all ICD-10 codes beginning with "C" that are not in breast_cancer).

  # -------------------------------------------------------------------------
  # Infectious / endocrine
  # -------------------------------------------------------------------------

  septicemia = c("A40", "A41"),

  diabetes   = c("E10", "E11", "E12", "E13", "E14"),

  # -------------------------------------------------------------------------
  # Neurological
  # -------------------------------------------------------------------------

  alzheimer  = c("G30"),

  # -------------------------------------------------------------------------
  # Circulatory — heart
  # -------------------------------------------------------------------------

  # "Diseases of heart" mirrors the broad SEER COD recode category:
  #   Rheumatic heart disease     I00-I09
  #   Ischemic heart disease      I20-I25
  #   Pulmonary heart disease     I26-I28
  #   Other forms of heart dis.   I30-I51
  #   Other circulatory           I80-I99
  diseases_of_heart = c(
    "I00", "I01", "I02", "I05", "I06", "I07", "I08", "I09",   # rheumatic
    "I20", "I21", "I22", "I23", "I24", "I25",                  # ischemic
    "I26", "I27", "I28",                                        # pulmonary
    "I30", "I31", "I32", "I33", "I34", "I35", "I36", "I37", "I38", "I39",
    "I40", "I41", "I42", "I43", "I44", "I45", "I46", "I47", "I48", "I49",
    "I50", "I51",                                               # other heart
    "I80", "I81", "I82", "I83", "I85", "I86", "I87", "I88", "I89",
    "I95", "I96", "I97", "I98", "I99"                          # other circ.
  ),

  hypertension   = c("I10", "I11", "I12", "I13", "I15"),

  # -------------------------------------------------------------------------
  # Circulatory — cerebrovascular / vascular
  # -------------------------------------------------------------------------

  cerebrovascular = c("I60", "I61", "I62", "I63", "I64",
                      "I65", "I66", "I67", "I68", "I69"),

  atherosclerosis = c("I70"),

  # Other arterial disease (I70-I78); note I70 is also in atherosclerosis
  other_arterial  = c("I70", "I71", "I72", "I73", "I74", "I75",
                      "I76", "I77", "I78"),

  # -------------------------------------------------------------------------
  # Respiratory
  # -------------------------------------------------------------------------

  pneumonia_influenza = c("J09", "J10", "J11", "J12", "J13", "J14",
                           "J15", "J16", "J17", "J18"),

  copd = c("J40", "J41", "J42", "J43", "J44", "J45", "J46", "J47"),

  # -------------------------------------------------------------------------
  # Digestive / renal
  # -------------------------------------------------------------------------

  chronic_liver_disease = c("K70", "K73", "K74"),

  nephritis = c("N00", "N01", "N02", "N03", "N04", "N05", "N06", "N07",
                "N17", "N18", "N19",
                "N25", "N26", "N27"),

  # -------------------------------------------------------------------------
  # External causes
  # -------------------------------------------------------------------------

  # Accidents / unintentional injuries (V01-X59 + Y85-Y86)
  # Single-char "V" and "W" capture entire chapters; "X0"-"X5" capture X00-X59.
  accidents = c("V", "W", "X0", "X1", "X2", "X3", "X4", "X5", "Y85", "Y86"),

  # Intentional self-harm (X60-X84, Y87.0, U03)
  suicide = c("U03",
              "X60", "X61", "X62", "X63", "X64", "X65", "X66", "X67", "X68", "X69",
              "X70", "X71", "X72", "X73", "X74", "X75", "X76", "X77", "X78", "X79",
              "X80", "X81", "X82", "X83", "X84", "Y870"),

  # -------------------------------------------------------------------------
  # Sentinel — no filtering
  # -------------------------------------------------------------------------

  all_cause = NULL
)
