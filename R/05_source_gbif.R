# 05_source_gbif.R
# GBIF occurrence records for Castor canadensis, western US states.
#
# IMPORTANT: these are ANIMAL sightings, not dams. A beaver observation
# tells you a beaver was there; it does not locate a dam or complex.
# type = "beaver_sighting", confidence = "low" always. Use only to seed
# candidate areas for manual NAIP labelling / as a weak prior -- do NOT
# train a dam detector on them directly. Heavy observer-effort bias
# (density near cities reflects people, not beavers).
#
# ACCESS: pulled live via the GBIF REST API (api.gbif.org/v1/occurrence/
# search), one query per state, hasCoordinate=true &
# hasGeospatialIssue=false, limit=300/state (10 western states). Saved as
# compact CSV in data/raw/gbif_compact/ (raw per-state JSON responses were
# ~20 MB total and are not retained).

GBIF_CSV <- file.path(DIR_RAW, "gbif_compact", "gbif_castor_canadensis.csv")

source_gbif <- function(csv = GBIF_CSV) {
  if (!file.exists(csv)) {
    message("[gbif] missing ", csv); return(NULL)
  }
  d <- readr::read_csv(csv, show_col_types = FALSE)
  d <- d[!is.na(d$lon) & !is.na(d$lat), ]

  # drop very imprecise records -- useless as labels at fine imagery scale
  acc <- dplyr::coalesce(d$coordinateUncertaintyInMeters, 1000)
  n0 <- nrow(d)
  keep <- acc <= 1000
  d <- d[keep, ]; acc <- acc[keep]
  message("[gbif] dropped ", n0 - nrow(d), " records with accuracy > 1000 m or unknown")

  tibble::tibble(
    id            = paste0("gbif_", d$gbif_key),
    lon           = d$lon,
    lat           = d$lat,
    type          = "beaver_sighting",
    confidence    = "low",
    source        = "GBIF Castor canadensis occurrences",
    source_url    = "https://www.gbif.org",
    date_observed = suppressWarnings(as.Date(substr(d$eventDate, 1, 10))),
    spatial_acc_m = acc,
    # NOT d$state_abbr: that's the state we searched for via a rectangular
    # bounding query, which can catch slivers of neighbouring states (5.5%
    # mismatch rate observed). Real state comes from the point-in-polygon
    # join in R/08_assemble.R.
    state         = NA_character_,
    notes         = paste0("animal sighting, not a dam; ", d$basisOfRecord,
                           "; observer-effort biased")
  ) |>
    dplyr::distinct(id, .keep_all = TRUE) |>
    check_schema("gbif")
}
