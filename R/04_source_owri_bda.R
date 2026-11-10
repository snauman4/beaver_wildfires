# 04_source_owri_bda.R
# Oregon Watershed Restoration Inventory (OWRI) -- confirmed BDA
# installation projects.
#
# ACCESS
#   OWRI is published as a single ArcGIS Hub feature service (hosted by
#   Oregon_Explorer_OSU). The Hub item id 256068a8d687464eb565a004d10a63b2
#   resolves (via https://www.arcgis.com/sharing/rest/content/items/<id>
#   ?f=json) to:
#     https://services1.arcgis.com/CD5mKowwN6nIaqd8/arcgis/rest/services/
#     project_owri_2024/FeatureServer
#   Queried directly (curl, not R's httr2/curl -- R's curl package could
#   not complete the TLS CONNECT through this sandbox's proxy for this
#   host, even though shell curl and other R network calls worked; see
#   docs/source_log.md) and saved to data/raw/owri_beaver.geojson.
#
# FILTER
#   Of 21,922 total OWRI restoration projects, 175 mention "beaver" in the
#   project name and 39 specifically mention "BDA" or "beaver dam analog"
#   in the derived project description. We use only the 39 BDA-specific
#   records as ground truth -- the broader "beaver" set includes generic
#   beaver management (e.g. exclusion fencing, trapping) that is not dam
#   construction and would misrepresent BDA presence.
#
# GEOMETRY
#   OWRI features are project-area POLYGONS, not individual structures.
#   We use the polygon centroid and flag low positional accuracy
#   (+/- 250 m) accordingly -- this is a real, documented limitation of
#   the source, not an error in this script.
#
# CONFIDENCE: medium (official state restoration-tracking database, but
# reach/project-level location precision).
# LICENSE: Oregon public data (OWEB); see
# https://www.oregon.gov/oweb/data-reporting/pages/owri.aspx

OWRI_GEOJSON <- file.path(DIR_RAW, "owri_beaver.geojson")

source_owri_bda <- function(f = OWRI_GEOJSON) {
  if (!file.exists(f)) {
    message("[owri_bda] missing ", f); return(NULL)
  }
  x <- sf::st_read(f, quiet = TRUE)

  bda_kw <- "BDA|BEAVER DAM ANALOG"
  is_bda <- grepl(bda_kw, toupper(x$project_name)) |
    grepl(bda_kw, toupper(x$drvd_project_description))
  x <- x[is_bda, ]
  if (!nrow(x)) return(NULL)

  cent <- sf::st_centroid(sf::st_zm(x, drop = TRUE))
  xy <- sf::st_coordinates(cent)

  tibble::tibble(
    id            = sprintf("owri_bda_%04d", seq_len(nrow(x))),
    lon           = xy[, 1],
    lat           = xy[, 2],
    type          = "bda",
    confidence    = "medium",
    source        = "Oregon Watershed Restoration Inventory (OWEB) -- confirmed BDA projects",
    source_url    = "https://www.oregonwaterdata.org/maps/256068a8d687464eb565a004d10a63b2",
    date_observed = suppressWarnings(as.Date(paste0(x$complete_year, "-07-01"))),
    spatial_acc_m = 250,
    state         = "OR",
    notes         = paste0(x$project_name, " (", x$county, " Co.); ",
                           stringr::str_trunc(x$drvd_project_description, 150))
  ) |>
    check_schema("owri_bda")
}
