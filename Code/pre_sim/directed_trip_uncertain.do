/*******************************************************************************
 Script:       directed_trip_uncertain.do
 Purpose:      Produces median and mean simulated directed trips at the day-mode level for 
			   WGOM cod and GOM haddock. This removes the uncertainty in simulated
			   trips for the uncertainty project. 
 Inputs:       $misc_data_cd/directed_trip_draws.csv 
 Outputs:      $misc_data_cd/directed_trip_draws.csv 
 Pipeline:     Gated by `directed_trip_uncertain' in model_wrapper.do. 
*******************************************************************************/

*** MANUAL TOGGLE ***
* Toggle for whether to take median trips at day-mode level or mean trips 
local median=1
local mean=0

if `median' {
import delimited "$misc_data_cd\directed_trip_draws.csv", clear

//collapse to median dtrip across draws at the day-mode level 
preserve
collapse (median) dtrip, by(mode day)
tempfile trip_med
save `trip_med', replace
restore

drop dtrip
merge m:1 mode day using `trip_med'
drop _merge

label variable dtrip ""

export delimited using "$misc_data_cd/directed_trip_draws.csv", replace
}

//Lou suggested doing means rather than medians 

if `mean' {
import delimited "$misc_data_cd\directed_trip_draws.csv", clear

//collapse to mean dtrip across draws at the day-mode level 
preserve
collapse (mean) dtrip, by(mode day)
tempfile trip_mean
save `trip_mean', replace
restore

drop dtrip
merge m:1 mode day using `trip_mean'
drop _merge

label variable dtrip ""

export delimited using "$misc_data_cd/directed_trip_draws.csv", replace
}

