# Manual NAIP labelling protocol (fallback / supplement)

Use this if the assembled database comes in under ~100 usable Western
montane presence points, or to add Colorado points where no inventory
exists. Method follows the NM census, which achieved 4,372 dams in 305
person-hours (~14 dams/hour).

## Setup

- Imagery: NAIP, 0.6–1 m, most recent leaf-on year for the county
- Overlay: NHD perennial flowlines + BRAT capacity, so you only scan
  reaches that could plausibly host beaver
- View at a digital altitude of roughly 200–800 m

## Evidence required — a point needs **two or more**

1. Impounded water with an abrupt, straight or gently arcuate downstream edge
   perpendicular to flow (the dam crest)
2. A pond that is wider than the channel upstream and downstream of it
3. Stepped or terraced ponds in series along the reach
4. Visible dam structure — a light-toned linear feature across the channel
5. Riparian harvest: thinned or cleared willow/aspen adjacent to the pond
6. Lodge or bank den

**One line of evidence is not a dam.** Beaver ponds are confused with:
stock ponds (usually rectangular, road-accessed, off-channel), road-crossing
impoundments, natural wetland pools, and mine or quarry water.

## Recording

Digitise a point at the centre of the dam crest, not the pond centroid.
Record in `data/raw/local/` as a CSV or GPKG and add a row to
`manifest.csv`:

```
file,type,confidence,source,source_url,spatial_acc_m,state,date_observed,notes
poudre_labels.gpkg,natural_dam,high,"Manual NAIP labelling — S. Nauman",local,5,CO,2023-07-01,"NAIP 2023; 3 lines of evidence"
```

Set `confidence = high` for 3+ lines of evidence, `medium` for 2.

## Absence points — do not skip these

A classifier needs negatives, and almost everyone forgets them. Generate
candidate absences from reaches with **high BRAT capacity but no ponding
signature**, then confirm on NAIP that there is genuinely no dam. Aim for
a 1:1 to 1:3 presence:absence ratio, drawn from the same ecoregions and the
same imagery years as the presences — otherwise the model learns imagery
vintage rather than beaver.

Record absences the same way with `type = absence` (add it to
`TYPE_LEVELS` in `R/00_setup.R` when you get to this step).

## Blind validation

Hold out 20% of your labels before you look at any model output, and have
a second person re-label 50 random points so you can report inter-rater
agreement. Photointerpreted labels without an agreement statistic are hard
to defend in a write-up.
