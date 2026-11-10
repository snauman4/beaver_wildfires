# Data pulls

These are the requests used to fetch each dataset. They were run one at a time with shell `curl` during development (not as one script), so treat them as a reference, not a tested one-command reproduction. Files marked **in repo** are committed under `data/raw/`; the rest are too large or easily re-fetched.

## Poudre animation

| Data | Request | Saved as |
|---|---|---|
| Watershed boundary (HUC8 10190007) | `https://hydro.nationalmap.gov/arcgis/rest/services/wbd/MapServer/4/query` with `where=huc8='10190007'`, `returnGeometry=true`, `outSR=4326`, `maxAllowableOffset=0.001`, `f=geojson` | `data/raw/poudre_huc8.geojson` (in repo) |
| NHDPlus flowlines, Strahler order >= 2 | `https://hydro.nationalmap.gov/arcgis/rest/services/nhd/MapServer/4/query` with `where=StreamOrde>=2`, `outFields=COMID,GNIS_NAME,StreamOrde,FromNode,ToNode,Hydroseq,DnHydroseq,TotDASqKM`, `maxAllowableOffset=0.0003`, `f=geojson`, one request per 0.3 x 0.25 degree tile (lon -105.95 to -104.45, lat 40.35 to 41.35). The service intermittently returns 502/504; retry. | `data/raw/poudre/nhd_tiles/` (in repo) |
| Cameron Peak fire progression (56 dated perimeters) | `https://services3.arcgis.com/T4QMspbfLg3qTGWY/arcgis/rest/services/Fire_Progression_Merged/FeatureServer/0/query` with `where=1=1`, `outFields=*`, `outSR=4326`, `maxAllowableOffset=0.0004`, `orderByFields=Perimeter_Date`, `f=geojson` | `data/raw/cameron_peak_progression.geojson` (in repo) |
| Cameron Peak final perimeter | `https://services1.arcgis.com/KNdRU5cN6ENqCTjk/arcgis/rest/services/CameronPeakFire2020_Perimeter/FeatureServer/0/query` (same style of query) | `data/raw/cameron_peak_final_perimeter.geojson` (in repo) |
| Beaver sightings, Poudre bounding box | GBIF `https://api.gbif.org/v1/occurrence/search?scientificName=Castor canadensis&decimalLatitude=40.37,41.21&decimalLongitude=-105.94,-104.59&hasCoordinate=true&hasGeospatialIssue=false&limit=300`; iNaturalist `https://api.inaturalist.org/v1/observations?taxon_name=Castor canadensis&quality_grade=research&swlat=40.37&swlng=-105.94&nelat=41.21&nelng=-104.59&per_page=200` | `data/raw/poudre/poudre_sightings_raw.csv` (in repo) |
| CSU ROSS turbidity, 2019 to 2025 | `https://www.hydroshare.org/resource/521e317e189e498581d0aaa08c3f32bc/data/contents/<year>/CSU_ROSS_<year>_cleaned.parquet` (redirects to Google Cloud Storage); plus `metadata/CSU_ROSS_sonde_location_metadata.csv`, `metadata/CSU_ROSS_delineated_basins.gpkg`, `README.md` | parquet: `data/raw/ross/` (**not in repo**, 73 MB); metadata: `data/raw/ross/meta/` (in repo) |
| USGS daily discharge (parameter 00060, statistic 00003), 11 gauges, 2015 on | `https://api.waterdata.usgs.gov/ogcapi/v0/collections/daily/items?monitoring_location_id=USGS-<site>&parameter_code=00060&statistic_id=00003&time=2015-01-01/..&limit=10000&f=json`; site names/locations from `.../collections/monitoring-locations/items?id=USGS-<site>&f=json` | `data/raw/usgs_discharge/loc_*.json` (in repo); `daily_*.json` (**not in repo**, 26 MB; the tidy `data/usgs_discharge_daily.csv` is) |
| USGS turbidity (continuous, parameter 63680) and discrete (Water Quality Portal) | `.../collections/daily/items?monitoring_location_id=USGS-<site>&parameter_code=63680`; `https://www.waterqualitydata.us/data/Result/search?huc=10190007&characteristicName=Turbidity&providers=NWIS&dataProfile=narrowResult&mimeType=csv` | `data/raw/usgs_turbidity/` (in repo). No USGS turbidity exists for the Poudre during the 2020 fire; see `docs/source_log.md`. |

## Ground-truth database (`R/`, `targets`)

| Data | Where it comes from | Saved as |
|---|---|---|
| EEAGER evaluation-polygon dams and training sample | HydroShare resource `17c9b293214641bea6948ae0d8facaeb` (`EEAGER_EvaluationPolygons.kmz`, `FairfaxEtAl_EEAGER_DataS2_TrainingDataSample.csv`) | `data/raw/eeager/` (in repo) |
| Wyoming dam traces | HydroShare resource `f078d94b1f99460f8f374dbe018a01bc` (`Wyoming_DamTraces.kmz`) | `data/raw/eeager_cluster/` (in repo) |
| Tualatin Basin dams | USGS ScienceBase item `59e67550e4b05fe04cd1ebbb` | `data/raw/usgs_tualatin/` (in repo) |
| Oregon BDA projects | OWRI feature service (ArcGIS Hub item `256068a8d687464eb565a004d10a63b2`), filtered to project names/descriptions mentioning BDA or beaver dam analog | `data/raw/owri_beaver.geojson` (in repo) |
| GBIF / iNaturalist sightings, 10 western states | the GBIF and iNaturalist APIs above, one query per state | `data/raw/gbif_compact/`, `data/raw/inat_compact/` (in repo) |
| EPA Level III ecoregions | `https://dmap-prod-oms-edc.s3.us-east-1.amazonaws.com/ORD/Ecoregions/us/us_eco_l3.zip` | `data/raw/ecoregions/` (**not in repo**; needed to run `R/08_assemble.R`) |
| State boundaries | `tigris::states(cb = TRUE, year = 2022)`, cached in `data/raw/tigris_cache/` | **not in repo**; `tigris` re-downloads it |

Two environment notes: R's `curl` package could not complete HTTPS requests through the sandbox proxy used during development, which is why the pulls above were done with shell `curl`; on a normal machine `httr2`/`rgbif`/`dataRetrieval` should work directly. And `sf::st_line_sample()` crashed on the GDAL 3.8.5 build used here, so `R/01_source_eeager.R` averages line vertices instead.
