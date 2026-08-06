/******************************************************************************/
/******************************************************************************/
/* Script:  catch_at_length_calibration.do                                    
                                                                            
 Purpose: Builds the calibration-year catch-at-length distributions for      
          WGOM cod and haddock. Harvest (A+B1) and discard (B2) lengths are  
          estimated separately from MRIP size data, converted to             
          proportions at length by species and season, scaled up by the      
          simulated harvest/release totals for each draw, and then smoothed  
          by fitting a gamma distribution to each species-season-draw.       
          Both the raw ("observed") and gamma-smoothed ("fitted")            
          distributions are exported.                                        
                                                                            
 Inputs:  $triplist  - stacked MRIP trip files                               
          $b2list    - stacked MRIP length files, used here for discards     
          $sizelist  - stacked MRIP length files, used here for harvest      
          $misc_data_cd/MRIP_COD_ALL_SITE_LIST.csv                           
          $misc_data_cd/simulated_catch_totals_for_catch_length.dta          
                                                                             
 Outputs: $misc_data_cd/baseline_catch_at_length_observed.csv                
          $misc_data_cd/baseline_catch_at_length.csv                         
                                                                             
 Dependencies: Run from model_wrapper.do, which must already have set        
          $seed, $ndraws, $calibration_year, $misc_data_cd, $triplist,       
          $b2list and $sizelist. simulated_catch_totals_for_catch_length.dta 
          is written by the catch-per-trip calibration step, so that must    
          run first.                                                         
                                                                            
 Pipeline: Pre-simulation. Supplies the length composition the R simulation  
          uses to decide which fish are legal to keep;                       
          catch_at_length_projection.do is the projection-year counterpart.  
                                                                             
 Note 1:  Sections A and B are near-identical ~90-line blocks that differ    
          only in which MRIP length file they read and in the cod discard    
          special case.                                                      
 Note 2:  $b2list and $sizelist appear to point at swapped files where they  
          are defined in model_wrapper.do; usage here follows the macro      
          names, not the file names.        */
/******************************************************************************/
/******************************************************************************/

/******************************************************************************/
/******************************************************************************/
/* Section A: MRIP discard (B2) lengths                                       */
/******************************************************************************/
/******************************************************************************/

set seed $seed

di "catch_at_length_calibration: building MRIP discard lengths; this may take a while ..."

clear

mata: mata clear

tempfile tl1 sl1 cl1
dsconcat $triplist

sort year strat_id psu_id id_code
/* MRIP flags unresolved/placeholder interviews with "xx" inside id_code */
drop if strmatch(id_code, "*xx*")==1
drop if strat_id==""
duplicates drop 
save `tl1'
clear

dsconcat $b2list
sort year strat_id psu_id id_code
/* MRIP flags unresolved/placeholder interviews with "xx" inside id_code */
drop if strmatch(id_code, "*xx*")==1
replace common=subinstr(lower(common)," ","",.)
save `sl1', replace

use `tl1'
merge 1:m year strat_id psu_id id_code using `sl1', keep(1 3) nogen

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

keep if inlist(st,23, 33, 25) //ensure relevent states 
keep if $calibration_year //ensure relevent year
 
gen st2 = string(st,"%02.0f")

/* Delineate WGOM versus non-WGOM fishing. MRIP records an interview site, not
   a stock area, so the site list is used to map each site to an NMFS statistical
   area; areas 513-515, 521, 526 and 541 make up the Western Gulf of Maine cod
   stock area. Everything else is labelled "XX" and dropped below. */
* MRIP-Western GoM site allocations
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

/* Classify into WGOM or not WGOM. All of New Hampshire (st2=="33") is treated
   as WGOM without consulting the site list; Massachusetts and Maine are
   assigned from the site-level lookup merged above. */
gen str3 area_s="XX"
replace area_s="WGOM" if st2=="33"
replace area_s=nmfs_stock_area if inlist(st2, "25", "23") 

gen mode1="sh" if inlist(mode_fx, "1", "2", "3")
replace mode1="pr" if inlist(mode_fx, "7")
replace mode1="fh" if inlist(mode_fx, "4", "5")

* drop shore trips
drop if mode1=="sh"

* classify catch into the things I care about (common=="c" | "h") and things I don't care about "z" 
gen common_dom="z"
replace common_dom="c" if strmatch(sp_code,"8791030402")
replace common_dom="h" if strmatch(sp_code,"8791031301")

tostring wave, gen(w2)
tostring year, gen(year2)

destring month, gen(mymo)
drop month
tostring mymo, gen(month)
drop mymo

* this might speed things up if I re-classify all length=0 for the species I don't care about 
replace l_cm_bin =0 if !inlist(common_dom, "c", "h")

sort year w2 strat_id psu_id id_code

* okay to drop non-target strata here because we are using only point estimates or raw lengths
keep if area_s=="WGOM"
drop if common_dom=="z"

/* Zero-pad month so the string comparisons below work. Note the rename relies
   on Stata's variable-name abbreviation: month has just been dropped, so
   "rename month month" uniquely matches month1 and renames it to month. */
destring month, replace
gen month1 = string(month,"%02.0f")
drop month
rename month month
/* Season definition used throughout the groundfish model: the "summer" season
   is May-August, everything else is "winter". */
gen season= "win" if inlist(month, "09", "10", "11", "12", "01", "02", "03", "04")
replace season="sum" if inlist(month, "05", "06", "07", "08")

gen my_dom_id_string=season+"_"+common_dom

replace my_dom_id_string=subinstr(ltrim(rtrim(my_dom_id_string))," ","",.)
encode my_dom_id_string, gen(my_dom_id)

svyset psu_id [pweight= wp_size], strata(var_id) singleunit(certainty)


/* Discard and harvest lengths:
     for cod, use unweighted b2 data, weighted a+b1
     for haddock, use weighted b2 data, weighted a+b1
   Cod released-fish lengths are sparse enough that the survey weights produce
   an unstable length distribution, so cod discards are tabulated as raw counts
   (`codb2' below) and then substituted for the weighted cod estimates. */

preserve
keep my_dom_id my_dom_id_string season common_dom l_cm_bin
keep if common_dom=="c"
gen species="cod" if common_dom=="c"
replace species="hadd" if common_dom=="h"
gen nfish_b2=1
collapse (sum) nfish_b2, by(season species l_cm_bin)
tempfile codb2
save `codb2', replace
restore

/* Survey-weighted cross-tab of length bin by season-species domain. Stata
   returns the cell proportions (e(Prop)), row labels (e(Row)) and column
   labels (e(Col)) as matrices; multiplying the proportions by the estimated
   population size e(N_pop) recovers estimated numbers of fish per cell. The
   svmat/reshape sequence below turns those matrices back into a long dataset
   of season x species x length x count. */
svy: tab l_cm_bin my_dom_id_string, count
mat eP=e(Prop)
mat eR=e(Row)'
mat eC=e(Col)
local PopN=e(N_pop)

local mycolnames: colnames(eC)
mat colnames eP=`mycolnames'
	
clear
svmat eP, names(col)
	foreach var of varlist *{
		replace `var'=`var'*`PopN'
	}
svmat eR
order eR
rename eR l_cm_bin

ds l_cm_bin, not
renvarlab `r(varlist)', prefix(tab_)
reshape long tab_, i(l_cm_bin) j(new) string	
split new, parse(_)
rename new1 season
rename new2 species
replace species="cod" if species=="c"
replace species="hadd" if species=="h"

drop new
rename tab nfish_b2
/* Discard the weighted cod discard lengths and substitute the raw counts */
drop if species=="cod"
append using `codb2'
sort  season species l_cm_bin

tempfile b2
save `b2', replace 


/******************************************************************************/
/******************************************************************************/
/* Section B: MRIP harvest (A+B1) lengths                                     */
/******************************************************************************/
/******************************************************************************/

di "catch_at_length_calibration: building MRIP harvest lengths ..."

cd $misc_data_cd

clear

mata: mata clear

tempfile tl1 sl1 cl1
dsconcat $triplist

sort year strat_id psu_id id_code
*replace id_code=ID_CODE if id_code=="" & ID_CODE!=""
/* MRIP flags unresolved/placeholder interviews with "xx" inside id_code */
drop if strmatch(id_code, "*xx*")==1
drop if strat_id==""
duplicates drop 
save `tl1'
clear
 

dsconcat $sizelist
sort year strat_id psu_id id_code
replace common=subinstr(lower(common)," ","",.)
save `sl1'

use `tl1'
merge 1:m year strat_id psu_id id_code using `sl1', keep(1 3) nogen


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

keep if inlist(st,23, 33, 25) //ensure relevent states 
keep if $calibration_year //ensure relevent year
 
gen st2 = string(st,"%02.0f")


/* Delineate WGOM versus non-WGOM fishing. MRIP records an interview site, not
   a stock area, so the site list is used to map each site to an NMFS statistical
   area; areas 513-515, 521, 526 and 541 make up the Western Gulf of Maine cod
   stock area. Everything else is labelled "XX" and dropped below. */

* MRIP-Western GoM site allocations
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

/* Classify into WGOM or not WGOM. All of New Hampshire (st2=="33") is treated
   as WGOM without consulting the site list; Massachusetts and Maine are
   assigned from the site-level lookup merged above. */
gen str3 area_s="XX"
replace area_s="WGOM" if st2=="33"
replace area_s=nmfs_stock_area if inlist(st2, "25", "23") 

gen mode1="sh" if inlist(mode_fx, "1", "2", "3")
replace mode1="pr" if inlist(mode_fx, "7")
replace mode1="fh" if inlist(mode_fx, "4", "5")

* drop shore trips
drop if mode1=="sh"

* classify catch into the things I care about (common=="c" of "h") and things I don't care about "z" 
gen common_dom="z"
replace common_dom="c" if strmatch(sp_code,"8791030402")
replace common_dom="h" if strmatch(sp_code,"8791031301")

tostring wave, gen(w2)
tostring year, gen(year2)

destring month, gen(mymo)
drop month
tostring mymo, gen(month)
drop mymo

* this might speed things up if I re-classify all length=0 for the species I don't care about 
replace l_cm_bin =0 if !inlist(common_dom, "c", "h")

sort year w2 strat_id psu_id id_code

* okay to drop non-target strata here because we are using only point estimates or raw lengths
keep if area_s=="WGOM"
drop if common_dom=="z"

/* Zero-pad month so the string comparisons below work. Note the rename relies
   on Stata's variable-name abbreviation: month has just been dropped, so
   "rename month month" uniquely matches month1 and renames it to month. */
destring month, replace
gen month1 = string(month,"%02.0f")
drop month
rename month month
/* Season definition used throughout the groundfish model: the "summer" season
   is May-August, everything else is "winter". */
gen season= "win" if inlist(month, "09", "10", "11", "12", "01", "02", "03", "04")
replace season="sum" if inlist(month, "05", "06", "07", "08")

gen my_dom_id_string=season+"_"+common_dom
replace my_dom_id_string=subinstr(ltrim(rtrim(my_dom_id_string))," ","",.)
encode my_dom_id_string, gen(my_dom_id)

svyset psu_id [pweight= wp_size], strata(var_id) singleunit(certainty)

svy: tab l_cm my_dom_id_string, count
mat eP=e(Prop)
mat eR=e(Row)'
mat eC=e(Col)
local PopN=e(N_pop)

local mycolnames: colnames(eC)
mat colnames eP=`mycolnames'
	
clear
svmat eP, names(col)
	foreach var of varlist *{
		replace `var'=`var'*`PopN'
	}
svmat eR
order eR
rename eR l_cm_bin

ds l_cm_bin, not
renvarlab `r(varlist)', prefix(tab_)
reshape long tab_, i(l_cm_bin) j(new) string	
split new, parse(_)
rename new1 season
rename new2 species
replace species="cod" if species=="c"
replace species="hadd" if species=="h"

drop new
rename tab nfish_ab1	
sort  season species l_cm_bin

/******************************************************************************/
/******************************************************************************/
/* Section C: Combine harvest and discard lengths into proportions            */
/******************************************************************************/
/******************************************************************************/

* merge harvest lengths to discards lengths
merge 1:1 l_cm_bin species season using `b2'

sort species  season l

/* Fill in length bins with no observed fish. Treating species-season as a
   panel and length as the time index lets tsfill insert the missing bins;
   mvencode then sets their counts to zero so every domain spans the same
   contiguous length range. */
gen panel_var=species+"_"+season
encode panel_var, gen(panel_var2)
xtset panel_var2 l_cm_bin
tsfill, full
mvencode nfish*, mv(0) over
decode panel_var2, gen(panel_var3)
split panel_var3, parse(_)
replace species=panel_var31
replace season=panel_var32

keep l_cm_bin nfish* species season
order species season  l_cm_bin nfish* 

* create proportions of harvest/discards at length
egen sum_ab1=sum(nfish_ab1), by(species season ) 
egen sum_b2=sum(nfish_b2), by(species season ) 

gen prop_ab1=nfish_ab1/sum_ab1
gen prop_b2=nfish_b2/sum_b2

keep species season l_cm_bin prop_ab1 prop_b2
replace season="winter" if season=="win"
replace season="summer" if season=="sum"

/* The length proportions are estimated once and reused for every draw; only
   the totals they are scaled by vary across draws. */
expand $ndraws
bysort species season l_cm: gen draw=_n

tempfile props
save `props', replace

/******************************************************************************/
/******************************************************************************/
/* Section D: Scale proportions to simulated harvest and release totals       */
/******************************************************************************/
/******************************************************************************/

u "$misc_data_cd\simulated_catch_totals_for_catch_length.dta", clear
keep tot_cod_keep_sim tot_cod_rel_sim tot_hadd_keep_sim tot_hadd_rel_sim  draw season
keep if draw<=$ndraws

preserve 
keep draw season tot_cod_keep_sim tot_cod_rel_sim
gen species="cod"
rename tot_cod_keep_sim ab1 
rename tot_cod_rel_sim b2 
tempfile cod
save `cod', replace
restore 

keep draw season tot_hadd_keep_sim tot_hadd_rel_sim
gen species="hadd"
rename tot_hadd_keep_sim ab1 
rename tot_hadd_rel_sim b2 
append using `cod'

merge 1:m species season draw using `props'

drop _merge

* generate total catch, harvest, discards at length
sort draw season species l
gen n_ab1=ab1*prop_ab1
gen n_b2=b2*prop_b2
gen n_fish=n_ab1+n_b2

drop prop_ab1 prop_b2 n_ab1 n_b2

/******************************************************************************/
/******************************************************************************/
/* Section E: Smooth catch-at-length by fitting a gamma distribution          */
/******************************************************************************/
/******************************************************************************/

/* observed_prob is the empirical catch-at-length share within each
   species-season-draw; the gamma fit below is what actually gets used
   downstream, and observed_prob is carried along for comparison. */
egen sumfish=sum(n_fish), by(season species draw)
gen observed_prob=n_fish/sum
drop sumfish
tostring draw, gen(draw1)
gen domain = species+"_"+season+"_"+draw1

drop if n_fish==0
rename l_cm length 

preserve 
rename length fitted_length
keep fitted_length observed_prob n_fish species season draw domain
duplicates drop
tempfile observed_prob
save `observed_prob', replace
restore


/* Each species-season-draw ("domain") is fitted separately. Method of moments
   is used rather than maximum likelihood because the ML fit failed to converge
   for the sparser domains. */

* Preserve the complete input dataset so it can be reloaded for each domain
tempfile source_data fitted_sizes_all
save `source_data', replace

levelsof domain, local(regs)

* Identifies the first successfully fitted domain
local first_result = 1

quietly foreach r of local regs {
    use `source_data', clear
    keep if domain == "`r'"
    noisily display as text "Fitting domain: `r'"

    keep length n_fish
    drop if missing(length) | missing(n_fish)
    drop if n_fish <= 0
    replace n_fish = round(n_fish)

    quietly summarize n_fish, meanonly
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
    quietly summarize length [fw=n_fish], meanonly
    local mu = r(mean)

    * Weighted variance: Var(x) = E(x^2) - [E(x)]^2
    generate double length2 = length^2
    quietly summarize length2 [fw=n_fish], meanonly
    local ex2 = r(mean)
    local v = `ex2' - (`mu'^2)

    * If the variance is zero or numerically negligible, approximate a
    * degenerate distribution concentrated near the weighted mean
    if missing(`v') | missing(`mu') | `mu' <= 0 | `v' <= 1e-10 {
        local alpha = 1e6
        local beta = `mu'/`alpha'
    }
    else {
        * Gamma shape and scale from the first two moments
        local alpha = (`mu'^2)/`v'
        local beta = `v'/`mu'
    }

    * -------------------------------------------------------------------------
    * (B) Simulate a discretized length distribution from the fitted gamma
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
    generate  domain = "`r'"

    * -------------------------------------------------------------------------
    * Safely accumulate results in one tempfile
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

* Load the combined fitted distributions
if `first_result' {
    clear
    display as error "No domains produced usable fitted-size distributions."
}
else {
    use `fitted_sizes_all', clear
    sort domain gammafit
}

rename gammafit fitted_length

merge 1:1 fitted_length domain using `observed_prob'
sort domain fitted_length 
mvencode fitted_prob observed_prob, mv(0) override 

split domain, parse(_)
replace species=domain1
replace season=domain2
replace domain=species+"_"+season+"_"+domain3

destring domain3, replace
replace draw=domain3
sort species season draw fitted_length

drop _merge domain1 domain2 domain3
rename fitted_length length 
sort species season draw length


/*
collapse (mean) observed* fitted* , by(species season length)
gen domain=season+"_"+species

levelsof domain , local(domz)
foreach d of local domz{
	twoway (scatter observed_prob length if domain=="`d'" ,   cmissing(no) connect(direct) lcol(gray) lwidth(med)  lpat(solid) msymbol(o) mcol(gray) $graphoptions) ///
		    (scatter fitted_prob length if  domain=="`d'"  , cmissing(no) connect(direct) lcol(black)   lwidth(med)  lpat(solid) msymbol(i)   ///
			xtitle("Length (cm)", yoffset(-2)) ytitle("Prob")    ylab(, angle(horizontal) labsize(vsmall)) ///
			legend(lab(1 "observed_prob") lab(2 "fitted_prob") cols() yoffset(-2) region(color(none)))   title("`d'", size(small))  name(dom`d', replace))
 local graphnames `graphnames' dom`d'
}

grc1leg `graphnames', rows(2)
*/

/******************************************************************************/
/******************************************************************************/
/* Section F: Truncate, renormalize and export                                */
/******************************************************************************/
/******************************************************************************/

/* The gamma has unbounded support, so trim each domain's fitted distribution
   back to the smallest and largest lengths actually observed for it, then
   renormalize the remaining probabilities to sum to one. */
levelsof domain, local(doms)
foreach d of local doms{
quietly summarize length if observed_prob!=0 & !missing(observed_prob) & domain=="`d'"
return list /* leftover debug output; prints r() after each summarize */
local minL = `r(min)'
local maxL = `r(max)'
drop if (length<`minL' | length>`maxL' ) & domain=="`d'"
}

egen sum_fitted_prob=sum(fitted_prob), by(domain)
replace fitted_prob=fitted_prob/sum_fitted_prob
sort species season draw length


/*
collapse (mean) observed* fitted* , by(species season length)
gen domain=season+"_"+species

levelsof domain , local(domz)
foreach d of local domz{
	twoway (scatter observed_prob length if domain=="`d'" ,   cmissing(no) connect(direct) lcol(gray) lwidth(med)  lpat(solid) msymbol(o) mcol(gray) $graphoptions) ///
		    (scatter fitted_prob length if  domain=="`d'"  , cmissing(no) connect(direct) lcol(black)   lwidth(med)  lpat(solid) msymbol(i)   ///
			xtitle("Length (cm)", yoffset(-2)) ytitle("Prob")    ylab(, angle(horizontal) labsize(vsmall)) ///
			legend(lab(1 "observed_prob") lab(2 "fitted_prob") cols() yoffset(-2) region(color(none)))   title("`d'", size(small))  name(dom`d', replace))
 local graphnames `graphnames' dom`d'
}

grc1leg `graphnames', rows(2)
*/

/*
* Graphs of the fitted observed/fitted probabilities
* Create a local macro for unique draws 

levelsof draw if draw < 2, local(draws)

* Initialize an empty plot command
local plots

* Build up one line per draw
foreach d of local draws {
    local plots `plots' (line fitted_prob fitted_length if draw==`d' & species=="hadd" & season=="summer", ///
        lcolor(gs10) lwidth(thin) lpattern(solid))
}

* Draw combined graph
twoway `plots', ///
    legend(off) ///
    xlabel(, labsize(small)) ///
    ylabel(, labsize(small)) ///
    title("Fitted catch-at-length probabilities by length (Haddock, closed season)", size(medium)) ///
    ytitle("Probability", size(medium)) xtitle("Length (cm)", size(medium)) xlab(#40)

*/

* save observed catch at length for creating projected catch-at-length

preserve 
keep length draw season species observed_prob n_fish
export delimited using "$misc_data_cd/baseline_catch_at_length_observed.csv", replace 
restore 

drop if fitted_prob==0
keep length fitted_prob draw season species observed_prob 
order draw season species length fitted_prob observed_prob	

export delimited using "$misc_data_cd/baseline_catch_at_length.csv", replace

di "catch_at_length_calibration: done."

