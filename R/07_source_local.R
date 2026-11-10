# 07_source_local.R
# Datasets that must be acquired by hand, dropped into data/raw/local/,
# and described in a small CSV manifest. Not fulfilled this week -- no
# files are present, so this returns NULL and contributes zero rows.
#
# This is where the following go once obtained:
#   - YOUR Little Beaver Creek / Cameron Peak BDA field sites (type = bda,
#     confidence = high, spatial_acc_m = 3 if GPS'd) -- your only Colorado
#     BDA points and highest-value addition available to you
#   - Utah Watershed Restoration Initiative BDA projects (wri.utah.gov;
#     no public API found -- export from the project search UI, or email
#     ugrc@utah.gov)
#   - Colorado BDA installations (CWCB Watershed Restoration Program, CPW,
#     Coalition for the Poudre River Watershed, Rocky Mountain NP)
#   - Coordinate tables from paper supplements
#
# MANIFEST FORMAT  data/raw/local/manifest.csv
#   file,type,confidence,source,source_url,spatial_acc_m,state,date_observed,notes
#   lbc_bdas.gpkg,bda,high,"CSU honors thesis field sites",https://...,3,CO,2025-08-01,"RTK GPS"
#
# RULE: never geocode a place name into a coordinate. If a source gives only
# a map figure or a stream name, log it as unusable in docs/source_log.md.

source_local <- function(dir = file.path(DIR_RAW, "local")) {
  man_path <- file.path(dir, "manifest.csv")
  if (!file.exists(man_path)) {
    message("[local] no manifest.csv -- see header of R/07_source_local.R")
    return(NULL)
  }
  man <- readr::read_csv(man_path, show_col_types = FALSE)

  out <- purrr::pmap_dfr(man, function(file, type, confidence, source,
                                       source_url, spatial_acc_m, state,
                                       date_observed, notes, ...) {
    fp <- file.path(dir, file)
    if (!file.exists(fp)) { message("[local] missing: ", file); return(NULL) }

    x <- if (grepl("\\.csv$", fp)) {
      d <- readr::read_csv(fp, show_col_types = FALSE) |> janitor::clean_names()
      stopifnot("csv needs lon/lat columns" = all(c("lon","lat") %in% names(d)))
      sf::st_as_sf(d, coords = c("lon","lat"), crs = CRS_WGS84)
    } else {
      sf::st_read(fp, quiet = TRUE)
    }

    x <- sf::st_transform(sf::st_zm(x, drop = TRUE), CRS_WGS84)
    if (!all(sf::st_geometry_type(x) == "POINT")) x <- sf::st_point_on_surface(x)
    xy <- sf::st_coordinates(x)

    tibble::tibble(
      id            = sprintf("local_%s_%04d",
                              tools::file_path_sans_ext(file), seq_len(nrow(x))),
      lon = xy[,1], lat = xy[,2],
      type = type, confidence = confidence,
      source = source, source_url = source_url,
      date_observed = suppressWarnings(as.Date(date_observed)),
      spatial_acc_m = as.numeric(spatial_acc_m),
      state = state, notes = notes
    )
  })

  if (is.null(out) || !nrow(out)) return(NULL)
  check_schema(out, "local")
}
