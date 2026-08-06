/******************************************************************************/
/*****************************************************************************
 Script:  catch_at_length_projection.do                                     
                                                                            
 Purpose: Produces the projection-year catch-at-length probability          
          distribution for WGOM cod and GOM haddock. The idea is to hold    
          recreational selectivity at length fixed at what was observed in  
          the calibration year, and let the length composition of the catch 
          change only because the projected stock has a different age (and  
          therefore length) composition.                                    
                                                                            
 Method (the numbered sections below follow these steps):                   
   1. Read baseline recreational catch-at-length.                           
   2. Build cod and haddock age-length keys (ALKs) from recent NEFSC trawl  
      data: pull the survey data, smooth counts across lengths within each  
      age with a LOWESS (bandwidth 0.3), then compute the proportion of     
      fish of age a that are length l.                                      
   3. Convert baseline stock assessment numbers-at-age (NAA) into baseline  
      numbers-at-length (NAL).                                              
   4. Merge baseline NAL to observed baseline catch-at-length and compute   
      an empirical recreational selectivity ("fraction caught") at length   
      by species, season, draw and length.                                  
   5. Convert projected NAA into projected NAL using the same ALKs.         
   6. Apply baseline selectivity-at-length to projected NAL to obtain       
      projected catch-at-length.                                            
   7. Smooth projected catch-at-length into a probability distribution by   
      fitting a gamma to each species-season-draw.                          
   8. Export projected fitted probabilities by draw/species/season/length.  
                                                                            
 Inputs:  $misc_data_cd/baseline_catch_at_length_observed.csv               
          $misc_data_cd/baseline_catch_at_length.csv                        
          $misc_data_cd/NEFSC_cruises.csv                                   
          $misc_data_cd/NEFSC_trawl_cod.csv, NEFSC_trawl_hadd.csv           
          $misc_data_cd/WGOM_Cod_historical_NAA.dta,                        
                       WGOM_Cod_projected_NAA.dta                           
          $misc_data_cd/GOM_Haddock_historical_NAA.dta,                     
                       GOM_Haddock_projected_NAA.dta                        
                                                                            
 Outputs: $misc_data_cd/projected_catch_at_length.csv                       
                                                                            
 Dependencies: catch_at_length_calibration.do (writes both baseline CSVs)   
          and the assessment scripts get_cod_assessment_data.R /            
          get_haddock_assessment_data.R (write the NAA files). Expects      
          $seed, $ndraws, $misc_data_cd, $trawl_survey_start_year,          
          $cod_NAA_base_year, $hadd_NAA_base_year, $cod_NAA_proj_year and   
          $hadd_NAA_proj_year to be set by model_wrapper.do.                
                                                                            
 Pipeline: Pre-simulation, immediately after catch_at_length_calibration.do 
          The exported CSV is what the R simulation reads to decide the     
          size composition of projection-year catch.                        
                                                                            
 Note 1:  Two renames in this file (see Sections 3 and 5) rely on Stata's   
          variable-name abbreviation rather than being no-ops; they are     
          annotated where they occur.    */
/******************************************************************************/
/******************************************************************************/

/******************************************************************************/
/******************************************************************************/
/* Section 1: Pull in baseline catch-at-lengths                               */
/******************************************************************************/
/******************************************************************************/

set seed $seed

import delimited using "$misc_data_cd/baseline_catch_at_length_observed.csv", clear  
keep if draw<= $ndraws
sort draw season species length

tempfile cal
save `cal', replace 


/******************************************************************************/
/******************************************************************************/
/* Section 2: Age-length keys from NEFSC trawl survey data                    */
/******************************************************************************/
/******************************************************************************/

	/* a. Pull in NEFSC trawl survey data from $trawl_survey_start_year on
	   b. Smooth counts across lengths within each age using LOWESS, bandwidth 0.3
	   c. Compute the proportion of fish of age a that are length l           */

di "catch_at_length_projection: building cod and haddock age-length keys ..."

/* Cod ALK - ages 1 through 6+. There are few observations at age 7+, so those
   ages are pooled into a 6+ plus-group. */

*2a
import delimited using "$misc_data_cd/NEFSC_cruises.csv", clear
renvarlab, lower
tempfile cruises
sort year 
save `cruises', replace 

import delimited using "$misc_data_cd/NEFSC_trawl_cod.csv", clear 
renvarlab, lower
rename countage count 
merge m:1 cruise6 using `cruises'
collapse (sum) count, by(year season svspp age length)
keep if year>=$trawl_survey_start_year
collapse (sum) count, by(year age length)

su year
local min_svy_yr=`r(min)'
local max_svy_yr=`r(max)'
di `min_svy_yr'
tabstat count, stat(sum) by(age)
replace age=6 if age>=6
collapse (sum) count, by (age length)
drop if age==. | length==.

/* Treat age as the panel and length as the time index so tsfill inserts the
   length bins with no sampled fish; mvencode then makes those counts zero, so
   every age spans the same contiguous length range before smoothing. */
tsset age length
tsfill, full

sort age length 
mvencode count, mv(0) override 

/* 2b. lowess writes its smoothed values into a separate variable per age, and
   each of those is missing outside that age's rows; the rowtotal below folds
   them back into one column. Negative smoothed counts are truncated at zero. */
levelsof age, local(ages)
foreach a of local ages{
	lowess count length if age==`a' , adjust bwidth(.3) gen(s`a') nograph
	replace s`a'=0 if s`a'<=0
}

egen smoothed=rowtotal(s0-s6)
drop s0-s6

egen sum=sum(smoothed), by(age)	
gen prop_smoothed=smoothed/sum	

*2c.
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


/* Haddock ALK - ages 1 through 9, with a 9+ plus-group */
*2a.
import delimited using "$misc_data_cd/NEFSC_cruises.csv", clear 
renvarlab, lower
tempfile cruises
sort year 
save `cruises', replace 

import delimited using "$misc_data_cd/NEFSC_trawl_hadd.csv", clear 
renvarlab, lower
merge m:1 cruise6 using `cruises'
collapse (sum) count, by(year season svspp age length)
keep if year>=$trawl_survey_start_year
collapse (sum) count, by(year age length)

su year
local min_svy_yr=`r(min)'
local max_svy_yr=`r(max)'
di `min_svy_yr'
tabstat count, stat(sum) by(age)
replace age=9 if age>=9
collapse (sum) count, by (age length)
drop if age==. | length==.

/* Treat age as the panel and length as the time index so tsfill inserts the
   length bins with no sampled fish; mvencode then makes those counts zero, so
   every age spans the same contiguous length range before smoothing. */
tsset age length
tsfill, full

sort age length 
mvencode count, mv(0) override 

/* 2b. lowess writes its smoothed values into a separate variable per age, and
   each of those is missing outside that age's rows; the rowtotal below folds
   them back into one column. Negative smoothed counts are truncated at zero. */
levelsof age, local(ages)
foreach a of local ages{
	lowess count length if age==`a' , adjust bwidth(.3) gen(s`a') nograph
	replace s`a'=0 if s`a'<=0
}

egen smoothed=rowtotal(s0-s9)
drop s0-s9

*2c.
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
/* Section 3: Baseline numbers-at-age -> baseline numbers-at-length           */
/******************************************************************************/
/******************************************************************************/

* cod
use "$misc_data_cd/WGOM_Cod_historical_NAA.dta", clear
keep if year==$cod_NAA_base_year
split metric, parse(" ")
rename metric6 age
keep age value year
destring age, replace
reshape wide value, i(year) j(age)

/* Collapse ages 6-9 into the 6+ plus-group used by the cod ALK. The rename
   is not a no-op: value6 has just been dropped, so "value6" abbreviates
   uniquely to value6_plus, which is renamed back to value6 so the subsequent
   reshape produces age==6. */
egen value6_plus=rowtotal(value6-value9)
drop value6 value7 value8 value9
rename value6 value6
reshape long value, i(year) j(new)
/* Assessment NAA are reported in thousands of fish */
replace value=value*1000
rename value nfish
rename new age 
drop year 

merge 1:m age using `al_cod', keep(3) nogen 
sort  age length

gen base_nal_raw = prop_raw*nfish
gen base_nal_smooth = prop_smoothed*nfish

drop count  prop* nfish smoothed
collapse (sum) base_nal*, by(length)

sort length 
gen species="cod"
/* NAA are annual, so the same numbers-at-length are copied to both seasons.
   Seasonal differences in catch composition therefore come entirely from the
   season-specific selectivity estimated in Section 4. The same expand is
   repeated for haddock and for both projected series below. */
expand 2, gen(dup)
gen season="winter" if dup==0
replace season="summer" if dup==1
drop dup

tempfile naa_cod
save `naa_cod', replace 

* haddock 
use "$misc_data_cd/GOM_Haddock_historical_NAA.dta", clear 
keep if year==$hadd_NAA_base_year
split metric, parse(" ")
rename metric6 age
keep age value 
replace value=value*1000
rename value nfish
destring age, replace

merge 1:m age using `al_hadd', keep(3) nogen 
sort  age length

gen base_nal_raw = prop_raw*nfish
gen base_nal_smooth = prop_smoothed*nfish

drop count  prop* nfish smoothed
collapse (sum) base_nal*, by(length)

sort length 
gen species="hadd"
expand 2, gen(dup)
gen season="winter" if dup==0
replace season="summer" if dup==1
drop dup

append using  `naa_cod'

tempfile base_naa
save `base_naa', replace 

/******************************************************************************/
/******************************************************************************/
/* Section 4: Empirical selectivity at length (fraction of the population     */
/*            at each length that the recreational fishery caught)            */
/******************************************************************************/
/******************************************************************************/

merge 1:m species season length using `cal', keep(2 3)
drop if draw==.

rename n_fish catch
mvencode catch base_nal* , mv(0) override
sort species season  draw length

gen frac_caught_smooth = catch / base_nal_smooth if base_nal_smooth > 0
gen frac_caught_raw    = catch / base_nal_raw    if base_nal_raw > 0

sort species season  draw length
drop if catch==0
mvencode frac_caught*, mv(0) override

/* catch_l > population_l adjustment.
   MRIP occasionally reports caught fish at lengths where the assessment-derived
   population is exactly zero, which would make the fraction caught undefined.
   This block moves any such catch to the nearest length inside the population's
   support, so it is retained rather than dropped.
   It does not address cases where catch > base_nal_smooth at lengths where the
   population is nonzero but small, which produce frac_caught_smooth > 1. That
   is acceptable because "fraction caught" is only used as a scaling factor. */

egen min_length_pop=min(length) if base_nal_smooth!=0, by(species season draw)
egen max_length_pop=max(length) if base_nal_smooth!=0, by(species season draw)

egen min_length_catch=min(length) if catch!=0, by(species season draw)
egen max_length_catch=max(length) if catch!=0, by(species season draw)

/* The egens above are defined only on the rows satisfying their if-condition;
   this loop broadcasts each one to every row of its species-season-draw group.
   Note the list names max_length_pop twice and the *_catch bounds are never
   used below; both are harmless, and left as-is. */
local vars min_length_pop max_length_pop min_length_catch max_length_pop max_length_catch
foreach v of local vars{
	egen mean_`v'=mean(`v'), by(species season draw)
	replace `v'= mean_`v'
	drop mean_`v'
	
}

replace length=max_length_pop if catch>0 & base_nal_smooth==0 & length>max_length_pop
replace length=min_length_pop if catch>0 & base_nal_smooth==0 & length<min_length_pop

collapse (sum) catch base_nal*,  by(species season  draw length )
drop if catch==0

gen frac_caught_smooth = catch / base_nal_smooth if base_nal_smooth > 0
gen frac_caught_raw    = catch / base_nal_raw    if base_nal_raw > 0

sort species season draw length

mvencode frac_caught*, mv(0) override

tempfile selectivity
save `selectivity', replace


/******************************************************************************/
/******************************************************************************/
/* Section 5: Projected numbers-at-age -> projected numbers-at-length         */
/******************************************************************************/
/******************************************************************************/

di "catch_at_length_projection: converting projected NAA to numbers-at-length ..."

* cod
use "$misc_data_cd/WGOM_Cod_projected_NAA.dta", clear
keep if year==$cod_NAA_proj_year

split metric, parse(" ")
rename metric5 age
keep age value year replicate
destring age, replace
reshape wide value, i(year replicate) j(age)
/* The assessment projection supplies many stochastic replicates; take a random
   $ndraws of them and treat each as one model draw. This is how assessment
   uncertainty propagates into the recreational model. */
sample $ndraws, count
gen draw=_n
egen value6_plus=rowtotal(value6-value9)
drop value6 value7 value8 value9
rename value6 value6
reshape long value, i(year replicate draw) j(new)
replace value=value*1000
rename value nfish
rename new age 

*check to validate  - increase the proportion of large fish 
*replace nfish=nfish*20 if age>=6

drop year 
sort draw age
rename replicate cod_replicate

preserve 
u `al_cod', clear 
/* One ALK is estimated for all draws, so replicate it across draws to make the
   merge to the per-draw projected NAA a clean 1:m. */
expand $ndraws
bysort length age: gen draw=_n
tempfile al_cod_expand
save `al_cod_expand', replace
restore 

merge 1:m age draw using `al_cod_expand', keep(3) nogen 
sort  draw age length

gen proj_nal_raw = prop_raw*nfish
gen proj_nal_smooth = prop_smoothed*nfish

drop count  prop* nfish smoothed
collapse (sum) proj_nal*, by(length draw cod_replicate)

sort length 
gen species="cod"
expand 2, gen(dup)
gen season="winter" if dup==0
replace season="summer" if dup==1
drop dup

tempfile proj_naa_cod
save `proj_naa_cod', replace 

* haddock 
use "$misc_data_cd/GOM_Haddock_projected_NAA.dta", clear 

keep if year==$hadd_NAA_proj_year
split metric, parse(" ")
rename metric5 age
keep age value replicate
replace value=value*1000
rename value nfish
destring age, replace

*check to validate  - increase the proportion of large fish 
*replace nfish=nfish*20 if age>=6

reshape wide nfish, i( replicate) j(age)
/* The assessment projection supplies many stochastic replicates; take a random
   $ndraws of them and treat each as one model draw. This is how assessment
   uncertainty propagates into the recreational model. */
sample $ndraws, count
gen draw=_n
reshape long nfish, i( draw replicate) j(new)
rename new age 
rename replicate hadd_replicate

preserve 
u `al_hadd', clear 
/* One ALK is estimated for all draws, so replicate it across draws to make the
   merge to the per-draw projected NAA a clean 1:m. */
expand $ndraws
bysort length age: gen draw=_n
tempfile al_hadd_expand
save `al_hadd_expand', replace
restore 

merge 1:m age draw using `al_hadd_expand', keep(3) nogen 
sort  draw age length

gen proj_nal_raw = prop_raw*nfish
gen proj_nal_smooth = prop_smoothed*nfish

collapse (sum) proj_nal*, by( length draw hadd_replicate)

sort length 
gen species="hadd"
expand 2, gen(dup)
gen season="winter" if dup==0
replace season="summer" if dup==1
drop dup

sort season draw length

append using  `proj_naa_cod' 


/******************************************************************************/
/******************************************************************************/
/* Section 6: Apply baseline selectivity-at-length to projected NAL           */
/******************************************************************************/
/******************************************************************************/

	/* This assumes that the length-specific recreational catchability/
	   selectivity observed in the baseline year remains constant in the
	   projection year, while projected stock composition changes according to
	   projected NAA translated to NAL using the ALK. */

merge 1:1 species season length draw using `selectivity'
sort species season draw length

gen catch_proj= frac_caught_smooth*proj_nal_smooth
mvencode catch*, mv(0)

keep length species season draw  catch catch_proj cod_replicate hadd_replicate proj_* base*
tostring draw, gen(draw2)
gen domain=species+"_"+season+"_"+draw2

egen sum=sum(catch), by(species season draw domain)
gen observed_prob_base=catch/sum
egen sum_proj=sum(catch_proj), by(species season draw domain)
gen observed_prob_proj=catch_proj/sum_proj
format sum* %20.0gc
drop sum*


preserve 
rename length fitted_length
keep fitted_length observed_prob*  species season domain draw proj_* base*
duplicates drop
tempfile observed_prob
save `observed_prob', replace
restore


/******************************************************************************/
/******************************************************************************/
/* Section 7: Smooth projected catch-at-length with a fitted gamma            */
/******************************************************************************/
/******************************************************************************/

di "catch_at_length_projection: fitting gamma distributions by domain; this may take a while ..."

/* Same method-of-moments gamma fit as catch_at_length_calibration.do, applied
   here to projected rather than baseline catch. MOM is used because the
   maximum-likelihood fit failed to converge for the sparser domains. */
   
tempfile new
save `new', replace
/* Compile projected fitted-length distributions safely in one tempfile rather
   than creating dynamically named temporary files for each domain. */

* Save the storage type of domain so the generated merge key is not strL
use `new', clear

capture confirm strL variable domain
if !_rc {
    gen str244 domain_fixed = strtrim(domain)
    drop domain
    rename domain_fixed domain
    save `new', replace
}
else {
    replace domain = strtrim(domain)
}

local domain_type : type domain

levelsof domain, local(regs)

tempfile fitted_sizes_all
local first_result = 1

quietly foreach r of local regs {
    use `new', clear
    keep if domain == "`r'"
    noisily display as text "Fitting domain: `r'"

    keep length catch_proj
    drop if missing(length) | missing(catch_proj)
    drop if catch_proj <= 0
    replace catch_proj = round(catch_proj)

    quietly summarize catch_proj, meanonly
    local tot_n_fish = r(sum)

    * Gamma distribution requires strictly positive support
    drop if length <= 0

    * Skip domains without usable observations
    if _N == 0 | missing(`tot_n_fish') | `tot_n_fish' <= 0 {
        noisily display as error "Skipping domain `r': no usable observations"
        continue
    }

    * -------------------------------------------------------------------------
    * (A) Estimate gamma parameters using weighted method of moments
    * -------------------------------------------------------------------------
    quietly summarize length [fw=catch_proj], meanonly
    local mu = r(mean)

    * Weighted variance: Var(x) = E(x^2) - [E(x)]^2
    generate double length2 = length^2
    quietly summarize length2 [fw=catch_proj], meanonly
    local ex2 = r(mean)
    local v = `ex2' - (`mu'^2)

    * Approximate a degenerate gamma when the variance is zero or very small
    if missing(`v') | missing(`mu') | `mu' <= 0 | `v' <= 1e-10 {
        local alpha = 1e6
        local beta = `mu'/`alpha'
    }
    else {
        local alpha = (`mu'^2)/`v'
        local beta = `v'/`mu'
    }

    * -------------------------------------------------------------------------
    * (B) Simulate and discretize the fitted length distribution
    * -------------------------------------------------------------------------
    local ndraw = round(`tot_n_fish')

    clear
    set obs `ndraw'

    generate double gammafit = rgamma(`alpha', `beta')
    replace gammafit = round(gammafit)

    generate long nfish = 1
    collapse (sum) nfish, by(gammafit)

    egen double sumnfish = total(nfish)
    generate double fitted_prob = nfish/sumnfish
    generate `domain_type' domain = "`r'"

    * -------------------------------------------------------------------------
    * Safely append each domain to one cumulative tempfile
    * -------------------------------------------------------------------------
    if `first_result' {
        save `fitted_sizes_all', replace
        local first_result = 0
    }
    else {
        append using `fitted_sizes_all'
        save `fitted_sizes_all', replace
    }
}

* Load the complete set of fitted distributions
if `first_result' {
    clear
    display as error "No domains produced usable fitted-size distributions."
    exit 2000
}
else {
    use `fitted_sizes_all', clear
}

rename gammafit fitted_length
sort domain fitted_length

* Confirm that the merge keys uniquely identify fitted observations
isid fitted_length domain

merge 1:1 fitted_length domain using `observed_prob'

sort domain fitted_length 
mvencode fitted_prob observed_prob*, mv(0) override 

split domain, parse(_)
replace season=domain2
replace species=domain1
drop draw
replace domain=species+"_"+season+"_"+domain3
rename domain3 draw
destring draw, replace 
rename fitted_l length

drop _merge nfish sum
order species season domain draw length
drop domain1 domain2 
rename fitted_prob fitted_prob_proj

preserve
import delimited using "$misc_data_cd/baseline_catch_at_length.csv", clear  
keep if draw<= $ndraws
tempfile baseyr
save `baseyr', replace 
restore

merge 1:1  species season draw length using `baseyr'
sort species season draw length

keep species season domain draw length fitted* observed* proj_nal*
mvencode fitted* observed* proj_nal*, mv(0) override
drop observed_prob
rename fitted_prob fitted_prob_base

merge m:1 length species season using  `base_naa'

sort draw species season length
local vars base_nal_raw base_nal_smooth proj_nal_raw proj_nal_smooth
foreach v of local vars{
	egen sum_`v'=sum(`v'), by(draw species season)
	gen prop_`v'=`v'/sum_`v'
	drop sum_`v'
}


/* Truncate the fitted distribution to the range of lengths actually observed
   in the baseline catch, then renormalize so each domain's probabilities sum
   to one. This keeps the gamma's unbounded tails from putting mass on lengths
   the fishery has never encountered. */
levelsof domain, local(doms)
foreach d of local doms{
quietly summarize length if observed_prob_base!=0 & !missing(observed_prob_base) & domain=="`d'"
local minL = `r(min)'
local maxL = `r(max)'
drop if (length<`minL' | length>`maxL') & domain=="`d'"
}

egen sum_fitted_prob=sum(fitted_prob_proj), by(domain)
replace fitted_prob_proj=fitted_prob_proj/sum_fitted_prob

* uncomment if you want plots of the resulting distributions, evaluated at mean by length
* plots of base and projected catch-at-length
/*
collapse (mean) observed* fitted* prop* base_nal* proj_nal*, by(species season length)
gen domain=season+"_"+species

levelsof domain , local(domz)
foreach d of local domz{
	twoway (scatter observed_prob_base length if domain=="`d'" ,   cmissing(no) connect(direct) lcol(gray) lwidth(med)  lpat(solid) msymbol(o) mcol(gray) $graphoptions) ///
		    (scatter observed_prob_proj length if  domain=="`d'"  , cmissing(no) connect(direct) lcol(black)   lwidth(med)  lpat(solid) msymbol(i)   ///
			xtitle("Length (cm)", yoffset(-2)) ytitle("Prob")    ylab(, angle(horizontal) labsize(vsmall)) ///
			legend(lab(1 "observed_catch_at_length_prob_base") lab(2 "observed_catch_at_length_prob_proj") cols() yoffset(-2) region(color(none)))   title("`d'", size(small))  name(dom`d', replace))
 local graphnames `graphnames' dom`d'
}

grc1leg `graphnames', rows(2)


levelsof domain , local(domz)
foreach d of local domz{

twoway (scatter fitted_prob_base length if domain=="`d'" ,   connect(direct) cmissing(no)  lcol(gray) lwidth(med)  lpat(solid) msymbol(o) mcol(gray) $graphoptions) ///
		    (scatter fitted_prob_proj length if  domain=="`d'"  , connect(direct) cmissing(no)  lcol(black)   lwidth(med)  lpat(solid) msymbol(i)   ///
			xtitle("Length (cm)", yoffset(-2)) ytitle("Prob")    ylab(, angle(horizontal) labsize(vsmall)) ///
			legend(lab(1 "fitted_catch_at_length_prob_base") lab(2 "fitted_catch_at_length_prob_proj") cols() yoffset(-2) region(color(none)))   title("`d'", size(small))  name(dom`d', replace))
 local graphnames `graphnames' dom`d'
}

grc1leg `graphnames', rows(2)

levelsof domain , local(domz)
foreach d of local domz{

twoway (scatter observed_prob_proj length if domain=="`d'" ,   connect(direct) cmissing(no)  lcol(gray) lwidth(med)  lpat(solid) msymbol(o) mcol(gray) $graphoptions) ///
		    (scatter fitted_prob_proj length if  domain=="`d'"  , connect(direct) cmissing(no)  lcol(black)   lwidth(med)  lpat(solid) msymbol(i)   ///
			xtitle("Length (cm)", yoffset(-2)) ytitle("Prob")    ylab(, angle(horizontal) labsize(vsmall)) ///
			legend(lab(1 "observed_catch_at_length_prob_proj") lab(2 "fitted_catch_at_length_prob_proj") cols() yoffset(-2) region(color(none)))   title("`d'", size(small))  name(dom`d', replace))
 local graphnames `graphnames' dom`d'
}

grc1leg `graphnames', rows(2)

levelsof domain , local(domz)
foreach d of local domz{

twoway (scatter observed_prob_base length if domain=="`d'" ,   connect(direct) cmissing(no)  lcol(gray) lwidth(med)  lpat(solid) msymbol(o) mcol(gray) $graphoptions) ///
		    (scatter fitted_prob_base length if  domain=="`d'"  , connect(direct) cmissing(no)  lcol(black)   lwidth(med)  lpat(solid) msymbol(i)   ///
			xtitle("Length (cm)", yoffset(-2)) ytitle("Prob")    ylab(, angle(horizontal) labsize(vsmall)) ///
			legend(lab(1 "observed_catch_at_length_prob_base") lab(2 "fitted_catch_at_length_prob_base") cols() yoffset(-2) region(color(none)))   title("`d'", size(small))  name(dom`d', replace))
 local graphnames `graphnames' dom`d'
}

grc1leg `graphnames', rows(2)



levelsof domain , local(domz)
foreach d of local domz{

twoway (scatter prop_base_nal_raw length if domain=="`d'" ,   connect(direct) cmissing(no)  lcol(gray) lwidth(med)  lpat(solid) msymbol(o) mcol(gray) $graphoptions) ///
		    (scatter prop_proj_nal_raw length if  domain=="`d'"  , connect(direct) cmissing(no)  lcol(black)   lwidth(med)  lpat(solid) msymbol(i)   ///
			xtitle("Length (cm)", yoffset(-2)) ytitle("Prob")    ylab(, angle(horizontal) labsize(vsmall)) ///
			legend(lab(1 "prop_base_nal_raw") lab(2 "prop_proj_nal_raw") cols() yoffset(-2) region(color(none)))   title("`d'", size(small))  name(dom`d', replace))
 local graphnames `graphnames' dom`d'
}

grc1leg `graphnames', rows(2)

levelsof domain , local(domz)
foreach d of local domz{

twoway (scatter prop_base_nal_smooth length if domain=="`d'" ,   connect(direct) cmissing(no)  lcol(gray) lwidth(med)  lpat(solid) msymbol(o) mcol(gray) $graphoptions) ///
		    (scatter prop_proj_nal_smooth length if  domain=="`d'"  , connect(direct) cmissing(no)  lcol(black)   lwidth(med)  lpat(solid) msymbol(i)   ///
			xtitle("Length (cm)", yoffset(-2)) ytitle("Prob")    ylab(, angle(horizontal) labsize(vsmall)) ///
			legend(lab(1 "prop_base_nal_smooth") lab(2 "prop_proj_nal_smooth") cols() yoffset(-2) region(color(none)))   title("`d'", size(small))  name(dom`d', replace))
 local graphnames `graphnames' dom`d'
}

grc1leg `graphnames', rows(2)

levelsof domain , local(domz)
foreach d of local domz{

twoway (scatter prop_base_nal_smooth length if domain=="`d'" ,   connect(direct) cmissing(no)  lcol(gray) lwidth(med)  lpat(solid) msymbol(o) mcol(gray) $graphoptions) ///
		    (scatter prop_proj_nal_smooth length if  domain=="`d'"  , connect(direct) cmissing(no)  lcol(black)   lwidth(med)  lpat(solid) msymbol(i)   ///
			xtitle("Length (cm)", yoffset(-2)) ytitle("Prob")    ylab(, angle(horizontal) labsize(vsmall)) ///
			legend(lab(1 "prop_base_nal_smooth") lab(2 "prop_proj_nal_smooth") cols() yoffset(-2) region(color(none)))   title("`d'", size(small))  name(dom`d', replace))
 local graphnames `graphnames' dom`d'
}

grc1leg `graphnames', rows(2)
*/

/******************************************************************************/
/******************************************************************************/
/* Section 8: Export projected fitted probabilities                           */
/******************************************************************************/
/******************************************************************************/

keep draw length species season  fitted_prob_proj
drop if missing(fitted_prob_proj) | fitted_prob_proj == 0
rename fitted_prob_proj fitted_prob
compress
export delimited using "$misc_data_cd/projected_catch_at_length.csv", replace

di "catch_at_length_projection: done."

