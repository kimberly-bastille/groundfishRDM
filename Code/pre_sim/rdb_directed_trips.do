
/*******************************************************************************
 Script:       rdb_directed_trips.do
 Purpose:      Cleans the simulated directed trips data and formats it for the recDST 
               dashboard: takes medians across all draws of the simulated directed trips 
			   targetting WGOM cod and/or GOM haddock for the regulatory baseline year at 
               the month-mode-kind of day level, and adds descriptive columns.  
 Inputs:       $misc_data_cd/directed_trip_draws.csv (written by directed_trips_calibration.do).
 Outputs:      $misc_data_cd/rdb_dtrips.dta
 Dependencies: Global $misc_data_cd (set in model_wrapper.do).
 Pipeline:     Wrapped by model_wrapper.do, gated by `prep_trips_for_dash'
               Followed by rdb_dtrips_to_drive.R, which pushes
               the output to Google Drive as an Rds.
               
Notes:    As of October 2026, we have 101 draws in this dataset, but this could change in the future.
*******************************************************************************/
/*
 General strategy:
  1. Read in data
  2. Collapse daily trip data to get N-draws of monthly directed trips by mode and kind-of-day.
  3. Take the median of the N draws of directed trips at the month, mode, and kind-of-day level. 
  4. Add descriptive columns for the dashboard. 
  5. Run rdb_dtrips_to_drive.R to push the processed data to Google Drive as an Rds.
*/


/******************************************************************************/
/******************************************************************************/
/* Section A: Median simulated directed trips */
/******************************************************************************/
/******************************************************************************/
import delimited "$misc_data_cd\directed_trip_draws.csv", clear

*generate date variables, 'day of the week' variable, and kind-of-day variable (weekday vs weekend)
gen date = date(day, "DMY")
format date %td
gen month = month(date)
gen year = year(date)
gen dow = dow(date)  //0=Sunday,...,6=Saturday
/* Friday, Saturday and Sunday count as "weekend" days for effort purposes */
gen kod="we" if inlist(dow, 5, 6, 0)
replace kod="wd" if inlist(dow, 1, 2, 3, 4)
* Include federal holidays as weekend days
drop day
rename date day
replace kod="we" if $fed_holidays

* Drop shore-based mode
drop if mode=="sh"

* Sum daily trip draws to get monthly trip draws by mode and kod
collapse (sum) dtrip, by(mode month year kod draw)

* Take the median of the draws of monthly trips by mode and kod
collapse (median) dtrip, by(mode kod month year)



/******************************************************************************/
/******************************************************************************/
/* Section B: Add descriptive columns for the dashboard and save */
/******************************************************************************/
/******************************************************************************/

* Re-label and rename some variables 
replace kod="weekday" if kod=="wd"
replace kod="weekend" if kod=="we"
rename kod metric
rename dtrip value
gen units="calibrated directed trips"
gen source="model intermediate"
gen fishery= "NE Groundfish"
label variable value ""
order fishery year month mode metric value units source

* Look at the data as a stacked bar chart 
graph bar value, over(metric) over(month) asyvars stack by(mode) ytitle("Directed Trips")

save "$misc_data_cd\rdb_dtrips.dta", replace 



/******************************************************************************/
/******************************************************************************/
/* Section C: Check monthly median trips against sum of medians (Commented out) */
/******************************************************************************/
/******************************************************************************/

/*
*The median of total monthly trips will be different from the sum of median trips by 
*kod and mode. But the numbers are very close and indistinguishable when plotted. 
* (All months have less than 1% difference compared to median total monthly trips)

*Compare the sum of the medians at the mode-kod level...
collapse (sum) value, by(month year)

*To the median of total monthly trips....
import delimited "$misc_data_cd\directed_trip_draws.csv", clear
gen date = date(day, "DMY")
format date %td
gen month = month(date)
gen year = year(date)
drop if mode=="sh"

collapse (sum) dtrip, by(month year draw)
collapse (median) dtrip, by(month year)

gen metric="total"
rename dtrip value

graph bar value, over(month) by(metric) ytitle("Directed Trips")

*...the sum of medians by kod-mode at the month level are very close to median total monthly trips

*/



