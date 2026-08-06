/*******************************************************************************
 Script:       baseline_and_projected_NAL.do
 Purpose:      Builds age-length keys (ALKs) from NEFSC trawl survey data and
               applies them to stock-assessment numbers-at-age (NAA) to produce
               numbers-at-length (NAL) proportions for WGOM cod and GOM haddock,
               for the baseline year (2025) and the projection year (2026). Ends
               by plotting the 5 cm-binned length distributions and reporting the
               proportion of fish at or above the legal minimum size.
 Inputs:       $input_data_cd/{NEFSC_cruises.csv, NEFSC_trawl_cod.csv,
               NEFSC_trawl_hadd.csv}; $input_data_cd/{WGOM_Cod,GOM_Haddock}_
               {historical,projected}_NAA*.dta.
 Outputs:      Diagnostic twoway plots. The graph-export and comparison blocks are
               commented out, so nothing is persisted (temp files only); the
               commented exports would write to $figure_cd if re-enabled.
 Dependencies: Globals $input_data_cd, $ndraws (and $figure_cd for the
               commented-out figure exports).
 Pipeline:     Standalone / unwrapped — no confirmed caller (per
               DATAFLOW_GROUNDFISH.md); looks like a verification/exploration script.
*******************************************************************************/

/******************************************************************************/
/******************************************************************************/
/* Section A: Cod age-length key from NEFSC trawl survey */
/******************************************************************************/
/******************************************************************************/

display "Building cod age-length key from NEFSC trawl survey ..."

*b1)
import delimited using "$input_data_cd/NEFSC_cruises.csv", clear
renvarlab, lower
tempfile cruises
sort year
save `cruises', replace

import delimited using "$input_data_cd/NEFSC_trawl_cod.csv", clear
renvarlab, lower
rename count count 
merge m:1 cruise6 using `cruises'
collapse (sum) count, by(year season svspp age length)
tostring year, gen(year2)
gen yr_season=year2+"_"+season
tab yr_season if year>2020
keep if year>2022
collapse (sum) count, by(year age length)

su year
local min_svy_yr=`r(min)'
local max_svy_yr=`r(max)'
di `min_svy_yr'
tabstat count, stat(sum) by(age)
* Top-code age into a 6+ plus-group (all fish age 6 and older pooled).
replace age=6 if age>=6
collapse (sum) count, by (age length)
drop if age==. | length==.

* Fill the full age x length grid so every length has a row within each age;
* mvencode then sets the newly-created (missing) counts to 0.
tsset age length
tsfill, full

sort age length
mvencode count, mv(0) override

*b2)
* LOWESS-smooth the length distribution separately within each age (bwidth = 0.3
* is the fraction of points used in each local fit); clamp negatives to 0.
levelsof age, local(ages)
foreach a of local ages{
	lowess count length if age==`a' , adjust bwidth(.3) gen(s`a') nograph
	replace s`a'=0 if s`a'<=0
}

egen smoothed=rowtotal(s0-s6)
drop s0-s6

egen sum=sum(smoothed), by(age)	
gen prop_smoothed=smoothed/sum	

*b3) 
egen sum_raw=sum(count), by(age)	
gen prop_raw=count/sum_raw	

/*
levelsof age, local(ages)
foreach a of local ages{
twoway(scatter prop_raw length if age==`a',   connect(direct) lcol(red)   lpat(solid) msymbol(i) ) ///
			(scatter prop_smoothed length if age==`a', connect(direct) lcol(blue) title("cod age `a' NEFSC trawl `min_svy_yr'-`max_svy_yr'", size(small)) ///
			ytitle("proportion of fish that are age-a", size(small)) ytick(, angle(horizontal) labsize(small)) xtitle(length cms, size(small)) xlab(, labsize(small)) ///
			ylab(, labsize(small) angle(horizontal)) xtick(, labsize(small)) lpat(solid) msymbol(i)  name(dom`a', replace))
 local graphnames `graphnames' dom`a'
}

grc1leg `graphnames' 
graph export "$figure_cd/cod_prop_length_at_age.png", as(png) replace
*/

drop if age==0
drop sum sum_raw
tempfile al_cod
save `al_cod', replace 


/******************************************************************************/
/******************************************************************************/
/* Section B: Haddock age-length key from NEFSC trawl survey */
/******************************************************************************/
/******************************************************************************/

display "Building haddock age-length key from NEFSC trawl survey ..."

* Haddock ALK - age 1 through 9 (mirrors the cod ALK above; top-coded at age 9+)
*b1)
import delimited using "$input_data_cd/NEFSC_cruises.csv", clear
renvarlab, lower
tempfile cruises
sort year 
save `cruises', replace 

import delimited using "$input_data_cd/NEFSC_trawl_hadd.csv", clear 
renvarlab, lower
rename count count 
merge m:1 cruise6 using `cruises'
collapse (sum) count, by(year season svspp age length)
tostring year, gen(year2)
gen yr_season=year2+"_"+season
tab yr_season if year>2020
keep if year>2022
collapse (sum) count, by(year age length)

su year
local min_svy_yr=`r(min)'
local max_svy_yr=`r(max)'
di `min_svy_yr'
tabstat count, stat(sum) by(age)
replace age=9 if age>=9
collapse (sum) count, by (age length)
drop if age==. | length==.

tsset age length
tsfill, full

sort age length 
mvencode count, mv(0) override 

*b2) 
levelsof age, local(ages)
foreach a of local ages{
	lowess count length if age==`a' , adjust bwidth(.3) gen(s`a') nograph
	replace s`a'=0 if s`a'<=0
}

egen smoothed=rowtotal(s0-s9)
drop s0-s9

*b3) 
egen sum=sum(smoothed), by(age)	
gen prop_smoothed=smoothed/sum	

egen sum_raw=sum(count), by(age)	
gen prop_raw=count/sum_raw	

/*
levelsof age, local(ages)
foreach a of local ages{
twoway(scatter prop_raw length if age==`a',   connect(direct) lcol(red)   lpat(solid) msymbol(i) ) ///
			(scatter prop_smoothed length if age==`a', connect(direct) lcol(blue) title("haddock age `a' NEFSC trawl `min_svy_yr'-`max_svy_yr'", size(small)) ///
			ytitle("proportion of fish that are age-a", size(small)) ytick(, angle(horizontal) labsize(small)) xtitle(length cms, size(small)) xlab(, labsize(small)) ///
			ylab(, labsize(small) angle(horizontal)) xtick(, labsize(small)) lpat(solid) msymbol(i)  name(dom`a', replace))
 local graphnames `graphnames' dom`a'
}

grc1leg `graphnames' 
graph export "$figure_cd/hadd_prop_length_at_age.png", as(png) replace
*/

drop if age==0
drop sum sum_raw
tempfile al_hadd
save `al_hadd', replace 


/******************************************************************************/
/******************************************************************************/
/* Section C: Baseline (2025) numbers-at-length from historical NAA */
/******************************************************************************/
/******************************************************************************/

*C) compute rec selectivity
	* c1) pull in historical NAA
	* c2) translate ages to lengths using the age-length keys
	* c3) merge numbers-at-length to catch-at-length
	* c4) apply adjustment code when catch-at-length is greater than numbers-at-length
	* c5) compute rec selectivity ql=CAL/NAL

* c1) cod
use "$input_data_cd/WGOM_Cod_historical_NAA_from_2024Assessment.dta", clear

egen age6_plus=rowtotal(age6-age9)
drop age6 age7 age8 age9
rename age6_plus age6
keep if year==2025
reshape long age, i(year) j(new)
rename age nfish
rename new age 
drop year 

* c2) cod
merge 1:m age using `al_cod', keep(3) nogen 
sort  age length

gen NaL_from_raw_trawl = prop_raw*nfish
gen NaL_from_smooth_trawl = prop_smoothed*nfish

drop count  prop* nfish smoothed
collapse (sum) NaL*, by(length)

sort length 
gen species="cod"
tempfile naa_cod
save `naa_cod', replace 

* c1) haddock 
use "$input_data_cd/GOM_Haddock_historical_NAA_2024Assessment.dta", clear 

keep if year==2025
reshape long age, i(year) j(new)
rename age nfish
rename new age 
drop year 

* c2) haddock
merge 1:m age using `al_hadd', keep(3) nogen 
sort  age length

gen NaL_from_raw_trawl = prop_raw*nfish
gen NaL_from_smooth_trawl = prop_smoothed*nfish

drop count  prop* nfish smoothed
collapse (sum) NaL*, by(length)

sort length 

gen species="hadd"

append using  `naa_cod'
* Rescale NAL by 1000 (assessment NAA are reported in thousands of fish); the
* same rescale is applied to the projected data in Section D.
replace NaL_from_raw_trawl=NaL_from_raw_trawl*1000
replace NaL_from_smooth_trawl=NaL_from_smooth_trawl*1000

gen year=2025
tempfile nal2025
save `nal2025'



/******************************************************************************/
/******************************************************************************/
/* Section D: Projected (2026) numbers-at-length from projected NAA */
/******************************************************************************/
/******************************************************************************/

display "Building projected (2026) numbers-at-length for $ndraws draws ..."

*projected - 2026
use "$input_data_cd/WGOM_Cod_projected_NAA_from_2024Assessment.dta", clear

egen age6_plus=rowtotal(age6-age9)
drop age6 age7 age8 age9
rename age6_plus age6
* Draw $ndraws random replicates from the projected-NAA replicate distribution.
sample $ndraws, count
gen draw=_n
reshape long age, i(year draw replicate) j(new)
rename age nfish
rename new age 
drop year 
rename replicate cod_replicate

* e2) cod
preserve 
u `al_cod', clear 
expand $ndraws
bysort length age: gen draw=_n
tempfile al_cod_expand
save `al_cod_expand', replace
restore 

merge 1:m age draw using `al_cod_expand', keep(3) nogen 
sort  age length

gen NaL_from_raw_trawl = prop_raw*nfish
gen NaL_from_smooth_trawl = prop_smoothed*nfish

drop count  prop* nfish smoothed
collapse (sum) NaL*, by(length draw cod_replicate)

sort length 
gen species="cod"

tempfile proj_naa_cod
save `proj_naa_cod', replace 

* e1) haddock 
use "$input_data_cd/GOM_Haddock_projected_NAA_2024Assessment.dta", clear 

sample $ndraws, count 
gen draw=_n
reshape long age, i(year draw replicate) j(new)
rename age nfish
rename new age 
drop year 
rename replicate hadd_replicate

preserve 
u `al_hadd', clear 
expand $ndraws
bysort length age: gen draw=_n
tempfile al_hadd_expand
save `al_hadd_expand', replace
restore 

* c2) haddock
merge 1:m age draw using `al_hadd_expand', keep(3) nogen 
sort  age length

gen NaL_from_raw_trawl = prop_raw*nfish
gen NaL_from_smooth_trawl = prop_smoothed*nfish

drop count  prop* nfish smoothed
collapse (sum) NaL*, by( length draw hadd_replicate)

sort length 
gen species="hadd"


append using  `proj_naa_cod' 

replace NaL_from_raw_trawl=NaL_from_raw_trawl*1000
replace NaL_from_smooth_trawl=NaL_from_smooth_trawl*1000
gen year =2026

append using `nal2025'


/******************************************************************************/
/******************************************************************************/
/* Section E: 5 cm-bin proportions, legal-size shares, and plots */
/******************************************************************************/
/******************************************************************************/

*haddock 18 inch = 45.72
*cod 23 inch = 58.42
egen sum= sum(NaL_from_smooth_trawl), by(year  species draw )
gen prop=NaL_from_smooth_trawl/sum
sort year  species draw length

gen cod_legal=1 if species=="cod" & length>=58.42
gen hadd_legal=1 if species=="hadd" & length>=45.72

egen sumproplegal_cod=sum(prop), by(year  species draw cod_legal)
egen sumproplegal_hadd=sum(prop), by(year  species draw hadd_legal)

su sumproplegal_cod if year==2025 & species=="cod" & length>=58.42
return list
local cod2025=round(`r(mean)', .01)

su sumproplegal_cod if year==2026 & species=="cod" & length>=58.42
return list
local cod2026=round(`r(mean)', .01)

su sumproplegal_hadd if year==2025 & species=="hadd" & length>=45.72
return list
local hadd2025=round(`r(mean)', .01)

su sumproplegal_hadd if year==2026 & species=="hadd" & length>=45.72
return list
local hadd2026=round(`r(mean)', .01)

gen length5_lo = floor(length/5)*5
gen length5_hi = length5_lo + 4

* String label: "20-24", "25-29", etc.
gen str20 length5_bin = string(length5_lo) + "-" + string(length5_hi)
label var length5_bin "Length bin (cm)"
replace length5_bin="05-9" if length5_bin=="5-9"

collapse (sum)  NaL_from_smooth_trawl, by(year  species draw length5_bin)
egen sum_nal=sum(NaL_from_smooth_trawl), by(year species draw)
gen prop_nal=NaL_from_smooth_trawl/sum
drop NaL_from_smooth_trawl sum
reshape wide  prop_nal, i(species  draw length ) j(year)
	
collapse (mean)	 prop*, by(species length)
encode len, gen(length2)

twoway(scatter prop_nal2025 length2 if species =="cod", connect(direct)) (scatter prop_nal2026 length2 if species =="cod", connect(direct) ///
    title("cod proportions number at length (cm)", size(medium)) ///
	xlabel(#10, valuelabel labsize(small)) ///
	xtitle("") ///
	ytitle(Proportion of fish that are length-{it:l}) ///
    ylab(#10, labsize(small)) ////
    legend(order(1 "2025" 2 "2026") position(3) cols(1)) ///
	caption("Proportion of cod at or above 23 inches:  `cod2025' (2025), `cod2026' (2026)", size(small) yoffset(-3)))

twoway(scatter prop_nal2025 length2 if species =="hadd", connect(direct)) (scatter prop_nal2026 length2 if species =="hadd", connect(direct) ///
    title("haddock proportions number at length (cm)", size(medium)) ///
	xlabel(#10, valuelabel labsize(small)) ///
	xtitle("") ///
	ytitle(Proportion of fish that are length-{it:l}) ///
    ylab(#10, labsize(small)) ////
    legend(order(1 "2025" 2 "2026") position(3) cols(1)) ///
	caption("Proportion of haddock at or above 18 inches:  `hadd2025' (2025), `hadd2026' (2026)", size(small) yoffset(-3)))
