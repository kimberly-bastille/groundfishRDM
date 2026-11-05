


/*******************************************************************************
 Script:       set_regulations.do
 Purpose:      Writes the status-quo bag limits and minimum sizes for cod and
               haddock onto a daily calendar dataset, for both the calibration
               period (variable `day') and the projection year (`day_y2'). Builds
               the projection-year calendar, merges the calibration-period regs
               onto it, and layers on year-2 status-quo (_y2) and alternative
               (_y2_alt) regulation scenarios. FY 2026 model.
 Inputs:       The daily calendar dataset already in memory (supplied by
               directed_trips_calibration.do); globals $projection_date_start,
               $projection_date_end, $leap_yr_days, $fed_holidays_y2.
 Outputs:      (in memory) the calendar with cod_bag/cod_min/hadd_bag/hadd_min for
               the calibration period plus _y2 and _y2_alt variants for the
               projection period.
 Dependencies: Expects a daily calendar (with day, mode, dow, kod, draw) in memory
               and the globals above set. THESE REGULATIONS MUST BE UPDATED EVERY
               YEAR.
 Pipeline:     Not called directly by model_wrapper.do; invoked via a nested `do'
               from directed_trips_calibration.do (step 5a in README.md's execution order).
 Note:         Suspected bug (flagged, code unchanged): the year-2 kind-of-day
               block (~lines 110-111) tests variable `dow', but at that point the
               dataset has just been rebuilt and only `dow_y2' exists (created a
               few lines above). This may error or misclassify projection-year
               weekends.
*******************************************************************************/

/******************************************************************************/
/******************************************************************************/
/* Section A: Calibration-period regulations (haddock and cod) */
/******************************************************************************/
/******************************************************************************/
* Generate baseline regulations for the calibration period, which covers (year==2026 & inlist(wave, 1, 2, 3, 4, 5)) | (year==2025 & inlist(wave, 6)). 
* So FY25 regs until April 30, 2026, FY26 regs starting May 1, 2026 
* Since Wave 6, 1, and 2 data are never available when we need to do management (in December), we use proxies:  
   * Wave 6 of 2025 serves as a proxy for Wave 6 of CY2026
   * Wave 1 of 2026 serves as a proxy for Wave 1 of CY2027
   * Wave 2 of 2026 serves as a proxy for Wave 2 of CY2027

/* These are the actual regulations, including the effective dates of implementation:
Species	open						mode	bag 	size
Haddock 	4/1/25-2/28/26		both		15	17
Haddock 	4/1/26-2/28/27		both		15	17
Cod			9/1/25-10/31/25		both		1		23
Cod			9/1/26-10/31/26		both		1	    23
https://www.fisheries.noaa.gov/new-england-mid-atlantic/recreational-fishing/recreational-fishing-regulations-species
*/

/* Defaults represent a closed fishery: bag 0, and a 100 cm minimum size that no
   fish reaches. Open seasons below overwrite these. Size limits are entered in
   inches and converted to cm (inches * 2.54). */
gen cod_bag  = 0
gen cod_min  = 100

gen hadd_bag = 0
gen hadd_min = 100

*-------------------------------
*        HADDOCK            
*-------------------------------
replace hadd_bag = 15        if inrange(day, td(01apr2025), td(28feb2026)) 
replace hadd_min = 17*2.54 if inrange(day, td(01apr2025), td(28feb2026)) 

replace hadd_bag = 15        if inrange(day, td(01apr2026), td(28feb2027)) 
replace hadd_min = 17*2.54 if inrange(day, td(01apr2026), td(28feb2027)) 


*-------------------------------
*            COD                 
*-------------------------------
replace cod_bag = 1           if inrange(day, td(01sep2025), td(31oct2025))
replace cod_min = 23*2.54  if inrange(day, td(01sep2025), td(31oct2025))

replace cod_bag = 1           if inrange(day, td(01sep2026), td(31oct2026))
replace cod_min = 23*2.54  if inrange(day, td(01sep2026), td(31oct2026))




tempfile regulations
save `regulations', replace 

/******************************************************************************/
/******************************************************************************/
/* Section B: Build the projection-year (y2) calendar and merge in calibration regs */
/******************************************************************************/
/******************************************************************************/

clear
set obs 2
gen day_y2=$projection_date_start if _n==1
replace day_y2=$projection_date_end if _n==2
format day_y2 %td
tsset day_y2
tsfill, full

gen day1=day(day_y2)
gen month1=month(day_y2)
gen year_y2=year(day_y2)
drop if day_y2==$leap_yr_days
gen dow_y2 = dow(day_y2)  

/* Kind-of-day: weekend ("we") for Fri/Sat/Sun (dow 5,6,0) and federal holidays,
   weekday ("wd") for Mon-Thu. NOTE: these two lines test `dow', but only `dow_y2'
   exists here (see the suspected-bug note in the header). */
gen kod_y2="we" if inlist(dow, 5, 6, 0)
replace kod_y2="wd" if inlist(dow, 1, 2, 3, 4)
replace kod_y2="we" if $fed_holidays_y2

gen month2_y2= string(month1,"%02.0f")
rename month2_y2 month_y2
gen mode="sh"
expand 2, gen(dup)
replace mode="pr" if dup==1
drop dup
expand 2 if mode=="pr", gen(dup)
replace mode="fh" if dup==1
drop dup


merge 1:m  mode day1 month1 using `regulations'
drop if day==$leap_yr_days
drop _merge 
order year mode month kod dow day  draw cod_bag cod_min hadd_bag hadd_min day_y2 dow_y2 kod_y2 month_y2
sort  mode day draw


/******************************************************************************/
/******************************************************************************/
/* Section C: Year-2 status-quo regulations (projection period) */
/******************************************************************************/
/******************************************************************************/
gen cod_bag_y2  = 0
gen cod_min_y2  = 100

gen hadd_bag_y2 = 0
gen hadd_min_y2 = 100

*-------------------------------
*        HADDOCK            
*-------------------------------
replace hadd_bag_y2 = 15        if inrange(day, td(01apr2027), td(28feb2028)) 
replace hadd_min_y2 = 17*2.54 if inrange(day, td(01apr2027), td(28feb2028)) 



*-------------------------------
*            COD                 
*-------------------------------
replace cod_bag_y2 = 1           if inrange(day, td(01sep2027), td(31oct2027))
replace cod_min_y2 = 23*2.54  if inrange(day, td(01sep2027), td(31oct2027))

