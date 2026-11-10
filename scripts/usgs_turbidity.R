# scripts/usgs_turbidity.R
# Tidy the USGS turbidity pulls into data/usgs_turbidity_daily.csv and
# data/usgs_turbidity_discrete.csv. Raw files in data/raw/usgs_turbidity/ were
# fetched with shell curl (R's curl cannot pass this sandbox's proxy):
#   daily_<site>.json   api.waterdata.usgs.gov/ogcapi/v0/collections/daily, parameter 63680
#   wqp_turbidity_results.csv  waterqualitydata.us Result/search, huc=10190007, Turbidity, NWIS
suppressMessages({library(jsonlite); library(dplyr); library(readr); library(purrr)})

STAT <- c("00001" = "max", "00002" = "min", "00008" = "median")
SITE <- tibble::tribble(
  ~site,          ~site_name,                                        ~lon,        ~lat,       ~in_poudre_huc8,
  "USGS-06752450", "Cache la Poudre R abv N 11th Ave at Greeley",     -104.701289, 40.442003, TRUE,
  "USGS-06752480", "Cache la Poudre R below Hwy 85 at Greeley",       -104.677203, 40.422719, TRUE,
  "USGS-06736600", "Big Thompson R at Jasper Lake Rd nr Drake",       -105.256192, 40.415647, FALSE)

daily <- map_dfr(list.files("data/raw/usgs_turbidity", "^daily_.*\\.json$", full.names = TRUE), function(f) {
  fs <- fromJSON(f, simplifyVector = FALSE)$features
  map_dfr(fs, ~ as_tibble(.x$properties[c("monitoring_location_id", "statistic_id", "time", "value", "unit_of_measure", "approval_status")]))
}) |>
  transmute(site = monitoring_location_id, date = as.Date(time),
            stat = unname(STAT[statistic_id]), fnu = as.numeric(value), approval = approval_status) |>
  tidyr::pivot_wider(names_from = stat, values_from = fnu) |>
  left_join(SITE, by = "site") |> arrange(site, date)
write_csv(daily, "data/usgs_turbidity_daily.csv")

disc <- read_csv("data/raw/usgs_turbidity/wqp_turbidity_results.csv", show_col_types = FALSE) |>
  transmute(site = MonitoringLocationIdentifier, date = as.Date(ActivityStartDate),
            value = suppressWarnings(as.numeric(ResultMeasureValue)), unit = `ResultMeasure/MeasureUnitCode`,
            usgs_pcode = USGSPCode, flag = ResultDetectionConditionText, qualifier = MeasureQualifierCode)
write_csv(disc, "data/usgs_turbidity_discrete.csv")

cat("daily rows:", nrow(daily), "\n")
daily |> group_by(site, site_name) |>
  summarise(n_days = n(), from = min(date), to = max(date), median_of_medians = median(median, na.rm = TRUE),
            max_fnu = max(max, na.rm = TRUE), .groups = "drop") |> print(width = Inf)
cat("\ndiscrete rows:", nrow(disc), "\n")
disc |> group_by(site, unit) |> summarise(n = n(), from = min(date), to = max(date),
  median = median(value, na.rm = TRUE), max = max(value, na.rm = TRUE), .groups = "drop") |> print(width = Inf)
