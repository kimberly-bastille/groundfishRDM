/*******************************************************************************
 Script:      		 predict_fishery_choice_probabilities.do
 Purpose:      	Applies the saved historical MNL fishery choice model to
						calibration-period choice occasions for simulation use. It:
							1) restores alternative, state, and mode identifiers from
								the historical training data,
							2) reconstructs supported opening and interaction regressors
								from saved coefficient names without re-screening,
							3) predicts baseline choice probabilities (p0) across all
								15 fisheries and checks they sum to one per occasion, and
							4) calculates each alternative's effective opening coefficient
								(beta_open), including species and monthly effects, for
								subsequent regulation-driven probability adjustments.
 Inputs:       		$misc_data_cd/fishery_choice_data_master.dta (created in prepare_fishery_choice_data.do)
						$misc_data_cd/choice_data_2010_2025.dta  (created in estimate_fishery_choice_model.do)
						$misc_data_cd/mnl_full_2010_2025.ster (created in estimate_fishery_choice_model.do)
 Outputs:     		 $misc_data_cd/baseline_choice_probabilities_long.dta
						(choice-occasion x alternative data with p0, beta_open, mode_string, and weekday, plus retained input variables)
 Dependencies: $misc_data_cd must already be set. Run
						estimate_fishery_choice_model.do to produce the historical
						estimates/coding and prepare_fishery_choice_data.do to produce
						the calibration master data. Requires a saved asclogit model
						and the same variable definitions used during estimation.
 Pipeline:     		Joins the historical-estimation and calibration-data branches.
						Supplies baseline probabilities and opening coefficients for
						the subsequent fishery simulation's trip-demand adjustments.
 Notes:        		Retention-closed alternatives remain in the choice set; open
						is a utility covariate. p0 reflects calibration-date regulations.
						weekday is Sunday=0 through Saturday=6, without holiday
						adjustment. This script does not generate counterfactual
						probabilities or aggregate trip totals.
*******************************************************************************/


version 19
local model_file "$misc_data_cd\mnl_full_2010_2025.ster"
local training_file "$misc_data_cd\choice_data_2010_2025.dta"
confirm file "`model_file'"
confirm file "`training_file'"

use "$misc_data_cd\fishery_choice_data_master.dta", clear
isid group alt_name
bysort group: assert _N==15
assert inlist(open, 0, 1)
assert !missing(catch_avail_14d, predicted_cost100, cal_month)

* Recover historical identifiers; never encode a smaller prediction sample anew.
tempfile altmap statemap modemap
preserve
use "`training_file'", clear
keep alt_name alt
duplicates drop
isid alt_name
isid alt
save `altmap'
restore
drop alt
merge m:1 alt_name using `altmap', keep(master match) generate(map_match)
assert map_match==3
drop map_match

preserve
use "`training_file'", clear
keep state state_id
duplicates drop
isid state
isid state_id
save `statemap'
restore
capture drop state_id
merge m:1 state using `statemap', keep(master match) generate(map_match)
assert map_match==3
drop map_match

preserve
use "`training_file'", clear
keep mode mode_id
duplicates drop
isid mode
isid mode_id
save `modemap'
restore
capture drop mode_id
merge m:1 mode using `modemap', keep(master match) generate(map_match)
assert map_match==3
drop map_match
assert inlist(mode, 1, 2)

estimates use "`model_file'"
if "`e(cmd)'"!="asclogit" {
    di as error "Expected an asclogit model; found `e(cmd)'. Check the estimation specification."
    exit 498
}
matrix B_saved=e(b)
local coefficient_vars : colnames B_saved
local coefficient_vars : list uniq coefficient_vars
local direct_species

* The coefficient names record which variables survived TRAINING screening.
* Reconstruct those variables; do not run support screeners on this sample.
foreach v of local coefficient_vars {
    if regexm("`v'", "^osp_([a-z0-9]+)$") {
        local sp=regexs(1)
        capture drop `v'
        gen byte `v'=(alt_name=="`sp'" & open==1)
        local direct_species `direct_species' `sp'
    }
    else if regexm("`v'", "^omdev_([a-z0-9]+)_m([0-9]+)$") {
        local sp=regexs(1)
        local mm=real(regexs(2))
        capture drop `v'
        gen byte `v'=(alt_name=="`sp'" & cal_month==`mm' & open==1)
    }
    else if regexm("`v'", "^open_([a-z0-9]+)_mnth([0-9]+)$") {
        local sp=regexs(1)
        local mm=real(regexs(2))
        capture drop `v'
        gen byte `v'=(alt_name=="`sp'" & cal_month==`mm' & open==1)
    }
    else if regexm("`v'", "^ast_([a-z0-9]+)_state([0-9]+)$") {
        local sp=regexs(1)
        local cell=real(regexs(2))
        capture drop `v'
        gen byte `v'=(alt_name=="`sp'" & state_id==`cell')
    }
    else if regexm("`v'", "^ad_([a-z0-9]+)_mode([0-9]+)$") {
        local sp=regexs(1)
        local cell=real(regexs(2))
        capture drop `v'
        gen byte `v'=(alt_name=="`sp'" & mode_id==`cell')
    }
    else if regexm("`v'", "^am_([a-z0-9]+)_mnth([0-9]+)$") {
        local sp=regexs(1)
        local cell=real(regexs(2))
        capture drop `v'
        gen byte `v'=(alt_name=="`sp'" & cal_month==`cell')
    }
}

local has_pool : list posof "open_pool" in coefficient_vars
if `has_pool' {
    capture drop open_pool
    gen byte open_pool=open
    foreach sp of local direct_species {
        replace open_pool=0 if alt_name=="`sp'"
    }
    tempvar partition
    gen byte `partition'=open_pool
    foreach sp of local direct_species {
        replace `partition'=`partition'+osp_`sp'
    }
    assert `partition'==open
    drop `partition'
}

* Unrecognized or missing inputs stop execution instead of silently becoming zero.
foreach v of local coefficient_vars {
    if "`v'"=="_cons" continue
    capture confirm numeric variable `v'
    if _rc {
        di as error "Required model variable is missing or unsupported: `v'"
        di as error "Inspect matrix list e(b); recreate this variable exactly as in training."
        exit 111
    }
    assert !missing(`v')
}

* Keep all 15 alternatives, including retention-closed fisheries.
* open is a utility covariate, not a hard choice-set availability restriction.
isid group alt
bysort group: assert _N==15
capture drop p0
predict double p0, pr
assert !missing(p0) & inrange(p0, 0, 1)
tempvar psum
bysort group: egen double `psum'=total(p0)
assert abs(`psum'-1)<1e-8
drop `psum'
gen str2 mode_string=cond(mode==1, "fh", "pr")
gen byte weekday=dow(date)
label variable weekday "Day of week: Sunday=0 through Saturday=6; not holiday-adjusted"
label variable p0 "Baseline probability under calibration-date regulations"
order group state mode mode_string date year cal_month alt alt_name choice open p0


* Effective derivative of utility with respect to open.
* Uses the naming conventions in your supplied estimation script.
matrix B_open=e(b)
local coefnames : colnames B_open
local coefnames : list uniq coefnames

gen double beta_open=0

* Common opening effect, if present in the saved specification.
local has_common : list posof "open" in coefnames
if `has_common' replace beta_open=beta_open+_b[open]

* Pooled opening effect.
local has_pool : list posof "open_pool" in coefnames
if `has_pool' replace beta_open=beta_open+_b[open_pool]

* Direct species effects replace the pooled component for those species.
foreach v of local coefnames {
    if regexm("`v'", "^osp_([a-z0-9]+)$") {
        local sp=regexs(1)
        if `has_pool' replace beta_open=beta_open-_b[open_pool] if alt_name=="`sp'"
        replace beta_open=beta_open+_b[`v'] if alt_name=="`sp'"
    }
}

* Add opening-by-month effects/deviations.
foreach v of local coefnames {
    if regexm("`v'", "^omdev_([a-z0-9]+)_m([0-9]+)$") {
        local sp=regexs(1)
        local mm=real(regexs(2))
        replace beta_open=beta_open+_b[`v'] if alt_name=="`sp'" & cal_month==`mm'
    }
    else if regexm("`v'", "^open_([a-z0-9]+)_mnth([0-9]+)$") {
        local sp=regexs(1)
        local mm=real(regexs(2))
        replace beta_open=beta_open+_b[`v'] if alt_name=="`sp'" & cal_month==`mm'
    }
}

label variable beta_open "Effective opening coefficient, including monthly effects"
assert !missing(beta_open)

save "$misc_data_cd\baseline_choice_probabilities_long.dta", replace
