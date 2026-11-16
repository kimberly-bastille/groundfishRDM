 /*******************************************************************************
 Script:       print_settings.do
 Purpose:      Verification Script. Print the global settings.
 Inputs:       None 
 Outputs:      None 
 Pipeline:     called in two places by model_wrapper.do 
               First use to help the user to verify settings before the time consuming data prep steps.
			   Used again at the end to print the info in a convenient place
*******************************************************************************/

capture program drop print_settings
program define print_settings
    version 17.0

    di as text "======================================================================================================"
	di as text "$ndraws draws of Data for $Fishery management in $ManagementCycle Management Cycle."

	if $uncertain==1{
		di as text "Uncertainty Project set to ON (global uncertain=$uncertain)."
	}
	else if $uncertain==0{
		di as text "Uncertainty Project set to OFF (global uncertain=$uncertain)."
	}
    di as text "======================================================================================================"
    di as text "======================================================================================================"
    di as text "======================================================================================================"
	di as text "Calibration Setup is : $calibration_year."
	di as text "First and Last years of mrip pulls: $first_mrip_year and $last_mrip_year."
    di as text "======================================================================================================"

	di as text "Cod NAA Base year: $cod_NAA_base_year."
	di as text "Haddock NAA Base year: $hadd_NAA_base_year."
	di as text "Cod NAA Projection year: $cod_NAA_proj_year."
	di as text "Haddock NAA Projection year: $hadd_NAA_proj_year."
    di as text "======================================================================================================"

	di as text "Calibration period starts: " %tdMonth_dd,_CCYY $calibration_date_start

	di as text "Calibration period ends: " %tdMonth_dd,_CCYY $calibration_date_start
    di as text "======================================================================================================"
	di as text "Projection period starts: " %tdMonth_dd,_CCYY $projection_date_start
	di as text "Projection period ends: " %tdMonth_dd,_CCYY $projection_date_end

    di as text "======================================================================================================"

	di as text "Trawl Survey Start year: $trawl_survey_start_year."
    di as text "======================================================================================================"
    di as text "======================================================================================================"


	
	
end
