# scripts/poudre_stream_turbidity.R
# For every stream vertex, find the nearest turbidity sensors UPSTREAM and
# DOWNSTREAM along the river network (distance in metres along the channel).
# The animation uses these to color the river by measured turbidity on each day:
#   - between two sensors with data that day: log-linear interpolation by channel distance
#   - beyond the outermost sensor: the nearest reading, up to EXT_M, drawn faded
#   - everywhere else: no color (neutral)
# Inputs : data/poudre_animation.json (stream geometry + topology), data/poudre_panel.json (sensor sites)
# Output : data/poudre_stream_cov.json
suppressMessages({library(jsonlite); library(sf); library(dplyr)}); sf_use_s2(FALSE)

EXCLUDE <- c('lbea')   # Little Beaver Cr sonde sits at its mouth, 45 m from the South Fork line: would color the wrong stream
SNAP_M <- 600       # a sensor must be within this of a flowline vertex to color the river
MAX_M  <- 40000     # farthest a reading is carried along the channel
K      <- 3         # candidate sensors kept per side per vertex (a sensor may have no data that day)

A <- fromJSON("data/poudre_animation.json", simplifyVector = FALSE)
PN <- fromJSON("data/poudre_panel.json", simplifyVector = FALSE)
st <- A$streams; nL <- length(st)

proj <- function(lonlat) st_coordinates(st_transform(st_sfc(st_multipoint(lonlat), crs = 4326), 5070))[, 1:2, drop = FALSE]
coords <- lapply(st, function(s) { m <- matrix(unlist(s$c), ncol = 2, byrow = TRUE); proj(m) })
cum <- lapply(coords, function(m) c(0, cumsum(sqrt(rowSums(diff(m)^2)))))
len <- vapply(cum, function(x) x[length(x)], 0)
fn <- vapply(st, function(s) s$fn, 0); tn <- vapply(st, function(s) s$tn, 0); da <- vapply(st, function(s) s$da, 0)
nm <- vapply(st, function(s) s$n, "")
succ <- lapply(seq_len(nL), function(i) which(fn == tn[i]))
pred_main <- vapply(seq_len(nL), function(i) { p <- which(tn == fn[i]); if (!length(p)) NA_integer_ else p[which.max(da[p])] }, 1L)

# ---- snap sensors ------------------------------------------------------------
ross <- PN$ross
sx <- do.call(rbind, lapply(ross, function(r) c(r$lon, r$lat))); sp <- proj(sx)
allv <- do.call(rbind, lapply(seq_len(nL), function(i) cbind(line = i, vtx = seq_len(nrow(coords[[i]])), coords[[i]])))
snap <- t(vapply(seq_len(nrow(sp)), function(k) { d <- sqrt((allv[, 3] - sp[k, 1])^2 + (allv[, 4] - sp[k, 2])^2); j <- which.min(d); c(allv[j, 1], allv[j, 2], d[j]) }, numeric(3)))
cat("Sensor snapping (distance to nearest NHDPlus vertex, order>=2 network):\n")
print(data.frame(id = vapply(ross, function(r) r$id, ""), line = snap[, 1], river = vapply(snap[, 1], function(l) st[[l]]$n, ""),
                 order = vapply(snap[, 1], function(l) st[[l]]$o, 0), snap_m = round(snap[, 3]), used = snap[, 3] <= SNAP_M & !vapply(ross, function(r) r$id %in% EXCLUDE, TRUE)), row.names = FALSE)

# ---- candidate lists --------------------------------------------------------------
U <- lapply(coords, function(m) vector("list", nrow(m)))   # sensors UPSTREAM of the vertex: (sensor, dist)
D <- lapply(coords, function(m) vector("list", nrow(m)))   # sensors DOWNSTREAM of the vertex
add <- function(side, l, j, k, d) { if (side == 'U') U[[l]][[j]] <<- c(U[[l]][[j]], list(c(k, d))) else D[[l]][[j]] <<- c(D[[l]][[j]], list(c(k, d))) }

use <- snap[, 3] <= SNAP_M & !vapply(ross, function(r) r$id %in% EXCLUDE, TRUE)
for (k in which(use)) {
  l0 <- snap[k, 1]; v0 <- snap[k, 2]; N0 <- nm[l0]
  same <- function(l) nm[l] == N0 || nm[l] == '' || N0 == ''   # a reading travels only along its own named river
  # downstream sweep: the sensor is upstream of these vertices
  d0 <- cum[[l0]] - cum[[l0]][v0]; for (j in which(d0 >= 0 & d0 <= MAX_M)) add('U', l0, j, k, d0[j])
  best <- numeric(0); queue <- list(list(l = l0, ds = -cum[[l0]][v0]))
  while (length(queue)) { q <- queue[[1]]; queue <- queue[-1]; de <- q$ds + len[q$l]; if (de > MAX_M) next
    for (nx in succ[[q$l]]) { if (!same(nx)) next; key <- as.character(nx); if (!is.na(best[key]) && best[key] <= de) next; best[key] <- de
      dd <- de + cum[[nx]]; for (j in which(dd <= MAX_M)) add('U', nx, j, k, dd[j]); queue[[length(queue) + 1]] <- list(l = nx, ds = de) } }
  # upstream sweep along the main stem: the sensor is downstream of these vertices
  d1 <- cum[[l0]][v0] - cum[[l0]]; for (j in which(d1 > 0 & d1 <= MAX_M)) add('D', l0, j, k, d1[j])
  l <- l0; dstart <- cum[[l0]][v0]          # distance from sensor to the START of line l
  repeat { p <- pred_main[l]; if (is.na(p) || dstart > MAX_M || !same(p)) break
    dd <- dstart + (len[p] - cum[[p]]); for (j in which(dd <= MAX_M)) add('D', p, j, k, dd[j]); dstart <- dstart + len[p]; l <- p }
}

keep_k <- function(lst) { if (is.null(lst)) return(NULL); m <- do.call(rbind, lst); m <- m[order(m[, 2]), , drop = FALSE]; m <- m[!duplicated(m[, 1]), , drop = FALSE]
  m <- head(m, K); as.vector(t(cbind(m[, 1] - 1, round(m[, 2] / 10) * 10))) }   # 0-based sensor index, distance rounded to 10 m
cov <- list()
for (l in seq_len(nL)) { has <- which(!vapply(U[[l]], is.null, TRUE) | !vapply(D[[l]], is.null, TRUE)); if (!length(has)) next
  cov[[length(cov) + 1]] <- list(s = l - 1L, v = has - 1L,
    u = lapply(has, function(j) keep_k(U[[l]][[j]]) %||% list()), d = lapply(has, function(j) keep_k(D[[l]][[j]]) %||% list())) }
nv <- sum(vapply(cov, function(z) length(z$v), 0)); km <- sum(vapply(cov, function(z) { l <- z$s + 1; sum(len[l] * length(z$v) / nrow(coords[[l]])) }, 0)) / 1000
cat(sprintf("\nstream lines with any coverage: %d of %d; covered vertices: %d; approx river length within reach of a sensor: %.0f km\n", length(cov), nL, nv, km))
write_json(list(params = list(snap_m = SNAP_M, max_m = MAX_M, k = K), cov = cov, snapped = as.integer(use)),
           "data/poudre_stream_cov.json", auto_unbox = TRUE, digits = NA, null = "null")
cat("wrote data/poudre_stream_cov.json", round(file.size("data/poudre_stream_cov.json") / 1e6, 2), "MB\n")
