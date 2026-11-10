# 06_source_inat.R
# iNaturalist research-grade Castor canadensis observations, western US.
#
# IMPORTANT: same caveat as GBIF (R/05_source_gbif.R) -- these are ANIMAL
# sightings, not dams. type = "beaver_sighting", confidence = "low" always.
# GBIF aggregates iNaturalist's "research grade" records too, so there is
# real overlap between the two sources; the 50 m dedupe step in
# R/05_assemble.R will collapse duplicates recorded by both.
#
# ACCESS: pulled live via the iNaturalist API (api.inaturalist.org/v1/
# observations), quality_grade=research, one bounding-box query per state
# (10 western states, per_page=200). This is what the rinat package wraps
# -- called directly here since rinat's underlying httr calls hit the same
# endpoint. Saved as compact CSV in data/raw/inat_compact/ (raw per-state
# JSON responses were >100 MB total and are not retained).

INAT_CSV <- file.path(DIR_RAW, "inat_compact", "inat_castor_canadensis.csv")

source_inat <- function(csv = INAT_CSV) {
  if (!file.exists(csv)) {
    message("[inat] missing ", csv); return(NULL)
  }
  d <- readr::read_csv(csv, show_col_types = FALSE)
  d <- d[!is.na(d$lon) & !is.na(d$lat), ]

  acc <- dplyr::coalesce(d$positional_accuracy, 1000)
  n0 <- nrow(d)
  keep <- acc <= 1000
  d <- d[keep, ]; acc <- acc[keep]
  message("[inat] dropped ", n0 - nrow(d), " records with accuracy > 1000 m or unknown")

  tibble::tibble(
    id            = paste0("inat_", d$id),
    lon           = d$lon,
    lat           = d$lat,
    type          = "beaver_sighting",
    confidence    = "low",
    source        = "iNaturalist research-grade Castor canadensis observations",
    source_url    = d$uri,
    date_observed = suppressWarnings(as.Date(d$observed_on)),
    spatial_acc_m = acc,
    # NOT d$state: that's the state whose rectangular bounding box we
    # queried, which can catch slivers of neighbouring states. Real state
    # comes from the point-in-polygon join in R/08_assemble.R.
    state         = NA_character_,
    notes         = paste0("animal sighting, not a dam; place: ",
                           stringr::str_trunc(d$place_guess, 80))
  ) |>
    dplyr::distinct(id, .keep_all = TRUE) |>
    check_schema("inat")
}
