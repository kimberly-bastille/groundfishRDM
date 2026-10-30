
/*******************************************************************************
 Dev paths note (no full script header yet - out of scope for this pass):
 5 hardcoded absolute paths to a developer's local machine (C:\ or E:\),
 at lines 3, 4, 5, 6 and 7 (the global path assignments below).
*******************************************************************************/

* adjust project paths based on user
global project_path "C:\Users\andrew.carr-harris\Desktop\Git\groundfishRDM" /* Lou's project path */
global input_data_cd "E:\Lou_projects\groundfishRDM\input_data" /* Lou's local data path */
global input_code_cd "C:\Users\andrew.carr-harris\Desktop\Git\groundfishRDM\Code\pre_sim"
global iterative_input_data_cd "E:\Lou_projects\groundfishRDM\process_data"
global figure_cd  "E:\Lou_projects\groundfishRDM\figures"



import delimited using "SQ_updated_hadd17_4_6_26_draws25.csv", clear
gen source = "25 draws"
tempfile draws25
save `draws25', replace

import delimited using "SQ_updated_hadd17_4_6_26_draws50.csv", clear
gen source = "50 draws"
tempfile draws50
save `draws50', replace

import delimited using "SQ_updated_hadd17_4_6_26_draws10.csv", clear
gen source = "10 draws"
tempfile draws10 
save `draws10 ', replace

append using `draws25'
append using `draws50'

/*
*merge to check differences
rename value value10
drop source
tempfile draws10 
save `draws10 ', replace

u `draws25', clear 
rename value value25
drop source
tempfile draws25 
save `draws25', replace

u `draws50', clear 
rename value value50
drop source

merge 1:1 metr species month mode draw using `draws25', keep(3) nogen 
merge 1:1 metr species month mode draw using `draws10', keep(3) nogen 
order metr species month mode draw

gen pct_diff_25_50=((value25-value50)/value50)*100
gen pct_diff_10_50=((value10-value50)/value50)*100
*/

format value* %12.02gc
sort source metric species month mode draw
keep if mode=="all modes"

*keep if inlist(month, 9, 10)
*drop if month==11
collapse (sum) value, by(metric species draw source)
replace value=value/2205 if strmatch(metric, "*weight*")==1
replace value=value*-1 if metric=="CV" 	
replace value=value/1000000 if metric=="CV" 	

format value* %12.02gc
sort source metric species   draw


preserve
keep if inlist(metric, "keep_numbers", "release_numbers")
collapse (sum) value, by(species draw  source)
gen metric="catch_numbers"
tempfile catch
save `catch', replace
restore
append using `catch'


*keep if inlist(month, 9, 10)
*drop if month==11

local metrics "catch_numbers discmort_number discmort_weight keep_numbers keep_weight release_numbers release_weight removals_number removals_weight"

foreach m of local metrics{
	
vioplot value if metric=="`m'" & species=="cod", over(source)  ///
title("`m'", size(medium))  name(`m', replace) ///
				ylab(#8, labsize(small) ) ytitle("`m'") ///
			 xlab(1 "10 draws" ///
					2 "25 draws" ///
			 		3 "50 draws " , ///
			 noticks labsize(vsmall) ) xtitle("") note("") ytitle("`m'", size(small)) ylab(,labsize(small))
}

graph combine ///
    catch_numbers ///
    discmort_number ///
    discmort_weight ///
    keep_numbers ///
    keep_weight ///
    release_numbers ///
    release_weight ///
    removals_number ///
    removals_weight, ///
    cols(3) imargin(small) ///
    title("Cod comparison across metrics")


local metrics "catch_numbers discmort_number discmort_weight keep_numbers keep_weight release_numbers release_weight removals_number removals_weight"
foreach m of local metrics{
	
vioplot value if metric=="`m'" & species=="hadd", over(source)  ///
title("`m'", size(medium))  name(`m', replace) ///
				ylab(#8, labsize(small) ) ytitle("`m'") ///
			 xlab(1 "10 draws" ///
					2 "25 draws" ///
			 		3 "50 draws " , ///
			 noticks labsize(vsmall) ) xtitle("") note("") ytitle("`m'", size(small)) ylab(,labsize(small))
}

graph combine ///
    catch_numbers ///
    discmort_number ///
    discmort_weight ///
    keep_numbers ///
    keep_weight ///
    release_numbers ///
    release_weight ///
    removals_number ///
    removals_weight, ///
    cols(3) imargin(small) ///
    title("Haddock comparison across metrics")	
	

local metrics "CV additional_trips"
foreach m of local metrics{
	
vioplot value if metric=="`m'", over(source)  ///
title("`m'", size(medium))  name(`m', replace) ///
				ylab(#8, labsize(small) ) ytitle("`m'") ///
			 xlab(1 "10 draws" ///
					2 "25 draws" ///
			 		3 "50 draws " , ///
			 noticks labsize(vsmall) ) xtitle("") note("") ytitle("`m'", size(small)) ylab(,labsize(small))
}

graph combine ///
    CV ///
    additional_trips, ///
    cols(3) imargin(small) ///
    title("Trips and CV comparison across metrics")		
	
	
	

local metrics "catch_numbers discmort_number discmort_weight keep_numbers keep_weight release_numbers release_weight removals_number removals_weight"
foreach m of local metrics{
	
gr box value if metric=="`m'" & species=="cod", over(source)  ///
title("`m'", size(medium))  name(`m', replace) ///
				ylab(#8, labsize(small) ) ytitle("`m'") ///
note("") ytitle("`m'", size(small)) ylab(,labsize(small))
}

graph combine ///
    catch_numbers ///
    discmort_number ///
    discmort_weight ///
    keep_numbers ///
    keep_weight ///
    release_numbers ///
    release_weight ///
    removals_number ///
    removals_weight, ///
    cols(3) imargin(small) ///
    title("Cod comparison across metrics", size(medium))

	

local metrics "catch_numbers discmort_number discmort_weight keep_numbers keep_weight release_numbers release_weight removals_number removals_weight"
foreach m of local metrics{
	
gr box value if metric=="`m'" & species=="hadd", over(source)  ///
title("`m'", size(medium))  name(`m', replace) ///
				ylab(#8, labsize(small) ) ytitle("`m'") ///
note("") ytitle("`m'", size(small)) ylab(,labsize(small))
}

graph combine ///
    catch_numbers ///
    discmort_number ///
    discmort_weight ///
    keep_numbers ///
    keep_weight ///
    release_numbers ///
    release_weight ///
    removals_number ///
    removals_weight, ///
    cols(3) imargin(small) ///
    title("Haddock comparison across metrics", size(medium))
		


local metrics "CV additional_trips"
foreach m of local metrics{
	
gr box value if metric=="`m'", over(source)  ///
title("`m'", size(medium))  name(`m', replace) ///
				ylab(#8, labsize(small) ) ytitle("`m'") ///
note("") ytitle("`m'", size(small)) ylab(,labsize(small))
}

graph combine ///
    CV ///
    additional_trips, ///
    cols(3) imargin(small) ///
    title("Trips and CV comparison across metrics", size(medium))