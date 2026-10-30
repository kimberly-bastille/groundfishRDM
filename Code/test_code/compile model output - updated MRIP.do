
/*******************************************************************************
 Dev paths note (no full script header yet - out of scope for this pass):
 6 hardcoded absolute paths to a developer's local machine (C:\ or E:\),
 at lines 3, 4, 5, 6, 7 and 28.
*******************************************************************************/

* adjust project paths based on user
global project_path "C:\Users\andrew.carr-harris\Desktop\Git\groundfishRDM" /* Lou's project path */
global input_data_cd "E:\Lou_projects\groundfishRDM\input_data" /* Lou's local data path */
global input_code_cd "C:\Users\andrew.carr-harris\Desktop\Git\groundfishRDM\Code\pre_sim"
global iterative_input_data_cd "E:\Lou_projects\groundfishRDM\process_data"
global figure_cd  "E:\Lou_projects\groundfishRDM\figures"

* set a global seed #
global seed 03211990

* years/waves of MRIP data. 
global yr_wvs 20231 20232 20233 20234 20235 20236  ///
					 20241 20242 20243 20244 20245 20246  ///
					 20251 20252 20253 20254 20255 20256
					 
global yearlist 2023 2024 2025
global wavelist 1 2 3 4 5 6

global calibration_year "(year==2025 & inlist(wave, 1, 2, 3, 4, 5)) | (year==2024 & inlist(wave, 6))"  // last six waves of data 

// Pull the MRIP data for comparison with model output
*do "$input_code_cd\MRIP data wrapper.do"


* This file computes predictions of harvest in weight in 2026 under acual status quo regulations (SQ) and proposed status quo regulations (SQ_alt)
/*
cd "C:\Users\andrew.carr-harris\Desktop\Git\groundfishRDM\Code\test_code"
import delimited using "cod_hadd_SQ_output_monthly_1_13.csv", clear
gen source = "FY25 actual regulations"
tempfile sq
save `sq', replace

import delimited using "cod_hadd_SQalt_output_monthly_1_13.csv", clear
gen source = "FY25 proposed regulations"
tempfile prop
save `prop', replace
*/
import delimited using "SQ_updated_2_19.csv", clear
gen source = "FY25 actual - updated MRIP"
tempfile sq_updated
save `sq_updated', replace

import delimited using "SQalt_updated_2_19.csv", clear
gen source = "FY25 proposed - updated MRIP"
tempfile prop_updated
save `prop_updated', replace

import delimited using "KLB8_updated_2_19.csv", clear
gen source = "KLB8 (close September) - updated MRIP"
tempfile KLB8_updated
save `KLB8_updated', replace

import delimited using "WRTIII5_updated_2_19.csv", clear
gen source = "WRTIII5 (close private) - updated MRIP"
tempfile WRTIII5_updated
save `WRTIII5_updated', replace

import delimited using "SQ_updated_hadd17_2_19.csv", clear
gen source = "FY25 actual cod; haddock 17 - updated MRIP"
tempfile hadd17
save `hadd17', replace

preserve
u `WRTIII5_updated', clear 
drop source 
rename value value_close_pr

merge 1:1 metric species month mode draw using `KLB8_updated', keep(3) nogen 
drop source 
rename value value_close_sep

merge 1:1 metric species month mode draw using `prop_updated', keep(3) nogen 
drop source 
rename value value_prop24_updated


drop if mode=="all modes"
restore


*append using `sq'
*append using `prop'
append using `sq_updated'
append using `prop_updated'
append using `KLB8_updated'
append using `WRTIII5_updated'


format value* %12.02gc
sort source metric species month mode draw
keep if mode=="all modes"


*keep if inlist(month, 9, 10)
*drop if month==11
collapse (sum) value, by(metric species draw source)
replace value=value/2205 if strmatch(metric, "*weight*")==1
replace value=value*-1 if metric=="CV" 	
replace value=value/1000000 if metric=="CV" 	


*incorporate reduced from estimates 
*a) add 40 mt to open may
expand 2 if metric=="removals_weight" & species=="cod" & inlist(source, "FY25 proposed", "FY25 proposed - updated MRIP"), gen(dup)
replace source=source+"*" if dup==1
replace value=value+40 if metric=="removals_weight" & species=="cod" & inlist(source, "FY25 proposed*", "FY25 proposed - updated MRIP*")
drop dup

* assess how our model predicts the impact of closing September on cod
preserve 
keep if metric=="removals_weight" & species=="cod"  & inlist(source, "FY25 actual regulations - updated MRIP") 
drop source
rename value value_actual 
tempfile actual
save `actual', replace
restore

preserve 
keep if metric=="removals_weight" & species=="cod"  & inlist(source,"KLB8 (close September) - updated MRIP") 
rename value value_close_sep 
drop source
merge 1:1 metric species draw using `actual', nogen 

gen diff=value_actual -value_close_sep
su diff //17.3 metric tons, very close to the reduced form estimate, so no adjustment
restore


* create a total catch statistic
preserve
keep if inlist(metric, "keep_numbers", "release_numbers")
collapse (sum) value, by(species draw  source)
gen metric="catch_numbers"
tempfile catch
save `catch', replace
restore
append using `catch'

collapse (sum) value, by(metric species  draw source)
sort metric species source draw
*keep if metric=="removals_weight"

*keep if draw<=100
/*
FY2026 sub-ACLs:
	GOM haddock – 1,146 mt
	WGOM cod – 118 mt
*/


/*
keep if inlist(source, "FY25 actual regulations - updated MRIP", "FY25 proposed regulations - updated MRIP", "FY25 proposed regulations - updated MRIP*", ///
"KLB8 (close September) - updated MRIP", "WRTIII5 (close private) - updated MRIP")
*/

keep if inlist(source,"FY25 actual - updated MRIP", "KLB8 (close September) - updated MRIP", "WRTIII5 (close private) - updated MRIP", "FY25 actual cod; haddock 17 - updated MRIP")

*cod
count if metric=="removals_weight" & species=="cod" & source=="FY25 actual - updated MRIP" & value<=118
di "percent below ACL   " round((`r(N)'/201)*100, .01)

su value if metric=="removals_weight" & species=="cod" & source=="FY25 actual - updated MRIP", detail 
di "median value   " round(`r(p50)', .01)


count if metric=="removals_weight" & species=="cod" & source=="WRTIII5 (close private) - updated MRIP" & value<=118
di "percent below ACL   " round((`r(N)'/201)*100, .01)

su value if metric=="removals_weight" & species=="cod" & source=="WRTIII5 (close private) - updated MRIP", detail 
di "median value   " round(`r(p50)', .01)


count if metric=="removals_weight" & species=="cod" & source=="KLB8 (close September) - updated MRIP" & value<=118
di "percent below ACL   " round((`r(N)'/201)*100, .01)

su value if metric=="removals_weight" & species=="cod" & source=="KLB8 (close September) - updated MRIP", detail 
di "median value   " round(`r(p50)', .01)


count if metric=="removals_weight" & species=="cod" & source=="FY25 actual cod; haddock 17 - updated MRIP" & value<=118
di "percent below ACL   " round((`r(N)'/201)*100, .01)

su value if metric=="removals_weight" & species=="cod" & source=="FY25 actual cod; haddock 17 - updated MRIP", detail 
di "median value   " round(`r(p50)', .01)

count if metric=="removals_weight" & species=="cod" & source=="FY25 proposed - updated MRIP*" & value<=118
di "percent below ACL   " round((`r(N)'/201)*100, .01)

su value if metric=="removals_weight" & species=="cod" & source=="FY25 proposed - updated MRIP*", detail 
di "median value   " round(`r(p50)', .01)

*haddock
count if metric=="removals_weight" & species=="hadd" & source=="FY25 actual - updated MRIP" & value<=1146
di "percent below ACL   " round((`r(N)'/201)*100, .01)

su value if metric=="removals_weight" & species=="hadd" & source=="FY25 actual - updated MRIP", detail 
di "median value   " round(`r(p50)', .01)

count if metric=="removals_weight" & species=="hadd" & source=="WRTIII5 (close private) - updated MRIP" & value<=1146
di "percent below ACL   " round((`r(N)'/201)*100, .01)

su value if metric=="removals_weight" & species=="hadd" & source=="WRTIII5 (close private) - updated MRIP", detail 
di "median value   " round(`r(p50)', .01)


count if metric=="removals_weight" & species=="hadd" & source=="KLB8 (close September) - updated MRIP" & value<=1146
di "percent below ACL   " round((`r(N)'/201)*100, .01)

su value if metric=="removals_weight" & species=="hadd" & source=="KLB8 (close September) - updated MRIP", detail 
di "median value   " round(`r(p50)', .01)


count if metric=="removals_weight" & species=="hadd" & source=="FY25 actual cod; haddock 17 - updated MRIP" &  value<=1146
di "percent below ACL   " round((`r(N)'/201)*100, .01)

su value if metric=="removals_weight" & species=="hadd" & source=="FY25 actual cod; haddock 17 - updated MRIP", detail 
di "median value   " round(`r(p50)', .01)


vioplot value if metric=="removals_weight" & species=="cod", over(source) yline(118) ///
title("Projected cod removal weight (mt)", size(medium))  name(`d', replace) ///
				yline(118,  lcolor(navy)   lpattern(dash)) ///
				ylab(#8, labsize(small) ) ytitle("total removals (mt)") ///
				text(128 4.1 "cod ACL", place(e) size(vsmall)) ///
			 xlab(1 "FY25 actual" ///
			 		2 "FY25 actual cod, haddock 17" ///
					3 "Close September" ///
					4 "Close private", ///
			 noticks labsize(vsmall) ) xtitle("") note("") ytitle("total removals (mt)", size(small)) ylab(,labsize(small))
			 
vioplot value if metric=="removals_weight" & species=="hadd", over(source) ///
title("Projected haddock removal weight (mt)", size(medium))  name(`d', replace) ///
				yline(1146,  lcolor(navy)   lpattern(dash)) ///
				ylab(#8, labsize(small) ) ytitle("total removals (mt)") ///
				text(1200 3.1 "haddock ACL", place(e) size(vsmall)) ///
			 xlab(1 "FY25 actual" ///
			 		2 "FY25 actual cod, haddock 17" ///
					3 "Close September" ///
					4 "Close private", ///
			 noticks labsize(vsmall) ) xtitle("") note("") ytitle("total removals (mt)", size(small)) ylab(,labsize(small))
	

vioplot value if metric=="CV" , over(source)  ///
title("Compensating variation ($)", size(medium))  name(`d', replace) ///
				ylab(#14, labsize(small) )  ///
			 xlab(1 "FY25 actual" ///
			 		2 "FY25 actual cod, haddock 17" ///
					3 "Close September" ///
					4 "Close private", ///
			 noticks labsize(vsmall) ) xtitle("") note("") ytitle("Millions of dollars", size(small)) ylab(,labsize(small))
			 
vioplot value if metric=="catch_numbers" , over(source)  ///
title("Compensating variation ($)", size(medium))  name(`d', replace) ///
				ylab(#8, labsize(small) )  ///
			 xlab(1 "FY25 actual" ///
			 2 "Close September" ///
			 3 "Close private", ///
			 noticks labsize(vsmall) ) xtitle("") note("") ytitle("CV ($)", size(small)) ylab(,labsize(small))		 
vioplot value if metric=="keep_weight" & species=="cod", over(source)  ///
title("Projected cod harvest weight (mt)", size(medium))  name(`d', replace) ///
				ylab(#8, labsize(small) ) ytitle("total harvest (mt)") ///
			 xlab(1 "FY25 actual - updated" ///
			 2 "FY25 proposed - updated" ///
			 3 "Close September - updated" ///
			 4 "Close private - updated", ///
			 noticks labsize(vsmall) angle(45)) xtitle("") note("") ytitle("", size(small)) ylab(,labsize(small))
			 
vioplot value if metric=="discmort_weight_weight" & species=="cod", over(source)  ///
title("Projected cod harvest weight (mt)", size(medium))  name(`d', replace) ///
				ylab(#8, labsize(small) ) ytitle("total harvest (mt)") ///
			 xlab(1 "FY25 actual - updated" ///
			 2 "FY25 proposed - updated" ///
			 3 "Close September - updated" ///
			 4 "Close private - updated", ///
			 noticks labsize(vsmall) angle(45)) xtitle("") note("") ytitle("", size(small)) ylab(,labsize(small))			 
			 
			 
vioplot value if metric=="discmort_weight" & species=="cod" & source=="WRTIII5 (close private) - updated MRIP"


gen domain=species+"_"+metric+"_"+source

count if metric=="removals_weight" & species=="cod" & source=="FY25 actual regulations" & value<=118
di "percent below ACL   " round((`r(N)'/201)*100, .01)

count if metric=="removals_weight" & species=="cod" & source=="FY25 proposed regulations" & value<=118
di "percent below ACL   " round((`r(N)'/201)*100, .01)

count if metric=="removals_weight" & species=="cod" & source=="FY25 actual regulations - updated MRIP" & value<=118
di "percent below ACL   " round((`r(N)'/201)*100, .01)

count if metric=="removals_weight" & species=="cod" & source=="FY25 proposed regulations - updated MRIP" & value<=118
di "percent below ACL   " round((`r(N)'/201)*100, .01)

count if metric=="removals_weight" & species=="cod" & source=="KLB8 (close September) - updated MRIP" & value<=118
di "percent below ACL   " round((`r(N)'/201)*100, .01)

count if metric=="removals_weight" & species=="cod" & source=="WRTIII5 (close private) - updated MRIP" & value<=118
di "percent below ACL   " round((`r(N)'/201)*100, .01)

vioplot value if metric=="removals_weight" & species=="cod", over(source) yline(118) ///
title("Projected cod removal weight (mt)", size(medium))  name(`d', replace) ///
				yline(118,  lcolor(navy)   lpattern(dash)) ///
				ylab(#8, labsize(small) ) ytitle("total removals (mt)") ///
				text(125 0.5 "cod ACL", place(e) size(small)) ///
			 xlab(1 "FY25 actual" 
			 2 "FY25 actual - updated" 
			 3 "FY25 proposed" ///
			 4 "FY25 proposed - updated" 
			 5 "FY25 proposed - updated*" 
			 5 "Close September - updated" 
			 6 "Close private - updated", ///
			 noticks labsize(vsmall) angle(45)) xtitle("") note("") ytitle("", size(small)) ylab(,labsize(small) )
			 
			 name(cod_removals, replace))

replace value=value+40 if metric=="removals_weight" & species=="cod" & inlist(source, "FY25 proposed regulations", "FY25 proposed regulations - updated MRIP")
replace value=max(0, value-18) if metric=="removals_weight" & species=="cod"  & inlist(source, "KLB8 (close September) - updated MRIP")
*replace value=max(0, value-18) if metric=="removals_weight" & species=="cod"  & mode=="pr" & inlist(source, "KLB8 (close September) - updated MRIP")

vioplot value if metric=="catch_numbers" & species=="cod", over(source) yline(118) ///
title("Projected cod removal weight (mt)", size(medium))  name(`d', replace) ///
				yline(118,  lcolor(navy)   lpattern(dash)) ///
				ylab(#8, labsize(small) ) ytitle("total removals (mt)") ///
				text(125 0.5 "cod ACL", place(e) size(small)) ///
			 xlab(1 "FY25 actual" 2 "FY25 actual - updated" 3 "FY25 proposed*" ///
			 4 "FY25 proposed - updated*" 5 "Close September - updated*" 6 "Close private - updated", ///
			 noticks labsize(vsmall) angle(45)) xtitle("") note("") ytitle("", size(small)) ylab(,labsize(small))
			 
			 
tempfile base
save `base', replace
*centile value if domain=="cod_removals_weight_FY25 actual regulations", centile(2.5 5 50 95 97.5)

*vioplot value if metric=="removals_weight" & species=="cod", lcolor(navy) over(source)




levelsof domain, local(doms)

clear
tempfile ptiles
save `ptiles', emptyok

foreach d of local doms{
u `base', clear 

*local d "cod_removals_weight_FY25 actual regulations"
centile value if domain=="`d'", centile(2.5 5 50 95 97.5)

local p2_5    = r(c_1)
local p5   = r(c_2)
local p50   = r(c_3)
local p95   = r(c_4)
local p97_5   = r(c_5)


su value if domain=="`d'" & value>=`p2_5' & value<=`p97_5'
local lb95=`r(min)'
local ub95=`r(max)'

su value if domain=="`d'" & value>=`p5' & value<=`p95'
local lb90=`r(min)'
local ub90=`r(max)'

clear
set obs 1
gen domain="`d'"
gen lb95=`p5'
gen ub95=`ub95'
gen p50=`p50'
gen lb90=`lb90'
gen ub90 = `ub90'

append using `ptiles'
save `ptiles', replace
}

use `ptiles', clear

split domain, parse(_)
rename domain1 species
gen metric= domain2+"_"+domain3 if domain4!=""
replace metric=domain2 if domain4==""
rename domain4 source
replace source=domain3 if source==""

drop domain2 domain3  domain
order species  metric  source lb95 lb90 p50 ub90 ub95

encode source, gen(source2)
gen domain=species+"_"+metric
replace domain=metric if inlist(metric, "CV") | strmatch(metric, "*trips")==1

local vars p50 lb90 ub90 lb95 ub95
foreach v of local vars{
	format  `v' %12.02gc

}



twoway  (rcap lb95 ub95 source2  if domain=="cod_removals_weight", lcolor(navy) ) ///
			(scatter p50 source2 if domain=="cod_removals_weight",  msymbol(O) msize(small)  mcolor(black)   ///
			title("Projected cod removal weight (mt)", size(medium))  name(`d', replace) ///
				yline(118,  lcolor(navy)   lpattern(dash)) ///
				ylab(#8, labsize(small) ) ytitle("total removals (mt)") ///
				text(125 0.5 "cod ACL", place(e) size(small)) ///
			 xlab(1 "FY25 actual" 2 "FY25 actual - updated" 3 "FY25 proposed" ///
			 4 "FY25 proposed - updated" 5 "Close September - updated" 6 "Close private - updated", ///
			 noticks labsize(vsmall) angle(45)) xtitle("") note("") ytitle("", size(small)) ylab(,labsize(small)) ///
			 legend(order(1 "90% CI" 2 "95% CI" ) pos(6) rows(1) size(small) region(lstyle(none))) )

vioplot value if domain=="cod_removals_weight", lcolor(navy) 
			 
				yline(118,  lcolor(navy)   lpattern(dash)) ///
	ylab(#8, labsize(small) ) ytitle("total removals (mt)") ///
    text(125 0.5 "cod ACL", place(e) size(small)) ///
			 xlab(1 "FY25 actual regulations" 2 "FY25 actual regulations - updated MRIP" 3 "FY25 proposed regulations" 4 "FY25 proposed regulations - updated MRIP" 5 "KLB8 (close September) - updated MRIP" 6 "WRTIII5 (close private) - updated MRIP", noticks labsize(vsmall) angle(45)) xtitle("") note("") ytitle("", size(small)) ylab(,labsize(small)) ///
			 legend(order(1 "90% CI" 2 "95% CI" ) pos(6) rows(1) size(small) region(lstyle(none))) )
			


/*
FY2026 sub-ACLs:
GOM haddock – 1,146 mt
WGOM cod – 118 mt
*/

*harvest based on age-length weights


levelsof domain if inlist(metric, "keep_weight") ,  local(doms)
foreach d of local doms{

levelsof species if dom=="`d'"
if `r(levels)'=="cod"{
	local sp="Cod"
}
if `r(levels)'=="hadd"{
	local sp="Haddock"
}


twoway  (rcap lb90 ub90 source2_90  if domain=="`d'", lcolor(navy)) ///
			 (rcap lb95 ub95 source2_95 if domain=="`d'", lcolor(blue)) ///
			(scatter p50 source2_90 if domain=="`d'", mcolor(black) msymbol(O) msize(small) ) ///
			(scatter p50 source2_95 if domain=="`d'", msymbol(O) msize(small)  mcolor(black) title("`sp', `md'", size(medium))  name(`d', replace) ///
			 xlab(1 " " 2 "MRIP 2024" 3 "RDM 2026" 4 " ", noticks labsize(small)  ) xtitle("") note("") ytitle("", size(small)) ylab(,labsize(small)) ///
			 legend(order(1 "90% CI" 2 "95% CI" ) pos(6) rows(1) size(small) region(lstyle(none))) )
			

 }
 
grc1leg cod_fh_keep_weight hadd_fh_keep_weight cod_pr_keep_weight hadd_pr_keep_weight, rows(2) title("Coastwide harvest (metric tons)",size(medium))  ///
	note("MRIP 2024: survey-weighted estimate and SE-based CIs" "RDM 2026: median and percentile-based CIs" , size(small) yoffset(-2)) 

***Total removals
*(a) cod
gr box value if metric=="removals_weight" & mode=="all modes" & species=="cod", over(source)  ///
	yline(118,  lcolor(navy)   lpattern(dash)) ///
	ylab(#8, labsize(small) ) ytitle("total removals (mt)") ///
    text(125 0.5 "cod ACL", place(e) size(small)) ///
    graphregion(margin(b+8)) title("Predicted FY26 cod removals", size(medium))  name(cod_mort, replace)  
	
graph export $figure_cd\predicted_cod_mort.jpg, width(1024) height(768) replace

*(b) haddock
su value if metric=="removals_weight" & mode=="all modes" & species=="hadd" & source=="FY25 actual regulations", detail
return list
local med_sq=round(r(p50))

su value if metric=="removals_weight" & mode=="all modes" & species=="hadd" & source=="FY25 proposed regulations", detail
return list
local med_sq_alt=round(r(p50))

su value if metric=="removals_weight" & mode=="all modes" & species=="hadd" & source=="FY25 proposed regulations Kim", detail
return list
local med_sq_alt_kim=round(r(p50))


gr box value if metric=="removals_weight" & mode=="all modes" & species=="hadd", over(source)  ///
	yline(1146,  lcolor(navy)   lpattern(dash)) ///
	ylab(#8, labsize(small)) ytitle("total removals (mt)") ///
    text(1200 0.5 "haddock ACL", place(e) size(small)) ///
	note("Median predicted removals under:" "   FY25 actual regulations = `med_sq' mt" "   FY25 proposed regulations = `med_sq_alt' mt" "   Kim FY25 proposed regulations = `med_sq_alt_kim' mt" , yoffset(-6)) ///
    graphregion(margin(b+8)) title("Predicted FY26 haddock removals", size(medium)) name(hadd_mort, replace)
	
graph export $figure_cd\predicted_hadd_mort.jpg, width(1024) height(768) replace



***Harvest 
*(a) cod
su value if metric=="keep_weight" & mode=="all modes" & species=="cod" & source=="FY25 actual regulations", detail
return list
local med_sq=round(r(p50))

su value if metric=="keep_weight" & mode=="all modes" & species=="cod" & source=="FY25 proposed regulations", detail
return list
local med_sq_alt=round(r(p50))

gr box value if metric=="keep_weight" & mode=="all modes" & species=="cod", over(source)  ///
	ylab(#8, labsize(small)) ytitle("harvest (mt)") ///
	note("Median predicted harvest under:" "   FY25 actual regulations = `med_sq' mt" "   FY25 proposed regulations = `med_sq_alt' mt" , yoffset(-6)) ///
    graphregion(margin(b+8)) title("Predicted FY26 cod harvest", size(medium))
	
graph export $figure_cd\predicted_cod_harv.jpg, width(1024) height(768) replace

*(b) haddock
su value if metric=="release_weight" & mode=="all modes" & species=="hadd" & source=="FY25 actual regulations", detail
return list
local med_sq=round(r(p50))

su value if metric=="release_weight" & mode=="all modes" & species=="hadd" & source=="FY25 proposed regulations", detail
return list
local med_sq_alt=round(r(p50))

gr box value if metric=="release_weight" & mode=="all modes" & species=="hadd", over(source)  ///
	ylab(#8, labsize(small)) ytitle("harvest (mt)") ///
	note("Median predicted harvest under:" "   FY25 actual regulations = `med_sq' mt" "   FY25 proposed regulations = `med_sq_alt' mt" , yoffset(-6)) ///
    graphregion(margin(b+8)) title("Predicted FY26 haddock harvest", size(medium))
	
graph export $figure_cd\predicted_hadd_harv.jpg, width(1024) height(768) replace

	
***Discard mortlaity  
*(a) cod
su value if metric=="discmort_weight" & mode=="all modes" & species=="cod" & source=="FY25 actual regulations", detail
return list
local med_sq=round(r(p50))

su value if metric=="discmort_weight" & mode=="all modes" & species=="cod" & source=="FY25 proposed regulations", detail
return list
local med_sq_alt=round(r(p50))

gr box value if metric=="discmort_weight" & mode=="all modes" & species=="cod", over(source)  ///
	ylab(#8, labsize(small)) ytitle("discard mortality (mt)") ///
	note("Median predicted discard mortality under:" "   FY25 actual regulations = `med_sq' mt" "   FY25 proposed regulations = `med_sq_alt' mt" , yoffset(-6)) ///
    graphregion(margin(b+8)) title("Predicted FY26 cod discard mortality", size(medium
	
graph export $figure_cd\predicted_cod_discmort.jpg, width(1024) height(768) replace

*(b) haddock
su value if metric=="discmort_weight" & mode=="all modes" & species=="hadd" & source=="FY25 actual regulations", detail
return list
local med_sq=round(r(p50))

su value if metric=="discmort_weight" & mode=="all modes" & species=="hadd" & source=="FY25 proposed regulations", detail
return list
local med_sq_alt=round(r(p50))

gr box value if metric=="discmort_weight" & mode=="all modes" & species=="hadd", over(source)  ///
	ylab(#8, labsize(small)) ytitle("discard mortality (mt)") ///
	note("Median predicted discard mortality under:" "   FY25 actual regulations = `med_sq' mt" "   FY25 proposed regulations = `med_sq_alt' mt" , yoffset(-6)) ///
    graphregion(margin(b+8)) title("Predicted FY26 haddock discard mortality", size(medium))	
	
graph export $figure_cd\predicted_hadd_discmort.jpg, width(1024) height(768) replace
