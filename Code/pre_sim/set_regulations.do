


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
               from directed_trips_calibration.do (step 5a in DATAFLOW_GROUNDFISH.md).
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
* Generate baseline regulations for the calibration period, which covers (year==2025 & inlist(wave, 1, 2, 3, 4)) | (year==2024 & inlist(wave, 5, 6)). 
* So FY24 regs until April 30, 2025, FY25 regs starting May 1, 2025 

/* These are the actual regulations, including the effective dates of implementation:
Species	open						mode	bag 	size
Haddock 	8/14/23-2/28/24		fh			15	18
Haddock 	4/1/24-4/30/24		fh			15	18
Haddock 	8/14/23-2/28/24		pr			10	17
Haddock 	4/1/24-4/30/24		pr			10	17
Haddock 	5/1/24-7/23/24		fh			15	18
Haddock 	5/1/24-7/23/24		pr			10	17
Haddock 	7/24/24-2/28/25		both		15	18
Haddock 	4/1/25-4/30/25		both		15	18
Haddock 	5/1/25-2/28/26		both		15	18
Cod			9/1/23-10/31/23		both		1		22
Cod			9/1/24-10/31/24		both		1	    23
Cod			9/1/25-10/31/25		both		1		23
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

* 8/14/2023–2/28/2024 (fh)
replace hadd_bag = 15        if inrange(day, td(14aug2023), td(28feb2024)) & mode=="fh"
replace hadd_min = 18*2.54 if inrange(day, td(14aug2023), td(28feb2024)) & mode=="fh"

* 8/14/2023–2/28/2024 (pr)
replace hadd_bag = 10        if inrange(day, td(14aug2023), td(28feb2024)) & mode=="pr"
replace hadd_min = 17*2.54 if inrange(day, td(14aug2023), td(28feb2024)) & mode=="pr"

* 4/1/2024–4/30/2024 (fh)
replace hadd_bag = 15        if inrange(day, td(01apr2024), td(30apr2024)) & mode=="fh"
replace hadd_min = 18*2.54 if inrange(day, td(01apr2024), td(30apr2024)) & mode=="fh"

* 4/1/2024–4/30/2024 (pr)
replace hadd_bag = 10        if inrange(day, td(01apr2024), td(30apr2024)) & mode=="pr"
replace hadd_min = 17*2.54 if inrange(day, td(01apr2024), td(30apr2024)) & mode=="pr"

* 5/1/2024–7/23/2024 (fh)
replace hadd_bag = 15        if inrange(day, td(01may2024), td(23jul2024)) & mode=="fh"
replace hadd_min = 18*2.54 if inrange(day, td(01may2024), td(23jul2024)) & mode=="fh"

* 5/1/2024–7/23/2024 (pr)
replace hadd_bag = 10        if inrange(day, td(01may2024), td(23jul2024)) & mode=="pr"
replace hadd_min = 17*2.54 if inrange(day, td(01may2024), td(23jul2024)) & mode=="pr"

* 7/24/2024–2/28/2025 (both modes)
replace hadd_bag = 15        if inrange(day, td(24jul2024), td(28feb2025))
replace hadd_min = 18*2.54 if inrange(day, td(24jul2024), td(28feb2025))

* 4/1/2025–4/30/2025 (both modes)
replace hadd_bag = 15        if inrange(day, td(01apr2025), td(30apr2025))
replace hadd_min = 18*2.54 if inrange(day, td(01apr2025), td(30apr2025))

* 5/1/2025–2/28/2026 (both modes)
replace hadd_bag = 15        if inrange(day, td(01may2025), td(28feb2026))
replace hadd_min = 18*2.54 if inrange(day, td(01may2025), td(28feb2026))

*-------------------------------
*            COD                 
*-------------------------------

* 9/1/2023–10/31/2023 (both)
replace cod_bag = 1           if inrange(day, td(01sep2023), td(31oct2023))
replace cod_min = 22*2.54  if inrange(day, td(01sep2023), td(31oct2023))

* 9/1/2024–10/31/2024 (both)
replace cod_bag = 1           if inrange(day, td(01sep2024), td(31oct2024))
replace cod_min = 23*2.54  if inrange(day, td(01sep2024), td(31oct2024))

* 9/1/2025–10/31/2025 (both)
replace cod_bag = 1           if inrange(day, td(01sep2025), td(31oct2025))
replace cod_min = 23*2.54  if inrange(day, td(01sep2025), td(31oct2025))


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
* Year 2 status-quo regs (projection period : 01may2026–30apr2027)
* Based on actual 2025 regulations:
*   Cod:     1 fish, 23",  9/1/25–10/31/25
*   Haddock: 15 fish, 18", 5/1/25–2/28/26 and 4/1/26–4/30/26

gen cod_bag_y2  = 0 
gen cod_min_y2  = 100

gen hadd_bag_y2 = 0
gen hadd_min_y2 = 100

*-------------------------------
*  COD – status quo actual (_y2) 
*-------------------------------
* 1 fish, 23", 9/1/2026–10/31/2026
 
replace cod_bag_y2 = 1           if inrange(day_y2, td(01sep2026), td(31oct2026))
replace cod_min_y2 = 23*2.54  if inrange(day_y2, td(01sep2026), td(31oct2026))

*-------------------------------
*  HADDOCK – status quo actual (_y2) 
*-------------------------------
* 15 fish, 18", 5/1/2026–2/28/2027 and 4/1/2027–4/30/2027

replace hadd_bag_y2 = 15      if inrange(day_y2, td(01may2026), td(28feb2027)) ///
                                              | inrange(day_y2, td(01apr2027), td(30apr2027))
replace hadd_min_y2 = 18*2.54 if inrange(day_y2, td(01may2026), td(28feb2027)) ///
                                                | inrange(day_y2, td(01apr2027), td(30apr2027))


/******************************************************************************/
/******************************************************************************/
/* Section D: Year-2 alternative regulations (voted but not implemented) */
/******************************************************************************/
/******************************************************************************/
*This section can be excluded if the regulations voted for the projection year were actually implemented. But this is not always the case, e.g., in FY 2026. 

* Year 2 alternative regs (projection: 01may2026–30apr2027)
* Based on *voted but not implemented* 2025 regs:
*   Cod:     1 fish, 23",  5/1/25–5/31/25 and 9/1/25–10/31/25
*   Haddock: 15 fish, 17", 5/1/25–2/28/26 and 4/1/26–4/30/26

gen cod_bag_y2_alt  = 0 
gen cod_min_y2_alt  = 100

gen hadd_bag_y2_alt = 0
gen hadd_min_y2_alt = 100

*-------------------------------
*  COD – status quo alternative (_y2_alt)  
*-------------------------------
* 1 fish, 23", 5/1/2026–5/31/2026 and 9/1/2026–10/31/2026
replace cod_bag_y2_alt = 1        if inrange(day_y2, td(01may2026), td(31may2026)) ///
												  | inrange(day_y2, td(01sep2026), td(31oct2026))
replace cod_min_y2_alt = 23*2.54  if inrange(day_y2, td(01may2026), td(31may2026)) ///
													| inrange(day_y2, td(01sep2026), td(31oct2026))

*-------------------------------
*  HADDOCK – status quo alternative (_y2_alt)  
*-------------------------------
* 15 fish, 17", 5/1/2026–2/28/2027 and 4/1/2027–4/30/2027
replace hadd_bag_y2_alt = 15      if inrange(day_y2, td(01may2026), td(28feb2027)) ///
													| inrange(day_y2, td(01apr2027), td(30apr2027))
replace hadd_min_y2_alt = 17*2.54 if inrange(day_y2, td(01may2026), td(28feb2027)) ///
													| inrange(day_y2, td(01apr2027), td(30apr2027))
									 


