# Week 1 — ground-truth database

**Goal:** assemble a verified database of confirmed beaver complex,
natural dam and BDA locations, and decide go/no-go on a reach-scale
classifier.

**Status: done.** 3,731 points assembled and written to
`data/groundtruth_beaver.gpkg`. Verdict: **GO** (785 usable high/medium
-confidence presence points in Western montane ecoregions, threshold 100).

## What is here

```
R/00_setup.R              packages, constants, schema + validator
R/01_source_eeager.R      Fairfax et al. 2023 EEAGER dams (HydroShare) -- 1,360 natural dams
R/02_source_wyoming_dams.R Fairfax 2025 Wyoming supplemental dams (HydroShare) -- 719 natural dams
R/03_source_usgs_tualatin.R USGS ScienceBase Tualatin Basin, OR dams -- 510 natural dams
R/04_source_owri_bda.R    Oregon OWRI confirmed BDA installations -- 39 BDAs
R/05_source_gbif.R        GBIF beaver sightings (low confidence) -- 2,168
R/06_source_inat.R        iNaturalist research-grade sightings (low confidence) -- 1,733
R/07_source_local.R       your field sites + hand pulls (none supplied yet)
R/08_assemble.R           dedupe (50 m), state + ecoregion join, write GPKG
R/09_report.R             counts, leaflet map, go/no-go assessment
_targets.R                the pipeline
docs/source_log.md        every source investigated, what was obtained and how, what wasn't
docs/labeling_protocol.md fallback manual NAIP labelling method (not needed -- see verdict)
```

## Run it

```r
# .libPaths() must include the renv project library; renv::restore() sets
# this up automatically once its download step works in your network
# environment (see "A note on this environment" below).
targets::tar_make()
targets::tar_read(summary_stats)
targets::tar_read(readiness)
targets::tar_read(gt_map)
```

Outputs: `data/groundtruth_beaver.gpkg` (3,731 points) and
`outputs/groundtruth_map.html` (leaflet map).

## Results summary

| | N |
|---|---|
| Total points | 3,731 |
| natural_dam (high conf.) | 899 |
| natural_dam (medium conf.) | 361 |
| bda (medium conf.) | 35 |
| beaver_sighting (low conf., not dams) | 2,436 |
| Colorado | 495 (203 high-conf. natural dams + 292 low-conf. sightings) |
| Western montane/intermountain, usable (high/med conf., presence types) | **785** |

By source: GBIF (1,676), iNaturalist (760), EEAGER eval-polygon dams (472),
USGS Tualatin Basin (361), Wyoming supplemental dams (328), EEAGER training
sample (99), OWRI confirmed BDAs (35). (Post-dedupe counts; 6,529 raw rows
merged to 3,731 after collapsing points within 50 m of each other, mostly
GBIF/iNaturalist recording the same underlying observations.)

Full breakdown, per-source licensing, and everything that was checked but
didn't pan out: see `docs/source_log.md`.

## Known gaps

- **BDAs are still thin.** 35 confirmed, all in Oregon (OWRI), all at
  ±250 m project-centroid accuracy. There are effectively zero
  high-confidence, precisely located BDA points anywhere, and none in
  Colorado. If you want BDA vs. natural-dam as a real modelling target
  rather than a descriptive attribute, this is the gap to close next --
  your own field sites are the best lever (see below).
- **Colorado has zero BDA points and zero medium/low-confidence natural
  dams** -- its 203 high-confidence points are all EEAGER eval-polygon
  dams (Southern Rockies).
- **Absence points do not exist yet.** See `docs/labeling_protocol.md`.

## Do these next (highest value, in order)

1. **Your Little Beaver Creek / Cameron Peak BDA field sites** -->
   `data/raw/local/` + `manifest.csv` (format documented in
   `R/07_source_local.R`). Your only lever for Colorado BDA points.
2. **Riverscapes account** (data.riverscapes.net) --> the NM statewide
   beaver dam census (4,372 dams) is real and well-documented but gated
   behind free account sign-in; not pursued this week. See
   `docs/source_log.md`.
3. State BDA programs not yet checked: CO CWCB Watershed Restoration
   Program, CPW, Coalition for the Poudre River Watershed, Rocky Mountain
   NP, UT WRI (no public API found), WA RCO/PRISM, MT Beaver Working
   Group.

## Notes for later weeks

- `data/gagesII/` is already here -- GAGES-II gives you reference-gage
  classification and basin attributes nationally, most of the week 5
  gage-linkage work. Note `data/gagesII/gagesII.zip` (53 MB) and
  `gagesII_sept30_2011_conterm.xlsx` (47 MB) exceed the 50 MB commit
  limit -- exclude them if/when this becomes a git repo (not part of this
  week's deliverable, predates this session).
- `CO_Reference_Gages_Analysis.Rmd` already uses
  `dataRetrieval::read_waterdata_daily()`. The legacy NWIS endpoints are
  being decommissioned, so check the current groundwater equivalent before
  assuming `readNWISgwl()` still works.
- `beaver_density_app/` is the natural home for the eventual monitoring app.

## A note on this environment

- R's `curl`/`httr2` could not complete HTTPS requests through this
  sandbox's proxy for several hosts (GBIF, ScienceBase, ArcGIS) even
  though shell `curl` reached them fine. All live pulls were done with
  shell `curl`, saved to `data/raw/`, and the R source scripts read those
  local files. This should not be an issue on your own machine.
- `sf::st_line_sample()` segfaults on this machine's GDAL 3.8.5 build --
  worked around by averaging line vertices instead (see
  `R/01_source_eeager.R`).
- `renv` is initialized (`renv.lock`, `renv/`); packages currently live in
  the renv project library. If `renv::restore()` hits the same sandboxed
  proxy issue on first run elsewhere, install packages directly first
  (`install.packages(..., lib = renv::paths$library())`) then
  `renv::snapshot()`.
