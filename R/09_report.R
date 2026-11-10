# 06_report.R -- counts, map, and the go/no-go assessment

summarise_groundtruth <- function(gt) {
  tab <- function(...) dplyr::count(sf::st_drop_geometry(gt), ..., sort = TRUE)

  list(
    total          = nrow(gt),
    by_source      = tab(source),
    by_type        = tab(type),
    by_confidence  = tab(confidence),
    by_state       = tab(state),
    by_type_conf   = tab(type, confidence),
    n_colorado     = sum(gt$state == "CO", na.rm = TRUE),
    n_western      = sum(gt$in_western_montane, na.rm = TRUE),
    n_usable       = sum(gt$confidence %in% c("high", "medium") &
                         gt$type %in% c("natural_dam", "bda", "complex"),
                         na.rm = TRUE),
    n_usable_west  = sum(gt$confidence %in% c("high", "medium") &
                         gt$type %in% c("natural_dam", "bda", "complex") &
                         gt$in_western_montane, na.rm = TRUE),
    n_bda          = sum(gt$type == "bda", na.rm = TRUE)
  )
}

#' Go/no-go: is this enough to train and validate a reach-scale classifier?
assess_readiness <- function(s, threshold = 100) {
  verdict <- if (s$n_usable_west >= threshold) "GO" else "NO-GO"
  msg <- c(
    sprintf("Usable presence points in Western montane ecoregions: %d (threshold %d)",
            s$n_usable_west, threshold),
    sprintf("Of which confirmed BDAs: %d", s$n_bda),
    sprintf("Colorado points: %d", s$n_colorado),
    sprintf("VERDICT: %s", verdict)
  )
  if (verdict == "NO-GO") {
    msg <- c(msg,
      "Fallback: run the manual NAIP labelling protocol in",
      "docs/labeling_protocol.md to reach N. Budget ~1 person-hour per",
      "15-25 labelled reaches.")
  }
  if (s$n_bda < 30) {
    msg <- c(msg,
      "WARNING: too few confirmed BDAs to model them as a separate class.",
      "Pool BDAs with natural dams for detection, and treat BDA-vs-natural",
      "as a descriptive attribute rather than a modelling target.")
  }
  cat(paste(msg, collapse = "\n"), "\n")
  invisible(verdict)
}

map_groundtruth <- function(gt, out = here::here("outputs", "groundtruth_map.html")) {
  pal <- leaflet::colorFactor("Set1", domain = TYPE_LEVELS)
  m <- leaflet::leaflet(gt) |>
    leaflet::addProviderTiles("Esri.WorldTopoMap") |>
    leaflet::addCircleMarkers(
      radius = 4, stroke = FALSE, fillOpacity = 0.7,
      color = ~pal(type),
      popup = ~paste0("<b>", id, "</b><br>", type, " (", confidence, ")<br>",
                      source, "<br>+/- ", spatial_acc_m, " m")
    ) |>
    leaflet::addLegend("bottomright", pal = pal, values = ~type, title = "Type")
  dir.create(dirname(out), showWarnings = FALSE, recursive = TRUE)
  htmlwidgets::saveWidget(m, out, selfcontained = FALSE)
  message("wrote ", out)
  m
}
