# 01_source_eeager.R
# Fairfax et al. 2023 EEAGER model (10.1029/2022JG007196) -- ground-truth
# beaver dam locations released alongside the paper.
#
# WHAT WE FOUND
#   The paper's Data Availability Statement says the full 13,344-dam
#   training set is NOT public (poaching/trapping risk). But it points to
#   a HydroShare deposit (Fairfax, E. 2022, EEAGERModel,
#   http://www.hydroshare.org/resource/17c9b293214641bea6948ae0d8facaeb,
#   CC BY 4.0) that contains:
#     - FairfaxEtAl_EEAGER_DataS2_TrainingDataSample.csv: a 300-row RANDOM
#       SAMPLE of the training data (100 Positive dam points, 100
#       PseudoNegative, 100 AssumedNegative). We take only the 100
#       Positive rows.
#     - EEAGER_EvaluationPolygons.kmz: the actual mapped dam locations
#       (as short line features, the dam crest) inside the paper's 12 held
#       -out evaluation polygons (A-L). Feature counts per polygon match
#       Table 1 of the paper exactly (1,262 dams total), so this is
#       verified to be the real evaluation data, not a placeholder.
#
#   A second, later HydroShare resource (Fairfax, E. 2025, "Beaver Dam
#   Locations: Cluster + Surface Water",
#   http://www.hydroshare.org/resource/f078d94b1f99460f8f374dbe018a01bc,
#   CC BY-NC 4.0) republishes the same 12-polygon evaluation set
#   (EEAGER_DamTraces.kmz -- confirmed identical feature counts) plus a
#   NEW Wyoming supplemental dataset, handled separately in
#   R/02_source_wyoming_dams.R.
#
# GEOMETRY
#   Dams are digitised as short LineStrings (the dam crest), not points.
#   We take the line midpoint (mean of vertex coordinates -- sf::st_line_
#   sample() segfaults on this machine's GDAL build).
#
#   Paper Table 2 lists eval-polygon locations as A-G Colorado, H Montana,
#   I Nevada, J Oregon, K Washington, L Wyoming, BUT the KML's own K/L
#   folder letters turn out to be swapped relative to the paper (verified:
#   KML "K_DamsHabitat" has 189 features matching Table 2's polygon L
#   count, not K's 43; a spot-check of its coordinates lands in WA, not
#   WY). So we do NOT hardcode state from the polygon letter -- state is
#   left NA here and filled in by the real point-in-polygon join against
#   Census state boundaries in R/08_assemble.R.
#
# CONFIDENCE
#   high -- expert-mapped from sub-0.2 m imagery specifically to serve as
#   ML ground truth in a peer-reviewed, published model.
#
# LICENSE
#   CC BY 4.0 (HydroShare resource 17c9b293...). Cite Fairfax (2022) and
#   Fairfax et al. (2023).

EEAGER_EVAL_KML   <- file.path(DIR_RAW, "eeager", "extracted",
                               "EEAGER_EvaluationPolygons.kml")
EEAGER_SAMPLE_CSV <- file.path(DIR_RAW, "eeager",
                               "FairfaxEtAl_EEAGER_DataS2_TrainingDataSample.csv")

#' Convert the "<Letter>_DamsHabitat" line layers to point midpoints
eeager_eval_dams <- function(kml = EEAGER_EVAL_KML) {
  if (!file.exists(kml)) {
    message("[eeager_eval] missing ", kml); return(NULL)
  }
  layers <- sf::st_layers(kml)$name
  dam_layers <- grep("_DamsHabitat$", layers, value = TRUE)

  out <- purrr::map_dfr(dam_layers, function(lyr) {
    poly_letter <- sub("_DamsHabitat$", "", lyr)
    x <- sf::st_read(kml, layer = lyr, quiet = TRUE) |> sf::st_zm(drop = TRUE)
    x <- x[sf::st_geometry_type(x) == "LINESTRING", ]
    if (!nrow(x)) return(NULL)
    # sf::st_line_sample() segfaults on this GDAL build (CPL_gdal_linestring_
    # sample) -- average the vertex coordinates of each line instead, which
    # is equivalent for the short, near-straight dam-crest lines here.
    xy <- t(vapply(sf::st_geometry(x), function(g) colMeans(sf::st_coordinates(g)[, 1:2, drop = FALSE]),
                   numeric(2)))
    tibble::tibble(
      id            = sprintf("eeager_eval_%s_%03d", poly_letter, seq_len(nrow(x))),
      lon           = xy[, 1],
      lat           = xy[, 2],
      type          = "natural_dam",
      confidence    = "high",
      source        = "Fairfax et al. 2023 EEAGER evaluation-polygon dams (HydroShare)",
      source_url    = "http://www.hydroshare.org/resource/17c9b293214641bea6948ae0d8facaeb",
      date_observed = as.Date(NA),
      spatial_acc_m = 5,
      state         = NA_character_,
      notes         = paste0("digitised dam crest, KML layer ", poly_letter,
                             "_DamsHabitat; imagery dated 2022 per paper Section 2.1.4")
    )
  })
  out
}

#' The 100 "Positive" rows from the public training-data sample
eeager_sample_dams <- function(csv = EEAGER_SAMPLE_CSV) {
  if (!file.exists(csv)) {
    message("[eeager_sample] missing ", csv); return(NULL)
  }
  d <- readr::read_csv(csv, show_col_types = FALSE) |>
    janitor::clean_names() |>
    dplyr::filter(type == "Positive")

  tibble::tibble(
    id            = sprintf("eeager_sample_%03d", seq_len(nrow(d))),
    lon           = d$lon,
    lat           = d$lat,
    type          = "natural_dam",
    confidence    = "high",
    source        = "Fairfax et al. 2023 EEAGER training-data sample (HydroShare)",
    source_url    = "http://www.hydroshare.org/resource/17c9b293214641bea6948ae0d8facaeb",
    date_observed = as.Date(NA),
    spatial_acc_m = 5,
    state         = NA_character_,
    notes         = "random public sample of the 13,344-dam training set (dates 2014-2021 per paper, not per-point)"
  )
}

source_eeager <- function() {
  out <- dplyr::bind_rows(eeager_eval_dams(), eeager_sample_dams())
  if (is.null(out) || !nrow(out)) return(NULL)
  check_schema(out, "eeager")
}
