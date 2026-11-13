/*******************************************************************************
 Script:      			prepare_fishery_choice_data.do
 Purpose:      		Builds the calibration-period fishery choice data used to
							integrate estimated fishery demand into the simulation. It:
								1) combines available MRIP trip/catch extracts and identifies
									WGOM trips targeting one of 15 fisheries in private/rental
									or for-hire mode,
								2) estimates survey-weighted species catch-per-trip over the
									preceding 14 days, with SEs and sample counts,
								3) prepares daily retention status and expands each eligible
									calibration trip to all 15 alternatives, and
								4) predicts alternative-specific trip costs and merges catch
									availability to form the prediction master dataset.
 Inputs:       			mrip_trip.dta, and mrip_catch.dta (from the get_mrip_oracle.R )  
						MRIP_COD_ALL_SITE_LIST.csv from get_mrip_site_list.R 
						These are created outside the repo and contained in $misc_data_cd:
								daily_rec_regulations_2010_2025.dta
								trip_cost_species_codes.dta
								trip_cost_model.ster
 Outputs:      			$misc_data_cd/fishery_choice_trips.dta
							$misc_data_cd/fishery_choice_availability.dta
							$misc_data_cd/fishery_choice_data_master.dta
 Dependencies: 	Set $misc_data_cd, $calibration_year, $calibration_date_start, and $calibration_date_end
							before running. Requires user-written renvarlab and the previously estimated trip-cost model with its input variables.
 Pipeline:     			Calibration-data branch. Run before predict_fishery_choice_probabilities.do, which combines the
							master data with the historical fishery choice estimates.
 Notes:        			Availability uses directed trips in the same mode and WGOM,  pooling states.
							Missing availability is set to zero in the master data.
							Numeric mode coding is fh=1, pr=2. 
							Review MRIP year coverage and the year-specific regulation block for each new cycle.
*******************************************************************************/

**Step 1: pull MRIP data for the calibration period
clear
tempfile master
save `master', emptyok replace

* Build site lookup for ME and MA once, outside the loop
* all NH is in WGOM, so we do not need it to be in this chunk of code

preserve
import delimited using "$misc_data_cd/MRIP_COD_ALL_SITE_LIST.csv", clear
keep if inlist(state, "MA", "ME")
keep state intsite nmfs_stock_area nmfs_stat_area
sort intsite nmfs_stock_area
replace nmfs_stock_area = "WGOM" if inlist(nmfs_stat_area, 521, 526, 541, 514, 513, 515)
replace nmfs_stock_area = "XX" if !inlist(nmfs_stat_area, 521, 526, 541, 514, 513, 515)
keep nmfs_stock_area intsite nmfs_stat_area state
duplicates drop
tempfile mrip_sites
save `mrip_sites', replace
restore



        capture confirm file "$misc_data_cd/mrip_trip.dta"
        if _rc continue

        capture confirm file "$misc_data_cd/mrip_catch.dta"
        if _rc continue


        tempfile tl1 cl1

        use "$misc_data_cd/mrip_trip.dta", clear
        renvarlab, lower
		keep if $calibration_year
		
        * keep if year == `yr' & wave == `wave'
        count
        if r(N) == 0 continue

        sort year strat_id psu_id id_code
        save `tl1', replace
		
        use "$misc_data_cd/mrip_catch.dta", clear
        renvarlab, lower
		keep if $calibration_year
        count
        if r(N) == 0 continue

        sort year strat_id psu_id id_code
        replace common = subinstr(lower(common), " ", "", .)
        save `cl1', replace

        use `tl1', clear
        merge 1:m year strat_id psu_id id_code using `cl1', keep(1 3)
        
		
        replace common       = subinstr(lower(common), " ", "", .)
        replace prim1_common = subinstr(lower(prim1_common), " ", "", .)
        replace prim2_common = subinstr(lower(prim2_common), " ", "", .)

        drop _merge

        keep if inlist(st, 23, 33, 25)

        count
        if r(N) == 0 continue

		* classify trips
      
        tostring wave, gen(w2)
        tostring year, gen(year2)
        gen st2 = string(st, "%02.0f")

        gen state = "MA" if st == 25
        replace state = "ME" if st == 23
        replace state = "NH" if st == 33

        gen mode1 = "sh" if inlist(mode_fx, "1", "2", "3")
        replace mode1 = "pr" if inlist(mode_fx, "7")
        replace mode1 = "fh" if inlist(mode_fx, "4", "5")

        gen date = substr(id_code, 6, 8)
        gen month1 = substr(date, 5, 2)
        gen day1 = substr(date, 7, 2)
        drop if inlist(day1, "9x", "xx")
        destring day1, replace
		

        merge m:1 intsite state using `mrip_sites', keep(1 3)
        drop _merge

        gen str3 area_s = "XX"
        replace area_s = "WGOM" if st2 == "33"
        replace area_s = nmfs_stock_area if inlist(st2, "25", "23")


        keep strat_id psu_id id_code  area_s mode1 wp_int year state wave prim1_common prim2_common hrsf area ffdays2 ffdays12 party boat_hrs dist gear prim1 prim2 area_x
        duplicates drop

        gen date_string = substr(id_code, 6, 8)
        gen month1 = substr(date_string, 5, 2)
        gen day1 = substr(date_string, 7, 2)
        drop if inlist(day1, "9x", "xx")
        destring day1 month1, replace
        drop date_string

        gen date = mdy(month1, day1, year)
        format date %td

        
        append using `master'
        save `master', replace
*    }
*}

use `master', clear

drop prim1 prim2

replace prim1_common="tuna" if inlist(prim1_common, "bigeyetuna", "bluefintuna", "tunagenus", "yellowfintuna")
replace prim2_common="tuna" if inlist(prim2_common, "bigeyetuna", "bluefintuna", "tunagenus", "yellowfintuna")

keep if $calibration_year

save "$misc_data_cd\fishery_choice_trips.dta", replace

tempfile trips
save `trips', replace 


**Step 2) re-create the variables needed for the predictions 

*Availability (average catch past two weeks)
clear
tempfile master
save `master', emptyok replace



        tempfile tl1 cl1

        use "$misc_data_cd/mrip_trip.dta", clear
		
		renvarlab, lower
		keep if $calibration_year
        count
        if r(N) == 0 continue

        sort year strat_id psu_id id_code
        save `tl1', replace
		
        use "$misc_data_cd/mrip_catch.dta", clear
        renvarlab, lower
		keep if $calibration_year
        count
        if r(N) == 0 continue

        sort year strat_id psu_id id_code
        replace common = subinstr(lower(common), " ", "", .)
        save `cl1', replace

        use `tl1', clear
        merge 1:m year strat_id psu_id id_code using `cl1', keep(1 3)
        
		
        replace common       = subinstr(lower(common), " ", "", .)
        replace prim1_common = subinstr(lower(prim1_common), " ", "", .)
        replace prim2_common = subinstr(lower(prim2_common), " ", "", .)

        drop _merge

        keep if inlist(st, 23, 33, 25)

        count
        if r(N) == 0 continue

		* classify trips
      
        tostring wave, gen(w2)
        tostring year, gen(year2)
        gen st2 = string(st, "%02.0f")

        gen state = "MA" if st == 25
        replace state = "ME" if st == 23
        replace state = "NH" if st == 33

        gen mode1 = "sh" if inlist(mode_fx, "1", "2", "3")
        replace mode1 = "pr" if inlist(mode_fx, "7")
        replace mode1 = "fh" if inlist(mode_fx, "4", "5")

        gen date = substr(id_code, 6, 8)
        gen month1 = substr(date, 5, 2)
        gen day1 = substr(date, 7, 2)
        drop if inlist(day1, "9x", "xx")
        destring day1, replace
		

        merge m:1 intsite state using `mrip_sites', keep(1 3)
        drop _merge

        gen str3 area_s = "XX"
        replace area_s = "WGOM" if st2 == "33"
        replace area_s = nmfs_stock_area if inlist(st2, "25", "23")

		replace common = "tuna" if inlist(common, "bigeyetuna", "bluefintuna", "tunagenus", "yellowfintuna")

		* Top 15 alternatives
		* Species-specific catch, harvest, and release totals
		local species atlanticcod blackseabass bluefish blueshark haddock littletunny pollock ///
			acadianredfish scup shortfinmako stripedbass summerflounder tautog tuna winterflounder

		foreach s of local species {
			foreach metric in catch claim harvest landing release {
				local source = cond("`metric'"=="catch", "tot_cat", "`metric'")
				gen double tmp_`metric'=cond(common=="`s'", `source', 0)
				bysort strat_id psu_id id_code: egen double `metric'_`s'=total(tmp_`metric')
				drop tmp_`metric'
			}
		}
		
		
		bysort year strat_id psu_id id_code: gen count_obs1=_n

		keep if count_obs1==1 // This keeps only one record for trips with catch of multiple species. We have already computed catch of the species of interest above and saved these in a trip-row


        keep strat_id psu_id id_code  area_s mode1 wp_int year state wave prim1_common prim2_common ///
				hrsf area ffdays2 ffdays12 party boat_hrs dist gear prim1 prim2 area_x catch* claim* harvest* release*
        duplicates drop

        gen date_string = substr(id_code, 6, 8)
        gen month1 = substr(date_string, 5, 2)
        gen day1 = substr(date_string, 7, 2)
        drop if inlist(day1, "9x", "xx")
        destring day1 month1, replace
        drop date_string

        gen date = mdy(month1, day1, year)
        format date %td

        
        append using `master'
        save `master', replace

use `master', clear


replace prim1_common="tuna" if inlist(prim1_common, "bigeyetuna", "bluefintuna", "tunagenus", "yellowfintuna")
replace prim2_common="tuna" if inlist(prim2_common, "bigeyetuna", "bluefintuna", "tunagenus", "yellowfintuna")


gen in_sample=(inlist(prim1_common, "atlanticcod", "blackseabass", "bluefish", "blueshark", "haddock", "littletunny") | ///
                    inlist(prim1_common, "pollock", "acadianredfish", "scup", "shortfinmako", "stripedbass") | ///
                    inlist(prim1_common, "summerflounder", "tautog", "tuna", "winterflounder")) & ///
                   inlist(mode1, "pr", "fh") & area_s=="WGOM"


preserve
keep if in_sample & ($calibration_year)
keep date state mode1
duplicates drop
sort state mode1 date
tempfile choice_cells
save `choice_cells', replace
restore

egen long svy_strat = group(year wave state strat_id)
egen long svy_psu   = group(year wave state strat_id psu_id)

svyset svy_psu [pweight=wp_int], strata(svy_strat) singleunit(certainty)


local species atlanticcod blackseabass bluefish blueshark haddock ///
    littletunny pollock acadianredfish scup shortfinmako stripedbass ///
    summerflounder tautog tuna winterflounder
	
foreach s of local species {
    gen double sqrt_catch_`s'=sqrt(catch_`s')
    gen byte any_catch_`s'=(catch_`s'>0) if !missing(catch_`s')
}

tempfile mrip_full
save `mrip_full', replace

* Store the dates required for every state-mode combination
use `choice_cells', clear
levelsof state, local(states)

foreach st of local states {
    foreach m in pr fh {
        local date_macro dates_`st'_`m'
        quietly levelsof date if state=="`st'" & mode1=="`m'", local(`date_macro')
    }
}

tempfile availability
tempname post_avail

local species atlanticcod blackseabass bluefish blueshark haddock ///
    littletunny pollock acadianredfish scup shortfinmako stripedbass ///
    summerflounder tautog tuna winterflounder

*local metrics catch sqrt_catch harvest release claim
local metrics catch /*sqrt_catch*/ 

* Construct list of survey variables
local outcome_vars
foreach metric of local metrics {
    foreach s of local species {
        local outcome_vars `outcome_vars' `metric'_`s'
    }
}

* Store results in long format
postfile `post_avail' double date str2 state str2 mode1 ///
    str20 species str12 metric double availability availability_se ///
    long availability_n using `availability', replace

use `mrip_full', clear
gen byte avail_subpop=0

foreach st of local states {
    foreach m in pr fh {
        local date_macro dates_`st'_`m'

        foreach d of local `date_macro' {
            foreach s of local species {

                quietly replace avail_subpop = ///
                    inrange(date, `d'-14, `d'-1) & ///
                    /*state=="`st'" &*/ mode1=="`m'" & area_s=="WGOM" & ///
                    (prim1_common=="`s'" | prim2_common=="`s'")

                quietly count if avail_subpop
                local n=r(N)

                if `n'>0 {
						capture quietly svy, subpop(avail_subpop): mean catch_`s' /*sqrt_catch_`s' harvest_`s' release_`s' claim_`s'*/
                    if !_rc {
                        matrix B=e(b)
                        matrix V=e(V)

                        foreach metric of local metrics {
                            local j=colnumb(B, "`metric'_`s'")
                            local mu=B[1,`j']
                            local se=sqrt(V[`j',`j'])

                            post `post_avail' (`d') ("`st'") ("`m'") ///
                                ("`s'") ("`metric'") (`mu') (`se') (`n')
                        }
                    }
                }
            }
        }
    }
}

postclose `post_avail'


use `availability', clear

reshape wide availability availability_se availability_n, ///
    i(date state mode1 species) j(metric) string

rename availabilitycatch catch_avail_14d
*rename availabilitysqrt_catch   sqrt_catch_avail_14d
*rename availabilityharvest harvest_avail_14d
*rename availabilityrelease release_avail_14d

rename availability_secatch catch_avail_se
*rename availability_sesqrt_catch sqrt_catch_avail_se
*rename availability_seharvest harvest_avail_se
*rename availability_serelease release_avail_se

rename availability_ncatch catch_avail_n
*rename availability_nsqrt_catch  sqrt_catch_avail_n
*rename availability_nharvest harvest_avail_n
*rename availability_nrelease release_avail_n

rename species alt_name
rename mode1 mode_string

gen byte mode=1 if mode_string=="fh"
replace mode=2 if mode_string=="pr"

drop mode_string

format date %td
order state date mode alt_name catch_avail_14d  /*sqrt_catch_avail_14d*/

isid state date mode alt_name

compress

rename catch_avail_se catch_avail_14d_se
rename catch_avail_n catch_avail_14d_n

*rename sqrt_catch_avail_se sqrt_catch_avail_14d_se
*rename sqrt_catch_avail_n sqrt_catch_avail_14d_n

save "$misc_data_cd\fishery_choice_availability.dta", replace



* Update regulations for ALL species through calibration period. 
* The regulations file used in the fishery choice model spans through 2025. Update any regulations for the calibration period that are not in the RDM calibration period.
* For mgt cycle 2027, this means 2026 regulations.
use "$misc_data_cd\daily_rec_regulations_2010_2025.dta", clear
rename prim1_common alt_name
keep state mode date alt_name open
keep if inlist(mode, "fh", "pr")
gen year=year(date)

su year
return list
if (`r(max)'==2025){
keep if inrange(date, $calibration_date_start, $calibration_date_end)

isid state mode date alt_name
bysort state mode date: assert _N==15
assert inlist(open, 0, 1)
}

su year
return list
if (`r(max)'==2026){
keep if year(date)==2025

tempfile regs2025 regs2026 regs
save `regs2025', replace

* Copy 2025 calendar dates into 2026.
replace date=mdy(month(date), day(date), 2026)
format date %td

* Update Massachusetts black sea bass retention season.
replace open=. if alt_name=="blackseabass" & state=="MA"
replace open=1 if inrange(date, td(16may2026), td(14oct2026)) & alt_name=="blackseabass" & state=="MA"
replace open=0 if alt_name=="blackseabass" & state=="MA" & open==.

isid state mode date alt_name
bysort state mode date: assert _N==15
assert inlist(open, 0, 1)
save `regs2026', replace

append using `regs2025'
gen int year=year(date)

isid state mode date alt_name
bysort state mode date: assert _N==15
}


tempfile regs
save `regs', replace

use "$misc_data_cd\fishery_choice_trips.dta", clear
rename mode1 mode

gen byte in_sample=(inlist(prim1_common, "atlanticcod", "blackseabass", "bluefish", "blueshark", "haddock", "littletunny") | ///
    inlist(prim1_common, "pollock", "acadianredfish", "scup", "shortfinmako", "stripedbass") | ///
    inlist(prim1_common, "summerflounder", "tautog", "tuna", "winterflounder")) & inlist(mode, "pr", "fh") & area_s=="WGOM"
keep if in_sample

assert year==year(date)
assert !missing(psu_id, strat_id, id_code, state, mode, date, year)
isid year wave state strat_id psu_id id_code

* Verify date coverage before expanding; joinby otherwise drops unmatched trips.
preserve
use `regs', clear
keep state mode date year
duplicates drop
tempfile regulation_dates
save `regulation_dates', replace
restore

merge m:1 state mode date year using `regulation_dates', keep(master match) generate(reg_match)
assert reg_match==3
drop reg_match

* Preserve prim1_common as the observed target.
capture drop alt_name
capture drop open

joinby state mode date year using `regs'

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

merge m:1 state date alt_name mode using "$misc_data_cd\fishery_choice_availability.dta", ///
    keep(master match) keepusing(catch_avail_14d) generate(avail_match)
tabulate alt_name avail_match, missing
drop avail_match
replace catch_avail_14d=0 if missing(catch_avail_14d)

assert !missing(catch_avail_14d, predicted_cost100)

gen byte cal_month=month(date)
gen byte cal_day=day(date)


compress
save "$misc_data_cd\fishery_choice_data_master.dta", replace

