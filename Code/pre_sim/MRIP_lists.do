/*******************************************************************************
 Script:       MRIP_lists.do
 Purpose:      Builds the MRIP file-list globals $catchlist/$triplist/$b2list/
               $sizelist as space-separated lists of one .dta per year x wave that
               both exists and has observations. This was important when data were 
			   provisioned in flat .sas7bdat files that were later converted to dta.
			   With the switch to oracle, this is not so necessary.
 Inputs:       $misc_data_cd/{catch,trip,size_b2,size}_<year><wave>.dta for each
               year in $yearlist and wave in $wavelist.
 Outputs:      Globals only: $catchlist, $triplist, $b2list, $sizelist.
 Dependencies: Globals $misc_data_cd, $yearlist, $wavelist (set in model_wrapper.do).
 Pipeline:     Wrapped by model_wrapper.do but gated by `assemblemriplists', which
               is DEFAULT OFF. 
*******************************************************************************/

/******************************************************************************/
/******************************************************************************/
/* Section A: catchlist */
/******************************************************************************/
/******************************************************************************/

/* For each candidate file: if it exists and has observations, append its quoted
   path to the running $catchlist. The nested quotes build a space-separated list
   of quoted file paths (the same accumulate idiom repeats for the three lists below). */
global catchlist
foreach year in $yearlist{
	foreach wave in $wavelist{
	capture confirm file "$misc_data_cd/catch_`year'`wave'.dta"
	if _rc==0{
		use "$misc_data_cd/catch_`year'`wave'.dta", clear
		quietly count
		scalar tt=r(N)
		if scalar(tt)>0{
			global catchlist "$catchlist "$misc_data_cd/catch_`year'`wave'.dta" " 
		}
		else{
		}
	}
	else{
	}
	
}
}

/******************************************************************************/
/******************************************************************************/
/* Section B: triplist */
/******************************************************************************/
/******************************************************************************/
global triplist
foreach year in $yearlist{
	foreach wave in  $wavelist{
	capture confirm file "$misc_data_cd/trip_`year'`wave'.dta"
	if _rc==0{
		use "$misc_data_cd/trip_`year'`wave'.dta", clear
		quietly count
		scalar tt=r(N)
		if scalar(tt)>0{
			global triplist "$triplist "$misc_data_cd/trip_`year'`wave'.dta" " 
		}
		else{
		}
	}
	else{
	}
	
}
}

/******************************************************************************/
/******************************************************************************/
/* Section C: b2list (released-fish size files) */
/******************************************************************************/
/******************************************************************************/
global b2list
foreach year in $yearlist{
	foreach wave in $wavelist{
	capture confirm file "$misc_data_cd/size_b2_`year'`wave'.dta"
	if _rc==0{
		use "$misc_data_cd/size_b2_`year'`wave'.dta", clear
		quietly count
		scalar tt=r(N)
		if scalar(tt)>0{
			global b2list "$b2list "$misc_data_cd/size_b2_`year'`wave'.dta " " 
		}
		else{
		}
	}
	else{
	}
	
}
}


/******************************************************************************/
/******************************************************************************/
/* Section D: sizelist (kept-fish size files) */
/******************************************************************************/
/******************************************************************************/
global sizelist
foreach year in $yearlist{
	foreach wave in $wavelist{
	capture confirm file "$misc_data_cd/size_`year'`wave'.dta"
	if _rc==0{
	use "$misc_data_cd/size_`year'`wave'.dta", clear
	quietly count
	scalar tt=r(N)
	if scalar(tt)>0{
		global sizelist "$sizelist "$misc_data_cd/size_`year'`wave'.dta" " 
		}
		else{
		}
	}
	else{
	}
	
}
}
