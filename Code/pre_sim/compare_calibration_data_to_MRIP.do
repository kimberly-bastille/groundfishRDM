
*B) The copula model data is used to generate daily catch-draw data, so here, I:
		*1) compute mean catch-per-trip from the daily catch-draw data
		*2) compute total catch/harvest/discards from the daily catch-draw data by multiplying
		*    mean catch/harvest/discards-per trip by the number of trips in that day
		*3) compare catch-per-trip means and total simulated catch from 2) with estimates from MRIP, both at the mode-wave level and the mode level

*B1 and B2)  
clear
tempfile master
save `master', emptyok

forv i=1/$ndraws{
di "`i'"

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
	gen tot_`v'= dtrip*`v'
	
}

gen draw=`i'

append using `master'
save `master', replace
}

use `master', clear

save "$misc_data_cd\simulated_catch_totals3.dta", replace 


*B3 compare means @ mode month level
u "$misc_data_cd\simulated_catch_totals3.dta", clear 
rename dtrip tot_dtrip_sim

ds draw mode month, not
local vars `r(varlist)'
foreach v of local vars{
	mvencode `v', mv(0) override
}

order mode month draw

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

levelsof domain, local(domain_list)
	foreach d in `domain_list' {
		u `new', clear
		keep if domain=="`d'"
	
		encode my_dom_id_string, gen(my_dom_id)
		gen my_dom_id_mrip = my_dom_id+0.1 
		gen my_dom_id_sim = my_dom_id-0.1  

* Start by clearing any existing macro
local xlabels ""

* Loop over the levels of the encoded variable
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


*B3 compare catch totals @ mode and month level
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
drop new my area common
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

ds mode month disp species domain, not
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


* Start by clearing any existing macro
local xlabels ""

* Loop over the levels of the encoded variable
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
	
	
*B3 compare catch totals @ mode level
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
drop new my area common
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

ds mode disp species domain, not
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


* Start by clearing any existing macro
local xlabels ""

* Loop over the levels of the encoded variable
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



	
*B3 compare catch totals @ mode and season level
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
drop new my area common
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

ds mode season disp species domain, not
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


* Start by clearing any existing macro
local xlabels ""

* Loop over the levels of the encoded variable
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

** FINAL STEP

* Once the simulated totals approximate MRIP, save the data to be used in the R code simulation
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

* Remove extraneous columns from the catch-per-trip data
mata: mata clear
clear

forvalues i = 1/$ndraws {
		use "$calib_catch_draws_cd\calib_catch_draws_`i'.dta", clear 
	   drop  cod_keep_sim cod_rel_sim hadd_keep_sim hadd_rel_sim  
	   compress
	   save  "$calib_catch_draws_cd\calib_catch_draws_`i'.dta", replace
	}


		

	
	
	