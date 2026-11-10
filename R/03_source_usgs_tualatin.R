# 03_source_usgs_tualatin.R
# USGS ScienceBase: "Beaver dam locations in the Tualatin Basin, Oregon,
# between 2011 and 2019" (item 59e67550e4b05fe04cd1ebbb)
#
# WHAT IT IS
#   USGS compiled beaver-dam sightings reported by 13 local watershed
#   groups/agencies around Portland, OR into a single ArcGIS point
#   shapefile. 510 point locations, each with a report date, reporting
#   source, and free-text notes (often including dam status/size).
#   Published USGS ScienceBase item, official government data release.
#
# CONFIDENCE: medium -- crowd-sourced from local orgs, GPS method is
# "Unknown" for many records, but coordinates are recorded as points
# (not project centroids) and dates are per-dam.
#
# LICENSE: US Government work, public domain.

TUALATIN_SHP <- file.path(
  DIR_RAW, "usgs_tualatin",
  "Beaver_dam_locations_in_the_Tualatin_Basin_Oregon_between_2011_and_2019_Version2.shp"
)

source_usgs_tualatin <- function(shp = TUALATIN_SHP) {
  if (!file.exists(shp)) {
    message("[usgs_tualatin] missing ", shp); return(NULL)
  }
  x <- sf::st_read(shp, quiet = TRUE) |>
    sf::st_zm(drop = TRUE) |>
    sf::st_transform(CRS_WGS84)
  xy <- sf::st_coordinates(x)

  tibble::tibble(
    id            = sprintf("tualatin_%04d", seq_len(nrow(x))),
    lon           = xy[, 1],
    lat           = xy[, 2],
    type          = "natural_dam",
    confidence    = "medium",
    source        = "USGS ScienceBase: Tualatin Basin, OR beaver dam locations 2011-2019",
    source_url    = "https://www.sciencebase.gov/catalog/item/59e67550e4b05fe04cd1ebbb",
    date_observed = suppressWarnings(as.Date(x$Date)),
    spatial_acc_m = 30,
    state         = "OR",
    notes         = paste0("reported by: ", x$Source, "; ", x$Notes) |>
      stringr::str_trunc(200)
  ) |>
    check_schema("usgs_tualatin")
}
