library(targets)
tar_option_set(packages = c("sf", "dplyr", "tidyr", "purrr", "stringr", "readr",
                            "tibble", "janitor", "httr2", "jsonlite", "glue",
                            "lubridate", "leaflet", "htmlwidgets", "ggplot2",
                            "here", "tigris", "xml2"))

lapply(list.files("R", pattern = "\\.R$", full.names = TRUE), source)

list(
  # ---- ground-truth sources (week 1) ----
  tar_target(eeager,        source_eeager()),        # 1,362 expert-mapped natural dams (HydroShare)
  tar_target(wyoming_dams,  source_wyoming_dams()),   # 719 expert-mapped natural dams, WY (HydroShare)
  tar_target(usgs_tualatin, source_usgs_tualatin()),  # 510 natural dams, OR (USGS ScienceBase)
  tar_target(owri_bda,      source_owri_bda()),       # confirmed BDA installations, OR (OWEB)
  tar_target(gbif,          source_gbif()),           # beaver sightings, weak/low confidence
  tar_target(inat,          source_inat()),           # beaver sightings, weak/low confidence
  tar_target(local_src,     source_local()),          # manual/local hand-pulls (none yet)

  tar_target(groundtruth,
             assemble_groundtruth(list(eeager, wyoming_dams, usgs_tualatin,
                                       owri_bda, gbif, inat, local_src))),

  tar_target(summary_stats, summarise_groundtruth(groundtruth)),
  tar_target(readiness,     assess_readiness(summary_stats)),
  tar_target(gt_map,        map_groundtruth(groundtruth))
)
