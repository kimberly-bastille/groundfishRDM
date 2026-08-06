/******************************************************************************/
/******************************************************************************/
/* Script:  compare_calibration_data_to_MRIP.do                               
                                                                              
   Purpose: Validation step for the simulated calibration-year catch. The     
            copula model produces daily catch-per-trip draws; this script     
              1) computes mean catch-per-trip from those daily draws,         
              2) scales them up to totals by multiplying by the number of     
                 directed trips on each day, and                              
              3) compares the resulting means and totals with the MRIP        
                 survey estimates at the mode-month, mode, and mode-season    
                 levels, exporting a diagnostic figure for each comparison.   
            The FINAL STEP section then saves the aggregated simulated totals 
            that the rest of the pipeline consumes.                           
                                                                              
   Inputs:  $calib_catch_draws_cd/calib_catch_draws_<i>.dta for i=1..$ndraws  
            $misc_data_cd/directed_trip_draws.csv                             
            $misc_data_cd/baseline_mrip_catch_processed.xlsx                  
            $misc_data_cd/mrip_catch_by_mode_month.dta, mrip_catch_by_mode.dta
            $misc_data_cd/mrip_catch_by_mode_season.dta                       
            $misc_data_cd/mrip_dtrip_by_mode_month.dta, mrip_dtrip_by_mode.dta
            $misc_data_cd/mrip_dtrip_by_mode_season.dta                       
                                                                              
   Outputs: $misc_data_cd/simulated_catch_totals3.dta   (intermediate)        
            $misc_data_cd/simulated_catch_totals.dta                          
            $misc_data_cd/simulated_catch_totals_for_catch_length.dta         
            $figure_cd/mean_catch_MRIP_simulated.png                          
            $figure_cd/monthly_catch_total_MRIP_simulated.png                 
            $figure_cd/monthly_dtrip_total_MRIP_simulated.png                 
            $figure_cd/catch_total_MRIP_simulated.png                         
            $figure_cd/dtrip_total_MRIP_simulated.png                         
            $figure_cd/season_catch_total_MRIP_simulated.png                  
            $figure_cd/season_dtrip_total_MRIP_simulated.png                  
            Also rewrites $calib_catch_draws_cd/calib_catch_draws_<i>.dta in  
            place with four columns dropped -- see Note 1.                    
                                                                              
   Dependencies: Run from model_wrapper.do after the copula catch draws and   
            the directed-trip draws exist. Expects $ndraws, $misc_data_cd,    
            $calib_catch_draws_cd and $figure_cd to be set, and requires the  
            user-written grc1leg and renvarlab commands.                      
                                                                              
   Pipeline: Pre-simulation. Despite the "compare" name this is not a purely  
            diagnostic script: simulated_catch_totals.dta feeds the R         
            simulation and simulated_catch_totals_for_catch_length.dta feeds  
            catch_at_length_calibration.do.                                   
                                                                              
   Note 1:  The final loop drops cod_keep_sim, cod_rel_sim, hadd_keep_sim and 
            hadd_rel_sim from the calib_catch_draws files and saves over the  
            originals. Those columns are what Section B1 collapses, so this   
            script cannot be re-run without regenerating the catch draws      
            first.                                                            
   Note 2:  Sections B3a-B3d are four near-identical aggregate-and-plot       
            blocks differing only in the grouping level and the MRIP file     
            they compare against.                                             
   Note 3:  Several `use ... , replace` statements appear below where         
            `, clear` is what is meant; flagged, code unchanged.            */
/******************************************************************************/
/******************************************************************************/

/******************************************************************************/
/******************************************************************************/
/* Section B1/B2: Mean catch-per-trip and simulated totals by mode-month      */
/******************************************************************************/
/******************************************************************************/

di "compare_calibration_data_to_MRIP: aggregating $ndraws draws of catch data; this may take a while ..."

clear
tempfile master
save `master', emptyok

forv i=1/$ndraws{

use "$calib_catch_draws_cd\calib_catch_draws_`i'.dta", clear 

collapse (mean) cod_keep_sim cod_cat_sim cod_rel_sim hadd_keep_sim hadd_rel_sim hadd_cat_sim , by(month mode)

tempfile catch
save `catch', replace 

import delimited using "$misc_data_cd\directed_trip_draws.csv",  clear 
drop if dtrip==0

keep if draw==`i'

gen date_num = date(day, "DMY")
gen month1 = month(date_num)	
drop date_num
gen month = string(month1, "%02.0f")
destring month, replace 

collapse (sum) dtrip, by(mode month)

merge 1:1 mode month  using `catch'
drop _merge

local vars cod_keep_sim cod_cat_sim cod_rel_sim hadd_keep_sim hadd_rel_sim hadd_cat_sim 
foreach v of local vars{
	/* Total = mean catch per trip x number of directed trips in that
	   mode-month. The catch draws are per-trip quantities, so this is the
	   step that turns them into fleet-wide numbers comparable to MRIP. */
	gen tot_`v'= dtrip*`v'

}

gen draw=`i'

append using `master'
save `master', replace
}

use `master', clear

save "$misc_data_cd\simulated_catch_totals3.dta", replace 


/******************************************************************************/
/******************************************************************************/
/* Section B3a: Compare mean catch-per-trip at the mode-month level           */
/******************************************************************************/
/******************************************************************************/

u "$misc_data_cd\simulated_catch_totals3.dta", clear
rename dtrip tot_dtrip_sim

ds draw mode month, not
local vars `r(varlist)'
foreach v of local vars{
	mvencode `v', mv(0) override
}

order mode month draw

/* Collapse across draws: the mean is the simulated point estimate and the
   standard deviation across draws plays the role of the MRIP standard error,
   so the two can be compared with the same +/-1.96 SE interval below. */
collapse (mean) cod_keep_sim cod_rel_sim cod_cat_sim hadd_keep_sim hadd_rel_sim hadd_cat_sim  	///
						(sd) sd_cod_keep_sim=cod_keep_sim  ///
						sd_cod_cat_sim=cod_cat_sim  ///
						sd_cod_rel_sim=cod_rel_sim ///
						sd_hadd_keep_sim=hadd_keep_sim ///
						sd_hadd_rel_sim=hadd_rel_sim ///
						sd_hadd_cat_sim=hadd_cat_sim , by(mode month)
						
renvarlab cod* hadd* , prefix(tot_)					

reshape long tot_ sd_, i(mode month) j(new) string
rename tot_ sim_total 
rename sd_ sim_sd
split new, parse(_)
rename new1 species
rename new2 disp
drop new3
drop new
tostring month, replace
tempfile sim
save `sim', replace


import excel using "$misc_data_cd\baseline_mrip_catch_processed.xlsx", clear first 
keep my_dom_id_string-missing_sehadd_rel
drop missing*
drop if strmatch(my_dom_id_string, "*XX*")==1
drop if strmatch(my_dom_id_string, "*ZZ*")==1
duplicates drop
drop if strmatch(my_dom_id_string, "*XX*")==1
drop if strmatch(my_dom_id_string, "*ZZ*")==1
split my, parse(_)
rename my_dom_id_string1 month
destring month, replace
tostring month, replace
rename my_dom_id_string2 mode
drop my_dom_id_string3
reshape long mean se, i(month mode) j(new) string
rename mean mrip_total 
rename se mrip_sd
split new, parse(_)
rename new1 species
rename new2 disp
drop new

merge 1:1 month mode  species disp using `sim'


gen mrip_ul=mrip_total+1.96*mrip_sd
gen mrip_ll=mrip_total-1.96*mrip_sd
gen sim_ul=sim_total+1.96*sim_sd
gen sim_ll=sim_total-1.96*sim_sd

drop if mrip_total==0 & sim_total==0
drop if mrip_total==. & sim_total==0

gen domain=species+"_"+disp

gen pct_diff = ((sim_total-mrip_total)/mrip_total)*100
gen diff= sim_total-mrip_total
sort pct_diff

replace my_dom_id_string=month+"_"+mode

tempfile new
save `new', replace 

/* One graph per species-disposition domain, held in memory by name and
   combined with grc1leg afterwards. The MRIP and simulated markers are offset
   by +/-0.1 on the x axis so their confidence bars do not overlap. */
levelsof domain, local(domain_list)
	foreach d in `domain_list' {
		u `new', clear
		keep if domain=="`d'"

		encode my_dom_id_string, gen(my_dom_id)
		gen my_dom_id_mrip = my_dom_id+0.1
		gen my_dom_id_sim = my_dom_id-0.1

/* Rebuild the axis labels by hand: my_dom_id is numeric with value labels, and
   twoway's xlabel() needs an explicit "value label" pair for each level. */
local xlabels ""
levelsof my_dom_id, local(levels)

foreach l of local levels {
    local label : label (my_dom_id) `l'
    local xlabels `xlabels' `l' "`label'"
}

qui twoway (rcap mrip_ul mrip_ll my_dom_id_mrip if domain=="`d'", color(blue)  ) ///
			(scatter mrip_total my_dom_id_mrip if domain=="`d'",  msymbol(o) mcolor(blue)) ///
			(rcap sim_ul sim_ll my_dom_id_sim if domain=="`d'",  color(red)) ///
			(scatter sim_total my_dom_id_sim if domain=="`d'", msymbol(o) mcolor(red)), ///
			legend(order(2 "MRIP estimate" 4 "Simulated estimate") size(small) rows(1)) ///
			ytitle("") xtitle("") ylabel(#10,  angle(horizontal) ) ///
			xlabel(`xlabels',  labsize(small) angle(45)) ///
			title("`d'", size(medium)) name(`d', replace) 
		}
  
u `new', clear 

sort  month mode 
grc1leg  hadd_keep cod_keep hadd_rel cod_rel  , cols(2) title("Mean catch-per-trip, MRIP vs.simulated estimates", size(small))
graph export "$figure_cd/mean_catch_MRIP_simulated.png", as(png) replace
gr drop _all


/******************************************************************************/
/******************************************************************************/
/* Section B3b: Compare catch totals at the mode-month level                  */
/******************************************************************************/
/******************************************************************************/

u "$misc_data_cd\simulated_catch_totals3.dta", replace
rename dtrip tot_dtrip_sim
ds draw mode month, not
local vars `r(varlist)'
foreach v of local vars{
	mvencode `v', mv(0) override
}

	
collapse (sum) tot_cod_keep_sim tot_cod_cat_sim tot_cod_rel_sim ///
						  tot_hadd_keep_sim tot_hadd_rel_sim tot_hadd_cat_sim ///
						  tot_dtrip_sim , by( mode  month draw)

collapse (mean) tot_cod_keep_sim tot_cod_cat_sim tot_cod_rel_sim ///
						  tot_hadd_keep_sim tot_hadd_rel_sim tot_hadd_cat_sim ///
						  tot_dtrip_sim ///
				(sd)	sd_cod_keep_sim=tot_cod_keep_sim sd_cod_cat_sim =tot_cod_cat_sim sd_cod_rel_sim =tot_cod_rel_sim ///
						  sd_hadd_keep_sim=tot_hadd_keep_sim sd_hadd_rel_sim =tot_hadd_rel_sim sd_hadd_cat_sim =tot_hadd_cat_sim ///
						  sd_dtrip_sim=tot_dtrip_sim, by( mode month)
						  
reshape long tot_ sd_, i(mode month) j(new) string
rename tot_ sim_total 
rename sd_ sim_sd
split new, parse(_)
rename new1 species
rename new2 disp
drop new3
drop new
replace disp="dtrip" if species=="dtrip"
replace species="NA" if disp=="dtrip"

preserve
keep if disp=="dtrip"
gen sim_ul = sim_total+1.96*sim_sd
gen sim_ll = sim_total-1.96*sim_sd
tempfile simdtrip
save `simdtrip', replace
restore 

drop if disp=="dtrip"
tempfile sim
save `sim', replace

u  "$misc_data_cd\mrip_catch_by_mode_month.dta", clear 
reshape long total se ll95 ul95, i(mode month) j(new) string
rename tot mrip_total 
rename se mrip_se
rename ll mrip_ll
rename ul mrip_ul
destring month, replace

split new, parse(_)
rename new1 species
rename new2 disp
drop new3
drop new my 
merge 1:1  mode month species disp  using `sim',  keep(3) nogen
gen sim_ul = sim_total+1.96*sim_sd
gen sim_ll = sim_total-1.96*sim_sd

sort  species disp mode
tempfile catch
save `catch', replace 


u  "$misc_data_cd\mrip_dtrip_by_mode_month.dta", clear 
rename se_mrip se_dtrip_mrip
rename ll ll_dtrip_mrip
rename ul ul_dtrip_mrip
rename dtrip_mrip tot_dtrip_mrip
reshape long tot_ se_ ll_ ul_, i(mode month) j(new) string
rename tot_ mrip_total 
rename ll mrip_ll
rename ul_ mrip_ul
drop se_
destring month, replace
rename new disp
replace disp="dtrip"
gen species="NA"
merge 1:1  mode month species disp  using `simdtrip', keep(3)

append using `catch'


replace disp="discards" if disp=="rel"
replace disp="harvest" if disp=="keep"
replace disp="catch" if disp=="cat"

gen domain=species+"_"+disp
replace domain="dtrip" if domain=="NA_dtrip"

ds mode disp species domain area_s common_dom, not
local var = r(varlist)
foreach v of local var{
	format `v' %14.0gc
}

gen pct_diff = ((sim_total-mrip_total)/mrip_total)*100
gen diff= sim_total-mrip_total

sort pct_diff
sort diff

tostring month, replace
tempfile new
save `new', replace 


levelsof disp, local(disp_list)

foreach s in `disp_list'{
	u `new', clear 
	keep if disp=="`s'"
	
	gen my_dom_id_string=month+"_"+mode
	encode my_dom_id_string , gen(my_dom_id)  
	gen my_dom_id_mrip = my_dom_id+0.1 
	gen my_dom_id_sim = my_dom_id-0.1  
		
	levelsof domain, local(domain_list)
		foreach d in `domain_list' {


/* Rebuild the axis labels by hand: my_dom_id is numeric with value labels, and
   twoway's xlabel() needs an explicit "value label" pair for each level. */
local xlabels ""
levelsof my_dom_id, local(levels)

foreach l of local levels {
    local label : label (my_dom_id) `l'
    local xlabels `xlabels' `l' "`label'"
}


qui twoway (rcap mrip_ul mrip_ll my_dom_id_mrip if domain=="`d'", color(blue)  ) ///
			(scatter mrip_total my_dom_id_mrip if domain=="`d'",  msymbol(o) mcolor(blue)) ///
			(rcap sim_ul sim_ll my_dom_id_sim if domain=="`d'",  color(red)) ///
			(scatter sim_total my_dom_id_sim if domain=="`d'", msymbol(o) mcolor(red)), ///
			legend(order(2 "MRIP estimate" 4 "Simulated estimate") size(small) rows(1)) ///
			ytitle("# ('000s)", xoffset(-3)) xtitle("") ylabel(#10,  angle(horizontal) ) ///
			xlabel(`xlabels',  angle(45) labsize(small)) ///
			title("`d'", size(medium)) name(`d'_`s', replace) 
		}
  }

u `new', clear 
grc1leg  cod_catch_catch  hadd_catch_catch cod_harvest_harvest  hadd_harvest_harvest , cols(2)  title("Catch totals, MRIP vs. simulated estimates", size(small))
graph export "$figure_cd/monthly_catch_total_MRIP_simulated.png", as(png) replace

grc1leg  dtrip_dtrip, cols(1)  title("Directed trip totals, MRIP vs. simulated estimates", size(small))
graph export "$figure_cd/monthly_dtrip_total_MRIP_simulated.png", as(png) replace
gr drop _all	
	
	
/******************************************************************************/
/******************************************************************************/
/* Section B3c: Compare catch totals at the mode level                        */
/******************************************************************************/
/******************************************************************************/

u "$misc_data_cd\simulated_catch_totals3.dta", replace
rename dtrip tot_dtrip_sim
ds draw mode month, not
local vars `r(varlist)'
foreach v of local vars{
	mvencode `v', mv(0) override
}

	
collapse (sum) tot_cod_keep_sim tot_cod_cat_sim tot_cod_rel_sim ///
						  tot_hadd_keep_sim tot_hadd_rel_sim tot_hadd_cat_sim ///
						  tot_dtrip_sim , by( mode draw)

collapse (mean) tot_cod_keep_sim tot_cod_cat_sim tot_cod_rel_sim ///
						  tot_hadd_keep_sim tot_hadd_rel_sim tot_hadd_cat_sim ///
						  tot_dtrip_sim ///
				(sd)	sd_cod_keep_sim=tot_cod_keep_sim sd_cod_cat_sim =tot_cod_cat_sim sd_cod_rel_sim =tot_cod_rel_sim ///
						  sd_hadd_keep_sim=tot_hadd_keep_sim sd_hadd_rel_sim =tot_hadd_rel_sim sd_hadd_cat_sim =tot_hadd_cat_sim ///
						  sd_dtrip_sim=tot_dtrip_sim, by( mode)
						  
reshape long tot_ sd_, i(mode) j(new) string
rename tot_ sim_total 
rename sd_ sim_sd
split new, parse(_)
rename new1 species
rename new2 disp
drop new3
drop new
replace disp="dtrip" if species=="dtrip"
replace species="NA" if disp=="dtrip"

preserve
keep if disp=="dtrip"
gen sim_ul = sim_total+1.96*sim_sd
gen sim_ll = sim_total-1.96*sim_sd
tempfile simdtrip
save `simdtrip', replace
restore 

drop if disp=="dtrip"
tempfile sim
save `sim', replace

u  "$misc_data_cd\mrip_catch_by_mode.dta", clear 
reshape long total se ll95 ul95, i(mode) j(new) string
rename tot mrip_total 
rename se mrip_se
rename ll mrip_ll
rename ul mrip_ul


split new, parse(_)
rename new1 species
rename new2 disp
drop new3
drop new my 
merge 1:1  mode  species disp  using `sim',  keep(3) nogen
gen sim_ul = sim_total+1.96*sim_sd
gen sim_ll = sim_total-1.96*sim_sd

sort  species disp mode
tempfile catch
save `catch', replace 


u  "$misc_data_cd\mrip_dtrip_by_mode.dta", clear 
rename se_mrip se_dtrip_mrip
rename ll ll_dtrip_mrip
rename ul ul_dtrip_mrip
rename dtrip_mrip tot_dtrip_mrip
reshape long tot_ se_ ll_ ul_, i(mode) j(new) string
rename tot_ mrip_total 
rename ll mrip_ll
rename ul_ mrip_ul
drop se_

rename new disp
replace disp="dtrip"
gen species="NA"
merge 1:1  mode species disp  using `simdtrip', keep(3)

append using `catch'

drop _merge mrip_se 

replace disp="discards" if disp=="rel"
replace disp="harvest" if disp=="keep"
replace disp="catch" if disp=="cat"

gen domain=species+"_"+disp
replace domain="dtrip" if domain=="NA_dtrip"

ds mode disp species domain area_s common_dom, not
local var = r(varlist)
foreach v of local var{
	format `v' %14.0gc
}

gen pct_diff = ((sim_total-mrip_total)/mrip_total)*100
gen diff= sim_total-mrip_total

sort pct_diff
sort diff

tempfile new
save `new', replace 

levelsof disp, local(disp_list)

foreach s in `disp_list'{
	u `new', clear 
	keep if disp=="`s'"
	
	gen my_dom_id_string=mode
	encode my_dom_id_string , gen(my_dom_id)  
	gen my_dom_id_mrip = my_dom_id+0.1 
	gen my_dom_id_sim = my_dom_id-0.1  
		
	levelsof domain, local(domain_list)
		foreach d in `domain_list' {


/* Rebuild the axis labels by hand: my_dom_id is numeric with value labels, and
   twoway's xlabel() needs an explicit "value label" pair for each level. */
local xlabels ""
levelsof my_dom_id, local(levels)

foreach l of local levels {
    local label : label (my_dom_id) `l'
    local xlabels `xlabels' `l' "`label'"
}


qui twoway (rcap mrip_ul mrip_ll my_dom_id_mrip if domain=="`d'", color(blue)  ) ///
			(scatter mrip_total my_dom_id_mrip if domain=="`d'",  msymbol(o) mcolor(blue)) ///
			(rcap sim_ul sim_ll my_dom_id_sim if domain=="`d'",  color(red)) ///
			(scatter sim_total my_dom_id_sim if domain=="`d'", msymbol(o) mcolor(red)), ///
			legend(order(2 "MRIP estimate" 4 "Simulated estimate") size(small) rows(1)) ///
			ytitle("# ('000s)", xoffset(-3)) xtitle("") ylabel(#10,  angle(horizontal) ) ///
			xlabel(`xlabels',  angle(45) labsize(small)) ///
			title("`d'", size(medium)) name(`d'_`s', replace) 
		}
  }

u `new', clear 
grc1leg  cod_catch_catch  hadd_catch_catch cod_harvest_harvest  hadd_harvest_harvest , cols(2)  title("Catch totals, MRIP vs. simulated estimates", size(small))
graph export "$figure_cd/catch_total_MRIP_simulated.png", as(png) replace

grc1leg  dtrip_dtrip, cols(1)  title("Directed trip totals, MRIP vs. simulated estimates", size(small))
graph export "$figure_cd/dtrip_total_MRIP_simulated.png", as(png) replace
gr drop _all



	
/******************************************************************************/
/******************************************************************************/
/* Section B3d: Compare catch totals at the mode-season level                 */
/******************************************************************************/
/******************************************************************************/

u "$misc_data_cd\simulated_catch_totals3.dta", replace
rename dtrip tot_dtrip_sim
ds draw mode month, not
local vars `r(varlist)'
foreach v of local vars{
	mvencode `v', mv(0) override
}


gen season= "winter" if inlist(month, 9, 10, 11, 12, 1, 2, 3, 4)
replace season="summer" if inlist(month, 5, 6, 7, 8)
	
collapse (sum) tot_cod_keep_sim tot_cod_cat_sim tot_cod_rel_sim ///
						  tot_hadd_keep_sim tot_hadd_rel_sim tot_hadd_cat_sim ///
						  tot_dtrip_sim , by( mode season draw)

collapse (mean) tot_cod_keep_sim tot_cod_cat_sim tot_cod_rel_sim ///
						  tot_hadd_keep_sim tot_hadd_rel_sim tot_hadd_cat_sim ///
						  tot_dtrip_sim ///
				(sd)	sd_cod_keep_sim=tot_cod_keep_sim sd_cod_cat_sim =tot_cod_cat_sim sd_cod_rel_sim =tot_cod_rel_sim ///
						  sd_hadd_keep_sim=tot_hadd_keep_sim sd_hadd_rel_sim =tot_hadd_rel_sim sd_hadd_cat_sim =tot_hadd_cat_sim ///
						  sd_dtrip_sim=tot_dtrip_sim, by( season mode)
						  
reshape long tot_ sd_, i(mode season) j(new) string
rename tot_ sim_total 
rename sd_ sim_sd
split new, parse(_)
rename new1 species
rename new2 disp
drop new3
drop new
replace disp="dtrip" if species=="dtrip"
replace species="NA" if disp=="dtrip"

preserve
keep if disp=="dtrip"
gen sim_ul = sim_total+1.96*sim_sd
gen sim_ll = sim_total-1.96*sim_sd
tempfile simdtrip
save `simdtrip', replace
restore 

drop if disp=="dtrip"
tempfile sim
save `sim', replace

u  "$misc_data_cd\mrip_catch_by_mode_season.dta", clear 
drop sec* seh*
reshape long total  ll95 ul95, i(mode season my) j(new) string
rename tot mrip_total 
rename ll mrip_ll
rename ul mrip_ul


split new, parse(_)
rename new1 species
rename new2 disp
drop new3
drop new my 
merge 1:1  mode  season species disp  using `sim',  keep(3) nogen
gen sim_ul = sim_total+1.96*sim_sd
gen sim_ll = sim_total-1.96*sim_sd

sort  species disp mode
tempfile catch
save `catch', replace 


u  "$misc_data_cd\mrip_dtrip_by_mode_season.dta", clear 
rename se_mrip se_dtrip_mrip
rename ll ll_dtrip_mrip
rename ul ul_dtrip_mrip
rename dtrip_mrip tot_dtrip_mrip
reshape long tot_ se_ ll_ ul_, i(mode season) j(new) string
rename tot_ mrip_total 
rename ll mrip_ll
rename ul_ mrip_ul
drop se_

rename new disp
replace disp="dtrip"
gen species="NA"
merge 1:1  mode species season disp  using `simdtrip', keep(3)

append using `catch'

drop _merge  

replace disp="discards" if disp=="rel"
replace disp="harvest" if disp=="keep"
replace disp="catch" if disp=="cat"

gen domain=species+"_"+disp
replace domain="dtrip" if domain=="NA_dtrip"

ds mode disp species domain area_s common_dom season, not
local var = r(varlist)
foreach v of local var{
	format `v' %14.0gc
}

gen pct_diff = ((sim_total-mrip_total)/mrip_total)*100
gen diff= sim_total-mrip_total

sort pct_diff
sort diff

tempfile new
save `new', replace 

levelsof disp, local(disp_list)

foreach s in `disp_list'{
	u `new', clear 
	keep if disp=="`s'"
	
	gen my_dom_id_string=season+"_"+mode
	encode my_dom_id_string , gen(my_dom_id)  
	gen my_dom_id_mrip = my_dom_id+0.1 
	gen my_dom_id_sim = my_dom_id-0.1  
		
	levelsof domain, local(domain_list)
		foreach d in `domain_list' {


/* Rebuild the axis labels by hand: my_dom_id is numeric with value labels, and
   twoway's xlabel() needs an explicit "value label" pair for each level. */
local xlabels ""
levelsof my_dom_id, local(levels)

foreach l of local levels {
    local label : label (my_dom_id) `l'
    local xlabels `xlabels' `l' "`label'"
}


qui twoway (rcap mrip_ul mrip_ll my_dom_id_mrip if domain=="`d'", color(blue)  ) ///
			(scatter mrip_total my_dom_id_mrip if domain=="`d'",  msymbol(o) mcolor(blue)) ///
			(rcap sim_ul sim_ll my_dom_id_sim if domain=="`d'",  color(red)) ///
			(scatter sim_total my_dom_id_sim if domain=="`d'", msymbol(o) mcolor(red)), ///
			legend(order(2 "MRIP estimate" 4 "Simulated estimate") size(small) rows(1)) ///
			ytitle("# ('000s)", xoffset(-3)) xtitle("") ylabel(#10,  angle(horizontal) ) ///
			xlabel(`xlabels',  angle(45) labsize(small)) ///
			title("`d'", size(medium)) name(`d'_`s', replace) 
		}
  }

u `new', clear 
grc1leg  cod_catch_catch  hadd_catch_catch cod_harvest_harvest  hadd_harvest_harvest , cols(2)  title("Catch totals, MRIP vs. simulated estimates", size(small))
graph export "$figure_cd/season_catch_total_MRIP_simulated.png", as(png) replace

grc1leg  dtrip_dtrip, cols(1)  title("Directed trip totals, MRIP vs. simulated estimates", size(small))
graph export "$figure_cd/season_dtrip_total_MRIP_simulated.png", as(png) replace
gr drop _all

/******************************************************************************/
/******************************************************************************/
/* Section C: FINAL STEP -- save the totals the rest of the pipeline uses     */
/******************************************************************************/
/******************************************************************************/

/* Only run once the diagnostics above show the simulated totals reasonably
   approximating MRIP. Two aggregations are saved: mode x season x draw for the
   R simulation, and season x draw for catch_at_length_calibration.do. */
u "$misc_data_cd\simulated_catch_totals3.dta", replace
rename dtrip tot_dtrip_sim
ds draw mode month, not
local vars `r(varlist)'
foreach v of local vars{
	mvencode `v', mv(0) override
}


gen season= "winter" if inlist(month, 9, 10, 11, 12, 1, 2, 3, 4)
replace season="summer" if inlist(month, 5, 6, 7, 8)


collapse (sum) tot_cod_keep_sim tot_cod_cat_sim tot_cod_rel_sim ///
						  tot_hadd_keep_sim tot_hadd_rel_sim tot_hadd_cat_sim ///
						  tot_dtrip_sim , by( mode season draw)
	  
save "$misc_data_cd\simulated_catch_totals.dta", replace 

collapse (sum) tot_cod_keep_sim tot_cod_cat_sim tot_cod_rel_sim ///
						  tot_hadd_keep_sim tot_hadd_rel_sim tot_hadd_cat_sim ///
						  tot_dtrip_sim , by( season draw)	
						  
save "$misc_data_cd\simulated_catch_totals_for_catch_length.dta", replace 

/* Shrink the catch-per-trip files: only the total-catch columns are needed
   downstream, so the keep/release splits are dropped and the files are saved
   over themselves.
   NOTE (flagged, code unchanged): this is destructive and not idempotent.
   Section B1 above collapses exactly these dropped columns, so re-running this
   script without first regenerating the calib_catch_draws files will fail. */
di "compare_calibration_data_to_MRIP: compressing catch-draw files ..."

mata: mata clear
clear

forvalues i = 1/$ndraws {
		use "$calib_catch_draws_cd\calib_catch_draws_`i'.dta", clear 
	   drop  cod_keep_sim cod_rel_sim hadd_keep_sim hadd_rel_sim  
	   compress
	   save  "$calib_catch_draws_cd\calib_catch_draws_`i'.dta", replace
	}


		

	
	
	