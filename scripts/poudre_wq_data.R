# scripts/poudre_wq_data.R
# Nitrate and pH grab-sample results for the Cache la Poudre HUC8 (10190007), 2015-2025,
# from the Water Quality Portal (all providers). Writes:
#   data/wq_nitrate_ph_samples.csv  tidy samples (one row per station, day, parameter)
#   data/poudre_wq.json             stations + sample series + above/below station pairs for the page
# Raw pulls: data/raw/wqp_poudre/ (see docs/data_pulls.md).
suppressMessages({library(dplyr); library(readr); library(jsonlite); library(sf)}); sf_use_s2(FALSE)

D0 <- as.Date("2020-08-01")
ORG <- c("Colorado Dept. of Public Health & Environment-WQCD" = "CDPHE",
         "Coalition for the Poudre River Watershed (Volunteer)" = "CPRW volunteers",
         "Colorado River Watch" = "Colorado River Watch",
         "USGS Colorado Water Science Center" = "USGS",
         "EPA National Aquatic Resources Survey (NARS)" = "EPA NARS",
         "National Park Service Water Resources Division" = "NPS",
         "North American Lake Management Society" = "NALMS")

stn <- read_csv("data/raw/wqp_poudre/stations_nitrate_ph.csv", show_col_types = FALSE) |>
  transmute(id = MonitoringLocationIdentifier, name = MonitoringLocationName, org_full = OrganizationFormalName,
            lat = LatitudeMeasure, lon = LongitudeMeasure)
raw <- read_csv("data/raw/wqp_poudre/results_nitrate_ph_2015_2025.csv", show_col_types = FALSE) |>
  transmute(id = MonitoringLocationIdentifier, date = as.Date(ActivityStartDate), param = CharacteristicName,
            value = suppressWarnings(as.numeric(ResultMeasureValue)), unit = `ResultMeasure/MeasureUnitCode`,
            org_full = OrganizationFormalName, status = ResultStatusIdentifier)

cat("results pulled:", nrow(raw), "; without a numeric value (non-detect / not reported), dropped:", sum(is.na(raw$value)), "\n")
smp <- raw |> filter(!is.na(value)) |>
  mutate(is_no3 = param == "Nitrate" & grepl("NO3", unit, ignore.case = TRUE),
         value = ifelse(is_no3, value * 0.2259, value),
         param = ifelse(param == "Nitrate", "nitrate", "ph"))
n_no3 <- sum(smp$is_no3)
smp <- smp |> group_by(id, date, param) |> summarise(value = mean(value), org_full = first(org_full), .groups = "drop") |>
  filter(date >= as.Date("2015-01-01"), date <= as.Date("2025-12-31"))
cat("nitrate results reported 'as NO3' converted to as-N (x 0.2259):", n_no3, "\n")

fin <- st_read("data/raw/cameron_peak_final_perimeter.geojson", quiet = TRUE) |> st_make_valid() |> st_union()
stn <- stn |> filter(id %in% smp$id) |> distinct(id, .keep_all = TRUE)
stn$burn <- lengths(st_intersects(st_as_sf(stn, coords = c("lon", "lat"), crs = 4326, remove = FALSE), fin)) > 0

write_csv(smp |> left_join(stn |> select(id, name, lat, lon, burn), by = "id") |>
            transmute(station_id = id, station = name, org = unname(ORG[org_full]), date, parameter = param, value = round(value, 4),
                      unit = ifelse(param == "nitrate", "mg/L (as reported; as-NO3 values converted to as-N)", "pH units"), lat, lon, inside_fire_perimeter = burn),
          "data/wq_nitrate_ph_samples.csv")

series <- function(id, p) { x <- smp |> filter(id == !!id, param == p) |> arrange(date)
  lapply(seq_len(nrow(x)), function(i) c(as.integer(x$date[i] - D0), round(x$value[i], ifelse(p == "ph", 2, 3)))) }
stations <- lapply(seq_len(nrow(stn)), function(i) { s <- stn[i, ]
  list(id = s$id, name = s$name, org = unname(ORG[s$org_full]), lat = s$lat, lon = s$lon, burn = s$burn,
       nit = series(s$id, "nitrate"), ph = series(s$id, "ph")) })

# CPRW volunteer stations are paired "Above"/"Below". Project windows come from CPRW / Forest Service project
# pages (read Nov 2026); exact construction dates are not published, so a season is shaded, not a day.
pairs <- list(
  list(key = "lbc", site = "Little Beaver Creek", above = "CPRW-LBEA1", below = "CPRW-LBEA2",
       project = list(label = "Dam analogs built, fall 2024", start = "2024-09-03", end = "2024-11-30",
                      note = "Forest Service decision signed Sep 3, 2024; CPRW lists the project as completed fall 2024. The structures are on Little Beaver Creek just above its mouth; the project pages do not say whether they lie between these two stations.")),
  list(key = "sf", site = "South Fork Cache la Poudre", above = "CPRW-S. FORK1", below = "CPRW-S. FORK2",
       project = list(label = "Dam analogs built, Sep to Nov 2024", start = "2024-09-01", end = "2024-11-30",
                      note = "CPRW's 2024 recap says the South Fork work was done between September and November 2024. The page does not give its location, so it is not certain the structures lie between these two stations.")),
  list(key = "shp", site = "Sheep Creek", above = "CPRW-SHEP1", below = "CPRW-SHEP2",
       project = list(label = "Dam analogs built, summer/fall 2025", start = "2025-06-01", end = "2025-11-30",
                      note = "CPRW lists Sheep Creek at Sleeping Elephant as completed summer/fall 2025. The samples end in September 2025, so there is essentially no after-construction record yet.")),
  list(key = "fish", site = "Fish Creek", above = "CPRW-FISH1", below = "CPRW-FISH2", project = NULL),
  list(key = "lazy", site = "Lazy D", above = c("CPRW-LAZD1", "CPRW-LAZYD1"), below = c("CPRW-LAZD2", "CPRW-LAZYD2"), project = NULL),
  list(key = "rat", site = "Ratville", above = "CPRW-RatV1", below = "CPRW-RatV2", project = NULL))

out <- list(d0 = as.character(D0), stations = stations, pairs = pairs,
            n_results = nrow(smp), n_stations = nrow(stn), n_burn = sum(stn$burn))
write_json(out, "data/poudre_wq.json", auto_unbox = TRUE, digits = NA, null = "null")
cat(sprintf("stations: %d (%d inside the fire perimeter); sample-days: %d\nwrote data/poudre_wq.json %.2f MB\n",
            nrow(stn), sum(stn$burn), nrow(smp), file.size("data/poudre_wq.json") / 1e6))
