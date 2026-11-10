# 05_assemble.R -- harmonise, dedupe, QC, spatial joins, write the database

#' Deduplicate points within DEDUPE_M metres
#'
#' Sources overlap: an OWRI project polygon centroid and a field GPS point
#' can describe the same structure. We cluster in projected space and keep
#' one representative per cluster -- the highest-confidence, most precise one.
dedupe_points <- function(x, dist_m = DEDUPE_M) {
  xp <- sf::st_transform(x, CRS_ALBERS)

  # cluster by connected components of the <dist_m adjacency graph
  nb  <- sf::st_is_within_distance(xp, dist = dist_m)
  cmp <- integer(length(nb)); k <- 0L
  for (i in seq_along(nb)) {
    if (cmp[i] != 0L) next
    k <- k + 1L
    stack <- i
    while (length(stack)) {
      j <- stack[1]; stack <- stack[-1]
      if (cmp[j] != 0L) next
      cmp[j] <- k
      stack <- c(stack, setdiff(nb[[j]], which(cmp != 0L)))
    }
  }

  x$.cluster <- cmp
  n_before <- nrow(x)

  out <- x |>
    dplyr::mutate(
      .conf_rank = match(confidence, CONFIDENCE_LEVELS),
      .type_rank = match(type, TYPE_LEVELS)
    ) |>
    dplyr::group_by(.cluster) |>
    dplyr::arrange(.conf_rank, spatial_acc_m, .type_rank, .by_group = TRUE) |>
    dplyr::mutate(
      n_sources    = dplyr::n_distinct(source),
      merged_from  = paste(unique(source), collapse = " | ")
    ) |>
    dplyr::slice(1) |>
    dplyr::ungroup() |>
    dplyr::select(-.cluster, -.conf_rank, -.type_rank)

  message("dedupe: ", n_before, " -> ", nrow(out),
          " (", n_before - nrow(out), " merged at ", dist_m, " m)")
  out
}

#' Attach state and EPA Level III ecoregion
attach_context <- function(x) {
  # --- state ---
  states <- tryCatch({
    tigris::states(cb = TRUE, year = 2022, progress_bar = FALSE) |>
      sf::st_transform(CRS_WGS84) |>
      dplyr::select(state_join = STUSPS)
  }, error = function(e) { message("[context] tigris unavailable: ",
                                   conditionMessage(e)); NULL })

  if (!is.null(states)) {
    x <- sf::st_join(x, states, join = sf::st_intersects) |>
      dplyr::mutate(state = dplyr::coalesce(state, state_join)) |>
      dplyr::select(-state_join)
  }

  # --- EPA Level III ecoregion ---
  # Download once from
  #   https://www.epa.gov/eco-research/ecoregion-download-files-state-region
  # and unzip to data/raw/ecoregions/
  eco_dir <- file.path(DIR_RAW, "ecoregions")
  eco_f   <- list.files(eco_dir, pattern = "\\.shp$", full.names = TRUE)

  if (length(eco_f)) {
    eco <- sf::st_read(eco_f[1], quiet = TRUE) |>
      sf::st_transform(CRS_WGS84) |>
      sf::st_make_valid()
    name_col <- grep("^US_L3NAME$|L3NAME", names(eco), value = TRUE)[1]
    eco <- dplyr::select(eco, ecoregion_l3 = dplyr::all_of(name_col))
    s2_was_on <- sf::sf_use_s2()
    sf::sf_use_s2(FALSE)
    on.exit(sf::sf_use_s2(s2_was_on), add = TRUE)
    x <- sf::st_join(x, eco, join = sf::st_intersects)
  } else {
    message("[context] no ecoregion shapefile in ", eco_dir,
            " -- ecoregion_l3 left NA")
    x$ecoregion_l3 <- NA_character_
  }

  x
}

#' Western montane / intermountain Level III ecoregions -- the transfer
#' domain we are willing to train on for a Colorado application.
WESTERN_MONTANE_L3 <- c(
  "Southern Rockies", "Middle Rockies", "Northern Rockies",
  "Idaho Batholith", "Canadian Rockies", "Wasatch and Uinta Mountains",
  "Arizona/New Mexico Mountains", "Colorado Plateaus",
  "Wyoming Basin", "Central Basin and Range", "Northern Basin and Range",
  "Blue Mountains", "Eastern Cascades Slopes and Foothills",
  "Sierra Nevada", "High Plains", "Southwestern Tablelands"
)

assemble_groundtruth <- function(sources) {
  raw <- dplyr::bind_rows(purrr::compact(sources))
  if (!nrow(raw)) stop("No sources returned any rows.")

  sf_pts <- sf::st_as_sf(raw, coords = c("lon", "lat"), crs = CRS_WGS84,
                         remove = FALSE)

  out <- sf_pts |>
    dedupe_points() |>
    attach_context() |>
    dplyr::mutate(
      type       = factor(type, levels = TYPE_LEVELS),
      confidence = factor(confidence, levels = CONFIDENCE_LEVELS),
      in_western_montane = ecoregion_l3 %in% WESTERN_MONTANE_L3
    )

  dir.create(DIR_PROC, showWarnings = FALSE, recursive = TRUE)
  gpkg <- file.path(DIR_PROC, "groundtruth_beaver.gpkg")
  sf::st_write(out, gpkg, layer = "groundtruth", delete_dsn = TRUE, quiet = TRUE)
  message("wrote ", gpkg, " (", nrow(out), " points)")

  out
}
