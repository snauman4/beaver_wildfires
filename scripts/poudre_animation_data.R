# scripts/poudre_animation_data.R
# Builds data/poudre_animation.json for the Cache la Poudre beaver / Cameron
# Peak fire animation (outputs/poudre_animation.html).
#
# Inputs (all fetched this session, see docs/source_log.md):
#   data/raw/poudre_huc8.geojson                  USGS WBD HUC8 10190007
#   data/raw/poudre/nhd_tiles/*.json              NHDPlus flowlines, StreamOrde >= 2
#   data/raw/cameron_peak_progression.geojson     NIFC fire progression, 56 dated perimeters
#   data/raw/cameron_peak_final_perimeter.geojson final perimeter (208,913 ac)
#   data/raw/poudre/poudre_sightings_raw.csv      GBIF + iNaturalist, Poudre bbox
#   data/groundtruth_beaver.gpkg                  week-1 dam database
#
# The green "water-quality benefit" is an ILLUSTRATIVE model, not measured
# data: each beaver site (dam weight 1.0, sighting weight 0.6) contributes
# w * exp(-d / LAMBDA_M) to every stream vertex DOWNSTREAM of it, d = distance
# along the flowline network; a vertex takes the max over sites.

invisible(lapply(list.files(here::here("R"), pattern = "^00_", full.names = TRUE), source))
suppressMessages({library(sf); library(dplyr); library(jsonlite)})
sf_use_s2(FALSE)

LAMBDA_M  <- 8000     # e-folding distance of the illustrative effect
LMAX_M    <- 30000    # stop tracing this far downstream
SNAP_M    <- 400      # max distance from a site to a flowline to count as "on stream"
W_DAM     <- 1.0
W_SIGHT   <- 0.6
DEDUPE_SIGHT_M <- 50

ws <- st_read("data/raw/poudre_huc8.geojson", quiet = TRUE) |> st_make_valid()

# ---- streams ---------------------------------------------------------------
tiles <- list.files("data/raw/poudre/nhd_tiles", full.names = TRUE)
fl <- bind_rows(lapply(tiles, st_read, quiet = TRUE)) |>
  distinct(COMID, .keep_all = TRUE) |> st_zm(drop = TRUE)
fl <- fl[lengths(st_intersects(fl, st_union(ws))) > 0, ]
fl <- st_cast(fl, "LINESTRING", warn = FALSE)
fl <- fl[!duplicated(fl$COMID), ]
cat("flowlines:", nrow(fl), "\n")

flp <- st_transform(fl, 5070)
coords <- lapply(st_geometry(flp), function(g) unclass(g)[, 1:2, drop = FALSE])
cum    <- lapply(coords, function(m) c(0, cumsum(sqrt(rowSums(diff(m)^2)))))
len    <- vapply(cum, function(x) x[length(x)], numeric(1))

# ---- beaver sites ------------------------------------------------------------
gt <- st_read("data/groundtruth_beaver.gpkg", quiet = TRUE)
dams <- gt[gt$type %in% c("natural_dam", "bda") &
             lengths(st_intersects(gt, st_union(ws))) > 0, ]
dams <- tibble(id = dams$id, kind = "dam", src = dams$source, url = dams$source_url,
               date = as.character(dams$date_observed), acc = dams$spatial_acc_m,
               geometry = st_geometry(dams)) |> st_as_sf(crs = 4326)

raw <- read.csv("data/raw/poudre/poudre_sightings_raw.csv", stringsAsFactors = FALSE)
raw <- raw[is.na(raw$acc) | raw$acc <= 1000, ]
sg  <- st_as_sf(raw, coords = c("lon", "lat"), crs = 4326)
sg  <- sg[lengths(st_intersects(sg, st_union(ws))) > 0, ]
sg  <- tibble(id = sg$id, kind = "sight",
              src = ifelse(sg$src == "GBIF", "GBIF occurrence (animal sighting)",
                           "iNaturalist research-grade (animal sighting)"),
              url = sg$url, date = sg$date, acc = sg$acc,
              geometry = st_geometry(sg)) |> st_as_sf(crs = 4326)

# collapse sightings within 50 m of each other and of any dam (dam wins)
sp <- st_transform(sg, 5070); dp <- st_transform(dams, 5070)
nb <- st_is_within_distance(sp, dp, dist = DEDUPE_SIGHT_M)
sp <- sp[lengths(nb) == 0, ]
keep <- logical(nrow(sp)); seen <- rep(FALSE, nrow(sp))
nbs <- st_is_within_distance(sp, dist = DEDUPE_SIGHT_M)
for (i in seq_len(nrow(sp))) if (!seen[i]) { keep[i] <- TRUE; seen[nbs[[i]]] <- TRUE }
sg <- st_transform(sp[keep, ], 4326)
cat("dams in watershed:", nrow(dams), " sightings after dedupe:", nrow(sg), "\n")

sites <- bind_rows(dams, sg)
sites$w <- ifelse(sites$kind == "dam", W_DAM, W_SIGHT)
xy_ll <- st_coordinates(sites)
xy_p  <- st_coordinates(st_transform(sites, 5070))

# ---- snap each site to nearest flowline vertex ---------------------------------
allv <- do.call(rbind, lapply(seq_along(coords), function(i)
  cbind(line = i, vtx = seq_len(nrow(coords[[i]])), coords[[i]])))
snap <- t(apply(xy_p, 1, function(p) {
  d <- sqrt((allv[, 3] - p[1])^2 + (allv[, 4] - p[2])^2); j <- which.min(d)
  c(allv[j, 1], allv[j, 2], d[j])
}))
sites$snap_m <- snap[, 3]
sites$on_stream <- sites$snap_m <= SNAP_M
cat("sites snapped to a flowline within", SNAP_M, "m:", sum(sites$on_stream), "of", nrow(sites), "\n")

# ---- downstream influence ---------------------------------------------------------
from_node <- fl$FromNode; to_node <- fl$ToNode
succ <- lapply(seq_len(nrow(fl)), function(i) which(from_node == to_node[i]))
infl <- lapply(coords, function(m) numeric(nrow(m)))

for (s in which(sites$on_stream)) {
  li <- snap[s, 1]; vi <- snap[s, 2]; w <- sites$w[s]
  # vertices on the snapped line at/after the snap vertex
  d0 <- cum[[li]] - cum[[li]][vi]
  idx <- which(d0 >= 0 & d0 <= LMAX_M)
  infl[[li]][idx] <- pmax(infl[[li]][idx], w * exp(-d0[idx] / LAMBDA_M))
  # Dijkstra-ish traversal over successor lines
  best <- numeric(0)                         # line -> distance at its start
  queue <- list(list(l = li, dstart = -cum[[li]][vi]))
  while (length(queue)) {
    q <- queue[[1]]; queue <- queue[-1]
    dend <- q$dstart + len[q$l]
    if (dend > LMAX_M) next
    for (nx in succ[[q$l]]) {
      key <- as.character(nx)
      if (!is.na(best[key]) && best[key] <= dend) next
      best[key] <- dend
      dd <- dend + cum[[nx]]
      ok <- dd <= LMAX_M
      infl[[nx]][ok] <- pmax(infl[[nx]][ok], w * exp(-dd[ok] / LAMBDA_M))
      queue[[length(queue) + 1]] <- list(l = nx, dstart = dend)
    }
  }
}

# ---- fire ------------------------------------------------------------------------------
fp <- st_read("data/raw/cameron_peak_progression.geojson", quiet = TRUE) |> st_make_valid()
fp$date <- as.Date(as.POSIXct(fp$Perimeter_Date / 1000, origin = "1970-01-01", tz = "UTC"))
fp <- fp[order(fp$date), ]
fin <- st_read("data/raw/cameron_peak_final_perimeter.geojson", quiet = TRUE) |> st_make_valid()
fire <- bind_rows(
  tibble(date = fp$date, acres = fp$Total_Acres, label = "mapped perimeter", geometry = st_geometry(fp)),
  tibble(date = as.Date("2020-12-02"), acres = fin$FireAcres[1], label = "final perimeter",
         geometry = st_geometry(fin)[1])) |> st_as_sf(crs = 4326)
fire <- fire[!duplicated(fire$date, fromLast = TRUE), ]

# first perimeter that contains each site
sites$burn_date <- NA_character_
for (k in seq_len(nrow(fire))) {
  hit <- lengths(st_intersects(sites, fire[k, ])) > 0
  sites$burn_date[hit & is.na(sites$burn_date)] <- as.character(fire$date[k])
}
cat("sites inside the final fire perimeter:", sum(!is.na(sites$burn_date)), "of", nrow(sites), "\n")

# stats: influenced stream length inside the final perimeter
finp <- st_transform(fire[nrow(fire), ], 5070)
seg_len <- 0; seg_len_burn <- 0
for (i in seq_along(coords)) {
  m <- coords[[i]]; n <- nrow(m); if (n < 2) next
  I <- (infl[[i]][-1] + infl[[i]][-n]) / 2
  L <- sqrt(rowSums(diff(m)^2))
  mid <- st_as_sf(data.frame(x = (m[-1, 1] + m[-n, 1]) / 2, y = (m[-1, 2] + m[-n, 2]) / 2),
                  coords = c("x", "y"), crs = 5070)
  g <- I >= 0.3
  if (!any(g)) next
  inb <- lengths(st_intersects(mid[g, ], finp)) > 0
  seg_len <- seg_len + sum(L[g]); seg_len_burn <- seg_len_burn + sum(L[g][inb])
}
cat(sprintf("stream length with influence >= 0.3: %.0f km (%.0f km inside burn)\n",
            seg_len / 1000, seg_len_burn / 1000))

# simplify rings for the web
simp <- function(g, tol) {
  gp <- st_transform(st_sfc(g, crs = 4326), 5070)
  st_transform(st_simplify(gp, dTolerance = tol, preserveTopology = TRUE), 4326)[[1]]
}
polys_to_list <- function(g) {
  flat <- function(x) {
    if (inherits(x, "GEOMETRYCOLLECTION")) return(unlist(lapply(unclass(x), flat), recursive = FALSE))
    if (inherits(x, "MULTIPOLYGON")) return(unclass(x))
    if (inherits(x, "POLYGON")) return(list(unclass(x)))
    list()
  }
  lapply(flat(g), function(p) lapply(p, function(r) round(as.vector(t(r[, 1:2])), 4)))
}
fire_out <- lapply(seq_len(nrow(fire)), function(k)
  list(d = as.character(fire$date[k]), ac = round(fire$acres[k]), kind = fire$label[k],
       g = polys_to_list(simp(st_geometry(fire)[[k]], 120))))
ws_out <- polys_to_list(simp(st_geometry(ws)[[1]], 100))

# streams out: name, order, flat coords, influence per vertex (0-100 ints)
st_out <- lapply(seq_len(nrow(fl)), function(i) {
  m <- unclass(st_geometry(fl)[[i]])[, 1:2, drop = FALSE]
  list(n = ifelse(is.na(fl$GNIS_NAME[i]), "", fl$GNIS_NAME[i]), o = fl$StreamOrde[i],
       c = round(as.vector(t(m)), 4), i = as.integer(round(100 * infl[[i]])),
       fn = fl$FromNode[i], tn = fl$ToNode[i], da = round(fl$TotDASqKM[i], 1))
})

sites_out <- lapply(seq_len(nrow(sites)), function(s)
  list(id = sites$id[s], k = sites$kind[s], src = sites$src[s], url = sites$url[s],
       date = sites$date[s], acc = if (is.na(sites$acc[s])) NULL else round(sites$acc[s]),
       lon = round(xy_ll[s, 1], 5), lat = round(xy_ll[s, 2], 5),
       on = sites$on_stream[s], burn = sites$burn_date[s]))

out <- list(
  params = list(lambda_km = LAMBDA_M / 1000, lmax_km = LMAX_M / 1000, snap_m = SNAP_M,
                w_dam = W_DAM, w_sight = W_SIGHT),
  stats = list(n_sites = nrow(sites), n_dams = sum(sites$kind == "dam"),
               n_sight = sum(sites$kind == "sight"), n_on_stream = sum(sites$on_stream),
               n_burned = sum(!is.na(sites$burn_date)),
               infl_km = round(seg_len / 1000), infl_burn_km = round(seg_len_burn / 1000),
               n_streams = nrow(fl)),
  watershed = ws_out, fire = fire_out, streams = st_out, sites = sites_out)

write_json(out, "data/poudre_animation.json", auto_unbox = TRUE, digits = NA, null = "null")
cat("wrote data/poudre_animation.json:",
    round(file.size("data/poudre_animation.json") / 1e6, 2), "MB\n")
