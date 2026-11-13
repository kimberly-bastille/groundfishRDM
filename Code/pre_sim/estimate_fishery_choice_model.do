/*******************************************************************************
 Script:       			estimate_fishery_choice_model.do
 Purpose:      		Prepares historical MRIP choice occasions and estimates the
							full-sample 2010-2025 multinomial logit (MNL) fishery choice
							model for WGOM private/rental and for-hire trips. It:
								1) expands each eligible trip to 15 fishery alternatives,
								2) merges daily retention status, predicted trip costs, and
									catch availability over the preceding 14 days,
								3) screens support for pooled/species opening effects,
									opening-by-month deviations, and species interactions
									with state, mode, and calendar month, and
								4) estimates a probability-weighted asclogit model with
									standard errors clustered by year-stratum-PSU.
 Inputs:     			All files below are created outside the repo and are contained in $misc_data_cd:
								trip_data.dta
								daily_rec_regulations_2010_2025.dta
								trip_cost_species_codes.dta
								trip_cost_model.ster
								availability_state.dta
Outputs:    		  $misc_data_cd/choice_data_2010_2025.dta (15 rows per choice occasion, generated 
								regressors, and full_estimation_sample flag)
						$misc_data_cd/mnl_full_2010_2025.ster (asclogit model output)
 Dependencies: $misc_data_cd must already be set and the historical
						trip, regulation, cost, and availability inputs prepared.
						Support-screening programs are defined within this file.
 Pipeline:  			Historical estimation branch. The saved estimates and choice
						data are read by predict_fishery_choice_probabilities.do;
						prepare_fishery_choice_data.do separately builds its
						calibration-period prediction data.
 Notes:    			Retention-closed fisheries remain in each choice set; open
						enters utility. Missing catch availability is set to zero.
						Trip cost enters in hundreds of the cost model's dollar units.
						Seven-nest membership and singleton constraints are prepared,
						but the fitted/saved model in this script is MNL.
*******************************************************************************/


version 19
clear all
set more off
set seed 03211990


* Experience is disabled by default, matching the simplified NL specification.
* Set use_ffdays=1 to add experience to BOTH models and apply complete-case screening.
* Optional percentile exclusion is calculated on training cases only.
* Set to 0 to retain all logically valid ffdays12 values.
local use_ffdays=0
local trim_ffdays=1

* Retain your existing missing-catch-to-zero convention. Set to 0 to require
* nonmissing catch estimates instead, including unmatched availability keys.
local missing_catch_zero=1

capture program drop screen_species_month_open
program define screen_species_month_open, rclass
    version 17
    syntax, SPECIES(varname) MONTH(varname numeric) OPEN(varname numeric) ///
        [ONLYSPECIES(string) MINREGS(integer 2) MINCASES(integer 50) MINCHOICES(integer 3) ///
         MINYEARS(integer 0) MINPSUS(integer 0) MINSTRATA(integer 0) MINOVERLAPCASES(integer 10)]

    confirm string variable `species'
    assert inlist(`open', 0, 1)
    assert !missing(`species', `month', state, mode, date, year, strat_id, psu_id, choice)
    assert inlist(choice, 0, 1)

    local open_vars
    local open_species_list
    local open_month_list

    tempvar reg_tag year_tag psu_tag n_open_sm n_closed_sm overlap_tag

    * Observed regulatory records; these are not independent policy episodes.
    quietly egen byte `reg_tag'=tag(`species' `month' state mode date `open')

    * Years represented under each status.
    quietly egen byte `year_tag'=tag(`species' `month' `open' year)

    * PSU identity includes year and survey stratum to handle reused identifiers.
    quietly egen byte `psu_tag'=tag(`species' `month' `open' year strat_id psu_id)

    * Open/closed support within the same species-month-state-mode combination.
    quietly bysort `species' `month' state mode: egen long `n_open_sm'=total(`open'==1)
    quietly bysort `species' `month' state mode: egen long `n_closed_sm'=total(`open'==0)
    quietly egen byte `overlap_tag'=tag(`species' `month' state mode)

    quietly levelsof `species', local(species_values)

    foreach s of local species_values {
        if "`onlyspecies'"!="" {
            local wanted : list s in onlyspecies
            if !`wanted' continue
        }
        quietly levelsof `month' if `species'=="`s'", local(month_values)

        foreach m of local month_values {

            * Count support separately for closed (0) and open (1) conditions.
            forvalues z=0/1 {
                quietly count if `species'=="`s'" & `month'==`m' & `open'==`z'
                local cases`z'=r(N)

                quietly count if `species'=="`s'" & `month'==`m' & `open'==`z' & choice==1
                local choices`z'=r(N)

                quietly count if `species'=="`s'" & `month'==`m' & `open'==`z' & `reg_tag'==1
                local regs`z'=r(N)

                quietly count if `species'=="`s'" & `month'==`m' & `open'==`z' & `year_tag'==1
                local years`z'=r(N)

                quietly count if `species'=="`s'" & `month'==`m' & `open'==`z' & `psu_tag'==1
                local psus`z'=r(N)
            }

            * Count state-mode combinations with adequate cases under both statuses.
            quietly count if `species'=="`s'" & `month'==`m' & `overlap_tag'==1 ///
                & `n_open_sm'>=`minoverlapcases' & `n_closed_sm'>=`minoverlapcases'
            local overlap_strata=r(N)

            * Record every failed criterion.
            local reasons
            if `regs1'<`minregs' | `regs0'<`minregs' local reasons "`reasons' records;"
            if `cases1'<`mincases' | `cases0'<`mincases' local reasons "`reasons' cases;"
            if `choices1'<`minchoices' | `choices0'<`minchoices' local reasons "`reasons' choices;"
            if `years1'<`minyears' | `years0'<`minyears' local reasons "`reasons' years;"
            if `psus1'<`minpsus' | `psus0'<`minpsus' local reasons "`reasons' PSUs;"
            if `overlap_strata'<`minstrata' local reasons "`reasons' state-mode overlap;"

            if "`reasons'"=="" {
                local newvar open_`s'_mnth`m'
                capture drop `newvar'
                quietly gen byte `newvar'=(`species'=="`s'" & `month'==`m' & `open'==1)
                label variable `newvar' "`s': retention open in month `m'"

                local open_vars `open_vars' `newvar'
                local open_species_list `open_species_list' `s'
                local open_month_list `open_month_list' `m'

                di as result "INCLUDED: `newvar'"
            }
            else {
                di as text "Excluded: `s', month `m'; failed:`reasons'"
            }

            di as text "  Open/closed: records=`regs1'/`regs0'; cases=`cases1'/`cases0'; choices=`choices1'/`choices0'"
            di as text "  Open/closed: years=`years1'/`years0'; PSUs=`psus1'/`psus0'; supported state-mode combinations=`overlap_strata'"
        }
    }

    return local varlist "`open_vars'"
    return local specieslist "`open_species_list'"
    return local monthlist "`open_month_list'"
end

* Screener
capture program drop screen_alt_interactions

program define screen_alt_interactions, rclass

    version 17

    syntax, CELL(varname numeric) PREFIX(name) CELLTAG(name) ///
        [MINCases(integer 50) MINChoices(integer 5)]

    local interaction_vars
    local interaction_alts
    local interaction_species
    local interaction_cells

    local base_alts
    local base_species
    local base_cells

    levelsof alt, local(alternatives)

    foreach a of local alternatives {

        * Species name corresponding to numeric alternative
        quietly levelsof alt_name if alt==`a', local(s) clean

        if "`s'"=="" {
            di as error "No alt_name found for alt=`a'"
            exit 498
        }

        levelsof `cell' if alt==`a', local(cells)

        local supported_cells

        *-----------------------------------------------------------------------
        * Determine supported species-by-cell combinations
        *-----------------------------------------------------------------------

        foreach c of local cells {

            quietly count if alt==`a' & `cell'==`c'
            local n_cases=r(N)

            quietly count if ///
                alt==`a' & `cell'==`c' & choice==1

            local n_chosen=r(N)
            local n_nonchosen=`n_cases'-`n_chosen'

            if `n_cases'>=`mincases' & ///
                `n_chosen'>=`minchoices' {

                local supported_cells `supported_cells' `c'
            }
            else {
                di as text ///
                    "`prefix': excluding `s', `celltag'=`c'; " ///
                    "cases=`n_cases', chosen=`n_chosen', " ///
                    "nonchosen=`n_nonchosen'"
            }
        }

        *-----------------------------------------------------------------------
        * Omit one supported cell per species as the reference
        *-----------------------------------------------------------------------

        local nsupported: word count `supported_cells'

        if `nsupported'>=2 {

            * Use the supported cell with the most choices as the reference
            local base_cell
            local base_nchosen=-1

            foreach c of local supported_cells {

                quietly count if ///
                    alt==`a' & `cell'==`c' & choice==1

                if r(N)>`base_nchosen' {
                    local base_nchosen=r(N)
                    local base_cell=`c'
                }
            }

            local base_alts    `base_alts' `a'
            local base_species `base_species' `s'
            local base_cells   `base_cells' `base_cell'

            di as result ///
                "`prefix': `s' reference `celltag'=`base_cell'; " ///
                "chosen observations=`base_nchosen'"

            foreach c of local supported_cells {

                if `c'!=`base_cell' {

                    local newvar `prefix'_`s'_`celltag'`c'

                    if strlen("`newvar'")>32 {
                        di as error ///
                            "Generated variable name exceeds 32 characters: `newvar'"
                        exit 198
                    }

                    capture drop `newvar'

                    gen byte `newvar'= ///
                        (alt_name=="`s'" & `cell'==`c')

                    label variable `newvar' ///
                        "`s': `celltag' `c' relative to `celltag' `base_cell'"

                    local interaction_vars    `interaction_vars' `newvar'
                    local interaction_alts    `interaction_alts' `a'
                    local interaction_species `interaction_species' `s'
                    local interaction_cells   `interaction_cells' `c'
                }
            }
        }
        else {
            di as text ///
                "`prefix': no interactions created for `s'; " ///
                "fewer than two supported `celltag' cells"
        }
    }

    return local varlist     "`interaction_vars'"
    return local altlist     "`interaction_alts'"
    return local specieslist "`interaction_species'"
    return local celllist    "`interaction_cells'"

    return local basealtlist     "`base_alts'"
    return local basespecieslist "`base_species'"
    return local baselist        "`base_cells'"

end



*===============================================================================
* OPENING EFFECTS: DIRECT SPECIES SLOPES + POOL + COD/HADDOCK MONTH DEVIATIONS
*===============================================================================
capture program drop screen_open_hierarchy
program define screen_open_hierarchy, rclass
    version 19
    syntax, [MINREGS(integer 2) MINCASES(integer 50) MINCHOICES(integer 3) ///
        MINYEARS(integer 0) MINPSUS(integer 0) MINSTRATA(integer 0) MINOVERLAPCASES(integer 10)]

    * Annual support uses the same criteria as monthly support, pooled over months.
    * One well-supported species stays in the pool to provide opening variation.
    * Prefer a pool anchor other than cod/haddock so their direct slopes remain explicit.
    tempvar annual_cell
    quietly gen byte `annual_cell'=1
    screen_species_month_open, species(alt_name) month(`annual_cell') open(open) ///
        minregs(`minregs') mincases(`mincases') minchoices(`minchoices') ///
        minyears(`minyears') minpsus(`minpsus') minstrata(`minstrata') minoverlapcases(`minoverlapcases')
    local annual_candidates `r(varlist)'
    local annual_species `r(specieslist)'
    local n : word count `annual_species'
    if `n'==0 {
        di as error "No species passes annual opening support; pooled opening effect is not adequately supported under these criteria."
        exit 498
    }

    local reference
    local best=-1
    * First pass excludes cod/haddock; second pass is used only if necessary.
    forvalues pass=1/2 {
        if "`reference'"!="" continue
        foreach sp of local annual_species {
            if `pass'==1 & inlist("`sp'", "atlanticcod", "haddock") continue
            quietly count if alt_name=="`sp'" & open==0 & choice==1
            local n0=r(N)
            quietly count if alt_name=="`sp'" & open==1 & choice==1
            local support=min(`n0', r(N))
            if `support'>`best' {
                local best=`support'
                local reference `sp'
            }
        }
    }
    di as result "Supported species retained in opening pool: `reference'"
    di as text "Species failing annual screening share the pooled opening slope with the supported anchor."

    local species_vars
    local species_names
    forvalues q=1/`n' {
        local old : word `q' of `annual_candidates'
        local sp : word `q' of `annual_species'
        if "`sp'"=="`reference'" {
            drop `old'
        }
        else {
            local v osp_`sp'
            capture drop `v'
            rename `old' `v'
            label variable `v' "Direct opening effect: `sp'"
            local species_vars `species_vars' `v'
            local species_names `species_names' `sp'
        }
    }

    * The direct species variables and pool partition all alternatives.
    * No common open regressor is included in this parameterization.
    capture drop open_pool
    quietly gen byte open_pool=open
    foreach sp of local species_names {
        quietly replace open_pool=0 if alt_name=="`sp'"
    }
    label variable open_pool "Opening effect for pooled species, including supported anchor"
    quietly levelsof alt_name, local(all_species) clean
    local pooled_species : list all_species - species_names
    di as result "Pooled opening species: `pooled_species'"

    * Generate candidate monthly deviations ONLY for cod and haddock.
    screen_species_month_open, species(alt_name) month(cal_month) open(open) ///
        onlyspecies("atlanticcod haddock") minregs(`minregs') mincases(`mincases') minchoices(`minchoices') ///
        minyears(`minyears') minpsus(`minpsus') minstrata(`minstrata') minoverlapcases(`minoverlapcases')
    local candidate_vars `r(varlist)'
    local candidate_species `r(specieslist)'
    local candidate_months `r(monthlist)'
    local monthly_vars
    local monthly_species
    local monthly_months
    local reference_species
    local reference_months
    local nc : word count `candidate_vars'

    foreach sp in atlanticcod haddock {
        local base_month
        local best=-1
        if `nc'>0 {
            forvalues q=1/`nc' {
                local ss : word `q' of `candidate_species'
                local mm : word `q' of `candidate_months'
                if "`ss'"!="`sp'" continue
                quietly count if alt_name=="`sp'" & cal_month==`mm' & open==0 & choice==1
                local n0=r(N)
                quietly count if alt_name=="`sp'" & cal_month==`mm' & open==1 & choice==1
                local support=min(`n0', r(N))
                if `support'>`best' {
                    local best=`support'
                    local base_month=`mm'
                }
            }
        }
        if "`base_month'"!="" {
            local reference_species `reference_species' `sp'
            local reference_months `reference_months' `base_month'
            di as result "`sp': reference opening month `base_month'; excluded monthly cells also share its base slope"
        }
        else {
            di as text "`sp': no supported monthly opening deviations"
        }
        if `nc'>0 {
            forvalues q=1/`nc' {
                local ss : word `q' of `candidate_species'
                local mm : word `q' of `candidate_months'
                local old : word `q' of `candidate_vars'
                if "`ss'"!="`sp'" continue
                if "`mm'"=="`base_month'" {
                    drop `old'
                }
                else {
                    local v omdev_`sp'_m`mm'
                    capture drop `v'
                    rename `old' `v'
                    label variable `v' "`sp': opening deviation in month `mm' from species base slope"
                    local monthly_vars `monthly_vars' `v'
                    local monthly_species `monthly_species' `sp'
                    local monthly_months `monthly_months' `mm'
                }
            }
        }
    }
    return local pooledspecies "`pooled_species'"
    return local speciesvars "`species_vars'"
    return local speciesnames "`species_names'"
    return local monthvars "`monthly_vars'"
    return local monthspecies "`monthly_species'"
    return local monthnumbers "`monthly_months'"
    return local reference "`reference'"
    return local refmonthspecies "`reference_species'"
    return local refmonths "`reference_months'"
end




use "$misc_data_cd\daily_rec_regulations_2010_2025.dta", clear
rename prim1_common alt_name
keep state mode date alt_name open
keep if inlist(mode, "fh", "pr")
isid state mode date alt_name
bysort state mode date: assert _N==15
assert inlist(open, 0, 1)
tempfile regs
save `regs', replace

use "$misc_data_cd\trip_data.dta", clear
rename mode1 mode
gen byte in_sample=(inlist(prim1_common, "atlanticcod", "blackseabass", "bluefish", "blueshark", "haddock", "littletunny") | ///
    inlist(prim1_common, "pollock", "acadianredfish", "scup", "shortfinmako", "stripedbass") | ///
    inlist(prim1_common, "summerflounder", "tautog", "tuna", "winterflounder")) & inlist(mode, "pr", "fh") & area_s=="WGOM"
keep if in_sample & inrange(year, 2010, 2025)
assert year==year(date)
assert !missing(psu_id, strat_id, id_code, state, mode, date, year)

* Require regulation coverage for every historical trip before expanding.
preserve
use `regs', clear
keep state mode date
duplicates drop
isid state mode date
tempfile regulation_dates
save `regulation_dates', replace
restore
merge m:1 state mode date using `regulation_dates', keep(master match) generate(reg_match)
assert reg_match==3
drop reg_match

* Use regulatory open, not a possibly pre-existing trip-file variable.
capture drop open
joinby state mode date using `regs'
merge m:1 alt_name using "$misc_data_cd\trip_cost_species_codes.dta", keep(master match) generate(cost_code_match)
assert cost_code_match==3
drop cost_code_match

egen long group=group(psu_id strat_id id_code state mode date year)
encode alt_name, gen(alt)
gen byte choice=(prim1_common==alt_name)
bysort group: assert _N==15
bysort group: egen byte n_choice=total(choice)
assert n_choice==1
drop n_choice
isid group alt

* Match trip-cost and catch-availability numeric mode coding: fh=1, pr=2.
destring wave, replace
destring area_x, replace
gen byte mode_cost=cond(mode=="fh", 1, 2)
drop mode
rename mode_cost mode
assert !missing(primary_target, mode, area_x, wave)

capture drop state_id mode_id
capture confirm numeric variable state
if _rc {
    encode state, gen(state_id)
}
else {
    clonevar state_id=state
}
clonevar mode_id=mode
assert !missing(state_id, mode_id)

* Distinguish PSUs reused across years or strata.
egen long survey_psu=group(year strat_id psu_id)

* This external cost model is held fixed across rolling windows. Its inputs and
* estimation data must themselves be available at the historical forecast origin.
estimates use "$misc_data_cd\trip_cost_model.ster"
predict double predicted_cost, mu
gen double predicted_cost100=predicted_cost/100

merge m:1 state date alt_name mode using "$misc_data_cd\availability_state.dta", ///
    keep(master match) keepusing(catch_avail_14d) generate(avail_match)
tabulate alt_name avail_match, missing
drop avail_match
replace catch_avail_14d=0 if missing(catch_avail_14d)
assert !missing(catch_avail_14d, predicted_cost100)

gen byte cal_month=month(date)
gen byte cal_day=day(date)

bysort group: assert wp_int==wp_int[1]

* Logical experience cleaning only; percentile exclusion is training-specific.
replace ffdays2=round(ffdays2)
replace ffdays12=round(ffdays12)
replace ffdays12=. if !missing(ffdays12) & !inrange(ffdays12, 0, 365)
replace ffdays12=. if !missing(ffdays2, ffdays12) & ffdays2>ffdays12
replace ffdays12=. if !missing(ffdays2) & ffdays2>=62
bysort group: assert ffdays12==ffdays12[1]

* Preserve the seven-nest membership in the supplied code.
nlogitgen species_group17=alt( ///
    ground: atlanticcod | haddock | pollock | acadianredfish, ///
    benthic: summerflounder | winterflounder | tautog, ///
    seabass: blackseabass | scup, ///
    pelagic: stripedbass | bluefish | littletunny, ///
    shark: blueshark, mako: shortfinmako, tuna: tuna)
assert !missing(species_group17)

* Singleton nests have no separately identified dissimilarity parameter.
constraint define 901 [shark_tau]_cons=1
constraint define 902 [mako_tau]_cons=1
constraint define 903 [tuna_tau]_cons=1

compress
save "$misc_data_cd\choice_data_2010_2025.dta", replace


use "$misc_data_cd\choice_data_2010_2025.dta", clear
keep if inrange(year, 2010, 2025)

* Verify full-series coverage and complete choice sets
quietly summarize year, meanonly
assert r(min)==2010 & r(max)==2025
tabulate year if choice==1

isid group alt
bysort group: assert _N==15
bysort group: egen byte nchoice_check=total(choice)
assert nchoice_check==1
drop nchoice_check

assert !missing(open, catch_avail_14d, predicted_cost100, survey_psu)
local missing_catch_zero=1

*-------------------------------------------------------------------------------
* Re-screen opening effects using the full sample
*-------------------------------------------------------------------------------

screen_open_hierarchy, minregs(2) mincases(50) minchoices(3) ///
    minyears(0) minpsus(0) minstrata(0) minoverlapcases(10)

local full_open_species_vars `r(speciesvars)'
local full_open_species_names `r(speciesnames)'
local full_open_month_vars `r(monthvars)'
local full_open_month_species `r(monthspecies)'
local full_open_month_numbers `r(monthnumbers)'
local full_open_anchor `r(reference)'
local full_open_pool `r(pooledspecies)'
local full_refmonth_species `r(refmonthspecies)'
local full_refmonths `r(refmonths)'

*-------------------------------------------------------------------------------
* Re-screen ordinary species x state, mode, and month controls
*-------------------------------------------------------------------------------

screen_alt_interactions, cell(state_id) prefix(ast) celltag(state) mincases(100) minchoices(10)
local full_altstate_vars `r(varlist)'

screen_alt_interactions, cell(mode_id) prefix(ad) celltag(mode) mincases(100) minchoices(10)
local full_altmode_vars `r(varlist)'

screen_alt_interactions, cell(cal_month) prefix(am) celltag(mnth) mincases(50) minchoices(5)
local full_altmonth_vars `r(varlist)'

local full_model_vars open_pool `full_open_species_vars' `full_open_month_vars' ///
    `full_altstate_vars' `full_altmode_vars' `full_altmonth_vars' catch_avail_14d predicted_cost100

*-------------------------------------------------------------------------------
* Estimate and save the full-sample model
*-------------------------------------------------------------------------------

asclogit choice `full_model_vars' [pweight=wp_int], ///
    case(group) alternatives(alt) vce(cluster survey_psu)

if e(converged)!=1 {
    di as error "Full-sample MNL did not converge; estimates were not saved."
    exit 430
}

estimates store mnl_full_2010_2025
estimates save "$misc_data_cd\mnl_full_2010_2025.ster", replace

* Save prepared data, including generated regressors and estimation-sample flag
gen byte full_estimation_sample=e(sample)

save "$misc_data_cd\choice_data_2010_2025.dta", replace
