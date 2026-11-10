# scripts/ross_turbidity.R
# CSU ROSS Poudre Water Quality Network (HydroShare 521e317e189e498581d0aaa08c3f32bc),
# 15-minute Aqua TROLL turbidity (NTU), cleaned/QAQC'd product, 2019-2025.
# Output: data/ross_turbidity_daily.csv (daily min/median/max of value_final) and
#         data/ross_turbidity_sites.csv.
# Rows with NA value_final were removed by the data providers' QAQC and are dropped.
suppressMessages({library(arrow); library(dplyr); library(readr); library(lubridate)})

raw <- bind_rows(lapply(2019:2025, function(y)
  read_parquet(sprintf("data/raw/ross/CSU_ROSS_%d_cleaned.parquet", y)))) |>
  filter(parameter == "Turbidity")

# 15-min records -> daily (UTC date). n_obs = valid 15-min readings that day (max 96).
daily <- raw |>
  filter(!is.na(value_final)) |>
  mutate(date = as.Date(DateTime_UTC)) |>
  group_by(site, date) |>
  summarise(n_obs = n(), ntu_min = min(value_final), ntu_median = median(value_final),
            ntu_max = max(value_final), pct_drift_corrected = round(100 * mean(grepl("drift", modifications), na.rm = TRUE)),
            .groups = "drop")

# site locations valid on each site's active dates (some sites were moved)
loc <- read_csv("data/raw/ross/meta/CSU_ROSS_sonde_location_metadata.csv", show_col_types = FALSE) |>
  transmute(site, site_description, lat = latitude, lon = longitude,
            from = as.Date(data_start_date), to = as.Date(data_end_date))
site_dates <- daily |> group_by(site) |> summarise(first = min(date), last = max(date), .groups = "drop")
sites <- site_dates |> inner_join(loc, by = "site", relationship = "many-to-many") |>
  filter(from <= last, to >= first) |>
  group_by(site) |> slice_min(from, n = 1, with_ties = FALSE) |> ungroup() |>
  select(site, site_description, lat, lon, first, last)

daily <- daily |> filter(n_obs >= 24)   # keep days with >= 6 h of valid readings
write_csv(daily, "data/ross_turbidity_daily.csv")
write_csv(sites, "data/ross_turbidity_sites.csv")

FIRE <- as.Date(c("2020-08-13", "2020-12-02"))
cat("daily rows (>= 24 valid readings):", nrow(daily), "\n\n"); print(as.data.frame(sites))
cat("\nFire window summary (days with >= 6 h data):\n")
print(daily |> filter(date >= FIRE[1], date <= FIRE[2]) |> group_by(site) |>
  summarise(days = n(), median_of_daily_medians = round(median(ntu_median), 2),
            max_daily_max = round(max(ntu_max), 1), date_of_max = date[which.max(ntu_max)], .groups = "drop") |> as.data.frame())
cat("\nTop 4 daily maxima per site, 2020-08-13 to 2021-12-31:\n")
print(daily |> filter(date >= FIRE[1]) |> group_by(site) |> slice_max(ntu_max, n = 4) |>
  select(site, date, ntu_median, ntu_max) |> as.data.frame())
