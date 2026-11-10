# beaver_wildfires

This repository holds two pieces of one research project on beavers and wildfire in Colorado. The first is a **ground-truth database of beaver dams, beaver dam analogs (BDAs), and beaver sightings** across the western United States: 3,731 points assembled from seven public sources, each with its provenance, positional accuracy, and a confidence rating (`data/groundtruth_beaver.gpkg`, built by the R/`targets` pipeline in `R/`). It was assembled to train and validate a model that detects beaver complexes from imagery, and the sources and their limits are written up in `docs/source_log.md`. Of the 1,295 high- or medium-confidence dam/BDA points, 785 fall in western montane ecoregions, which is enough to start a reach-scale classifier. BDAs are the weak spot: only 35 are confirmed, all in Oregon.

The second piece is an **interactive animation of the Cache la Poudre watershed through the 2020 Cameron Peak Fire** (`index.html`). It plays the fire's 56 mapped perimeters (Aug 13 to Nov 1, 2020, plus the final 208,913-acre outline) over the river network, with beaver records drawn as icons and the fire's arrival at each one marked. Nitrate and pH lab samples (4,575 station-days at 132 stations, 2015 to 2025) appear as map dots, and a **tracker compares stations above and below dam-analog project reaches** (Little Beaver Creek, South Fork, Sheep Creek) before and after construction. An optional river color shows **measured turbidity** (green clear, near-black murky) from the CSU ROSS sensor network (18 sites, 2019 to 2025). A linked panel charts turbidity and USGS discharge (10 gauges) with a cursor that follows the playhead, and a built-in guide explains every variable, its source, and its caveats. A **Limitations** tab spells out what the page cannot show: there are no dates for when beaver dams or dam analogs were added, and no turbidity record for the burned headwaters, so the page does not test whether beaver structures affected turbidity. The sensors are mostly on the lower river below the canyon, so the color between them is a distance-weighted blend, not a measurement, and the burned headwaters and tributaries are left uncolored in 2020. The tracker is built to let you look for a dam-analog benefit, but there are only 3 after-construction sample pairs at Little Beaver and at the South Fork and none at Sheep Creek, so the data cannot show a benefit or a harm yet. The page does **not** test whether beaver structures changed water quality or fire behavior.

To see it, open `index.html` in a browser. It is a single self-contained file (data inlined; only the web fonts load from Google, with fallbacks). To host it, push this repo and turn on GitHub Pages (Settings, Pages, deploy from branch `main`, folder `/ (root)`); it will serve at `https://snauman4.github.io/beaver_wildfires/`. To rebuild it after changing data or code, run the scripts in `scripts/` (listed below) and then `python3 scripts/build_poudre_animation.py`, which inlines the data into `scripts/poudre_animation_template.html` and writes `index.html`. R dependencies are pinned with `renv` (`renv::restore()`).

## Layout

| Path | What it is |
|---|---|
| `index.html` | The animation (generated; do not edit by hand) |
| `scripts/poudre_animation_template.html` | Source of the animation page (code, styles, variables guide) |
| `scripts/poudre_animation_data.R` | Watershed, stream network, fire perimeters, beaver sites -> `data/poudre_animation.json` |
| `scripts/poudre_wq_data.R` | Nitrate and pH samples and the above/below station pairs -> `data/poudre_wq.json` |
| `scripts/ross_turbidity.R` | CSU ROSS 15-minute turbidity -> daily values (`data/ross_turbidity_*.csv`) |
| `scripts/usgs_discharge.R`, `scripts/usgs_turbidity.R` | USGS daily discharge and turbidity tidying |
| `scripts/poudre_panel_data.R` | Chart-panel data, plus each sensor's upstream basin share burned |
| `scripts/poudre_stream_turbidity.R` | Which sensors lie upstream/downstream of each stream vertex (river-color rule) |
| `scripts/build_poudre_animation.py` | Inlines the JSON data into the template -> `index.html` |
| `R/`, `_targets.R` | Ground-truth database pipeline (`targets::tar_make()`), one file per source |
| `data/` | Outputs (GeoPackage, CSVs, JSON) and the small raw inputs used |
| `docs/source_log.md` | Every source tried: what was obtained, how, license, and what was not usable |
| `docs/data_pulls.md` | The endpoints used to fetch each dataset, and which large files are not in the repo |

## Data sources and licenses

The code has no license file yet; choose one before others reuse it. The data keep their original terms:

- **CSU ROSS Poudre Water Quality Network** (turbidity): Struthers, Willi, De La Torre, Ross (2026), HydroShare, [doi:10.4211/hs.521e317e189e498581d0aaa08c3f32bc](https://doi.org/10.4211/hs.521e317e189e498581d0aaa08c3f32bc), CC BY 4.0. The providers note that 2019 to 2021 data predate their calibration procedures and optical sensors foul easily; use extremes with caution.
- **Fairfax et al. (2023) EEAGER dams and the 2025 Wyoming dam traces** (HydroShare, CC BY 4.0 and **CC BY-NC 4.0** respectively: noncommercial use only), **USGS ScienceBase** Tualatin Basin dams (public domain), **Oregon OWRI** BDA projects, **GBIF** and **iNaturalist** research-grade sightings (each record carries its own license; sightings are animals, not dams).
- **Fire perimeters:** NIFC Fire Progression (Cameron Peak); final perimeter from a CSU-hosted layer. **Streams and watershed:** USGS NHDPlus and WBD. **Streamflow:** USGS daily values (public domain).

Raw downloads over 50 MB (EPA ecoregions, ROSS parquet files, raw USGS discharge JSON, the Census state-boundary cache) are not committed; `docs/data_pulls.md` says how to fetch them.
