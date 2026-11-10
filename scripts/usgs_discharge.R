# scripts/usgs_discharge.R
# Tidy USGS daily-mean discharge (parameter 00060, statistic 00003, cfs) pulled
# with shell curl from api.waterdata.usgs.gov/ogcapi/v0/collections/daily.
# Outputs: data/usgs_discharge_daily.csv, data/usgs_discharge_sites.csv
suppressMessages({library(jsonlite); library(dplyr); library(readr); library(purrr)})

sites <- map_dfr(list.files("data/raw/usgs_discharge", "^loc_.*\\.json$", full.names = TRUE), function(f) {
  x <- fromJSON(f, simplifyVector = FALSE)$features[[1]]
  tibble(site = x$id, site_name = x$properties$monitoring_location_name,
         drainage_km2 = as.numeric(x$properties$drainage_area %||% NA) * 2.58999,  # API reports sq mi
         huc12 = x$properties$hydrologic_unit_code, lon = x$geometry$coordinates[[1]], lat = x$geometry$coordinates[[2]])
})

daily <- map_dfr(list.files("data/raw/usgs_discharge", "^daily_.*\\.json$", full.names = TRUE), function(f) {
  fs <- fromJSON(f, simplifyVector = FALSE)$features
  map_dfr(fs, ~ tibble(site = .x$properties$monitoring_location_id, date = as.Date(.x$properties$time),
                       cfs = as.numeric(.x$properties$value), approval = .x$properties$approval_status,
                       qualifier = { q <- unlist(.x$properties$qualifier); if (length(q)) paste(q, collapse = ",") else NA_character_ }))
}) |> arrange(site, date)

FIRE <- as.Date(c("2020-08-13", "2020-12-02"))
summ <- daily |> group_by(site) |>
  summarise(n_days = n(), from = min(date), to = max(date),
            fire_days = sum(date >= FIRE[1] & date <= FIRE[2]),
            median_cfs_all = median(cfs, na.rm = TRUE),
            median_cfs_fire = median(cfs[date >= FIRE[1] & date <= FIRE[2]], na.rm = TRUE),
            median_cfs_prefire_same_season = median(cfs[format(date, "%m-%d") >= "08-13" &
                                                       format(date, "%m-%d") <= "12-02" & date < FIRE[1]], na.rm = TRUE),
            pct_provisional = round(100 * mean(approval == "Provisional"), 1), .groups = "drop")
sites_out <- sites |> left_join(summ, by = "site") |> filter(!is.na(n_days))

write_csv(daily, "data/usgs_discharge_daily.csv")
write_csv(sites_out, "data/usgs_discharge_sites.csv")
print(sites_out |> select(site, site_name, drainage_km2, n_days, from, to, fire_days,
                          median_cfs_prefire_same_season, median_cfs_fire), width = Inf, n = 20)
cat("\nqualifiers:", paste(names(table(daily$qualifier)), table(daily$qualifier), collapse = "; "), "\n")
