/*******************************************************************************
 Script:       calibration_catch_per_trip_part1.do
 Purpose:      Uses MRIP trip and catch records to build the calibration-year
               catch-per-trip inputs for the copula simulation, plus the MRIP
               benchmark totals used later to check the simulation.
               Part A: estimates survey-weighted mean harvest-, discard-, and
                 catch-per-trip and their standard errors by month/mode/area/
                 species-domain (the "my_dom_id_string" strata). Strata with a
                 single PSU have no SE; these are imputed from neighboring-month
                 strata (an approach loosely modeled on MRIP hot/cold-deck
                 imputation). Flags strata where keep and release never co-occur
                 (or are perfectly correlated) so the copula treats them as
                 independent. Saves baseline_mrip_catch_processed.dta for the R
                 copula step.
               Part B: computes survey-weighted MRIP catch TOTALS by mode, by
                 mode-month, and by mode-season, as benchmarks the simulated
                 calibration-year totals are later compared against.
 Inputs:       $triplist, $catchlist (tidied MRIP extracts),
               $misc_data_cd/MRIP_COD_ALL_SITE_LIST.csv (site -> stock-area map).
 Outputs:      $misc_data_cd/baseline_mrip_catch_processed.{xlsx,dta},
               $misc_data_cd/mrip_catch_by_mode.dta,
               $misc_data_cd/mrip_catch_by_mode_month.dta,
               $misc_data_cd/mrip_catch_by_mode_season.dta.
 Dependencies: Globals $seed, $calibration_year, $triplist, $catchlist,
               $misc_data_cd (set in model_wrapper.do). User command renvarlab.
 Pipeline:     Step 5a. Gated by `catch_per_trip1' in model_wrapper.do; its
               output feeds copula_modeling_calibration.R (step 5b), then
               calibration_catch_per_trip_part2.do (step 5c).
 Note:         Several comments were copied from the flukeRDM template and
               referred to "fluke, sea bass, or scup" / "sf/bsb"; the code here
               classifies Atlantic cod and haddock, so those comments were
               corrected. Part B repeats the same MRIP-prep block three times
               (once per aggregation level); this duplication is intentional in
               the source, not a merge artifact. Suspected copy-paste (code
               unchanged): prim2_common is assigned from prim1_common (see the
               "classify trips" lines); prim2_common is not used downstream.
*******************************************************************************/



/******************************************************************************/
/******************************************************************************/
/* Part A: Mean catch-per-trip by stratum, with SE imputation */
/******************************************************************************/
/******************************************************************************/

di "Part A: estimating mean catch-per-trip and standard errors by stratum"
set seed $seed

* Pull in MRIP data


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


keep if $calibration_year
 
gen st2 = string(st,"%02.0f")

gen mode1="sh" if inlist(mode_fx, "1", "2", "3")
replace mode1="pr" if inlist(mode_fx, "7")
replace mode1="fh" if inlist(mode_fx, "4", "5")

*drop shore trips
drop if mode1=="sh"

* classify trips into the domain we care about (caught or targeted cod or haddock) and everything else, marked "ZZ"
replace prim1_common=subinstr(lower(prim1_common)," ","",.)
replace prim2_common=subinstr(lower(prim1_common)," ","",.)

* We need to retain 1 observation for each strat_id, psu_id, and id_code
/* A.  Trip targeted or caught cod or haddock -> domain "ATLCO"
   B.  Trip did not target or catch either species -> domain "ZZ"
*/

gen common_dom="ZZ"
replace common_dom="ATLCO" if inlist(common, "atlanticcod") 
replace common_dom="ATLCO" if inlist(common, "haddock") 

replace common_dom="ATLCO"  if inlist(prim1_common, "atlanticcod") 
replace common_dom="ATLCO"  if inlist(prim1_common, "haddock") 

*MRIP-Western GoM site allocations
preserve 
import delimited using "$misc_data_cd/MRIP_COD_ALL_SITE_LIST.csv", clear 
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
replace area_s="WGOM" if st2=="33" /*classify all NH sites as WGOM */
replace area_s=nmfs_stock_area if inlist(st2, "25", "23") 

tostring wave, gen(wv2)
tostring year, gen(yr2)

gen my_dom_id_string=area_s+"_"+month+"_"+mode1+"_"+common_dom

* Define the list of species to process
local species "atlanticcod haddock"

* Loop over each species
foreach s of local species {

    * Create short species prefix (e.g., cod, hadd)
    local short = substr("`s'", 1, 4)
    if "`s'" == "atlanticcod" local short "cod"
    if "`s'" == "haddock"     local short "hadd"

    * Generate species-specific totals
    gen `short'_tot_cat = tot_cat if common == "`s'"
    egen sum_`short'_tot_cat = sum(`short'_tot_cat), by(strat_id psu_id id_code)

    gen `short'_harvest = landing if common == "`s'"
    egen sum_`short'_harvest = sum(`short'_harvest), by(strat_id psu_id id_code)

    gen `short'_releases = release if common == "`s'"
    egen sum_`short'_releases = sum(`short'_releases), by(strat_id psu_id id_code)
}

rename sum_cod_tot_cat cod_cat
rename sum_cod_harvest cod_keep
rename sum_cod_releases cod_rel
rename sum_hadd_tot_cat hadd_cat
rename sum_hadd_harvest hadd_keep
rename sum_hadd_releases hadd_rel

* Set a variable "no_dup"=0 if the record is "$my_common" catch and no_dup=1 otherwise
  
gen no_dup=0
replace no_dup=1 if  strmatch(common, "atlanticcod")==0
replace no_dup=1 if strmatch(common, "haddock")==0

/*
We sort on year, strat_id, psu_id, id_code, "no_dup", and "my_dom_id_string". For records with duplicate year, strat_id, psu_id, and id_codes, the first entry will be the cod/haddock catch record if it exists (domain "ATLCO"). If there is no cod/haddock catch but the trip targeted or caught either species, the secondary sort on "my_dom_id_string" ensures the trip is properly classified.

After sorting, we generate a count variable (count_obs1 from 1....n) and we keep only the "first" observations within each "year, strat_id, psu_id, and id_codes" group.
*/

bysort year strat_id psu_id id_code (my_dom_id_string no_dup): gen count_obs1=_n

keep if count_obs1==1 // This keeps only one record for trips with catch of multiple species. We have already computed catch of the species of interest above and saved these in a trip-row

order strat_id psu_id id_code no_dup my_dom_id_string count_obs1 common

replace my_dom_id_string=month+"_"+mode1+"_"+area_s+"_"+common_dom

svyset psu_id [pweight= wp_int], strata(strat_id) singleunit(certainty)

drop if wp_int==0
encode my_dom_id_string, gen(my_dom_id)

preserve
keep my_dom_id my_dom_id_string
duplicates drop 
tempfile domains
save `domains', replace 
restore

tempfile basefile
save `basefile', replace 


* Here I will estimate mean catch/harvest/discards per trip for each strata in order to identify strata with missing SE
* For strata with missing SE's, I'll follow similar approch to MRIP's hot and cold deck imputation for observations with missing lengths and weights

/* From the MRIP data handbook:

"For intercepted angler trips with landings where both length and weight measurements are missing, paired length and weight observations are imputed from complete cases using hot and cold deck imputation. (Complete cases include records with both length and weight data available, as well as records where we were able to compute a missing length or weight using the length-weight modeling described above.) Up to five rounds of imputation are conducted in an attempt to fill in missing values. These rounds begin with imputation cells that correspond to the most detailed MRIP estimation cells, but are aggregated to higher levels in subsequent rounds to bring in more length-weight data. 
	- Round 1: Current year, two-month sampling wave, sub-region, state, mode, area fished, species. 
	- Round 2: Current year, half-year, sub-region, state, mode, species. 
	- Round 3: Current + most recent prior year, two-month sampling wave, sub-region, state, mode, area fished, species. 
	- Round 4: Current + most recent prior year, sub-region, state, mode, species. 
	- Round 5: Current + most recent prior year, sub-region, species."
	

* The calibration estimation strata is: current year + month + mode, for harvest/discards/catch per trip

* For strata with missing, I'll impute a PSE from other strata and apply it to the missing-SE strata. 
	- Round 1: current year + current and neighboring month  + state + mode
 */

* Create a postfile to collect results
tempfile results
postfile handle str15 varname str15 domain float mean se ll95 ul95 using `results', replace

* Loop over variables
foreach var in cod_keep cod_rel cod_cat hadd_keep hadd_rel hadd_cat  {

    * Run svy mean for the variable by domain
    svy: mean `var', over(my_dom_id)

    * Grab result matrix and domain labels
    matrix M = r(table)
    local colnames : colnames M

    * Loop over columns (domains)
    foreach col of local colnames {
        local m  = M[1, "`col'"]
        local se = M[2, "`col'"]
        local lb = M[5, "`col'"]
        local ub = M[6, "`col'"]

        post handle ("`var'") ("`col'") (`m') (`se') (`lb') (`ub')
    }
}

postclose handle

* Load results back into memory
use `results', clear

split domain, parse("@")
drop domain1
split domain2, parse(.)
split domain21, parse(b)

drop domain2 domain21 domain22 domain212
destring domain211, replace
rename domain211 my_dom_id
merge m:1 my_dom_id using `domains' 
sort varname  my_dom_id
keep varname mean se my_dom_id_string
drop if mean==0

tempfile base_results
save `base_results', replace

gen pse=se/mean
keep if se==.

split my, parse(_)
rename my_dom_id_string1 month
rename my_dom_id_string2 mode
rename my_dom_id_string3 area_s
rename my_dom_id_string4 common_dom


keep if area_s=="WGOM"
keep if common=="ATLCO"

gen shoulder_month="10" if month=="11"


gen strata_id=_n
levelsof strata_id, local(stratz)

tempfile missing_se
save `missing_se', replace 

* Round 1
global impute
foreach s of local stratz{
	u `missing_se', clear 
	keep if strata_id==`s'
	
	levelsof mode, local(md) clean
	levelsof month, local(month1) clean
	levelsof common_dom, local(common_dom1) clean
	levelsof area_s, local(area_s1) clean
	levelsof shoulder_month, local(month2) clean
	levelsof varname, local(outcome) clean
	levelsof my_dom_id_string, local(my_dom_id_string) clean

	u `basefile', clear 
	keep if mode1=="`md'" & inlist(month, "`month1'", "`month2'") & area_s=="`area_s1'" & common_dom=="`common_dom1'"
	drop my_dom_id_string my_dom_id
	gen my_dom_id_string="`my_dom_id_string'"
	encode my_dom_id_string, gen(my_dom_id)

	
	* Create a postfile to collect results
	tempfile results
	postfile handle2 str15 varname str15 domain float mean se ll95 ul95 using `results', replace

    * Run svy mean for the variable by domain
    svy: mean `outcome', over(my_dom_id)

    * Grab result matrix and domain labels
    matrix M = r(table)
    local colnames : colnames M

    * Loop over columns (domains)
    foreach col of local colnames {
        local m  = M[1, "`col'"]
        local se = M[2, "`col'"]
        local lb = M[5, "`col'"]
        local ub = M[6, "`col'"]

        post handle2 ("`outcome'") ("`my_dom_id_string'") (`m') (`se') (`lb') (`ub')
    }


postclose handle2

* Load results back into memory
use `results', clear

gen pse_impute=se/mean
rename domain my_dom_id_string
keep varname pse_impute my_dom_id_string

tempfile impute`s'
save `impute`s'', replace
global impute "$impute "`impute`s''" " 

}	
dsconcat $impute 

merge 1:1  varname my_dom_id_string using `missing_se'
keep if _merge==3
drop _merge
merge 1:1 varname my_dom_id_string using `base_results'

replace se=mean*pse_impute if se==. & _merge==3
drop month mode area_s common

split my, parse(_)
rename my_dom_id_string1 month
rename my_dom_id_string2 mode
rename my_dom_id_string3 area_s
rename my_dom_id_string4 common_dom

keep if area_s=="WGOM"
keep if common=="ATLCO"
* Stop code if non-value mean harvest/discards/catch-per trip are missing standard errors
* Check condition across the dataset
summarize if mean != 0 & missing(se)

* If any observations meet the condition, stop
if r(N) > 0 {
    display "Stopping: mean is not zero and se is missing for some observations."
    exit 1
}

gen missing_se=1 if _merge==3
drop _merge
sort my_dom_id_string var
drop pse
keep varname my mean se missing
reshape wide mean se missing, i(my) j(varname) string

* make indicator variables for whether each domain contains keep, discards, or keep and discards of each species 
mvencode meanhadd_keep meanhadd_rel  meancod_keep meancod_rel, mv(0) override

gen cod_only_keep=1 if meancod_keep>0 & meancod_rel==0
gen cod_only_rel=1 if meancod_rel>0 & meancod_keep==0
gen cod_keep_and_rel=1 if meancod_rel>0 & meancod_keep>0
gen cod_no_catch=1 if meancod_rel==0 & meancod_keep==0

gen hadd_only_keep=1 if meanhadd_keep>0 & meanhadd_rel==0
gen hadd_only_rel=1 if meanhadd_rel>0 & meanhadd_keep==0
gen hadd_keep_and_rel=1 if meanhadd_rel>0 & meanhadd_keep>0
gen hadd_no_catch=1 if meanhadd_rel==0 & meanhadd_keep==0


mvencode cod_only_keep cod_only_rel cod_keep_and_rel cod_no_catch hadd_only_keep hadd_only_rel hadd_keep_and_rel hadd_no_catch, mv(0) override

merge 1:m my_dom_id_string using `basefile'
*drop non-WGOM and non-dom catch
drop if strmatch(my_dom_id_string, "*XX*")==1 | strmatch(my_dom_id_string, "*ZZ*")==1

drop if strmatch(my_dom_id_string, "*XX*")==1 | strmatch(my_dom_id_string, "*ZZ*")==1 

*condition for when keep and release are both positive for a stratum, but they never occur on the same trip
*Will model these distributions as independent
gen tab=1 if cod_keep>0 & cod_keep!=. & cod_rel>0 & cod_rel!=.
egen sumtab=sum(tab), by(my_dom_id_string)
gen cod_keep_and_rel_ind=1 if cod_keep_and_rel==1 & sumtab==0
replace cod_keep_and_rel=0 if cod_keep_and_rel_ind==1
drop tab sumtab

gen tab=1 if hadd_keep>0 & hadd_keep!=. & hadd_rel>0 & hadd_rel!=.
egen sumtab=sum(tab), by(my_dom_id_string)
gen hadd_keep_and_rel_ind=1 if hadd_keep_and_rel==1 & sumtab==0
replace hadd_keep_and_rel=0 if hadd_keep_and_rel_ind==1
drop tab sumtab

*condition for when keep and release are both positive for a stratum, but occured together on only one trip so that the correlation==1.
*Will model these distributions as independent
*cod
gen perfect_corr=.
levelsof my_dom_id_string if cod_keep_and_rel==1, local(doms)
foreach d of local doms{
di "`d'" 
egen rank_keep = rank(cod_keep) if my_dom_id_string=="`d'" 
egen rank_rel  = rank(cod_rel) if my_dom_id_string=="`d'" 
count if  my_dom_id_string=="`d'" 
if `r(N)'>1{
corr rank_keep rank_rel if my_dom_id_string=="`d'"  [aw=wp_int]
if `r(rho)'==1 | `r(rho)'==. {
	replace perfect_corr=1 if my_dom_id_string=="`d'"
}
}
	drop rank*

}

replace cod_keep_and_rel=0 if cod_keep_and_rel==1 & perfect_corr==1
replace cod_keep_and_rel_ind=1 if perfect_corr==1

drop perfect_corr

*hadd
gen perfect_corr=.
levelsof my_dom_id_string if hadd_keep_and_rel==1, local(doms)
foreach d of local doms{
di "`d'" 
egen rank_keep = rank(hadd_keep) if my_dom_id_string=="`d'" 
egen rank_rel  = rank(hadd_rel) if my_dom_id_string=="`d'" 
count if  my_dom_id_string=="`d'" 
if `r(N)'>1{
corr rank_keep rank_rel if my_dom_id_string=="`d'"   [aw=wp_int]
if `r(rho)'==1 | `r(rho)'==. {
	replace perfect_corr=1 if my_dom_id_string=="`d'" 
}
}
	drop rank*

}

replace hadd_keep_and_rel=0 if hadd_keep_and_rel==1 & perfect_corr==1
replace hadd_keep_and_rel_ind=1 if perfect_corr==1
drop perfect_corr


keep wp_int my_dom_id_string meancod_cat-id_code year common_dom cod_tot_cat-hadd_rel cod_keep_and_rel_ind hadd_keep_and_rel_ind

mvencode se*, mv(0) override
mvencode missing*, mv(0) override
mvencode mean*, mv(0) override
replace cod_no_catch=1 if meancod_rel==0 & meancod_keep==0
replace hadd_no_catch=1 if meancod_rel==0 & meancod_keep==0

export excel "$misc_data_cd\baseline_mrip_catch_processed.xlsx", firstrow(variables) replace
import excel using "$misc_data_cd\baseline_mrip_catch_processed.xlsx", clear first

//saving as dta for further processing
save "$misc_data_cd\baseline_mrip_catch_processed.dta", replace 


/******************************************************************************/
/******************************************************************************/
/* Part B: Survey-weighted MRIP catch totals (benchmarks for the simulation) */
/******************************************************************************/
/******************************************************************************/
* Compute MRIP estimates for comparison with simulated estimates
* Each of the three sub-blocks below re-reads and re-preps the raw MRIP data
* from scratch, differing only in the aggregation level of my_dom_id_string
* (mode; mode-month; mode-season).

/******************************************************************************/
/* Part B.1: Totals by mode */
/******************************************************************************/
di "Part B.1: MRIP catch totals by mode"

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

* ensure only relevant states/year
keep if inlist(st, 23, 33, 25)
keep if $calibration_year

gen st2 = string(st,"%02.0f")

gen mode1="sh" if inlist(mode_fx, "1", "2", "3")
replace mode1="pr" if inlist(mode_fx, "7")
replace mode1="fh" if inlist(mode_fx, "4", "5")

*drop shore trips
drop if mode1=="sh"

* classify trips into the domain we care about (caught or targeted cod or haddock) and everything else, marked "ZZ"
replace prim1_common=subinstr(lower(prim1_common)," ","",.)
replace prim2_common=subinstr(lower(prim1_common)," ","",.)

* We need to retain 1 observation for each strat_id, psu_id, and id_code
/* A.  Trip targeted or caught cod or haddock -> domain "ATLCO"
   B.  Trip did not target or catch either species -> domain "ZZ"
*/

gen common_dom="ZZ"
replace common_dom="ATLCO" if inlist(common, "atlanticcod") 
replace common_dom="ATLCO" if inlist(common, "haddock") 

replace common_dom="ATLCO"  if inlist(prim1_common, "atlanticcod") 
replace common_dom="ATLCO"  if inlist(prim1_common, "haddock") 


*MRIP-Western GoM site allocations
preserve 
import delimited using "$misc_data_cd/MRIP_COD_ALL_SITE_LIST.csv", clear 
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

merge m:1 intsite state using `mrip_sites',  keep(1 3)

/*classify into WGOM or not WGOM */
gen str3 area_s="XX"
replace area_s="WGOM" if st2=="33"
replace area_s=nmfs_stock_area if inlist(st2, "25", "23") 

tostring wave, gen(wv2)
tostring year, gen(yr2)

gen my_dom_id_string=area_s+"_"+month+"_"+mode1+"_"+common_dom

* Define the list of species to process
local species "atlanticcod haddock"

* Loop over each species
foreach s of local species {

    * Create short species prefix (e.g., cod, hadd)
    local short = substr("`s'", 1, 4)
    if "`s'" == "atlanticcod" local short "cod"
    if "`s'" == "haddock"     local short "hadd"

    * Generate species-specific totals
    gen `short'_tot_cat = tot_cat if common == "`s'"
    egen sum_`short'_tot_cat = sum(`short'_tot_cat), by(strat_id psu_id id_code)

    gen `short'_harvest = landing if common == "`s'"
    egen sum_`short'_harvest = sum(`short'_harvest), by(strat_id psu_id id_code)

    gen `short'_releases = release if common == "`s'"
    egen sum_`short'_releases = sum(`short'_releases), by(strat_id psu_id id_code)
}

rename sum_cod_tot_cat cod_cat
rename sum_cod_harvest cod_keep
rename sum_cod_releases cod_rel
rename sum_hadd_tot_cat hadd_cat
rename sum_hadd_harvest hadd_keep
rename sum_hadd_releases hadd_rel

* Set a variable "no_dup"=0 if the record is "$my_common" catch and no_dup=1 otherwise
  
gen no_dup=0
replace no_dup=1 if  strmatch(common, "atlanticcod")==0
replace no_dup=1 if strmatch(common, "haddock")==0

/*
We sort on year, strat_id, psu_id, id_code, "no_dup", and "my_dom_id_string". For records with duplicate year, strat_id, psu_id, and id_codes, the first entry will be the cod/haddock catch record if it exists (domain "ATLCO"). If there is no cod/haddock catch but the trip targeted or caught either species, the secondary sort on "my_dom_id_string" ensures the trip is properly classified.

After sorting, we generate a count variable (count_obs1 from 1....n) and we keep only the "first" observations within each "year, strat_id, psu_id, and id_codes" group.
*/

bysort year strat_id psu_id id_code (my_dom_id_string no_dup): gen count_obs1=_n

keep if count_obs1==1 // This keeps only one record for trips with catch of multiple species. We have already computed catch of the species of interest above and saved these in a trip-row

order strat_id psu_id id_code no_dup my_dom_id_string count_obs1 common


replace my_dom_id_string=mode1+"_"+area_s+"_"+common_dom

svyset psu_id [pweight= wp_int], strata(strat_id) singleunit(certainty)

drop if wp_int==0
encode my_dom_id_string, gen(my_dom_id)

preserve
keep my_dom_id my_dom_id_string
duplicates drop 
tempfile domains
save `domains', replace 
restore

tempfile basefile
save `basefile', replace 


* Create a postfile to collect results
tempfile results
postfile handle str15 varname str15 domain float total se ll95 ul95 using `results', replace

* Loop over variables
foreach var in cod_keep cod_rel cod_cat hadd_keep hadd_rel hadd_cat  {

    * Run svy mean for the variable by domain
    svy: total `var', over(my_dom_id)

    * Grab result matrix and domain labels
    matrix M = r(table)
    local colnames : colnames M

    * Loop over columns (domains)
    foreach col of local colnames {
        local m  = M[1, "`col'"]
        local se = M[2, "`col'"]
        local lb = M[5, "`col'"]
        local ub = M[6, "`col'"]

        post handle ("`var'") ("`col'") (`m') (`se') (`lb') (`ub')
    }
}

postclose handle

* Load results back into memory
use `results', clear

split domain, parse("@")
drop domain1
split domain2, parse(.)
split domain21, parse(b)

drop domain2 domain21 domain22 domain212
destring domain211, replace
rename domain211 my_dom_id
merge m:1 my_dom_id using `domains' 
sort varname  my_dom_id
keep varname total se my_dom_id_string ll95 ul95
reshape wide total se ll95 ul95, i(my_dom) j(varname) string

split my_dom, parse(_)
rename my_dom_id_string1 mode
rename my_dom_id_string2 area_s
rename my_dom_id_string3 common_dom
keep if area_s=="WGOM"
keep if common_dom=="ATLCO"

ds my_dom_id_string mode area_s common_dom, not

renvarlab `r(varlist)', postfix(_mrip)

order my_dom_id_string mode area common

save "$misc_data_cd\mrip_catch_by_mode.dta", replace 





/******************************************************************************/
/* Part B.2: Totals by mode and month */
/******************************************************************************/
di "Part B.2: MRIP catch totals by mode and month"

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

* ensure only relevant states/year
keep if inlist(st, 23, 33, 25)
keep if $calibration_year

gen st2 = string(st,"%02.0f")

gen mode1="sh" if inlist(mode_fx, "1", "2", "3")
replace mode1="pr" if inlist(mode_fx, "7")
replace mode1="fh" if inlist(mode_fx, "4", "5")

*drop shore trips
drop if mode1=="sh"

* classify trips into the domain we care about (caught or targeted cod or haddock) and everything else, marked "ZZ"
replace prim1_common=subinstr(lower(prim1_common)," ","",.)
replace prim2_common=subinstr(lower(prim1_common)," ","",.)

* We need to retain 1 observation for each strat_id, psu_id, and id_code
/* A.  Trip targeted or caught cod or haddock -> domain "ATLCO"
   B.  Trip did not target or catch either species -> domain "ZZ"
*/

gen common_dom="ZZ"
replace common_dom="ATLCO" if inlist(common, "atlanticcod")
replace common_dom="ATLCO" if inlist(common, "haddock")

replace common_dom="ATLCO"  if inlist(prim1_common, "atlanticcod")
replace common_dom="ATLCO"  if inlist(prim1_common, "haddock")



*MRIP-Western GoM site allocations
preserve
import delimited using "$misc_data_cd/MRIP_COD_ALL_SITE_LIST.csv", clear
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

merge m:1 intsite state using `mrip_sites',  keep(1 3)

/*classify into WGOM or not WGOM */
gen str3 area_s="XX"
replace area_s="WGOM" if st2=="33"
replace area_s=nmfs_stock_area if inlist(st2, "25", "23")

gen my_dom_id_string=month+"_"+mode1+"_"+area_s+"_"+common_dom

tostring wave, gen(wv2)
tostring year, gen(yr2)

* Define the list of species to process
local species "atlanticcod haddock"

* Loop over each species
foreach s of local species {

    * Create short species prefix (e.g., cod, hadd)
    local short = substr("`s'", 1, 4)
    if "`s'" == "atlanticcod" local short "cod"
    if "`s'" == "haddock"     local short "hadd"

    * Generate species-specific totals
    gen `short'_tot_cat = tot_cat if common == "`s'"
    egen sum_`short'_tot_cat = sum(`short'_tot_cat), by(strat_id psu_id id_code)

    gen `short'_harvest = landing if common == "`s'"
    egen sum_`short'_harvest = sum(`short'_harvest), by(strat_id psu_id id_code)

    gen `short'_releases = release if common == "`s'"
    egen sum_`short'_releases = sum(`short'_releases), by(strat_id psu_id id_code)
}

rename sum_cod_tot_cat cod_cat
rename sum_cod_harvest cod_keep
rename sum_cod_releases cod_rel
rename sum_hadd_tot_cat hadd_cat
rename sum_hadd_harvest hadd_keep
rename sum_hadd_releases hadd_rel

* Set a variable "no_dup"=0 if the record is "$my_common" catch and no_dup=1 otherwise
  
gen no_dup=0
replace no_dup=1 if  strmatch(common, "atlanticcod")==0
replace no_dup=1 if strmatch(common, "haddock")==0

/*
We sort on year, strat_id, psu_id, id_code, "no_dup", and "my_dom_id_string". For records with duplicate year, strat_id, psu_id, and id_codes, the first entry will be the cod/haddock catch record if it exists (domain "ATLCO"). If there is no cod/haddock catch but the trip targeted or caught either species, the secondary sort on "my_dom_id_string" ensures the trip is properly classified.

After sorting, we generate a count variable (count_obs1 from 1....n) and we keep only the "first" observations within each "year, strat_id, psu_id, and id_codes" group.
*/

bysort year strat_id psu_id id_code (my_dom_id_string no_dup): gen count_obs1=_n

keep if count_obs1==1 // This keeps only one record for trips with catch of multiple species. We have already computed catch of the species of interest above and saved these in a trip-row

order strat_id psu_id id_code no_dup my_dom_id_string count_obs1 common


svyset psu_id [pweight= wp_int], strata(strat_id) singleunit(certainty)

drop if wp_int==0
encode my_dom_id_string, gen(my_dom_id)

preserve
keep my_dom_id my_dom_id_string
duplicates drop 
tempfile domains
save `domains', replace 
restore

tempfile basefile
save `basefile', replace 


* Create a postfile to collect results
tempfile results
postfile handle str15 varname str15 domain float total se ll95 ul95 using `results', replace

* Loop over variables
foreach var in cod_keep cod_rel cod_cat hadd_keep hadd_rel hadd_cat  {

    * Run svy mean for the variable by domain
    svy: total `var', over(my_dom_id)

    * Grab result matrix and domain labels
    matrix M = r(table)
    local colnames : colnames M

    * Loop over columns (domains)
    foreach col of local colnames {
        local m  = M[1, "`col'"]
        local se = M[2, "`col'"]
        local lb = M[5, "`col'"]
        local ub = M[6, "`col'"]

        post handle ("`var'") ("`col'") (`m') (`se') (`lb') (`ub')
    }
}

postclose handle

* Load results back into memory
use `results', clear

split domain, parse("@")
drop domain1
split domain2, parse(.)
split domain21, parse(b)

drop domain2 domain21 domain22 domain212
destring domain211, replace
rename domain211 my_dom_id
merge m:1 my_dom_id using `domains' 
sort varname  my_dom_id
keep varname total se my_dom_id_string ll95 ul95
reshape wide total se ll95 ul95, i(my_dom) j(varname) string

split my_dom, parse(_)
rename my_dom_id_string1 month 
rename my_dom_id_string2 mode 
rename my_dom_id_string3 area_s
rename my_dom_id_string4 common_dom
keep if area_s=="WGOM"
keep if common_dom=="ATLCO"

ds my_dom_id_string month mode area_s common_dom, not
renvarlab `r(varlist)', postfix(_mrip)

order my_dom_id_string month mode  area_s common_dom

save "$misc_data_cd\mrip_catch_by_mode_month.dta", replace 


/******************************************************************************/
/* Part B.3: Totals by mode and season (winter = Sep-Apr, summer = May-Aug) */
/******************************************************************************/
di "Part B.3: MRIP catch totals by mode and season"

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

* ensure only relevant states/year
keep if inlist(st, 23, 33, 25)
keep if $calibration_year
 
gen st2 = string(st,"%02.0f")

gen mode1="sh" if inlist(mode_fx, "1", "2", "3")
replace mode1="pr" if inlist(mode_fx, "7")
replace mode1="fh" if inlist(mode_fx, "4", "5")

*drop shore trips
drop if mode1=="sh"

* classify trips into the domain we care about (caught or targeted cod or haddock) and everything else, marked "ZZ"
replace prim1_common=subinstr(lower(prim1_common)," ","",.)
replace prim2_common=subinstr(lower(prim1_common)," ","",.)

* We need to retain 1 observation for each strat_id, psu_id, and id_code
/* A.  Trip targeted or caught cod or haddock -> domain "ATLCO"
   B.  Trip did not target or catch either species -> domain "ZZ"
*/

gen common_dom="ZZ"
replace common_dom="ATLCO" if inlist(common, "atlanticcod") 
replace common_dom="ATLCO" if inlist(common, "haddock") 

replace common_dom="ATLCO"  if inlist(prim1_common, "atlanticcod") 
replace common_dom="ATLCO"  if inlist(prim1_common, "haddock") 



*MRIP-Western GoM site allocations
preserve 
import delimited using "$misc_data_cd/MRIP_COD_ALL_SITE_LIST.csv", clear 
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

merge m:1 intsite state using `mrip_sites',  keep(1 3)

/*classify into WGOM or not WGOM */
gen str3 area_s="XX"
replace area_s="WGOM" if st2=="33"
replace area_s=nmfs_stock_area if inlist(st2, "25", "23") 

gen season= "winter" if inlist(month, "09", "10", "11", "12", "01", "02", "03", "04")
replace season="summer" if inlist(month, "05", "06", "07", "08")

gen my_dom_id_string=season+"_"+mode1+"_"+area_s+"_"+common_dom

tostring wave, gen(wv2)
tostring year, gen(yr2)

* Define the list of species to process
local species "atlanticcod haddock"

* Loop over each species
foreach s of local species {

    * Create short species prefix (e.g., cod, hadd)
    local short = substr("`s'", 1, 4)
    if "`s'" == "atlanticcod" local short "cod"
    if "`s'" == "haddock"     local short "hadd"

    * Generate species-specific totals
    gen `short'_tot_cat = tot_cat if common == "`s'"
    egen sum_`short'_tot_cat = sum(`short'_tot_cat), by(strat_id psu_id id_code)

    gen `short'_harvest = landing if common == "`s'"
    egen sum_`short'_harvest = sum(`short'_harvest), by(strat_id psu_id id_code)

    gen `short'_releases = release if common == "`s'"
    egen sum_`short'_releases = sum(`short'_releases), by(strat_id psu_id id_code)
}

rename sum_cod_tot_cat cod_cat
rename sum_cod_harvest cod_keep
rename sum_cod_releases cod_rel
rename sum_hadd_tot_cat hadd_cat
rename sum_hadd_harvest hadd_keep
rename sum_hadd_releases hadd_rel

* Set a variable "no_dup"=0 if the record is "$my_common" catch and no_dup=1 otherwise
  
gen no_dup=0
replace no_dup=1 if  strmatch(common, "atlanticcod")==0
replace no_dup=1 if strmatch(common, "haddock")==0

/*
We sort on year, strat_id, psu_id, id_code, "no_dup", and "my_dom_id_string". For records with duplicate year, strat_id, psu_id, and id_codes, the first entry will be the cod/haddock catch record if it exists (domain "ATLCO"). If there is no cod/haddock catch but the trip targeted or caught either species, the secondary sort on "my_dom_id_string" ensures the trip is properly classified.

After sorting, we generate a count variable (count_obs1 from 1....n) and we keep only the "first" observations within each "year, strat_id, psu_id, and id_codes" group.
*/

bysort year strat_id psu_id id_code (my_dom_id_string no_dup): gen count_obs1=_n

keep if count_obs1==1 // This keeps only one record for trips with catch of multiple species. We have already computed catch of the species of interest above and saved these in a trip-row

order strat_id psu_id id_code no_dup my_dom_id_string count_obs1 common



svyset psu_id [pweight= wp_int], strata(strat_id) singleunit(certainty)

drop if wp_int==0
encode my_dom_id_string, gen(my_dom_id)

preserve
keep my_dom_id my_dom_id_string
duplicates drop 
tempfile domains
save `domains', replace 
restore

tempfile basefile
save `basefile', replace 


* Create a postfile to collect results
tempfile results
postfile handle str15 varname str15 domain float total se ll95 ul95 using `results', replace

* Loop over variables
foreach var in cod_keep cod_rel cod_cat hadd_keep hadd_rel hadd_cat  {

    * Run svy mean for the variable by domain
    svy: total `var', over(my_dom_id)

    * Grab result matrix and domain labels
    matrix M = r(table)
    local colnames : colnames M

    * Loop over columns (domains)
    foreach col of local colnames {
        local m  = M[1, "`col'"]
        local se = M[2, "`col'"]
        local lb = M[5, "`col'"]
        local ub = M[6, "`col'"]

        post handle ("`var'") ("`col'") (`m') (`se') (`lb') (`ub')
    }
}

postclose handle

* Load results back into memory
use `results', clear

split domain, parse("@")
drop domain1
split domain2, parse(.)
split domain21, parse(b)

drop domain2 domain21 domain22 domain212
destring domain211, replace
rename domain211 my_dom_id
merge m:1 my_dom_id using `domains' 
sort varname  my_dom_id
keep varname total se my_dom_id_string ll95 ul95
reshape wide total se ll95 ul95, i(my_dom) j(varname) string

split my_dom, parse(_)
rename my_dom_id_string1 season
rename  my_dom_id_string2 mode
rename  my_dom_id_string3 area_s
rename  my_dom_id_string4 common_dom

keep if common_dom=="ATLCO"
keep if area_s=="WGOM"

order my_dom_id_string season mode  area_s common_dom


ds my_dom_id_string season mode  area_s common_dom, not
renvarlab `r(varlist)', postfix(_mrip)



save "$misc_data_cd\mrip_catch_by_mode_season.dta", replace 


