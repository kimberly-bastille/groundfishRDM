# GroundfishRDM: Glossary of Recurring Terms

*A companion to the in-code documentation. This lists programming and
package-specific terms that appear repeatedly in the comments and headers, so
those comments can stay short. It assumes you already know loops, conditionals,
functions and basic data manipulation; nothing here explains R or Stata syntax
as such.*

---

## Codebase structure

**Wrapper script** — A script whose main job is to run other scripts in a
specific order, sometimes switching sections on or off via flags, rather than
doing data processing itself. `Code/pre_sim/model_wrapper.do` is the Stata
wrapper; `R code wrapper.R` is the R one, and the Stata wrapper calls it.

**Execution toggle** — A 0/1 local macro near the top of a wrapper that decides
whether a block runs on this pass. Setting one to 0 does not delete anything; it
just skips that step, which is normal when its output already exists on disk.

**Pre-sim / sim** — The two halves of the pipeline. `Code/pre_sim` prepares
inputs (MRIP survey processing, catch-at-length, directed trips, assessment
data); `Code/sim` runs the angler-choice simulation and the projections.

**Calibration vs. projection** — The calibration year is the historical year the
model is tuned to reproduce; the projection year is the future year whose
regulations are being evaluated. Many scripts have a matched pair of files, one
per period.

---

## Stata

**Global macro** — A named value defined with `global`, accessible by name
(`$name`) in *any* script that runs afterwards in the same Stata session. This
codebase uses globals for paths (`$misc_data_cd`), settings (`$ndraws`,
`$seed`), and even for whole filter expressions (`$calibration_year` expands to
a complete `if` condition). Because they persist, a script that expects a global
will silently do the wrong thing if the wrapper did not set it.

**Local macro** — The same idea, written `` `name' ``, but it disappears at the
end of the script or loop that created it. Locals are used for loop counters and
for lists built up on the fly.

**Variable-name abbreviation** — Stata resolves a variable name you type to any
unique prefix match. This makes lines like `rename month month` do real work: if
`month` has just been dropped and `month1` exists, "month" matches `month1`,
which is then renamed to `month`. The pipeline relies on this in a few places;
it is flagged in the comments wherever it occurs.

**Tempfile** — A scratch dataset (`tempfile x` / `save \`x'`) that Stata deletes
when the session ends. Used constantly here to hold intermediate results,
because Stata can only have one dataset in memory at a time.

**`preserve` / `restore`** — Save the in-memory dataset, do something else
entirely (usually load and summarize a different file), then put the original
back. The idiom that makes "one dataset in memory" workable.

**`dsconcat`** — A user-written command that stacks a list of `.dta` files into
one dataset. Used to combine MRIP files across years and waves.

**`renvarlab`** — A user-written command for bulk-renaming variables by adding a
prefix or suffix, or lower-casing them.

**`xsvmat`** — A user-written command that converts a Stata matrix (typically an
estimation result like `r(table)`) into a dataset so it can be merged and
reshaped like any other data.

**`svyset` / `svy:`** — Declares the survey design (sampling unit, stratum,
weight) and then runs an estimator that accounts for it. MRIP is a complex
survey, so a plain `mean` would give the wrong standard error.

**PSU and stratum** — The survey design's sampling unit (a site-day, roughly)
and the group it was sampled within. They determine how uncertainty is
calculated, not how the data are analyzed substantively.

**Domain estimation** — Estimating a total or mean for a subgroup (here: trips
that targeted or caught cod/haddock) while keeping the rest of the sample in the
calculation. Dropping the other records first would give the wrong variance,
which is why several scripts classify records into `dom_id=1`/`dom_id=2` instead
of filtering.

**`merge` / `_merge`** — Joining two datasets on key variables. The `1:1`,
`1:m`, `m:1` prefix declares how many rows on each side may match, and Stata
errors if reality disagrees — so it doubles as an assertion. `keep(1 3)` means
"keep unmatched rows from the file in memory and matched rows", i.e. a left
join; `keep(3)` is an inner join. The `_merge` variable records which case each
row fell into.

**`collapse`** — Aggregates the dataset in place to one row per group
(`by(...)`), replacing the data in memory. Roughly `GROUP BY`.

**`reshape long` / `reshape wide`** — Pivot between one-row-per-entity with many
columns and one-row-per-entity-per-measure. Used heavily to turn matrices of
estimates into tidy tables.

**`expand`** — Duplicates rows. Used to replicate a table across draws or across
seasons when the same values apply to each.

**`tsset` + `tsfill`** — Declares a panel/time structure and then inserts the
missing rows so every group spans a contiguous range. Used here on length bins
and on calendar days, not on time series in the econometric sense.

**`mvencode`** — Replaces missing values with a specified number, usually 0.
`override` forces it even on variables Stata thinks are ill-suited.

**`postfile` / `post` / `postclose`** — Writes results row-by-row to a new
dataset from inside a loop, without disturbing the data in memory.

**`display` / `di`** — Prints a message to the Results window. In this codebase
these are treated as documentation: they mark the start and end of blocks that
take a long time to run.

---

## R

**`data.table` non-standard evaluation (NSE)** — Inside `DT[i, j, by]`, column
names are written bare, as if they were variables in scope. `DT[, CV := x - y]`
adds a column named `CV`; the `:=` assigns **by reference**, modifying the table
in place rather than returning a copy. This is why a function can change a
data.table its caller passed in.

**Keyed join** — `setkey()` sorts a data.table by columns and lets later merges
use those columns implicitly and quickly. Order matters: the key determines what
`DT[other]` joins on.

**`fst` / `feather`** — Binary file formats for fast reading and writing of data
frames. Used instead of CSV wherever a file is written by one stage and read by
the next, purely for speed and size.

**`list2env`** — Takes a named list and creates one variable per element in a
given environment. The projection code uses it to unpack a list of inputs into
plain objects, so downstream code can refer to them by name.

**Roxygen2** — The `#'` comment convention above a function that documents its
title, parameters and return value. The tags (`@param`, `@return`, …) are just
structured comments here; nothing in this project generates package
documentation from them.

**Reactive (Shiny)** — An expression that re-runs automatically when something it
reads changes, and caches its result otherwise. `outputs()` in `app.R` is a
reactive: it reads the results folder, and every plot that calls it shares the
same cached read.

**`observeEvent`** — A Shiny block that runs for its side effect when a specific
input changes — writing a file, sending a message — rather than producing a
displayed value.

**`future` / `future.apply`** — Runs iterations in parallel across several R
processes (`multisession`). Each worker starts empty, so anything the loop body
needs must be passed in or re-loaded inside it.

**Logsum** — The log of the summed exponentiated utilities across the choices
available. In a logit model it is the expected utility of the whole choice set;
dividing the change in logsum by the (negative) cost coefficient converts it to
dollars.

**Compensating variation (CV)** — The dollar amount that makes an angler as well
off under the new policy as under the baseline. Positive means the policy makes
anglers better off. Computed here from the logsum, per choice occasion.

---

## Modeling and data

**MRIP** — Marine Recreational Information Program, the survey that produces the
recreational catch and effort estimates this model is calibrated to.

**A+B1 / B2** — MRIP catch categories. A+B1 is harvest (fish available for
identification plus fish reported kept); B2 is fish released alive. The model
tracks them separately because only harvest is limited by a bag limit.

**Directed trip** — A trip that targeted or caught the species of interest. The
unit that effort is measured in throughout this pipeline.

**Kind-of-day (`kod`)** — Weekend (including federal holidays) versus weekday.
Effort differs sharply between the two, so it is a stratum everywhere.

**Mode (`pr` / `fh` / `sh`)** — Private boat, for-hire (charter and headboat
combined), and shore. Shore trips are dropped throughout; the model covers the
two boat modes.

**WGOM** — Western Gulf of Maine, the cod stock area this model covers. MRIP
records an interview *site*, not a stock area, so a site list is merged in to map
sites to NMFS statistical areas, and areas 513–515, 521, 526 and 541 are
treated as WGOM.

**Draw** — One replicate of the whole model, carrying one sampled value of every
uncertain input (catch rates, trip counts, projected stock size). Results are
summarized as medians and intervals across draws.

**NAA / NAL** — Numbers-at-age and numbers-at-length. The stock assessment
produces NAA; an age-length key converts it to NAL so it can be compared with
the length composition of recreational catch.

**Age-length key (ALK)** — The probability that a fish of a given age is a given
length, estimated here from NEFSC trawl survey data and smoothed with a LOWESS.

**Selectivity at length** — The fraction of the fish present at each length that
the fishery catches. Estimated in the calibration year and held fixed in the
projection, so that changes in catch composition come only from changes in the
stock.

**Copula** — A way of modeling two counts (cod and haddock caught on the same
trip) with their own separate distributions plus a chosen dependence structure.
Used because catch of the two species is correlated within a trip.

**Method of moments (MOM)** — Setting distribution parameters so the fitted mean
and variance equal the observed ones, instead of maximizing a likelihood. Used
here for the gamma catch-at-length fits and the negative binomial dispersion,
because the likelihood fits failed to converge on sparse domains.

**Bag limit / minimum size** — The two regulations the model varies: how many
fish an angler may keep, and how long a fish must be to be kept. Minimum sizes
are entered in inches and converted to centimetres (× 2.54) internally.

**ACL** — Annual catch limit. The reference point results are compared against;
in `app.R`, 118 mt for cod and 1,146 mt for haddock.
