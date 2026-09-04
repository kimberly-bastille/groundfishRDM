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



//I'm not sure how the pipeline will work
// I could save a baseline_catch_at_length.csv that has what I need and run stuff or I can name it 
// something else and then edit the downstream code to basically replicate everything but using
// that input data. For now I am naming them differently....
// I'm grabbing medians. Do we want to test the means?
// just to check, the projected_catch_at_length.csv isn't used anywhere in the pipeline
// maybe the sim code is recalculating it somwhere using the baseline_catch_at_length and projected NAA's?

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

////DO WE ALSO WANT MEANS? not now. maybe later
// DO WE ALSO WANT A VERSION WITH THE MEDIANS FOR BOTH COD AND HADD
//projected_catch_at_length gets used in predict rec catch functions so make medians for that

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


//think you need to rename things so that they all contain the same pattern, so 
//baseline_catch_at_length.csv
//baseline_catch_at_length_uc_cod.csv
//baseline_catch_at_length_uc_hadd.csv
//baseline_catch_at_length_uc_gf.csv

//projected_catch_at_length.csv
//projected_catch_at_length_uc_cod.csv
//projected_catch_at_length_uc_hadd.csv
//projected_catch_at_length_uc_gf.csv




/******************************************************************************/
/******************************************************************************/
/* Section C: Take medians of directed trips  */
/******************************************************************************/
/******************************************************************************/
import delimited "$misc_data_cd\directed_trip_draws.csv", clear

//am i just collapsing dtrip across  draws? so just have the median by day-mode?
//or do I need to do other steps like use the next year calendar adjustment 











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




/******************************************************************************/
/******************************************************************************/
/* Section E: Take medians of catch per trip for Haddock */
/******************************************************************************/
/******************************************************************************/



















