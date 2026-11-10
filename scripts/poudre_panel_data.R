# scripts/poudre_panel_data.R
# Builds data/poudre_panel.json: the measurement series for the time-linked
# panel in outputs/poudre_animation.html.
#   ross  : CSU ROSS daily turbidity (data/ross_turbidity_daily.csv) + sonde location
#           + share of each sonde's upstream basin inside the final Cameron Peak perimeter
#   usgs  : USGS daily mean discharge (data/usgs_discharge_daily.csv)
# Day index t = days since 2020-08-01 (animation day 0); window 2019-04-01..2025-12-31.
suppressMessages({library(dplyr); library(readr); library(jsonlite); library(sf)}); sf_use_s2(FALSE)

D0 <- as.Date("2020-08-01"); WIN <- as.Date(c("2019-04-01", "2025-12-31"))
tix <- function(d) as.integer(d - D0)

ROSS_NAMES <- c(
  pfal = "Poudre Falls, Hwy 14", pbr = "Poudre below Rustic", pman = "Poudre above FC intake",
  pbd = "Canyon mouth (below N. Fork)", bellvue = "Tamasag (above Fort Collins)",
  salyer = "Legacy Bridge (Fort Collins)", udall = "Lincoln St (Fort Collins)",
  cottonwood = "Prospect Rd", riverbend = "Timberline Rd", elc = "Above Boxelder Sanitation",
  archery = "Archery Range", riverbluffs = "Below Fossil Creek Res.",
  chd = "Chambers Lake outflow", joei = "Joe Wright Cr above reservoir", cbri = "Joe Wright Cr below reservoir",
  sfm = "South Fork at Pingree Park Rd", lbea = "Little Beaver Cr (burned)", penn = "Pennock Cr (unburned control)")
USGS_NAMES <- c(
  "USGS-06752260" = "Poudre at Fort Collins", "USGS-06752280" = "Poudre above Boxelder Cr",
  "USGS-06751490" = "North Fork at Livermore", "USGS-06751150" = "N. Fork below Halligan Res.",
  "USGS-06751145" = "N. Fork above Halligan Res.", "USGS-06746110" = "Joe Wright Cr below reservoir",
  "USGS-06746095" = "Joe Wright Cr above reservoir", "USGS-06741510" = "Big Thompson at Loveland",
  "USGS-402114105350101" = "Big Thompson below Moraine Park", "USGS-06614800" = "Michigan R near Cameron Pass")

dense <- function(df, col, digits) {         # dense array over observed range, NA -> null
  rng <- range(df$t); v <- rep(NA_real_, diff(rng) + 1); v[df$t - rng[1] + 1] <- df[[col]]
  list(t0 = rng[1], v = I(ifelse(is.na(v), NA, signif(round(v, digits), 4))))
}
round_series <- function(x) lapply(x, function(z) if (is.na(z)) NULL else z)

# ---- ROSS ---------------------------------------------------------------------
loc <- read_csv("data/raw/ross/meta/CSU_ROSS_sonde_location_metadata.csv", show_col_types = FALSE) |>
  group_by(site) |> slice_max(as.Date(data_end_date), n = 1, with_ties = FALSE) |> ungroup() |>
  select(site, desc = site_description, lat = latitude, lon = longitude)

basins <- st_read("data/raw/ross/meta/CSU_ROSS_delineated_basins.gpkg", quiet = TRUE) |> st_make_valid()
fin <- st_read("data/raw/cameron_peak_final_perimeter.geojson", quiet = TRUE) |> st_make_valid() |> st_union()
bp <- st_transform(basins, 5070); fp <- st_transform(st_sfc(fin, crs = 4326), 5070)
area_in <- function(g) { x <- suppressWarnings(st_intersection(g, fp)); if (length(x) == 0) 0 else sum(as.numeric(st_area(x))) }
burn <- tibble(site = basins$site, basin_km2 = as.numeric(st_area(bp)) / 1e6,
               burn_km2 = vapply(seq_len(nrow(bp)), function(i) area_in(st_geometry(bp)[i]) / 1e6, 0))
burn <- burn |> mutate(burn_pct = 100 * burn_km2 / basin_km2) |>
  group_by(site) |> slice_max(basin_km2, n = 1, with_ties = FALSE) |> ungroup()

tur <- read_csv("data/ross_turbidity_daily.csv", show_col_types = FALSE) |>
  mutate(t = tix(date)) |> filter(date >= WIN[1], date <= WIN[2])
ross <- lapply(split(tur, tur$site), function(df) {
  s <- df$site[1]; l <- loc[loc$site == s, ]; b <- burn[burn$site == s, ]
  med <- dense(df, "ntu_median", 2); mx <- dense(df, "ntu_max", 2)
  list(id = s, name = unname(ROSS_NAMES[s]), desc = l$desc, lat = l$lat, lon = l$lon,
       basin_km2 = if (nrow(b)) round(b$basin_km2, 1) else NULL, burn_pct = if (nrow(b)) round(b$burn_pct, 1) else NULL,
       t0 = med$t0, med = med$v, max = dense(df |> mutate(ntu_max = ntu_max), "ntu_max", 2)$v)
})

# ---- USGS discharge ---------------------------------------------------------------
us <- read_csv("data/usgs_discharge_daily.csv", show_col_types = FALSE) |>
  filter(date >= WIN[1], date <= WIN[2], site %in% names(USGS_NAMES), !is.na(cfs)) |> mutate(t = tix(date))
sites_u <- read_csv("data/usgs_discharge_sites.csv", show_col_types = FALSE)
usgs <- lapply(split(us, us$site), function(df) {
  s <- df$site[1]; l <- sites_u[sites_u$site == s, ]
  list(id = s, name = unname(USGS_NAMES[s]), full = l$site_name, lat = l$lat, lon = l$lon,
       da_km2 = round(l$drainage_km2, 0), t0 = min(df$t), cfs = dense(df, "cfs", 3)$v)
})

out <- list(
  d0 = as.character(D0), win = as.character(WIN),
  ross = unname(ross[order(vapply(ross, function(z) z$lon, 0))]),
  usgs = unname(usgs[order(vapply(usgs, function(z) -z$lat, 0))]))
write_json(out, "data/poudre_panel.json", auto_unbox = TRUE, digits = NA, null = "null", na = "null")
cat("wrote data/poudre_panel.json", round(file.size("data/poudre_panel.json") / 1e6, 2), "MB\n")
cat("\nROSS sites (burn % of upstream basin inside final perimeter):\n")
print(as.data.frame(bind_rows(lapply(ross, function(z) tibble(id = z$id, name = z$name, basin_km2 = z$basin_km2 %||% NA,
  burn_pct = z$burn_pct %||% NA, days = sum(!vapply(z$med, is.na, TRUE)))))), row.names = FALSE)
cat("\nUSGS series:", paste(vapply(usgs, function(z) z$id, ""), collapse = ", "), "\n")
