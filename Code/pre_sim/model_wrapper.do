

/**** Groundfish RDM input code wrapper ****/

**Data availability**

* We make projections for the next fishing year in Dec/Jan. 

* MRIP catch, effort, and length data: most recent 6 waves of MRIP data. 

*Stock assessment projections data:
		*Jan 1 2024 NAA to compute historical rec. selectivity ***CHECK
		*Jan 1 2026 NAA to compute projected catch-at-length ***CHECK
		
*NEFSC trawl survey data from 2024, 2023, 2022 years used to create age-length keys
		*CHECK

*MRIP data is stored in  
	*"smb://net/mrfss/products/mrip_estim/Public_data_cal2018"
	*Windows, just mount \\net.nefsc.noaa.gov\mrfss to A:\

* Dependencies
*ssc install xsvmat 
*ssc install gammafit 



**Set globals **
* these need to be changed every year 

/*Original data years*/
*global calibration_year "(year==2025 & inlist(wave, 1, 2, 3, 4)) | (year==2024 & inlist(wave, 5, 6))"  // last six waves of data 
*global calibration_date_start td(01sep2024)
*global calibration_date_end td(31aug2025)

/*Updated data years*/
global calibration_year "(year==2025 & inlist(wave, 1, 2, 3, 4, 5)) | (year==2024 & inlist(wave, 6))"  // last six waves of data  updated
global calibration_date_start td(01nov2024)
global calibration_date_end td(31oct2025)

global projection_date_start td(01may2026)
global projection_date_end td(30apr2027)

* add federal holidays, as these are considered "weekend" days by the MRIP and we need to account for this when estimating fishing effort at the month and kind-of-day level

* fed holidays in the calibration year 
global fed_holidays "inlist(day, td(11nov2024), td(28nov2024), td(25dec2024), td(01jan2025), td(20jan2025), td(17feb2025), td(26may2025), td(19jun2025), td(04jul2025), td(01sep2025), td(13oct2025))" 

* fed holidays in the projection year 
global fed_holidays_y2 "inlist(day1, td(25may2026), td(19jun2026), td(03jul2026), td(07sep2026), td(12oct2026), td(11nov2026),  td(26nov2026),  td(25dec2026), td(01jan2027), td(18jan2027), td(15feb2027))"

* leap-year days here
global leap_yr_days "td(29feb2024)" 

* set number of model iterations to create
global ndraws 50

* adjust 2022 survey trip costs to account for inflation (January 2022 - January 2025)
* source =https://www.bls.gov/data/inflation_calculator.htm
global inflation_expansion=1.13

* adjust project paths based on user
global input_code_cd "C:\Users\andrew.carr-harris\Desktop\Git\groundfishRDM\Code\pre_sim"
global misc_data_cd "E:\Lou_projects\groundfishRDM\2027_mgt_cycle\miscellaneous" /* Lou's local data path */
global calib_catch_draws_cd "E:\Lou_projects\groundfishRDM\2027_mgt_cycle\calib_catch_draws"
global figure_cd  "E:\Lou_projects\groundfishRDM\2027_mgt_cycle\figures"

* set a global seed #
global seed 03211990

* years/waves of MRIP data. 
global yr_wvs 20231 20232 20233 20234 20235 20236  ///
					 20241 20242 20243 20244 20245 20246  ///
					 20251 20252 20253 20254 20255 20256
					 
global yearlist 2023 2024 2025
global wavelist 1 2 3 4 5 6

* stock assessment numbers-at-age data
	* Min-Yang processes the historical numbers-at-age data and makes projections, and stores his output in Google Drive
	* Here I pull that data from Google Drive (using the Desktop app file path) and save it with a generic name in a local folder 

local google_folder "D:/Shared drives/NMFS NEC READ SSB/socialsci/RecreationalDST/2027_management_cycle_data/groundfishRDM/input_data"
local filestubs  "GOM_Haddock_historical_NAA GOM_Haddock_projected_NAA WGOM_Cod_projected_NAA WGOM_Cod_historical_NAA"

foreach s of local filestubs {
    clear
    local files : dir "`google_folder'" files "`s'_*.dta" // find matching file
    local myfile : word 1 of `files' // grab first match
    local myfile : subinstr local myfile `"""' "", all // remove embedded quotes
    local fullpath `"`google_folder'/`myfile'"' // build full path
    di as text "Loading: `fullpath'" 
    use `"`fullpath'"', clear
    save `"$misc_data_cd/`s'.dta"', replace // save standardized filename
}

* set the baseline year and projection year numbers-at-age globals 
global cod_NAA_base_year 2025  
global hadd_NAA_base_year 2025
global cod_NAA_proj_year 2026
global hadd_NAA_proj_year 2026

* set the starting year for the NEFSC trawl survey data pull (in catch_at_length_projection.do)
	* we aggregate these data across multiple years and use them to create age-length keys  
	* I usually check how many observations are available across different choices of the starting year; we want sufficient data 
	* but do not want to use historical data too far in the past. 
	
global trawl_survey_start_year 2022


**************************************************Model calibration ************************************************** 
// 1) Pull the MRIP data
do "$input_code_cd\MRIP_data_wrapper.do"

// 2) Estimate directed trips at the month, mode, kind-of day level
do "$input_code_cd\directed_trips_calibration.do"
		*This file calls "set_regulations.do". In it you must enter the SQ regulations in the calibration and projection year. 
		*THIS NEEDS TO BE ADJUSTED EVERY YEAR. 

// 3) Create distributions of costs per trip across strata - only needs to be run once
do "$input_code_cd\survey_trip_costs.do"

// 4) Create draw of angler preference parameters 
*do "$input_code_cd\estimate_angler_preferences.do" - only needs to be run once

// 5) Estimate catch-per-trip at the month and mode level
		//a) compute mean catch-per-trip and standard error, imputing standard errors from historcial data when they are missing. 
		do "$input_code_cd\calibration_catch_per_trip_part1.do"

		//b) use copula model (in R) to simulate harvest and discards per-trip
		* run copula_modeling_calibration.R
		
		//c) generate estimates of simulated total harvest based on random draws of catch-per-trip and directed trips
		do "$input_code_cd\calibration_catch_per_trip_part2.do"

// 6) compare calibration output to MRIP, and retain total simulated harvest and discards to apply to the baseline catch-at-length distribution
		do "$input_code_cd\compare_calibration_data_to_MRIP.do" 

// 7) add additonal angler demographics based on results of utilty model
		do "$input_code_cd\additional_angler_dems.do" 

// 8) Generate baseline-year catch-at-length, using the simulated harvest/discard totals from step 5
		do "$input_code_cd\catch_at_length_calibration.do"
		
// 9) Generate projection-year catch-at-length, incorporating the stock assessment data
		do "$input_code_cd\catch_at_length_projection.do"

// The calibration and projection routines can now be run in R. 		


		






