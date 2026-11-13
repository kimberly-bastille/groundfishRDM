/*******************************************************************************
 Script:       get_fes_from_gdrive.do
 Purpose:      Copies the most recent FES data from Google drive.
 Outputs:      $misc_data_cd/fes_person_final_<year><w>.dta
 Dependencies: Global $misc_data_cd (set in model_wrapper.do). Google Drive
               mounted to D:.
 Pipeline:     Step 1 of model_wrapper.do, gated by `get_fes_from_gdrive' (default ON).
              Requires 3 arguments, Fishery, ManagementCycle and the FesYear.
			  Fishery and ManagementCycle is used to assemble the google folder.
			  FES year is used to search for the proper files
*******************************************************************************/

args Fishery ManagementCycle  FesYear

if missing("`FesYear'") | missing("`ManagementCycle'") | missing("`FesYear'")  {
    display as error "Error: Missing required arguments."
    display as error "Syntax: do get_fes_from_gdrive.do <Fishery> <ManagementCycle> <FesYear>"
    exit 198 /* invalid syntax exit code */
}

local google_folder "D:/Shared drives/NMFS NEC READ SSB/socialsci/RecreationalDST/`ManagementCycle'_management_cycle_data/`Fishery'RDM/miscellaneous"
local filestubs  "fes_person_final_`FesYear'"

display "Pulling FES_person_final files Google Drive ..."
local filecount=0
local files : dir "`google_folder'" files "`filestubs'*.dta" /* find matching files */
foreach myfile of local files{
    local fullpath `"`google_folder'/`myfile'"' // build full path
    di as text "Copying: `fullpath'" 
	copy "`fullpath'" `"$misc_data_cd/`myfile'.dta"' , replace /*copy files from google drive to misc_data_cd*/ 
	local ++filecount 
}

display "Pulled `filecount' of 6 FES_person_final files from Google Drive"
if (`filecount'!=6) {
    display as error "Error: incorrect number of FES files copied."
}


