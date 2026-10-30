/*******************************************************************************
 Script:       MRIP_column_cases.do
 Purpose:      Lowercases the variable names in the MRIP trip / size / size_b2 /
               catch files, one file per year-wave, so downstream code can rely
               on consistent lower-case column names. Intended to be run once
               after new MRIP data enters the repo.
 Inputs:       $misc_data_cd/{trip,size,size_b2,catch}_<yr_wv>.dta for each
               year-wave in $yr_wvs.
 Outputs:      The same files, overwritten in place with lower-cased names.
 Dependencies: Globals $misc_data_cd and $yr_wvs (set in model_wrapper.do);
               the renvarlab command (renvars package).
 Pipeline:     Wrapped by model_wrapper.do but gated by `processMRIP', which is
               DEFAULT OFF. The developers' comments label this script as
               "dead code" — it is retained but not run in the normal pipeline.

*******************************************************************************/


qui foreach wave in	$yr_wvs {

capture confirm file "${misc_data_cd}/trip_`wave'.dta"
if _rc==0{
	use "${misc_data_cd}/trip_`wave'.dta", clear
	renvarlab, lower
	save "${misc_data_cd}/trip_`wave'.dta", replace
}

else{
	
}

capture confirm file "${misc_data_cd}/size_b2_`wave'.dta"
if _rc==0{
	use "${misc_data_cd}/size_b2_`wave'.dta", clear
	renvarlab, lower
	save ""${misc_data_cd}/size_b2_`wave'.dta", replace
}

else{
	
}

capture confirm file "${misc_data_cd}/size_`wave'.dta"
if _rc==0{
	use "${misc_data_cd}/size_`wave'.dta", clear
	renvarlab, lower
	save "${misc_data_cd}/size_`wave'.dta", replace
}

else{
	
}

capture confirm file "${misc_data_cd}/catch_`wave'.dta"
if _rc==0{
	use "${misc_data_cd}/catch_`wave'.dta", clear
	renvarlab, lower
	save "${misc_data_cd}/catch_`wave'.dta", replace
}

else{
	
}

}


