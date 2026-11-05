/*******************************************************************************
 Script:       projected_naa_uncertain.do
 Purpose:      Produces the projection-year mean numbers at age (NAA) for WGOM cod and 
			   GOM haddock. This removes the uncertainty in NAA to produce catch at 
			   length probabilities for the uncertainty project. 
 Inputs:       $misc_data_cd/WGOM_Cod_projected_NAA.dta
               $misc_data_cd/GOM_Haddock_projected_NAA.dta
 Outputs:      $misc_data_cd/WGOM_Cod_projected_NAA.dta
               $misc_data_cd/GOM_Haddock_projected_NAA.dta
 Dependencies: The assessment scripts get_cod_assessment_data.R /
               get_haddock_assessment_data.R (write the NAA files which we are overwriting).
 Pipeline:     Gated by `projected_naa_uncertain' in model_wrapper.do. The outputs are
			   then used in catch_at_length_projection.do. 
This script expects exactly 1 argument, which is can be "cod", "haddock", or "both".  
*******************************************************************************/


* Argument set in model_wrapper.do for which species to set deterministic in projected catch at length 
if `1'=="cod"{
local cod_catl_certain =1
}
else if `1'=="haddock"{
local haddock_catl_certain =1
}
else if `1'=="both"{
local cod_catl_certain =1
local cod_catl_certain =1
} 
else{
di "Warning message" or stop
}


* Take mean projected NAA and expand it out to 500 draws for cod
if `cod_catl_certain' {
use "$misc_data_cd/WGOM_Cod_projected_NAA.dta", clear

split metric, parse(" ") 
rename metric5 age 
keep age value year replicate 
destring age, replace 

collapse (mean) value, by(age)

gen row_id = _n
expand 500
bysort row_id: gen replicate = _n
sort replicate row_id
drop row_id

rename value uc_value

tempfile cod_uc
sort replicate age
save `cod_uc', replace


use "$misc_data_cd/WGOM_Cod_projected_NAA.dta", clear
split metric, parse(" ") 
rename metric5 age 
destring age, replace 
drop metric1-metric4

merge 1:1 replicate age using `cod_uc'
drop _merge age value
rename uc_value value 

save "$misc_data_cd\WGOM_Cod_projected_NAA.dta", replace
}


* Take mean projected NAA and expand it out to 500 draws for haddock
if `haddock_catl_certain' {
use "$misc_data_cd/GOM_Haddock_projected_NAA.dta", clear

split metric, parse(" ") 
rename metric5 age 
keep age value year replicate 
destring age, replace 

collapse (mean) value, by(age)

gen row_id = _n
expand 500
bysort row_id: gen replicate = _n
sort replicate row_id
drop row_id

rename value uc_value

tempfile had_uc
sort replicate age
save `had_uc', replace

use "$misc_data_cd/GOM_Haddock_projected_NAA.dta", clear
split metric, parse(" ") 
rename metric5 age 
destring age, replace 
drop metric1-metric4

merge 1:1 replicate age using `had_uc'
drop _merge age value
rename uc_value value 

save "$misc_data_cd\GOM_Haddock_projected_NAA.dta", replace
}


