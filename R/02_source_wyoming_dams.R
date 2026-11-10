# 02_source_wyoming_dams.R
# Supplemental Wyoming beaver dam traces from Fairfax's 2025 HydroShare
# resource "Beaver Dam Locations: Cluster + Surface Water"
# (http://www.hydroshare.org/resource/f078d94b1f99460f8f374dbe018a01bc,
# CC BY-NC 4.0).
#
# WHAT IT IS
#   719 individually digitised beaver dams near Laramie, WY (~41.2-41.3N,
#   -105.3 to -105.4W), each stored as a paired Area polygon (pond) and
#   Length line (dam crest) in Wyoming_DamTraces.kmz. Same digitisation
#   method/lab as EEAGER (R/01_source_eeager.R), just not part of the 12
#   published evaluation polygons.
#
# GEOMETRY / PARSING
#   The KML has ~720 nested <Document> pairs (DamNArea.kmz, DamNLength.kmz)
#   -- reading this via GDAL's KML driver one layer at a time is slow for
#   >700 layers, so this script parses the raw KML XML directly with xml2
#   and takes the midpoint of each dam's Length LineString.
#
# CONFIDENCE: high (same expert digitisation as EEAGER).
# LICENSE: CC BY-NC 4.0 -- noncommercial academic/research use only.

WY_DAMS_KML <- file.path(DIR_RAW, "eeager_cluster", "extracted",
                         "Wyoming_DamTraces.kml")

source_wyoming_dams <- function(kml = WY_DAMS_KML) {
  if (!requireNamespace("xml2", quietly = TRUE)) {
    message("[wyoming_dams] xml2 not installed -- skipping"); return(NULL)
  }
  if (!file.exists(kml)) {
    message("[wyoming_dams] missing ", kml); return(NULL)
  }

  doc <- xml2::read_xml(kml)
  ns  <- c(k = "http://www.opengis.net/kml/2.2")

  docs <- xml2::xml_find_all(doc, ".//k:Document", ns)
  names_txt <- xml2::xml_text(xml2::xml_find_first(docs, "k:name", ns))
  length_docs <- docs[grepl("Length", names_txt)]

  out <- purrr::map_dfr(seq_along(length_docs), function(i) {
    d <- length_docs[[i]]
    coord_txt <- xml2::xml_text(
      xml2::xml_find_first(d, ".//k:LineString/k:coordinates", ns))
    if (is.na(coord_txt) || !nzchar(coord_txt)) return(NULL)
    pts <- do.call(rbind, lapply(strsplit(trimws(coord_txt), "\\s+")[[1]],
                                 function(p) as.numeric(strsplit(p, ",")[[1]][1:2])))
    tibble::tibble(
      id            = sprintf("wy_dam_%04d", i),
      lon           = mean(pts[, 1]),
      lat           = mean(pts[, 2]),
      type          = "natural_dam",
      confidence    = "high",
      source        = "Fairfax 2025 Wyoming beaver dam traces (HydroShare)",
      source_url    = "http://www.hydroshare.org/resource/f078d94b1f99460f8f374dbe018a01bc",
      date_observed = as.Date(NA),
      spatial_acc_m = 5,
      state         = NA_character_,  # filled by the point-in-polygon join in 08_assemble.R
      notes         = "digitised dam crest midpoint; CC BY-NC 4.0"
    )
  })

  if (is.null(out) || !nrow(out)) return(NULL)
  check_schema(out, "wyoming_dams")
}
