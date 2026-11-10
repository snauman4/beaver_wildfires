# Ground-truth source log — beaver dams & beaver dam analogs

Week 1 deliverable. One entry per candidate source: what it is, whether it
was actually obtained (not assumed), and what it yields. Every source below
was tested by making a real network request or opening the real page —
nothing here is inferred from a source's description alone. Updated
2026-09-17 (all sources accessed this date).

**Status key:** ✅ obtained, in the database · ⚠️ obtainable but needs a
manual step (account, email) not completed this week · ❌ tested and not
usable for point ground truth

---

## ✅ Fairfax et al. 2023 EEAGER paper (10.1029/2022JG007196) — HydroShare deposit

The paper (AGU JGR: Biogeosciences, open access) says its Data Availability
Statement: the full 13,344-dam training set is **not public**, citing
"ongoing risk of beaver trapping and intentional habitat destruction."
Additional data requires emailing project-eager@google.com. However, the
statement points to a real HydroShare deposit that *is* public:

| | |
|---|---|
| Citation | Fairfax, E. (2022). EEAGERModel, HydroShare |
| URL | http://www.hydroshare.org/resource/17c9b293214641bea6948ae0d8facaeb |
| License | CC BY 4.0 |
| Contents used | `EEAGER_EvaluationPolygons.kmz` (dam locations, as digitised crest lines, inside the paper's 12 held-out evaluation polygons A–L) + `FairfaxEtAl_EEAGER_DataS2_TrainingDataSample.csv` (a 300-row public random sample of the training set: 100 Positive / 100 PseudoNegative / 100 AssumedNegative) |
| Verification | KML feature counts per polygon (350, 61, 8, 29, 72/73, 78/77, 133, 193, 19, 87, 189, 43) match paper Table 2 almost exactly (total 1,262, vs. paper's reported 1,262) — confirmed to be the real, not placeholder, data |
| N obtained | **1,360** natural-dam points (1,262 eval-polygon dams − 2 CONUS outliers, + 100 sample positives) |
| Type | natural dams (expert-mapped) |
| Confidence | high |
| Spatial accuracy | ~5 m (sub-0.2 m imagery, line-crest digitisation) |
| Date | training dates 2014–2021 (paper §2.1.1); eval imagery 2022 (§2.1.4); not resolvable per-point |
| Distinguishes BDA vs. natural | no — natural dams only |

**Bug found and fixed:** the KML's own `K_DamsHabitat` / `L_DamsHabitat`
folder letters are swapped relative to paper Table 2 (KML "K" has 189
features matching Table 2's polygon L=Wyoming; a coordinate check confirmed
those points are in WA, not WY). We do not trust the polygon-letter → state
mapping at all; state is assigned by an actual point-in-polygon join
against Census state boundaries (R/08_assemble.R), not by label.

**Also checked:** a second Fairfax HydroShare resource, "Beaver Dam
Locations: Cluster + Surface Water" (2025,
http://www.hydroshare.org/resource/f078d94b1f99460f8f374dbe018a01bc,
CC BY-NC 4.0) republishes the same 12-polygon set (`EEAGER_DamTraces.kmz`,
confirmed identical counts — not re-ingested to avoid double counting) plus
a genuinely new `Wyoming_DamTraces.kmz` — see next entry.

---

## ✅ Fairfax 2025 Wyoming supplemental dam traces — HydroShare

| | |
|---|---|
| URL | http://www.hydroshare.org/resource/f078d94b1f99460f8f374dbe018a01bc |
| License | **CC BY-NC 4.0** — noncommercial/academic use only |
| Contents | `Wyoming_DamTraces.kmz`: 720 individually digitised dams near Laramie, WY, each as a paired Area (pond) + Length (crest) KML geometry, nested ~1,440 `<Document>` elements deep |
| Parsing | GDAL's KML driver reading 700+ layers one at a time was impractical (and `st_line_sample()` segfaults on this machine's GDAL 3.8.5 build — see Known issues below); parsed the raw KML XML directly with `xml2`, took the mean vertex coordinate of each Length line |
| N obtained | **719** natural-dam points |
| Type | natural dams |
| Confidence | high (same digitisation method/lab as EEAGER) |
| Spatial accuracy | ~5 m |

---

## ✅ USGS ScienceBase — Tualatin Basin, Oregon beaver dam locations

| | |
|---|---|
| Item | "Beaver dam locations in the Tualatin Basin, Oregon, between 2011 and 2019" |
| URL | https://www.sciencebase.gov/catalog/item/59e67550e4b05fe04cd1ebbb |
| Producer | USGS, compiled from 13 local watershed groups/agencies around Portland, OR |
| License | US Government work, public domain |
| Format | ArcGIS point shapefile, downloaded directly (28 KB zip) |
| N obtained | **510** points, each with a report `Date`, `Source` org, `Method`, and free-text `Notes` |
| Type | natural dams |
| Confidence | medium — crowd-sourced from local orgs, GPS method recorded as "Unknown" for many records, but coordinates are per-structure points (not project centroids) |
| Spatial accuracy | ~30 m (estimated; not documented per-point) |

Also checked a companion item, "Beaver dam locations and beaver activity in
the Tualatin Basin, Oregon (ver. 2.0)" (5977ba8ce4b0ec1a4888e49f) — its
attached file is a 1 KB revision-notes text file, not a data file; not used.

---

## ✅ Oregon Watershed Restoration Inventory (OWRI) — confirmed BDA installations

| | |
|---|---|
| Producer | Oregon Watershed Enhancement Board (OWEB) |
| Access | ArcGIS Hub item `256068a8d687464eb565a004d10a63b2` resolves (at run time, via the ArcGIS `sharing/rest` API) to `https://services1.arcgis.com/CD5mKowwN6nIaqd8/arcgis/rest/services/project_owri_2024/FeatureServer/5` |
| Total DB size | 21,922 restoration project records (1995–2022) |
| Filter tested | 175 projects mention "beaver" in the project name; only **39** specifically mention "BDA" or "beaver dam analog" in the description. We use only the 39 — the broader 175 includes generic beaver management (exclusion fencing, trapping) that is not dam construction and would misrepresent BDA presence |
| N obtained | **39** BDA installation records |
| Type | bda |
| Confidence | medium |
| Spatial accuracy | ±250 m — OWRI geometry is the **project-area polygon**, not the individual structure; we use the polygon centroid. This is a real limitation of the source. |
| Note | R's `curl`/`httr2` could not complete a TLS CONNECT through this sandbox's proxy for `www.arcgis.com` (see Known issues) — the feature-service query was run with shell `curl` and saved to `data/raw/owri_beaver.geojson`; `R/04_source_owri_bda.R` reads that local file. |

---

## ✅ GBIF — *Castor canadensis* occurrences (low confidence)

Animal sightings, **not dam locations**. Pulled live from
`api.gbif.org/v1/occurrence/search`, one query per state (CO, NM, UT, WY,
MT, ID, OR, WA, NV, AZ), `hasCoordinate=true`, `limit=300`/state.
2,819 raw records → **2,168** after dropping records with coordinate
uncertainty > 1000 m. `type = beaver_sighting`, `confidence = low` always.
Heavy observer-effort bias (density near cities reflects people, not
beavers) — used only as a weak prior / candidate-area seed, per project
instructions, never as a dam-presence label.

---

## ✅ iNaturalist — research-grade *Castor canadensis* observations (low confidence)

Same caveat as GBIF. Pulled live from `api.inaturalist.org/v1/observations`,
`quality_grade=research`, one bounding-box query per state (same 10
states), `per_page=200`. 2,000 raw records → **1,733** after the same
1000 m accuracy filter. GBIF aggregates iNaturalist's research-grade
records too, so there is real overlap between the two sources — the 50 m
dedupe step in `R/08_assemble.R` collapses duplicates recorded by both
(this is most of the 2,798 records merged out during assembly).

---

## ⚠️ New Mexico Statewide 2020 NAIP Beaver Dam Census (Riverscapes Data Exchange)

4,372 photointerpreted dams across all 85 NM HUC8s (Defenders of
Wildlife / USU). **Tested and confirmed gated behind account sign-in**:
`data.riverscapes.net` returns a bare "SIGN IN" page with no anonymous
browse/search; its GraphQL API (`api.data.riverscapes.net`) answers
`{__typename}` anonymously but querying real project data was not
attempted without credentials. Rio Grande Return's project page
(riograndereturn.org/beaver-dam-census) confirms the census is complete
and confirms the data is served only through the Riverscapes warehouse —
no separate direct download. **Not pursued this week** — needs a free
account creation, which is a manual step outside this script's scope.
Flagged for week 2 if more Colorado-relevant training data is needed.

---

## ❌ BRAT (Beaver Restoration Assessment Tool)

Outputs are **modeled dam capacity** (dams/km a reach could support), not
observed dams — not ground truth by definition. Not pursued as a point
source. Worth revisiting later as a covariate/stratifier for drawing
absence points (https://brat.riverscapes.net/).

---

## ❌/⚠️ Other sources checked this week

- **data.gov** (`catalog.data.gov/api/3/action/package_search`): the CKAN
  API endpoint returned `404 Not Found` — this endpoint appears to have
  been retired/moved as part of data.gov's ongoing platform migration.
  Not pursued further via the UI search this week.
- **ScienceBase general search** ("beaver dam", 124 results; "beaver dam
  analog", 0 results): besides the two items above, results were mostly
  historical photographs, USGS topo quadrangle sheets named "Beaver Dam"
  (a place name in WI/KY/MS, unrelated to beavers), and "The Muddy Creek
  Design for Beaver Dam Analogs" (`699df686b66b018a7ec13dc5`) — a design
  document with no attached spatial data (`distributionLinks: []`).
- **CUAHSI HydroShare general search** ("beaver dam", 24 resources):
  reviewed all 24 titles. Most are UAV imagery, DEMs, water-quality/
  water-chemistry data, or modeling outputs for a handful of intensively
  studied sites (Red Canyon Creek WY, Temple Fork UT, Spawn Creek UT) —
  not dam location inventories. Two *did* yield real location data and
  are logged above (EEAGER, Wyoming supplemental).
- **OBIS**: not queried — OBIS is marine/aquatic-species occurrence data;
  *Castor canadensis* is fully covered by GBIF (which OBIS itself
  aggregates into for freshwater mammals), so a separate OBIS pull would
  be redundant.
- **State agency BDA records** (CO CWCB, UT WRI, WY, WA RCO/PRISM, MT
  Beaver Working Group, ID): not pursued this week beyond OR (OWRI, above)
  due to time. UT WRI (wri.utah.gov) publishes no documented public API —
  confirmed via its project-search page, which is a JS UI with no visible
  bulk-download or REST endpoint. Flagged for week 2.
- **Your own Little Beaver Creek / Cameron Peak field sites**: not yet
  supplied — see `R/07_source_local.R` / `data/raw/local/manifest.csv`
  for the intake format. These would be your only genuinely field-GPS'd,
  high-confidence Colorado BDA points and are worth prioritizing next.

---

## Known issues in this environment

- **R's `curl`/`httr2` package cannot complete HTTPS requests through this
  sandbox's proxy** for at least `api.gbif.org`, `www.sciencebase.gov`, and
  `www.arcgis.com` (`Proxy CONNECT aborted`, reproduced with bare
  `curl::curl_fetch_memory()`), while the system `curl` binary reaches the
  same hosts without issue. All live API pulls in this project were
  therefore done with shell `curl` and saved as local files under
  `data/raw/`, which the R source scripts read. If you re-run this outside
  the sandbox (e.g. on your own machine per the previous session's note),
  `httr2`-based live queries should work directly and these pre-fetch
  steps are unnecessary.
- **`sf::st_line_sample()` segfaults** on this machine's GDAL 3.8.5 build
  (`CPL_gdal_linestring_sample`). Worked around in `R/01_source_eeager.R`
  by averaging line vertex coordinates instead, which is equivalent for
  the short, near-straight dam-crest lines here.
- The EPA Level III ecoregions shapefile has minor topology defects that
  break `st_join` under spherical geometry (S2); fixed with
  `st_make_valid()` and a scoped `sf_use_s2(FALSE)` in `R/08_assemble.R`.

## Note on the environment

Contrary to a note left by an earlier session ("the container blocks CRAN,
USGS, GBIF, iNaturalist, ArcGIS and the data portals"), this environment's
Bash sandbox *does* reach these hosts — each command just needs to declare
its target domains (`allowed_domains`). Every download logged above was
performed from inside this session.

---

## Poudre animation data (added 2026-10-20)

Used by `scripts/poudre_animation_data.R` -> `data/poudre_animation.json` -> `outputs/poudre_animation.html`.

- **Watershed**: USGS WBD HUC8 10190007 (Cache La Poudre), `hydro.nationalmap.gov` WBD MapServer layer 4.
- **Streams**: NHDPlus flowlines, StreamOrde >= 2 (943 reaches), `hydro.nationalmap.gov` nhd MapServer layer 4, fetched in 20 tiles (the service intermittently returns 502/504; retry works). Downstream tracing uses FromNode/ToNode.
- **Cameron Peak daily perimeters**: NIFC `Fire_Progression_Merged` (56 dated perimeters, 2020-08-13 to 2020-11-01, up to 184,329 ac) from `services3.arcgis.com/T4QMspbfLg3qTGWY`. Final perimeter (208,913 ac) from CSU `CameronPeakFire2020_Perimeter`; its own date field says 2020-10-06, so it is drawn at the Dec 2 end of the timeline and labeled "final perimeter". No perimeters are mapped between Nov 1 and the final one.
- **Beaver records**: 5 dam records (week-1 database) + 64 GBIF/iNaturalist sightings (all records in the HUC8 bbox, 50 m dedupe). Sightings are animals, not dams, and are observer-biased (clustered around Fort Collins/Greeley).
- **Green gradient = illustrative model, not water-quality data**: weight (dam 1.0, sighting 0.6) x exp(-d / 8 km) along flowlines downstream of each record, max over records, traced up to 30 km.
- Not found: daily perimeters in WFIGS (single current perimeter only), a Historic GeoMAC 2020 layer on NIFC (2019 and earlier only).

---

## USGS turbidity (pulled 2026-10-20)

Outputs: `data/usgs_turbidity_daily.csv`, `data/usgs_turbidity_discrete.csv` (script: `scripts/usgs_turbidity.R`; raw in `data/raw/usgs_turbidity/`). Public domain (USGS).

- **Continuous (parameter 63680, FNU), USGS Water Data OGC API `daily` collection** (daily min/median/max; instantaneous 15-min series not pulled):
  - 06752450 Cache la Poudre abv N 11th Ave, Greeley: 62 days, 2026-07-30 to 2026-10-08 (provisional)
  - 06752480 Cache la Poudre below Hwy 85, Greeley: 70 days, 2026-07-31 to 2026-10-11 (provisional)
  - 06736600 Big Thompson R at Jasper Lake Rd nr Drake (outside the Poudre HUC8, adjacent fire-affected basin): 255 days, 2017-11-22 to 2019-04-03 (pre-fire)
  - 06752380 Cache la Poudre nr Hwy 257, Windsor: a turbidity series is listed but has no begin/end dates and no data.
- **Discrete (Water Quality Portal, NWIS, HUC8 10190007):** 450 results, but only 1 is from a river (06752258, Shields St, Fort Collins, 1 sample in 2002). The rest are Horsetooth Reservoir (2011-14), Hansen Canal (2000-08), and wells.
- **Gap:** no USGS turbidity of any kind in the Poudre during Aug-Dec 2020. The Water Quality Portal (all providers) also returns zero turbidity stations in the HUC8 for 2020-08 to 2021-06. The legacy NWIS `iv`/`dv` services return no 2020 turbidity either.
- Cache la Poudre at Fort Collins (06752260) and the canyon-mouth gauges have no turbidity series in this API.

---

## USGS daily discharge (pulled 2026-10-20)

Outputs: `data/usgs_discharge_daily.csv` (daily mean cfs, approval status, qualifiers), `data/usgs_discharge_sites.csv` (names, locations, drainage area km2, period of record, pre-fire vs fire-period median flow). Script: `scripts/usgs_discharge.R`; raw in `data/raw/usgs_discharge/`. Source: USGS Water Data OGC API `daily` collection, parameter 00060, statistic 00003, 2015-01-01 to present. Public domain.

11 gauges, 10 with complete coverage of Aug 13 to Dec 2, 2020 (112 days):
- Cache la Poudre: 06752260 at Fort Collins, 06752280 above Boxelder Cr nr Timnath
- North Fork: 06751490 at Livermore, 06751150 below Halligan Res; 06751145 above Halligan (starts 2020-10-22, only 42 fire-period days)
- Joe Wright Creek (burned headwaters): 06746095 above reservoir (ends 2023), 06746110 below reservoir
- Adjacent fire-affected basins: 06741510 Big Thompson at Loveland, 402114105350101 Big Thompson below Moraine Park, 06614800 Michigan River nr Cameron Pass
- 06752450 Cache la Poudre at Greeley: 2026 only (78 days), no fire-period data.

Not pulled (records end before 2020): 06752000 Poudre at canyon mouth (ends 2007), 06752500 near Greeley (ends 1998), 06738000 Big Thompson at canyon mouth (ends 2007). Roughly 80 other historic or peak-only sites in the bbox were skipped.

Flags (39,956 daily values): 15.4% carry an ESTIMATED qualifier (11.2% in the Aug 13 to Dec 2, 2020 window), 0.9% ICE, 6% are provisional. (An earlier version of this note wrongly said most values were estimated.) Several gauges are below reservoirs or diversions (Halligan, Joe Wright), so flow there is regulated.

---

## Turbidity during the Cameron Peak fire: CSU ROSS Poudre Water Quality Network (pulled 2026-10-22)

- **Source:** Struthers, S., Willi, K., De La Torre, J., Ross, M. R. (2026). CSU ROSS High-Frequency Water Quality Sensor Dataset, HydroShare, https://doi.org/10.4211/hs.521e317e189e498581d0aaa08c3f32bc. **CC BY 4.0.** (Older versions 151d11da... and f6a71206... hold only 2024-25.)
- **What:** 15-minute Aqua TROLL turbidity (NTU) on the lower Cache la Poudre mainstem (below the canyon mouth, Fort Collins to Boxelder), QAQC'd "cleaned" product. Pulled the 2019, 2020, 2021 cleaned parquet files (17.7 MB total) plus site metadata, QC-flag key and delineated basins (`data/raw/ross/`). 2022-2025 files exist in the same resource (not pulled).
- **Tidy outputs:** `data/ross_turbidity_daily.csv` (daily min/median/max, days with >= 24 valid readings), `data/ross_turbidity_sites.csv`. Script: `scripts/ross_turbidity.R`. Reading parquet needs the `arrow` R package (installed into the renv library).
- **Fire-window coverage (Aug 13 to Dec 2, 2020):** salyer/Legacy Bridge 103 days, cottonwood/Prospect 77, elc/above Boxelder 71, bellvue/Tamasag 63, riverbend/Timberline 23, archery 0. No sensors in the canyon or burned headwaters, and none at beaver sites.
- **Quality caveat from the providers:** 2019-2021 predates their SOPs: no calibration data, frequent gaps, and optical sensors (turbidity) are fouling-prone, so use with caution.
- **Not found:** Fort Collins Utilities' intake/Manners Bridge turbidity (shown in charts, not archived as data); the UCLP annual reports (fcgov.com) have summary tables only (PDF). Zenodo ROSS grab-sample chemistry (10.5281/zenodo.11110885) is chemistry, not turbidity. USGS data release 10.5066/P134AK8X covers North Fork Big Thompson and Buckhorn Creek, not the Poudre (not pulled).

---

## ROSS 2022-2025 and the linked-measurements panel (2026-10-22)

- Pulled `CSU_ROSS_{2022..2025}_cleaned.parquet` (5.1, 10.7, 17.6, 18.9 MB) from the same HydroShare resource (DOI 10.4211/hs.521e317e189e498581d0aaa08c3f32bc, CC BY 4.0). `data/raw/ross/` now holds 2019-2025 (73 MB total; every file under 50 MB). `data/ross_turbidity_daily.csv` rebuilt: 10,557 site-days at 18 sites, Sep 2019 to Nov 2025 (2022-2025 adds the canyon, South Fork, Joe Wright and Chambers sites, plus Little Beaver Cr (burned) and Pennock Cr (unburned control) in 2024).
- `scripts/poudre_panel_data.R` -> `data/poudre_panel.json`: turbidity daily median/max per site, USGS daily discharge for 10 gauges, and each sonde's upstream-basin share inside the final Cameron Peak perimeter (basin polygons from the ROSS dataset). `scripts/build_poudre_animation.py` inlines both JSONs into `outputs/poudre_animation.html`.
- Burned share of upstream basin (final perimeter): Little Beaver Cr 100%, Poudre below Rustic 57%, Poudre above FC intake 44%, South Fork at Pingree 45%, Chambers outflow 35%, Poudre Falls 37%, Joe Wright below reservoir 24%, Fort Collins reach about 19%, Pennock Cr 3.9%, Joe Wright above reservoir 0.2%.
- Correction: the earlier note that most USGS discharge values were "estimated" was wrong; 15.4% are (11.2% in the fire window).

---

## River color = measured turbidity (2026-10-22)

The modeled "beaver influence" green gradient was removed from the animation. River color now comes from the CSU ROSS daily turbidity (`data/ross_turbidity_daily.csv`), carried along the NHDPlus network by `scripts/poudre_stream_turbidity.R` -> `data/poudre_stream_cov.json` (inlined by `scripts/build_poudre_animation.py`).
- Each sensor is snapped to the nearest flowline vertex (all within 243 m; Little Beaver Cr excluded because it sits at its creek's mouth, 45 m from the South Fork line).
- For every vertex the 3 nearest sensors upstream and downstream (distance along the channel) are stored. On each date the page uses the nearest sensors that have data: log-linear blend by channel distance when sensors bracket the vertex (gap <= 40 km), otherwise the nearest reading up to 3 km (drawn paler beyond 1 km). A reading travels only along its own named river (tributary readings do not color the Poudre below the confluence). Everything else stays gray-blue.
- Scale (log NTU): <= 1 green, ~10 olive, ~100 brown, >= 1,000 near-black. Visual choice, not a regulatory threshold.
- Potential coverage 227 km of river; on a given day only reaches near sensors with data are colored (17 km on Sep 14, 2020 with 3 sensors reporting; 139 km on Jul 1, 2025 with 16; none in winter).
- `scripts/poudre_animation_data.R` still computes the old modeled influence (field `i` in `data/poudre_animation.json`), but the page no longer uses it.

---

## Nitrate and pH samples, and the above/below dam-analog tracker (2026-11-10)

- **Pull:** Water Quality Portal, all providers, HUC8 10190007, 2015-01-01 to 2025-12-31, `characteristicName=Nitrate` and `pH`, narrowResult profile (4,999 results) plus the matching Station records, saved in `data/raw/wqp_poudre/`. Tidied by `scripts/poudre_wq_data.R` into `data/wq_nitrate_ph_samples.csv` (4,575 station-days, 132 stations, 39 inside the final fire perimeter) and `data/poudre_wq.json`.
- **Cleaning:** 56 results without a numeric value (non-detect or not reported) dropped; 70 nitrate results reported "as NO3" converted to as-N (x 0.2259); same-day duplicates at a station averaged. The form of the remaining nitrate values (as N or as NO3) is not stated in the CPRW volunteer records.
- **Pairs:** CPRW volunteer stations named "Above"/"Below" (Little Beaver Creek, South Fork, Sheep Creek, Fish Creek, Lazy D, Ratville), sampled about monthly from Dec 2021. Station descriptions are empty, so where the structures sit relative to each pair is not known.
- **Project timing** (from CPRW and Forest Service pages, read Nov 2026; exact dates not published): Little Beaver Creek decision signed 2024-09-03, completed fall 2024; South Fork Sep-Nov 2024; Sheep Creek summer/fall 2025. These are drawn as seasons.
- **What the data show:** Little Beaver has 22 paired samples before construction, 1 during, 3 after (Jul 25, Aug 27, Sep 19, 2025); South Fork 4 / 1 / 3; Sheep Creek 17 / 1 / 0. Median below-minus-above shifts are tiny (nitrate within 0.03 mg/L, pH within 0.09), and the median chance gap at pairs with no project known is 0.35 mg/L (nitrate) and 0.07 (pH). With 3 after-construction pairs no effect can be claimed or ruled out.
- **Page changes:** nitrate/pH sample dots on the map, the paired tracker chart, guide entries, a Limitations section. The turbidity river color is now off by default.
