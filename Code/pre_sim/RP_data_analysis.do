/******************************************************************************/
/******************************************************************************/
/* Script:  RP_data_analysis.do                                               */
/*                                                                            */
/* Purpose: Exploratory revealed-preference (RP) analysis of whether anglers   */
/*          choose to take a groundfish trip. For each of three MRIP           */
/*          expenditure-survey years (2011, 2017, 2022) it links trip records  */
/*          to reported trip expenditures, flags WGOM trips that targeted cod  */
/*          or haddock as "groundfish" trips, and then stacks the three years  */
/*          and estimates a series of models: survey-weighted logits of the    */
/*          groundfish indicator on year/season/mode, a conditional logit of   */
/*          a constructed groundfish-vs-other binary choice on cost, and a     */
/*          regression of the groundfish indicator on a logsum built from      */
/*          existing preference parameters.                                    */
/*                                                                            */
/* Inputs:  MRIP trip_YYYYW.dta and catch_YYYYW.dta files in the working       */
/*          directory set at the top of this script                           */
/*          gulf_atl_2022.dta, atl_states_2017_expsurvey.dta,                  */
/*          trip_master_final.dta (expenditure surveys)                        */
/*          MRIP_COD_ALL_SITE_LIST.csv                                         */
/*          preference_params.dta                                              */
/*                                                                            */
/* Outputs: None. Nothing is saved or exported; results are estimation output  */
/*          printed to the Results window.                                     */
/*                                                                            */
/* Dependencies: None within this repository -- this script sets its own       */
/*          paths and macros and is not called by model_wrapper.do or any      */
/*          other script. It requires the user-written dsconcat and renvarlab  */
/*          commands.                                                          */
/*                                                                            */
/* Pipeline: Off to the side. This is analyst working code that supported the  */
/*          choice-model specification, not a production pipeline step. It is  */
/*          documented here for the record rather than because it runs.        */
/*                                                                            */
/* Note 1:  Paths are hard-coded to individual developers' machines            */
/*          (C:\Users\andrew.carr-harris\Desktop\..., E:\Lou_projects\...),    */
/*          so the script will not run as written on another machine.          */
/* Note 2:  The three year blocks (2022, 2011, 2017) are near-identical        */
/*          ~130-line copies differing only in the expenditure file, the year  */
/*          filter, and the cod_open season definition.                        */
/* Note 3:  The final estimation section references cod_keep, cod_rel,         */
/*          hadd_keep and hadd_rel, which are not present in the data at that  */
/*          point, and re-generates cod_open after it already exists. Flagged  */
/*          inline; code unchanged.                                            */
/* Dev paths: 10 hardcoded absolute paths to developers' local machines        */
/*          (C:\ or E:\), at lines 54, 110, 113, 117, 118, 335, 387, 542,      */
/*          595 and 791 (see Note 1 above).                                    */
/******************************************************************************/
/******************************************************************************/

/******************************************************************************/
/******************************************************************************/
/* Section A: Locate the MRIP trip and catch files                            */
/******************************************************************************/
/******************************************************************************/

cd "C:\Users\andrew.carr-harris\Desktop\MRIP_data"

**MRIP catch data
global yr_wvs 20221 20222 20223 20224 20225 20226  ///
20111 20112 20113 20114 20115 20116  ///
20171 20172 20173 20174 20175 20176  
global yearlist 2011 2017 2022
global wavelist 1 2 3 4 5 6


/* catchlist and triplist assemble the names of the MRIP files to stack. A file
   is added only if it exists and contains observations, because MRIP does not
   publish every year-wave combination. This is the same idiom used in
   model_wrapper.do. */
global catchlist
foreach year in $yearlist{
	foreach wave in $wavelist{
	capture confirm file "catch_`year'`wave'.dta"
	if _rc==0{
		use "catch_`year'`wave'.dta", clear
		quietly count
		scalar tt=r(N)
		if scalar(tt)>0{
			global catchlist "$catchlist "catch_`year'`wave'.dta " " 
		}
		else{
		}
	}
	else{
	}
	
}
}

global triplist
foreach year in $yearlist{
	foreach wave in  $wavelist{
	capture confirm file "trip_`year'`wave'.dta"
	if _rc==0{
		use "trip_`year'`wave'.dta", clear
		quietly count
		scalar tt=r(N)
		if scalar(tt)>0{
			global triplist "$triplist "trip_`year'`wave'.dta " " 
		}
		else{
		}
	}
	else{
	}
	
}
}


/*
u "C:\Users\andrew.carr-harris\Desktop\MRIP_data_2025\atl_states_2017_expsurvey.dta", clear 
renvarlab, lower 

u "C:\Users\andrew.carr-harris\Desktop\trip_master_final.dta", clear 
renvarlab, lower 
*/

global input_data_cd "E:\Lou_projects\groundfishRDM\2027_mgt_cycle\miscellaneous" /* Lou's local data path */
global input_code_cd "C:\Users\andrew.carr-harris\Desktop\Git\groundfishRDM\Code\pre_sim"

/******************************************************************************/
/******************************************************************************/
/* Section B: 2022 -- trip expenditures joined to MRIP trip records           */
/******************************************************************************/
/******************************************************************************/

di "RP_data_analysis: building 2022 expenditure and trip data ..."

*Enter a directory with the expenditure survey data
u "$input_data_cd\gulf_atl_2022.dta", clear
renvarlab *, lower


/* As per Sabrina, run the following code before using the expenditure data. It
   sets expenditure categories that cannot apply to a given mode to missing, so
   that the rowtotal below does not count a spurious zero as a real zero. */
* For-Hire trips: set boat fuel and boat rental to missing
replace bfuelexp = . if mode == "For-Hire"
replace brentexp = . if mode == "For-Hire"

* Private Boat trips: set guide costs and crew tips to missing
replace guideexp = . if mode == "Private Boat"
replace crewexp  = . if mode == "Private Boat"

* Shore trips: set all of those to missing
replace bfuelexp = . if mode == "Shore"
replace crewexp  = . if mode == "Shore"
replace guideexp = . if mode == "Shore"
replace brentexp = . if mode == "Shore"

mvencode afuelexp arentexp ptransexp lodgexp grocexp restexp baitexp iceexp parkexp bfuelexp brentexp guideexp crewexp procexp feesexp giftsexp  othexp, mv(0) override

/* The free-text "other" category mixes trip costs with durable goods and
   annual purchases (licenses, boat repair, a new rod). Those are not costs of
   taking this particular trip, so they are zeroed out. */
replace othexp=0 if inlist(oth_cat, "2 LICENSES", "BOAT REPAIR", "Boat Towing", "CART", "FISHING LICENSE")
replace othexp=0 if inlist(oth_cat,"LICENSE", "LICENSES", "MONEY SPENT AT CASINO", "NEW ROD", "SEATOW", "SPA", "HAT")

* Compute total trip expenditure
egen total_exp=rowtotal(afuelexp arentexp ptransexp lodgexp grocexp restexp baitexp iceexp parkexp bfuelexp brentexp guideexp crewexp procexp feesexp giftsexp othexp) 

svyset psu_id [pweight= sample_wt], strata(var_id) singleunit(certainty)

*Sabrina's definition of for-hire mode include both headboat and charter boats
*Survey mode definitions:
	*3=shore
	*4=headboat
	*5=charter
	*7=private boat

gen mode1="sh" if inlist(mode_fx, "1", "2", "3")
replace mode1="fh" if inlist(mode_fx, "4", "5")
replace mode1="pr" if inlist(mode_fx,  "7")

keep if inlist(st, 23, 33, 25)

keep  strat_id psu_id id_code total_exp

tempfile costs
save `costs', replace 


clear
mata: mata clear

tempfile tl1 cl1
dsconcat $triplist

sort year strat_id psu_id id_code
drop if strmatch(id_code, "*xx*")==1
duplicates drop 
save `tl1'
clear

dsconcat $catchlist
sort year strat_id psu_id id_code
replace common=subinstr(lower(common)," ","",.)
save `cl1'

replace var_id=strat_id if strmatch(var_id,"")

use `tl1'
merge 1:m year strat_id psu_id id_code using `cl1', keep(1 3) nogenerate /*Keep all trips including catch==0*/
replace var_id=strat_id if strmatch(var_id,"")

keep if year==2022

* Format MRIP data for estimation 
gen state="MA" if st==25
replace state="MD" if st==24
replace state="RI" if st==44
replace state="CT" if st==9
replace state="NY" if st==36
replace state="NJ" if st==34
replace state="DE" if st==10
replace state="VA" if st==51
replace state="NC" if st==37
replace state="ME" if st==23
replace state="NH" if st==33

* Ensure only relevant states 
keep if inlist(st, 23, 33, 25)

gen st2 = string(st,"%02.0f")

gen mode1="sh" if inlist(mode_fx, "1", "2", "3")
replace mode1="pr" if inlist(mode_fx, "7")
replace mode1="fh" if inlist(mode_fx, "4", "5")

/* Classify each trip by its primary target species. Trips targeting cod or
   haddock become domain "ATLCO"; other named targets get their own code; and
   everything else falls in "ZZ".
   NOTE (flagged, code unchanged): the second line assigns prim2_common from
   prim1_common. It looks like a copy-paste, and the same line appears in
   calibration_catch_per_trip_part1.do. prim2_common is not used below, so it
   is currently harmless. */
replace prim1_common=subinstr(lower(prim1_common)," ","",.)
replace prim2_common=subinstr(lower(prim1_common)," ","",.)

gen common_dom="ZZ"

replace common_dom="ATLCO"  if inlist(prim1_common, "atlanticcod") 
replace common_dom="ATLCO"  if inlist(prim1_common, "haddock") 
replace common_dom="BSB"  if inlist(prim1_common, "blackseabass") 
replace common_dom="TUNA"  if inlist(prim1_common, "bluefintuna", "yellowfintuna", "tunagenus") 
replace common_dom="BLU"  if inlist(prim1_common, "bluefish") 
replace common_dom="POL"  if inlist(prim1_common, "pollock") 
replace common_dom="SCUP"  if inlist(prim1_common, "scup") 
replace common_dom="STR"  if inlist(prim1_common, "stripedbass") 
replace common_dom="SF"  if inlist(prim1_common, "summerflounder") 
replace common_dom="TAU"  if inlist(prim1_common, "tautog") 

*New MRIP site allocations
preserve 
import delimited using "$input_data_cd/MRIP_COD_ALL_SITE_LIST.csv", clear 
keep if inlist(state, "MA", "ME")
keep state intsite nmfs_stock_area nmfs_stat_area
sort intsite nmfs_stock_area  
replace nmfs_stock_area="WGOM" if inlist(nmfs_stat_area, 521, 526, 541, 514, 513, 515)
replace nmfs_stock_area="XX" if !inlist(nmfs_stat_area, 521, 526, 541, 514, 513, 515)
keep nmfs_stock_area intsite nmfs_stat_area state
duplicates drop
tempfile mrip_sites
save `mrip_sites', replace 
restore

merge m:1 intsite state using `mrip_sites',  keep(1 3) nogen

/*classify into WGOM or not WGOM */
gen str3 area_s="XX"
replace area_s="WGOM" if st2=="33"
replace area_s=nmfs_stock_area if inlist(st2, "25", "23") 

tostring wave, gen(wv2)
tostring year, gen(yr2)

gen my_dom_id_string=area_s+"_"+month+"_"+mode1+"_"+common_dom


order strat_id psu_id id_code    
keep strat_id psu_id id_code common_dom area_s  mode1 wp_int
duplicates drop 

merge 1:1  strat_id psu_id id_code  using `costs'
 
/* The interview date is embedded in id_code, positions 6-13 as YYYYMMDD; "9x"
   and "xx" are MRIP's placeholders for an unknown day. Note that month was not
   carried through the keep above, so later references to "month" resolve by
   Stata's name abbreviation to the numeric month1 created here. */
gen date=substr(id_code, 6,8)
gen month1=substr(date, 5, 2)
gen day1=substr(date, 7, 2)
drop if inlist(day1,"9x", "xx")
destring day1, replace
destring month1, replace

keep if _merge==3
tab mode1
drop _merge 

/* A "groundfish trip" is one that targeted cod or haddock AND took place in
   the WGOM stock area; everything else is the outside option. */
gen trip_type="groundfish" if common_dom=="ATLCO" & area_s=="WGOM"
tab mode1 if trip_type=="groundfish"

drop if mode1=="sh"
replace trip_type="other" if trip_type!="groundfish"

gen groundfish=1 if trip_type=="groundfish"
mvencode groundfish, mv(0) override
order groundfish strat_id psu_id id_code 
drop common_dom area_s

/* Season indicators reflect the regulations actually in force in that year;
   they differ across the three year blocks. In 2022 the recreational cod
   season was September-October and haddock was open except in April. */
gen cod_open =1 if inlist(month, 9, 10)
mvencode cod_open, mv(0)

gen haddock_open =1 if !inlist(month, 4)
mvencode haddock_open, mv(0)

gen year=2022

tempfile y2022
save `y2022', replace

/******************************************************************************/
/******************************************************************************/
/* Section C: 2011 -- same processing as Section B                            */
/******************************************************************************/
/******************************************************************************/

di "RP_data_analysis: building 2011 expenditure and trip data ..."

u "C:\Users\andrew.carr-harris\Desktop\trip_master_final.dta", clear
renvarlab * , lower 

/* As per Sabrina, run the following code before using the expenditure data. It
   sets expenditure categories that cannot apply to a given mode to missing, so
   that the rowtotal below does not count a spurious zero as a real zero. */
* For-Hire trips: set boat fuel and boat rental to missing
replace bfuelexp = . if mode == "For-Hire"
replace brentexp = . if mode == "For-Hire"

* Private Boat trips: set guide costs and crew tips to missing
replace guideexp = . if mode == "Private Boat"
replace crewexp  = . if mode == "Private Boat"

* Shore trips: set all of those to missing
replace bfuelexp = . if mode == "Shore"
replace crewexp  = . if mode == "Shore"
replace guideexp = . if mode == "Shore"
replace brentexp = . if mode == "Shore"

mvencode afuelexp arentexp ptransexp lodgexp grocexp restexp baitexp iceexp parkexp bfuelexp brentexp guideexp crewexp procexp feesexp giftsexp  othexp, mv(0) override

/* The free-text "other" category mixes trip costs with durable goods and
   annual purchases (licenses, boat repair, a new rod). Those are not costs of
   taking this particular trip, so they are zeroed out. */
replace othexp=0 if inlist(oth_cat, "2 LICENSES", "BOAT REPAIR", "Boat Towing", "CART", "FISHING LICENSE")
replace othexp=0 if inlist(oth_cat,"LICENSE", "LICENSES", "MONEY SPENT AT CASINO", "NEW ROD", "SEATOW", "SPA", "HAT")

* Compute total trip expenditure
egen total_exp=rowtotal(afuelexp arentexp ptransexp lodgexp grocexp restexp baitexp iceexp parkexp bfuelexp brentexp guideexp crewexp procexp feesexp giftsexp othexp) 

svyset psu_id [pweight= sample_wt], strata(strat_id) singleunit(certainty)


*Sabrina's definition of for-hire mode include both headboat and charter boats
*Survey mode definitions:
	*3=shore
	*4=headboat
	*5=charter
	*7=private boat

gen mode1="sh" if inlist(mode_fx, "1", "2", "3")
replace mode1="fh" if inlist(mode_fx, "4", "5")
replace mode1="pr" if inlist(mode_fx,  "7")

keep if inlist(st, 23, 33, 25)

keep  strat_id psu_id id_code total_exp

tempfile costs
save `costs', replace 

cd "C:\Users\andrew.carr-harris\Desktop\MRIP_data"


clear
mata: mata clear

tempfile tl1 cl1
dsconcat $triplist

sort year strat_id psu_id id_code
drop if strmatch(id_code, "*xx*")==1
duplicates drop 
save `tl1'
clear

dsconcat $catchlist
sort year strat_id psu_id id_code
replace common=subinstr(lower(common)," ","",.)
save `cl1'

replace var_id=strat_id if strmatch(var_id,"")

use `tl1'
merge 1:m year strat_id psu_id id_code using `cl1', keep(1 3) nogenerate /*Keep all trips including catch==0*/
replace var_id=strat_id if strmatch(var_id,"")

keep if year==2011

* Format MRIP data for estimation 
gen state="MA" if st==25
replace state="MD" if st==24
replace state="RI" if st==44
replace state="CT" if st==9
replace state="NY" if st==36
replace state="NJ" if st==34
replace state="DE" if st==10
replace state="VA" if st==51
replace state="NC" if st==37
replace state="ME" if st==23
replace state="NH" if st==33

* Ensure only relevant states 
keep if inlist(st, 23, 33, 25)

gen st2 = string(st,"%02.0f")

gen mode1="sh" if inlist(mode_fx, "1", "2", "3")
replace mode1="pr" if inlist(mode_fx, "7")
replace mode1="fh" if inlist(mode_fx, "4", "5")

/* Classify each trip by its primary target species. Trips targeting cod or
   haddock become domain "ATLCO"; other named targets get their own code; and
   everything else falls in "ZZ".
   NOTE (flagged, code unchanged): the second line assigns prim2_common from
   prim1_common. It looks like a copy-paste, and the same line appears in
   calibration_catch_per_trip_part1.do. prim2_common is not used below, so it
   is currently harmless. */
replace prim1_common=subinstr(lower(prim1_common)," ","",.)
replace prim2_common=subinstr(lower(prim1_common)," ","",.)

gen common_dom="ZZ"

replace common_dom="ATLCO"  if inlist(prim1_common, "atlanticcod") 
replace common_dom="ATLCO"  if inlist(prim1_common, "haddock") 
replace common_dom="BSB"  if inlist(prim1_common, "blackseabass") 
replace common_dom="TUNA"  if inlist(prim1_common, "bluefintuna", "yellowfintuna", "tunagenus") 
replace common_dom="BLU"  if inlist(prim1_common, "bluefish") 
replace common_dom="POL"  if inlist(prim1_common, "pollock") 
replace common_dom="SCUP"  if inlist(prim1_common, "scup") 
replace common_dom="STR"  if inlist(prim1_common, "stripedbass") 
replace common_dom="SF"  if inlist(prim1_common, "summerflounder") 
replace common_dom="TAU"  if inlist(prim1_common, "tautog") 

*New MRIP site allocations
preserve 
import delimited using "$input_data_cd/MRIP_COD_ALL_SITE_LIST.csv", clear 
keep if inlist(state, "MA", "ME")
keep state intsite nmfs_stock_area nmfs_stat_area
sort intsite nmfs_stock_area  
replace nmfs_stock_area="WGOM" if inlist(nmfs_stat_area, 521, 526, 541, 514, 513, 515)
replace nmfs_stock_area="XX" if !inlist(nmfs_stat_area, 521, 526, 541, 514, 513, 515)
keep nmfs_stock_area intsite nmfs_stat_area state
duplicates drop
tempfile mrip_sites
save `mrip_sites', replace 
restore

merge m:1 intsite state using `mrip_sites',  keep(1 3) nogen

/*classify into WGOM or not WGOM */
gen str3 area_s="XX"
replace area_s="WGOM" if st2=="33"
replace area_s=nmfs_stock_area if inlist(st2, "25", "23") 

tostring wave, gen(wv2)
tostring year, gen(yr2)

gen my_dom_id_string=area_s+"_"+month+"_"+mode1+"_"+common_dom


order strat_id psu_id id_code    
keep strat_id psu_id id_code common_dom area_s  mode1 wp_int
duplicates drop 

merge 1:1  strat_id psu_id id_code  using `costs'
 
/* The interview date is embedded in id_code, positions 6-13 as YYYYMMDD; "9x"
   and "xx" are MRIP's placeholders for an unknown day. Note that month was not
   carried through the keep above, so later references to "month" resolve by
   Stata's name abbreviation to the numeric month1 created here. */
gen date=substr(id_code, 6,8)
gen month1=substr(date, 5, 2)
gen day1=substr(date, 7, 2)
drop if inlist(day1,"9x", "xx")
destring day1, replace
destring month1, replace

keep if _merge==3
tab mode1
drop _merge 

/* A "groundfish trip" is one that targeted cod or haddock AND took place in
   the WGOM stock area; everything else is the outside option. */
gen trip_type="groundfish" if common_dom=="ATLCO" & area_s=="WGOM"
tab mode1 if trip_type=="groundfish"

drop if mode1=="sh"
replace trip_type="other" if trip_type!="groundfish"

gen groundfish=1 if trip_type=="groundfish"
mvencode groundfish, mv(0) override
order groundfish strat_id psu_id id_code 
drop common_dom area_s

/* Cod was open April-October in 2011, a much longer season than in 2017/2022 */
gen cod_open =1 if inlist(month,4, 5, 6, 7, 8, 9, 10)
mvencode cod_open, mv(0)

gen haddock_open =1 if !inlist(month, 4)
mvencode haddock_open, mv(0)

gen year=2011

tempfile y2011
save `y2011', replace 


/******************************************************************************/
/******************************************************************************/
/* Section D: 2017 -- same processing as Section B                            */
/******************************************************************************/
/******************************************************************************/

di "RP_data_analysis: building 2017 expenditure and trip data ..."

u "C:\Users\andrew.carr-harris\Desktop\MRIP_data_2025\atl_states_2017_expsurvey.dta", clear
renvarlab *, lower 


/* As per Sabrina, run the following code before using the expenditure data. It
   sets expenditure categories that cannot apply to a given mode to missing, so
   that the rowtotal below does not count a spurious zero as a real zero. */
* For-Hire trips: set boat fuel and boat rental to missing
replace bfuelexp = . if mode == "For-Hire"
replace brentexp = . if mode == "For-Hire"

* Private Boat trips: set guide costs and crew tips to missing
replace guideexp = . if mode == "Private Boat"
replace crewexp  = . if mode == "Private Boat"

* Shore trips: set all of those to missing
replace bfuelexp = . if mode == "Shore"
replace crewexp  = . if mode == "Shore"
replace guideexp = . if mode == "Shore"
replace brentexp = . if mode == "Shore"

mvencode afuelexp arentexp ptransexp lodgexp grocexp restexp baitexp iceexp parkexp bfuelexp brentexp guideexp crewexp procexp feesexp giftsexp  othexp, mv(0) override

/* The free-text "other" category mixes trip costs with durable goods and
   annual purchases (licenses, boat repair, a new rod). Those are not costs of
   taking this particular trip, so they are zeroed out. */
replace othexp=0 if inlist(oth_cat, "2 LICENSES", "BOAT REPAIR", "Boat Towing", "CART", "FISHING LICENSE")
replace othexp=0 if inlist(oth_cat,"LICENSE", "LICENSES", "MONEY SPENT AT CASINO", "NEW ROD", "SEATOW", "SPA", "HAT")

* Compute total trip expenditure
egen total_exp=rowtotal(afuelexp arentexp ptransexp lodgexp grocexp restexp baitexp iceexp parkexp bfuelexp brentexp guideexp crewexp procexp feesexp giftsexp othexp) 

svyset psu_id [pweight= sample_wt], strata(strat_id) singleunit(certainty)


*Sabrina's definition of for-hire mode include both headboat and charter boats
*Survey mode definitions:
	*3=shore
	*4=headboat
	*5=charter
	*7=private boat

gen mode1="sh" if inlist(mode_fx, "1", "2", "3")
replace mode1="fh" if inlist(mode_fx, "4", "5")
replace mode1="pr" if inlist(mode_fx,  "7")

keep if inlist(st, 23, 33, 25)

keep  strat_id psu_id id_code total_exp

tempfile costs
save `costs', replace 

cd "C:\Users\andrew.carr-harris\Desktop\MRIP_data"
clear
mata: mata clear

tempfile tl1 cl1
dsconcat $triplist

sort year strat_id psu_id id_code
drop if strmatch(id_code, "*xx*")==1
duplicates drop 
save `tl1'
clear

dsconcat $catchlist
sort year strat_id psu_id id_code
replace common=subinstr(lower(common)," ","",.)
save `cl1'

replace var_id=strat_id if strmatch(var_id,"")

use `tl1'
merge 1:m year strat_id psu_id id_code using `cl1', keep(1 3) nogenerate /*Keep all trips including catch==0*/
replace var_id=strat_id if strmatch(var_id,"")

keep if year==2017

* Format MRIP data for estimation 
gen state="MA" if st==25
replace state="MD" if st==24
replace state="RI" if st==44
replace state="CT" if st==9
replace state="NY" if st==36
replace state="NJ" if st==34
replace state="DE" if st==10
replace state="VA" if st==51
replace state="NC" if st==37
replace state="ME" if st==23
replace state="NH" if st==33

* Ensure only relevant states 
keep if inlist(st, 23, 33, 25)

gen st2 = string(st,"%02.0f")

gen mode1="sh" if inlist(mode_fx, "1", "2", "3")
replace mode1="pr" if inlist(mode_fx, "7")
replace mode1="fh" if inlist(mode_fx, "4", "5")

/* Classify each trip by its primary target species. Trips targeting cod or
   haddock become domain "ATLCO"; other named targets get their own code; and
   everything else falls in "ZZ".
   NOTE (flagged, code unchanged): the second line assigns prim2_common from
   prim1_common. It looks like a copy-paste, and the same line appears in
   calibration_catch_per_trip_part1.do. prim2_common is not used below, so it
   is currently harmless. */
replace prim1_common=subinstr(lower(prim1_common)," ","",.)
replace prim2_common=subinstr(lower(prim1_common)," ","",.)

gen common_dom="ZZ"

replace common_dom="ATLCO"  if inlist(prim1_common, "atlanticcod") 
replace common_dom="ATLCO"  if inlist(prim1_common, "haddock") 
replace common_dom="BSB"  if inlist(prim1_common, "blackseabass") 
replace common_dom="TUNA"  if inlist(prim1_common, "bluefintuna", "yellowfintuna", "tunagenus") 
replace common_dom="BLU"  if inlist(prim1_common, "bluefish") 
replace common_dom="POL"  if inlist(prim1_common, "pollock") 
replace common_dom="SCUP"  if inlist(prim1_common, "scup") 
replace common_dom="STR"  if inlist(prim1_common, "stripedbass") 
replace common_dom="SF"  if inlist(prim1_common, "summerflounder") 
replace common_dom="TAU"  if inlist(prim1_common, "tautog") 

*New MRIP site allocations
preserve 
import delimited using "$input_data_cd/MRIP_COD_ALL_SITE_LIST.csv", clear 
keep if inlist(state, "MA", "ME")
keep state intsite nmfs_stock_area nmfs_stat_area
sort intsite nmfs_stock_area  
replace nmfs_stock_area="WGOM" if inlist(nmfs_stat_area, 521, 526, 541, 514, 513, 515)
replace nmfs_stock_area="XX" if !inlist(nmfs_stat_area, 521, 526, 541, 514, 513, 515)
keep nmfs_stock_area intsite nmfs_stat_area state
duplicates drop
tempfile mrip_sites
save `mrip_sites', replace 
restore

merge m:1 intsite state using `mrip_sites',  keep(1 3) nogen

/*classify into WGOM or not WGOM */
gen str3 area_s="XX"
replace area_s="WGOM" if st2=="33"
replace area_s=nmfs_stock_area if inlist(st2, "25", "23") 

tostring wave, gen(wv2)
tostring year, gen(yr2)

gen my_dom_id_string=area_s+"_"+month+"_"+mode1+"_"+common_dom


order strat_id psu_id id_code    
keep strat_id psu_id id_code common_dom area_s  mode1 wp_int
duplicates drop 

merge 1:1  strat_id psu_id id_code  using `costs'
 
/* The interview date is embedded in id_code, positions 6-13 as YYYYMMDD; "9x"
   and "xx" are MRIP's placeholders for an unknown day. Note that month was not
   carried through the keep above, so later references to "month" resolve by
   Stata's name abbreviation to the numeric month1 created here. */
gen date=substr(id_code, 6,8)
gen month1=substr(date, 5, 2)
gen day1=substr(date, 7, 2)
drop if inlist(day1,"9x", "xx")
destring day1, replace
destring month1, replace

keep if _merge==3
tab mode1
drop _merge 

/* A "groundfish trip" is one that targeted cod or haddock AND took place in
   the WGOM stock area; everything else is the outside option. */
gen trip_type="groundfish" if common_dom=="ATLCO" & area_s=="WGOM"
tab mode1 if trip_type=="groundfish"

drop if mode1=="sh"
replace trip_type="other" if trip_type!="groundfish"

gen groundfish=1 if trip_type=="groundfish"
mvencode groundfish, mv(0) override
order groundfish strat_id psu_id id_code 
drop common_dom area_s

gen cod_open =1 if inlist(month,9, 10)
mvencode cod_open, mv(0)

gen haddock_open =1 if !inlist(month, 4)
mvencode haddock_open, mv(0)

gen year=2017


/******************************************************************************/
/******************************************************************************/
/* Section E: Stack the three years and estimate                              */
/******************************************************************************/
/******************************************************************************/

append using `y2011'
append using `y2022'

/* Descriptive models of who takes a groundfish trip. The logit is repeated
   verbatim; only the second call has any effect. */
encode mode1, gen(mode2)
svyset [pweight=wp_int]
svy: logit groundfish i.year   i.cod_open##i.month i.mode2
svy: logit groundfish i.year   i.cod_open##i.month i.mode2


gen trip_id=_n
probit groundfish i.year  i.cod_open##i.month


/* Build a two-alternative choice set out of each observed trip: the row the
   angler actually chose (dup==0, choice==1) and a counterfactual row for the
   alternative trip type (dup==1), priced at the average expenditure for that
   month and trip type. The conditional logit then identifies the cost
   coefficient from the observed choice between the two. */
egen avg_cost=mean(total_exp), by(month trip_type)
gen orig_trip_type=groundfish

expand 2, gen(dup)
order trip_id
sort trip_id

bysort trip_id (dup): gen alt=_n
order alt
gen choice=1 if dup==0
order choice
order dup
mvencode choice, mv(0)

replace groundfish=0 if orig_trip_type==1 & dup==1
replace groundfish=1 if orig_trip_type==0 & dup==1

sort trip_id alt


replace total_exp=avg if dup==1

clogit choice total_exp groundfish, group(trip_id)


/* Bring in the mean utility parameters estimated elsewhere so that a
   groundfish-trip quality index can be constructed for each trip. The
   tab=1 variable is a join key that gives every row the same parameters. */
preserve
u   "E:\Lou_projects\groundfishRDM\process_data\preference_params.dta", clear
collapse (mean) beta*
keep beta_sqrt_cod_keep beta_sqrt_cod_release beta_sqrt_hadd_keep beta_sqrt_hadd_release beta_sqrt_cod_hadd_keep beta_cost
gen tab=1
tempfile params
save `params', replace 
restore

gen tab=1
merge m:1 tab using `params' 

/* Trip quality index and its logsum by month: the expected utility of a
   groundfish trip, aggregated over trips within a month, is then used as a
   regressor for the probability that a trip is a groundfish trip.
   NOTE (flagged, code unchanged): cod_keep, cod_rel, hadd_keep and hadd_rel
   are not in the data at this point -- they were not retained by the keep in
   each year block -- and cod_open below is generated a second time. Both
   would stop this section from running as written. */
gen Q_gf= beta_sqrt_cod_keep*sqrt(cod_keep) +beta_sqrt_cod_release*sqrt(cod_rel) ///
				+beta_sqrt_hadd_keep*sqrt(hadd_keep) + beta_sqrt_hadd_release*sqrt(hadd_rel) ///
				+beta_sqrt_cod_hadd_keep*sqrt(cod_keep)*sqrt(hadd_keep) ///
				+beta_cost*total_exp if trip_type=="groundfish"

gen exp_Q_gf=exp(Q_gf)
egen sum_exp_Q_gf= sum(exp_Q_gf), by(month)
gen log_exp_Q_gf= log(sum_exp_Q_gf)


gen cod_open =1 if inlist(month, 9, 10)
mvencode cod_open, mv(0)

reg groundfish log_exp_Q_gf cod_open

				





