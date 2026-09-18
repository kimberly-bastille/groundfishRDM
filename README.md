# groundfishRDM

Recreational Decision Support Tool (RecDST) for Gulf of Maine Cod and Haddock.

Last updated September 10, 2026

## Overview

groundfishRDM implements a Stata → R → Shiny pipeline that simulates how recreational fishing regulations — season dates, bag limits and minimum sizes — affect fishing outcomes for Atlantic cod and haddock in the Western Gulf of Maine. Raw MRIP survey data and stock assessment output are processed in Stata and R against. It is combined with the results of a valuation survey. Stakeholders can use a RShiny application to design and evaluate candidate regulation packages and compare their predicted mortality, harvest, and angler-welfare consequences.

The scientific core is a discrete-choice model of angler trip-taking behavior, combined with copula-based simulation of correlated cod/haddock catch per trip and Monte Carlo propagation of uncertainty across \~100 draws. Results are compared against annual catch limits (2026 Rec subACLs are 118 mt for WGOM cod and 1,146 mt for GOM haddock) so managers can weigh conservation targets against recreational access.

This repository is the closely related to **flukeRDM** (summer flounder, black sea bass and scup in the Mid-Atlantic). The two share a common origin and a near-identical house style — same wrapper filenames, same toggle convention, same `$developer` startup sequence. groundfishRDM is the more thoroughly hardened of the two and many recent changes in groundfishRDM will be ported over to flukeRDM.

## Repository Structure

| Path | Contents |
|----|----|
| `Code/pre_sim/` | Stage 1. Stata data processing (\~20 `.do` files) plus the R scripts Stata invokes via `rscript using` — MRIP Oracle pull, copula modeling, Google Drive pushes. Orchestrated by `model_wrapper.do`. |
| `Code/sim/` | Stage 2. R calibration and simulation. Orchestrated by `R code wrapper.R`. Also holds `predict_rec_catch_functions.R` (used by the projection path) and `required_packages.R`. |
| `Code/helpers/` | Leaf utilities sourced by other scripts: `developer_setup.R` / `developer_setup_stata.do` (path bootstrap), Google Drive auth, NAA helpers, WHAM version installer. Not orchestrators. |
| `Code/test_code/` | Development and QA scratch scripts. Not called by any wrapper; several hard-code developer-specific absolute paths. Archive candidate. |
| `RecDST/` | `model_run.R` — the single unified cod/haddock projection runner invoked by `Run_Model.R`. |
| `docs/` | `Run_Summary.Rmd` / `.html` — rendered analysis summary; `USER_GUIDE_GROUNDFISH.md`; `GulfofMaineCodandHaddockSurvey2025.pdf`; `figures/`. |
| `input_data/` | Local raw and reference inputs (assessment NAA files, trawl data). Empty in a fresh checkout. |
| `Data/` | Pipeline output consumed downstream. Gitignored; empty in a fresh checkout. |
| `keda/` | KEDA (Kubernetes Event-Driven Autoscaling) configuration — queue-creation scripts, `consume_and_run.sh` worker entrypoint, `scaledjobgroundfish.yaml`. |
| `shiny-deployment/` | Kubernetes / ShinyProxy / Helm deployment manifests (\~51 YAML files), plus its own `README.md` and `prometheus.md`. |
| `.devcontainer/` | VS Code dev container definition. |
| `.secrets/` | Cached `googledrive` OAuth token location. Gitignored; a placeholder is committed. |
| `app.R` | The Shiny application (root level, monolithic single file). |
| `Run_Model.R` | CLI entry point for a projection run: `Rscript Run_Model.R <Run_Name>`. |
| `Model_Summary.Rmd` / `.html` | Long-form model documentation. |
| `Dockerfile` | Shiny app image (`rocker/shiny:4.3`). |
| `Dockerfile.RmodelGroundFish` | Model-runner worker image (`rocker/r-ver:4.3.2`). |
| `shiny-server.conf`, `load_env.sh`, `.env.example` | Deployment configuration and environment variable template. |

Two directories are created at runtime and are **not** in a fresh checkout: `output/` (model result CSVs) and `saved_regs/` (submitted regulation scenarios). Both are gitignored and both are required by `app.R` — see [Running the Shiny Application](#running-the-shiny-application).

## Requirements

### R Package Dependencies

**No version pinning exists** for these packages: there is no `renv.lock`, no `DESCRIPTION`, and no explicit version comments anywhere in the code. The one exception is WHAM (see below). Versions below are therefore listed only where the code actually states one.

**Data manipulation and I/O** `arrow`, `conflicted`, `data.table`, `doBy`, `dplyr`, `feather`, `fs`, `fst`, `glue`, `haven`, `here`, `magrittr`, `plyr`, `purrr`, `readr`, `readxl`, `reshape2`, `rlist`, `splitstackshape`, `stringr`, `tibble`, `tidyr`, `tidyverse`, `WriteXLS`, `writexl`

**Statistical modeling** `copula`, `fitdistrplus`, `Hmisc`, `logspline`, `MASS`, `psych`, `Rcpp`, `scales`, `survey`, `univariateML`, `VineCopula`, `wCorr`, `weights`

**Parallel execution** `furrr`, `future`, `future.apply`, `profvis`

**Plotting and reporting** `ggplot2`, `gridExtra`, `knitr`, `lubridate`, `patchwork`, `plotly`, `rgl`

**Shiny** `DT`, `shiny`, `shinyjs`, `shinyWidgets`

**External data access** `DBI`, `googledrive`, `httr`, `jsonlite`, `openssl`, `ROracle`, `RStata`, `uuid`

**Stock assessment** `remotes`, `TMB`, `wham`, `mriptacklebox`

Base and recommended packages that ship with R (`grid`, `parallel`, `stats`, `tools`, `graphics`) are used but not listed as dependencies.

**Not on CRAN — install from GitHub:**

| Package | Source | Notes |
|----|----|----|
| `mriptacklebox` | `NEFSC/READ-PDB-mriptacklebox` | Provides the Oracle connection (`nefscdb_con`) used by `Code/pre_sim/get_mrip_oracle.R`. Install line is present but commented out at that file's line 37. |
| `wham` | `timjmiller/wham` | **Version-pinned by commit hash.** `Code/helpers/wham_version_installer.R` reads the `wham_commit` provenance string out of each accepted assessment `.rds` model and installs that exact commit into a per-species library path (`R_LIBS_USER/cod_wham_install`, `R_LIBS_USER/haddock_wham_install`). This is the only genuine version pin in the repository. |

**Planned**

We are working on the [dstoolkit](https://github.com/kimberly-bastille/dstoolkit) package. This is intended to be a collection of functions that are used in both repositories. A package of shared libraries will reduce ongoing maintenance time/costs. It will also make it easier to develop new models of this type.

**Declared in the Dockerfiles but with no `library()` call found in the code:** `markdown`, `openxlsx`, `parallelly`, `rlang`. These are installed into the container images but appear unused by current code — treat as candidates for removal rather than as confirmed dependencies.

### Software Requirements

-   **R 4.3** — pinned by the Docker base images: `rocker/shiny:4.3` for the app, `rocker/r-ver:4.3.2` for the model-runner worker. No `.Rprofile` or `renv` constraint exists in the repository itself.
-   **Stata 17** — Expect to install several SSC packages.
-   **Oracle client** — required by `ROracle`/`DBI` for the MRIP data pull.
-   **Google Drive access** — several pipeline steps read from and write to the "NMFS NEC READ SSB" shared drive. `get_assessment_from_gdrive.do` additionally assumes the Drive client is mounted at `D:`.
-   **Docker / Kubernetes / KEDA / ShinyProxy / Redis Sentinel / Azure** — production deployment stack. See `shiny-deployment/README.md`.

## Running the Pipeline

### Prerequisite: set `developer`

Both the Stata and R halves require an externally-set developer identifier that **is not defined anywhere in this repository**:

-   Stata: `$developer`, asserted in `Code/helpers/developer_setup_stata.do`
-   R: `developer`, asserted in `Code/helpers/developer_setup.R` via `stopifnot(developer %in% c("TP","LCH","ML","KB"))`

This value branches the data-root path global (`$gfdatadir` / `gf.data.dir`). It must be set with .Rprofile or profile.do before anything runs.

### Stage 1 + 2: `Code/pre_sim/model_wrapper.do`

One command runs the whole pipeline. groundfishRDM chains its two wrappers: the Stata wrapper's final toggle-gated step invokes the R wrapper directly, so Stata → R is a real code-level hand-off, not a manual sequencing convention.

```         
do Code/pre_sim/model_wrapper.do
```

Execution order and the controlling toggle for each step:

```
 0.                                   developer_setup_stata.do          (unconditional)
 1.  pull_assessment                  get_assessment_from_gdrive.do
 2.  pull_MRIP                        get_mrip_oracle.R → tidyup_mrip_data_fromR.do
 3.  processMRIP                      MRIP_column_cases.do              ["dead code" per source]
 4.  assemblemriplists                MRIP_lists.do                     ["dead code" per source]
 5.  estimate_dtrips                  directed_trips_calibration.do
       5a.                            └─ set_regulations.do             (nested, unconditional)
 6.  costs_per_trip                   survey_trip_costs.do
 7.  draw_angler_preferences          estimate_angler_preferences.do
 8.  catch_per_trip1                  calibration_catch_per_trip_part1.do
 9.  copula_in_R                      copula_modeling_calibration.R
10.  catch_per_trip2                  calibration_catch_per_trip_part2.do
11.  compare_calibration_MRIP         compare_calibration_data_to_MRIP.do
12.  prep_cpt_for_dashboard           rdb_processing_catch_per_trip.do
13.  Rpush_cpt_to_gdrive              rdb_catch_per_trip_to_drive.R
14.  angler_demogs                    additional_angler_dems.do
15.  generate_baseline                catch_at_length_calibration.do
                                        └─ catch_at_length_programs.do  (loaded, not toggled)
16.  prep_catch_at_length_for_dash    rdb_catch_at_length.do
17.  Rpush_catch_at_length_to_gdrive  rdb_catch_at_len_to_drive.R
18.  catch_at_length_project          catch_at_length_projection.do
                                        └─ catch_at_length_programs.do  (loaded, not toggled)
19.  run_calibration                  Code/sim/R code wrapper.R
       19a.                           ├─ developer_setup.R
       19b.                           ├─ calibrate_rec_catch0.R              ["STEP 1"]
       19c.                           ├─ calibration_routine.R               ["STEP 2"]
                                      │    └─ calibrate_rec_catch1.R  (re-sourced in loops)
       19d.                           └─ export_to_GoogleDrive.R
```

**About the toggles.** All 19 are Stata *locals* (not globals), defined in one contiguous
block in Section D ("Execution control") of `model_wrapper.do`, uniformly `0`/`1`,
uniformly checked via `` if `toggle' ``. Setting one to `0` deletes nothing — it just
skips that step, which is normal when its output already exists on disk. **The committed
values are not defaults.** They are whatever the last developer ran, and they change from
commit to commit; check Section D before every run and set each toggle for the run you
intend. `processMRIP` and `assemblemriplists` are labeled "(dead code)" in the wrapper's
own comments and are expected to stay `0`.

A 20th flag, `proto`, sits just below the toggles. It gates no script: when it is `1` the
wrapper overwrites `$ndraws` (set to 101 in Section A) with a small number for fast
prototyping runs. Like the toggles, its committed value reflects the last run, not a
default; a production run needs `proto = 0`. The wrapper prints a reminder at the end of
its log when `proto` was on.


Two steps are slow enough to look hung but are not: `pull_MRIP` (the Oracle pull) and `copula_in_R` — the latter carries an explicit "this takes a while and will look like it's hung. it's not" comment. Two steps are commented "run 1x" (`costs_per_trip`, `draw_angler_preferences`), implying they are not meant to be re-run every pass.

`set_regulations.do` requires **manual editing every year** to enter status-quo regulations for the calibration and projection years. It is reached only through `estimate_dtrips`; the wrapper never calls it directly.

### Stage 3: the projection run

```         
Rscript Run_Model.R <Run_Name>
```

`Run_Model.R` → `RecDST/model_run.R` → `Code/sim/predict_rec_catch_functions.R`. It reads `saved_regs/regs_<Run_Name>.csv` and writes results into `output/`.

This path has **no code-level link** to either wrapper or to `app.R`. It consumes files the wrappers produce, but the connection is a shared-filesystem convention rather than a call. In production, `app.R` enqueues an Azure Storage queue message and a separate worker (`keda/consume_and_run.sh`, running the `Dockerfile.RmodelGroundFish` image) picks it up and executes this command.

Scripts with no confirmed caller anywhere in the repo — `RP_data_analysis.do`,
`baseline_and_projected_NAL.do`, `get_cod_assessment_data.R`,
`get_haddock_assessment_data.R`, `get_commercial_landings.R`
— are legacy, exploratory, or run manually. 

The two `get_*_assessment_data.R` scripts are how the the pre-computed assessment files that step 1 downloads are generated in
the first place

## Data Flow Summary

```         
External sources
  MRIP survey (Oracle)   Stock assessment (WHAM, via Google Drive)   NEFSC trawl survey
        │                              │                                    │
        └──────────────────────────────┴────────────────────────────────────┘
                                       ▼
  STAGE 1 — Stata, Code/pre_sim/            [model_wrapper.do]
    survey-weighted domain estimation of directed trips and catch per trip;
    trip-cost and angler-preference draws; catch-at-length for calibration and
    projection years via an age-length key
        → directed trip draws, baseline MRIP catch, baseline catch-at-length
                                       ▼
    copula_modeling_calibration.R  — correlated cod/haddock catch draws per trip
                                       ▼
  STAGE 2 — R, Code/sim/                    [R code wrapper.R]
    iterative reallocation of harvest and discards until simulated totals match
    MRIP; non-converging draws filtered out; results written as .fst for fast
    Shiny loading
        → calibrated_model_stats, base_outcomes_*, n_choice_occasions_*
                                       ▼
  STAGE 3 — R projection                    [Run_Model.R → RecDST/model_run.R]
    applies a user's regulation scenario, runs the discrete-choice simulation in
    parallel across draws, aggregates with uncertainty
        → output/<run>.csv   (long format: model, species, mode, draw, metric, value)
                                       ▼
  SHINY — app.R
    reads output/*.csv and saved_regs/*.csv; writes saved_regs/regs_<name>.csv and
    enqueues a job message. Never runs the model itself.
```

Both hand-offs out of Stage 2 are filesystem-only. The Stata → R hand-off (Stage 1 → 2) is the pipeline's one true code-level chain.

Cross-script state is carried almost entirely by Stata **global macros** set in the wrapper and read by every script that runs afterwards in the same session — paths (`$misc_data_cd`, `$figure_cd`, `$gfdatadir`, `$calib_catch_draws_cd`), settings (`$ndraws`, `$seed 03211990`), and in some cases whole filter expressions (`$calibration_year` expands to a complete `if` condition). A script that expects a global the wrapper did not set will silently do the wrong thing rather than error. The R side follows the same pattern with global-environment objects set at the top of `R code wrapper.R` (`code_cd`, the `final_process_*_cd` paths, `n_simulations`, `n_draws`) and consumed implicitly by everything it sources.

## Running the Shiny Application {#running-the-shiny-application}

``` r
# from the repository root
shiny::runApp("app.R")
```

`app.R` is a single monolithic file — there is no `global.R`, `ui.R` or `server.R` split, and it makes no `source()` or `system()` calls. It does two separable jobs: browse completed model runs, and compose a new regulation scenario and submit it.

**Must exist before launching:**

| Requirement | Produced by |
|----|----|
| `output/*.csv` | Stage 3 projection runs (`Rscript Run_Model.R <Run_Name>`), which in turn need Stages 1 and 2 to have completed |
| `saved_regs/*.csv` | Previous submissions through the app; the directory must exist for new scenarios to be written |
| `GROUNDFISH_AZURE_STORAGE_QUEUE_URL` | Environment variable holding a SAS-authenticated Azure Storage queue URL. Without it, submitting a run fails. See `.env.example` and `load_env.sh`. |

Neither `output/` nor `saved_regs/` is in the repository — both are gitignored and must be created locally. With empty directories the app launches but the results tab has nothing to display.

**The app never runs the simulation.** Submitting a scenario writes `saved_regs/regs_<Run_Name>.csv` and posts one queue message; a separate worker consumes that message and runs the model. The results page does not change until the worker finishes and the user clicks "Update", which reloads the page.

## Known Issues & Technical Debt

**Pipeline structure** - The Stage 3 projection path (`Run_Model.R` → `model_run.R`) has no code-level tie to the wrappers or to `app.R`. It works, but nothing in the repository enforces or records that it must run after Stage 2 and before the app is refreshed. - `$developer` (Stata) and `developer` (R) are required but defined nowhere in the repo. - `MRIP_column_cases.do` and `MRIP_lists.do` are self-labeled "(dead code)" and default OFF. If `assemblemriplists` is ever flipped on, `$catchlist`/`$triplist`/`$b2list`/ `$sizelist` silently switch from one consolidated file each to many per-wave files. - `R code wrapper.R` line 137 references `predict_rec_catch.R`, which does not exist under that name — a stale, commented-out reference.

## Documentation Index

### In this repository

| File | Contents |
|----|----|
| `Model_Summary.Rmd` / `.html` | Long-form description of the model and its outputs. |
| `GLOSSARY_GROUNDFISH.md` | Full glossary of Stata, R and modeling terms (the table below is the short version). |
| `docs/USER_GUIDE_GROUNDFISH.md` | User guide for the decision support tool: how the model works, an app walkthrough, and how to read results. |
| `docs/Run_Summary.Rmd` / `.html` | Rendered summary of a model run. |
| `docs/GulfofMaineCodandHaddockSurvey2025.pdf` | Reference PDF, 2025 Gulf of Maine cod and haddock survey. |
| `shiny-deployment/README.md` | Kubernetes / ShinyProxy deployment instructions. |
| `shiny-deployment/prometheus.md` | Monitoring setup. |
| `shiny-deployment/deployment/README.md`, `.../overlays/1-namespaced/README.md` | Kustomize overlay notes. |
| `.env.example` | Template for the environment variables the app and worker require. |
| In-code headers | Every pipeline script carries a structured header block — Purpose, Inputs, Outputs, Dependencies, Pipeline position — plus section banners. This is the most reliable per-file documentation in the repository and is kept current with the code. |

## Glossary

The terms below are the ones you will hit immediately. The full glossary — covering Stata idioms (`preserve`/`restore`, `dsconcat`, `renvarlab`, `xsvmat`, domain estimation, variable-name abbreviation), R idioms (`data.table` NSE, keyed joins, `list2env`, Shiny reactives) and the rest of the modeling vocabulary — is in `GLOSSARY_GROUNDFISH.md`.

| Term | Meaning |
|----|----|
| **Wrapper script** | A script whose job is running other scripts in order, with sections switched on or off by flags, rather than processing data itself. |
| **Execution toggle** | A `0`/`1` local macro near the top of a wrapper gating whether a block runs on this pass. Setting one to `0` deletes nothing — it skips a step whose output is already on disk. |
| **Pre-sim / sim** | The two halves of the pipeline. `Code/pre_sim` prepares inputs; `Code/sim` runs the simulation and projections. |
| **Calibration vs. projection year** | The calibration year is the historical year the model is tuned to reproduce; the projection year is the future year whose regulations are being evaluated. Many scripts come in matched pairs, one per period. |
| **Global macro** | A Stata value defined with `global`, readable as `$name` in *any* script running later in the same session. Used here for paths, settings, and even whole filter expressions. Because they persist, a script expecting a global the wrapper never set will silently misbehave. |
| **`svyset` / `svy:`** | Declares the survey sampling design, then runs an estimator that respects it. MRIP is a complex survey — a plain `mean` gives the wrong standard error. |
| **Domain estimation** | Estimating for a subgroup while keeping the rest of the sample in the variance calculation. This is why scripts classify records into `dom_id=1`/`dom_id=2` instead of filtering them out. |
| **MRIP** | Marine Recreational Information Program — the survey producing the catch and effort estimates this model calibrates to. |
| **A+B1 / B2** | MRIP catch categories. A+B1 is harvest; B2 is fish released alive. Tracked separately because only harvest is bag-limited. |
| **Directed trip** | A trip that targeted or caught the species of interest. The unit effort is measured in throughout. |
| **Mode** (`pr` / `fh` / `sh`) | Private boat, for-hire (charter and headboat), shore. Shore trips are dropped; the model covers the two boat modes. |
| **Kind-of-day** (`kod`) | Weekend (including federal holidays) versus weekday. Effort differs sharply, so it is a stratum everywhere. |
| **WGOM** | Western Gulf of Maine, the cod stock area covered. MRIP records an interview *site*, so a site list maps sites to NMFS statistical areas; areas 513–515, 521, 526 and 541 are treated as WGOM. |
| **Draw** | One replicate of the whole model, carrying one sampled value of every uncertain input. Results are summarized as medians and intervals across draws. |
| **Copula** | A way of modeling two counts (cod and haddock caught on the same trip) with their own marginal distributions plus a chosen dependence structure. Used because the two species' catch is correlated within a trip. |
| **NAA / NAL** | Numbers-at-age and numbers-at-length. The assessment produces NAA; an age-length key converts it to NAL. |
| **Age-length key (ALK)** | The probability a fish of a given age is a given length, estimated from NEFSC trawl survey data and LOWESS-smoothed. |
| **Selectivity at length** | The fraction of fish present at each length that the fishery catches. Estimated in the calibration year and held fixed in projection, so catch-composition change comes only from stock change. |
| **Logsum** | The log of summed exponentiated utilities across available choices — in a logit model, the expected utility of the whole choice set. |
| **Compensating variation (CV)** | The dollar amount making an angler as well off under the new policy as under the baseline. Computed from the logsum, per choice occasion. |
| **Bag limit / minimum size** | The two regulations the model varies. Minimum sizes are entered in inches and converted to centimetres (× 2.54) internally; `254` is the sentinel for "no minimum size". |
| **ACL** | Annual catch limit — the reference point results are compared against. In `app.R`: 118 mt cod, 1,146 mt haddock. |

## Disclaimer

This repository is a scientific product and is not official communication of the National Oceanic and Atmospheric Administration, or the United States Department of Commerce. All NOAA GitHub project code is provided on an 'as is' basis and the user assumes responsibility for its use. Any claims against the Department of Commerce or Department of Commerce bureaus stemming from the use of this GitHub project will be governed by all applicable Federal law. Any reference to specific commercial products, processes, or services by service mark, trademark, manufacturer, or otherwise, does not constitute or imply their endorsement, recommendation or favoring by the Department of Commerce. The Department of Commerce seal and logo, or the seal and logo of a DOC bureau, shall not be used in any manner to imply endorsement of any commercial product or activity by DOC or the United States Government.
