# 00_setup.R -- packages, constants, and the ground-truth schema
# Project: remote detection of beaver complexes (natural dams + BDAs)

pkgs <- c(
  "sf", "dplyr", "tidyr", "purrr", "stringr", "readr", "janitor",
  "httr2", "jsonlite", "glue", "lubridate",
  "leaflet", "htmlwidgets", "ggplot2", "targets", "here", "tigris"
)
missing <- pkgs[!pkgs %in% rownames(installed.packages())]
if (length(missing)) {
  message("Install these first:\n  install.packages(c(",
          paste0('"', missing, '"', collapse = ", "), "))")
}
invisible(lapply(intersect(pkgs, rownames(installed.packages())),
                 library, character.only = TRUE))

# ---- constants ----------------------------------------------------------
CRS_WGS84   <- 4326
CRS_ALBERS  <- 5070          # CONUS Albers, metres -- use for distance work
DEDUPE_M    <- 50            # points closer than this are treated as one
CONUS_BBOX  <- c(xmin = -125, ymin = 24, xmax = -66.5, ymax = 49.5)

DIR_RAW  <- here::here("data", "raw")
DIR_PROC <- here::here("data")

options(tigris_use_cache = TRUE)
Sys.setenv(TIGRIS_CACHE_DIR = file.path(DIR_RAW, "tigris_cache"))
dir.create(file.path(DIR_RAW, "tigris_cache"), showWarnings = FALSE, recursive = TRUE)

# ---- the schema ---------------------------------------------------------
# Every source module must return a tibble with exactly these columns
# before it is passed to assemble(). Geometry is added in 05_assemble.R.

GT_SCHEMA <- c(
  id            = "character",  # unique, prefixed by source, e.g. "nmbdc_00123"
  lon           = "numeric",
  lat           = "numeric",
  type          = "character",  # natural_dam | bda | complex | beaver_sighting
  confidence    = "character",  # high | medium | low
  source        = "character",
  source_url    = "character",
  date_observed = "Date",
  spatial_acc_m = "numeric",
  state         = "character",
  notes         = "character"
)

TYPE_LEVELS       <- c("natural_dam", "bda", "complex", "beaver_sighting")
CONFIDENCE_LEVELS <- c("high", "medium", "low")

#' Validate a source module's output against GT_SCHEMA
check_schema <- function(df, source_name) {
  missing_cols <- setdiff(names(GT_SCHEMA), names(df))
  if (length(missing_cols)) {
    stop(source_name, " is missing columns: ",
         paste(missing_cols, collapse = ", "), call. = FALSE)
  }
  df <- df[, names(GT_SCHEMA)]

  stopifnot(
    "type has invalid values"       = all(df$type %in% TYPE_LEVELS),
    "confidence has invalid values" = all(df$confidence %in% CONFIDENCE_LEVELS),
    "ids are not unique"            = !anyDuplicated(df$id),
    "every row needs a source_url"  = all(!is.na(df$source_url) & nzchar(df$source_url))
  )

  # coordinates must be real and inside CONUS -- never silently keep an outlier
  bad <- with(df, is.na(lon) | is.na(lat) |
                lon < CONUS_BBOX["xmin"] | lon > CONUS_BBOX["xmax"] |
                lat < CONUS_BBOX["ymin"] | lat > CONUS_BBOX["ymax"])
  if (any(bad)) {
    warning(source_name, ": dropping ", sum(bad),
            " rows with missing or out-of-CONUS coordinates")
    df <- df[!bad, ]
  }

  message(source_name, ": ", nrow(df), " rows passed schema check")
  df
}
