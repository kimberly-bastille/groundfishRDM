/*******************************************************************************
 Script:       uncertainty_data.do
 Purpose:      Take medians/means of the simulated catch-at-length, directed trips, 
			   and catch-per-trip to investigate which data sources are the biggest
               drivers of uncertainty in the RDM. Takes medians and means across 
               101 draws of the fitted catch-at-length probabilities for WGOM cod 
               and GOM haddock for the regulatory baseline year by season. Takes medians and 
			   means across 101 draws of the simulated directed trips at the year
               x month x kind-of-day x mode (pr/fh) level for the regulatory 
               baseline year and projection year. Takes medians and means across 
               101 draws of catch-per-trip at the mode-month level for WGOM cod 
               and GOM haddock (or its the means/medians of the daily catch draws in calib_catch_draws_<i>.dta)
 Inputs:       $misc_data_cd/baseline_catch_at_length.csv (written by catch_at_length_calibration.do).
			   $misc_data_cd/directed_trip_draws.csv (written by directed_trips_calibration.do).
			   $misc_data_cd/simulated_catch_totals3.dta (written by compare_calibration_data_to_MRIP.do).
               
 Outputs:      $misc_data_cd/rdb_cat_len.dta
			   $misc_data_cd/
			   $misc_data_cd/
 Dependencies: Global $misc_data_cd (set in model_wrapper.do).
 Pipeline:     Wrapped by model_wrapper.do, gated by `prep_catch_at_length_for_dash'
               (default ON). Outputs are called in the pre-sim pipeline and by the R simulation
*******************************************************************************/




/*
 Description: 
 

 General strategy:
  1. Read in data
  2. Collapse data to get median probabilities caught at length for Cod and Haddock by season 
  3. Add descriptive columns for dashboard
  4. Run rdb_catch_at_len_to_drive.R to push the processed data to Google Drive as an Rds
  
*/

//need to run the pre sim pipeline first

do "${here}/Code/helpers/developer_setup_stata.do"

* adjust project paths based on user
global input_code_cd "${here}/Code/pre_sim"
global misc_data_cd "${gfdatadir}/miscellaneous"
global calib_catch_draws_cd "${gfdatadir}/calib_catch_draws"

global ndraws 101



//I'm not sure how the pipeline will work
// I could save a baseline_catch_at_length.csv that has what I need and run stuff or I can name it 
// something else and then edit the downstream code to basically replicate everything but using
// that input data. For now I am naming them differently....
// just to check, the projected_catch_at_length.csv isn't used anywhere in the pipeline. yes it is 
////DO WE ALSO WANT MEANS? not now. maybe later
//projected_catch_at_length gets used in predict rec catch functions so make medians for that

/******************************************************************************/
/******************************************************************************/
/* Section A: Take medians of fitted baseline catch-at-length for Cod */
/******************************************************************************/
/******************************************************************************/

* Import 101 draws of baseline catch at length probabilities
import delimited "$misc_data_cd\baseline_catch_at_length.csv", clear
drop observed_prob

*Take medians of 101 draws of the fitted catch at length probabilities
preserve  
collapse (median) fitted_prob, by(season species length)
keep if species=="cod"
//expand out the medians so there are 101 draws of them
gen row_id = _n
expand 101
bysort row_id: gen draw = _n
sort draw row_id
drop row_id
order draw season species length fitted_prob
tempfile cod_med
save `cod_med', replace

//merge the expanded medians with the original haddock catch at length draws
import delimited "$misc_data_cd\baseline_catch_at_length.csv", clear
drop observed_prob
keep if species=="hadd"
append using `cod_med'

//there are 18,455 rows in baseline_catch_at_length but there are 18,481 now.
//maybe there was an extra length for cod in only some of the draws?
export delimited using "$misc_data_cd/baseline_catch_at_length_uc_cod.csv", replace
 
restore

//yeah... there arent 101 draws of length 17 and 18 for cod for summer 
//and winter haddock has less than 101 draws for every length from 54 cm to 72cm
// but maybe that is fine 
tab length if species=="cod" & season=="summer"



/******************************************************************************/
/******************************************************************************/
/* Section B: Take medians of fitted baseline catch-at-length for Haddock */
/******************************************************************************/
/******************************************************************************/

*Take medians of 101 draws of the fitted catch at length probabilities
preserve  
collapse (median) fitted_prob, by(season species length)
keep if species=="hadd"
//expand out the medians so there are 101 draws of them
gen row_id = _n
expand 101
bysort row_id: gen draw = _n
sort draw row_id
drop row_id
order draw season species length fitted_prob
tempfile hadd_med
save `hadd_med', replace

//merge the expanded medians with the original haddock catch at length draws
import delimited "$misc_data_cd\baseline_catch_at_length.csv", clear
drop observed_prob
keep if species=="cod"
append using `hadd_med'

//there are 18,455 rows in baseline_catch_at_length but there are 19,467 now.
//see note above. some lengths only show up in some draws
export delimited using "$misc_data_cd/baseline_catch_at_length_uc_hadd.csv", replace
restore


/******************************************************************************/
/******************************************************************************/
/* Section C: Take medians of fitted baseline catch-at-length for Both*/
/******************************************************************************/
/******************************************************************************/
use `cod_med', clear
append using `hadd_med'
export delimited using "$misc_data_cd/baseline_catch_at_length_uc_gf.csv", replace


//baseline CATCH AT LENGTH is called in calibrate_rec_catch0.R and calibrate_rec_catch1.R



/******************************************************************************/
/******************************************************************************/
/* Section D: Take medians of projected catch-at-length for Cod, Haddock, then Both (Steps A-C)*/
/******************************************************************************/
/******************************************************************************/
* Import 101 draws of projected catch at length probabilities
import delimited "$misc_data_cd\projected_catch_at_length.csv", clear

*Take medians of 101 draws of the projected catch at length probabilities for Cod
preserve  
collapse (median) fitted_prob, by(season species length)
keep if species=="cod"
//expand out the medians so there are 101 draws of them
gen row_id = _n
expand 101
bysort row_id: gen draw = _n
sort draw row_id
drop row_id
order draw season species length fitted_prob
tempfile cod_med
save `cod_med', replace

//merge the expanded medians with the original haddock catch at length draws
import delimited "$misc_data_cd\projected_catch_at_length.csv", clear
keep if species=="hadd"
append using `cod_med'

export delimited using "$misc_data_cd/projected_catch_at_length_uc_cod.csv", replace
restore

*Take medians of 101 draws of the projected catch at length probabilities for Haddock
preserve  
collapse (median) fitted_prob, by(season species length)
keep if species=="hadd"
//expand out the medians so there are 101 draws of them
gen row_id = _n
expand 101
bysort row_id: gen draw = _n
sort draw row_id
drop row_id
order draw season species length fitted_prob
tempfile hadd_med
save `hadd_med', replace

//merge the expanded medians with the original cod catch at length draws
import delimited "$misc_data_cd\projected_catch_at_length.csv", clear
keep if species=="cod"
append using `hadd_med'

export delimited using "$misc_data_cd/projected_catch_at_length_uc_hadd.csv", replace
restore

*Dataset with medians for both species
use `cod_med', clear
append using `hadd_med'
export delimited using "$misc_data_cd/projected_catch_at_length_uc_gf.csv", replace


//projected CATCH AT LENGTH is called in predict_rec_catch_functions.R




/******************************************************************************/
/******************************************************************************/
/* Section C: Take medians of directed trips  */
/******************************************************************************/
/******************************************************************************/

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

export delimited using "$misc_data_cd/directed_trip_draws_uc_gf.csv", replace



//Lou suggested doing means rather than medians 


/******************************************************************************/
/******************************************************************************/
/* Section D: Take medians of catch per trip for Cod */
/******************************************************************************/
/******************************************************************************/

/* 
For catch per trip, am I grabbing medians of each calib_catch_draws_<i>.dta at the mode month level? 
The R pipeline does use simulated_catch_totals.dta and simulated_catch_totals_for_catch_length.dta 
gets used in the catch at length calibration but these are too aggregated?
 I think simulated_catch_totals3.dta has the means of catch per trip at mode month level so maybe use that 
 if making a mean input dataset and also create another version of simulated_catch_totals3.dta 
 that's collapsed to the median (look at compare_calibration_data_to_MRIP.do)
*/

//look at the end of the additional angler demos do file
//its the calib catch draw files. collapse these to the median at the mode-month level and they get pulled into the R sim pipeline 

//Inputs:       $calib_catch_draws_cd/calib_catch_draws_<i>.dta (i = 1..$ndraws)
//Outputs:      $calib_catch_draws_cd/calib_catch_draws_<i>_uc.dta


//ask lou: looks like in each catch draw file, each day-mode has 50 trips, each with 30 catch draws. so are we sure we want to collapse it down that far. calib_catch_draws_1 would go from 577500 observations to just 14 observations cause 7 months for each mode

use "C:\Users\theresa.petesch\Documents\GitHub\groundfishRDM\Data\2027_mgt_cycle\calib_catch_draws\calib_catch_draws_1.dta", clear 
collapse (median) cod_keep_sim cod_rel_sim hadd_keep_sim hadd_rel_sim cod_cat_sim hadd_cat_sim, by (mode month)
collapse (median) cod_keep_sim cod_rel_sim cod_cat_sim, by (mode month)
collapse (median) hadd_keep_sim hadd_rel_sim hadd_cat_sim, by (mode month)

forvalues i = 1/$ndraws {

	*local i=1
	   use "$calib_catch_draws_cd\calib_catch_draws_`i'.dta", clear
	   
	   preserve 
	   collapse (median) cod_keep_sim cod_rel_sim cod_cat_sim, by (mode month)
	   tempfile cod_med 
	   save `cod_med', replace 
	   restore 
	   
	   drop cod_keep_sim cod_rel_sim cod_cat_sim
	   merge m:1 mode month using `cod_med'
	   drop _merge
	   
	   
	   save  "$calib_catch_draws_cd\calib_catch_draws_`i'_uc_cod.dta", replace
	}


/******************************************************************************/
/******************************************************************************/
/* Section E: Take medians of catch per trip for Haddock */
/******************************************************************************/
/******************************************************************************/

forvalues i = 1/$ndraws {

	*local i=1
	   use "$calib_catch_draws_cd\calib_catch_draws_`i'.dta", clear
	   
	   preserve 
	   collapse (median) hadd_keep_sim hadd_rel_sim hadd_cat_sim, by (mode month)
	   tempfile hadd_med 
	   save `hadd_med', replace 
	   restore 
	   
	   drop hadd_keep_sim hadd_rel_sim hadd_cat_sim
	   merge m:1 mode month using `hadd_med'
	   drop _merge
	   
	   
	   save  "$calib_catch_draws_cd\calib_catch_draws_`i'_uc_hadd.dta", replace
	}




/******************************************************************************/
/******************************************************************************/
/* Section F: Take medians of catch per trip for Cod & Haddock */
/******************************************************************************/
/******************************************************************************/

forvalues i = 1/$ndraws {

	*local i=1
	   use "$calib_catch_draws_cd\calib_catch_draws_`i'.dta", clear
	   
	   preserve 
	   collapse (median) cod_keep_sim cod_rel_sim hadd_keep_sim hadd_rel_sim cod_cat_sim hadd_cat_sim, by (mode month)
	   tempfile gf_med 
	   save `gf_med', replace 
	   restore 
	   
	   drop cod_keep_sim cod_rel_sim hadd_keep_sim hadd_rel_sim cod_cat_sim hadd_cat_sim
	   merge m:1 mode month using `gf_med'
	   drop _merge
	   
	   
	   save  "$calib_catch_draws_cd\calib_catch_draws_`i'_uc_gf.dta", replace
	}












