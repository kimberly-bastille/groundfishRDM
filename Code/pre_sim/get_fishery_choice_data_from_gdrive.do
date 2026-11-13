/*******************************************************************************
 Script:       get_fishery_choice_data_from_gdrive.do
 Purpose:      Copies files needed for the fishery choice model from google drive to local folders
 Inputs:       Requires the Google Drive
               Desktop app mounted at D:.
 Outputs:      trip_data.dta
			   daily_rec_regulations_2010_2025.dta
			   trip_cost_species_codes.dta
			   trip_cost_model.ster
			   availability_state.dta

 Dependencies: Global $misc_data_cd (set in model_wrapper.do). Google Drive
               mounted to D:.
 Pipeline:     Gated by `get_fishery_choice_from_gdrive' (default ON).
*******************************************************************************/

args Fishery ManagementCycle

if missing("`Fishery'") | missing("`ManagementCycle'")  {
    display as error "Error: Missing required arguments."
    display as error "Syntax: do get_fishery_choice_from_gdrive.do <Fishery> <ManagementCycle>"
    exit 198 /* invalid syntax exit code */
}




local google_folder "D:/Shared drives/NMFS NEC READ SSB/socialsci/RecreationalDST/`ManagementCycle'_management_cycle_data/`Fishery'RDM/miscellaneous"
local dta_stubs  "trip_data.dta daily_rec_regulations_2010_2025.dta trip_cost_species_codes.dta availability_state.dta trip_cost_model.ster"
local ster_stubs "trip_cost_model"

display "Copying fishery choice data from Google Drive to misc_data_cd..."

foreach s of local dta_stubs {
    clear
	copy "`google_folder'/`s'" `"$misc_data_cd/`s'"' , replace /*copy files from google drive to misc_data_cd*/
	di as text "Successfully copied `s' "
}

display "Finished copying fishery choice data to misc_data_cd."

