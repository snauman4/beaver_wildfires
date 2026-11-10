# 01_groundtruth.R
# Single entry point that assembles the ground-truth database end to end.
# The actual work is split across R/00-09 (one file per source, plus
# assembly/report) for readability -- see docs/WEEK1_README.md for the
# map. This script just runs the whole thing and writes
# data/groundtruth_beaver.gpkg, matching `targets::tar_make()`.
#
# Usage:  Rscript R/01_groundtruth.R

lapply(list.files(here::here("R"), pattern = "\\.R$", full.names = TRUE),
       function(f) if (!grepl("01_groundtruth\\.R$", f)) source(f))

groundtruth <- assemble_groundtruth(list(
  source_eeager(),
  source_wyoming_dams(),
  source_usgs_tualatin(),
  source_owri_bda(),
  source_gbif(),
  source_inat(),
  source_local()
))

summary_stats <- summarise_groundtruth(groundtruth)
assess_readiness(summary_stats)
map_groundtruth(groundtruth)

invisible(groundtruth)
