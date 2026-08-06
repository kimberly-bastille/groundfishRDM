/*******************************************************************************
 Script:       get_assessment_from_gdrive.do
 Purpose:      Copies the most recent stock-assessment numbers-at-age (NAA)
               files (GOM haddock and WGOM cod, each historical and projected)
               from the mounted Google Drive into the local misc_data_cd,
               renaming each to a stable generic name for downstream use.
 Inputs:       Date-suffixed .dta files (e.g. GOM_Haddock_historical_NAA_*.dta)
               in the shared-drive input_data folder. Requires the Google Drive
               Desktop app mounted at D:.
 Outputs:      $misc_data_cd/{GOM_Haddock_historical_NAA, GOM_Haddock_projected_NAA,
               WGOM_Cod_projected_NAA, WGOM_Cod_historical_NAA}.dta
 Dependencies: Global $misc_data_cd (set in model_wrapper.do). Google Drive
               mounted to D:.
 Pipeline:     Step 1 of model_wrapper.do, gated by `pull_assessment' (default ON).
               The NAA files it stages are produced upstream by
               get_cod_assessment_data.R / get_haddock_assessment_data.R.
*******************************************************************************/

local google_folder "D:/Shared drives/NMFS NEC READ SSB/socialsci/RecreationalDST/2027_management_cycle_data/groundfishRDM/input_data"
local filestubs  "GOM_Haddock_historical_NAA GOM_Haddock_projected_NAA WGOM_Cod_projected_NAA WGOM_Cod_historical_NAA"

display "Pulling latest assessment NAA files from Google Drive ..."

foreach s of local filestubs {
    clear
    local files : dir "`google_folder'" files "`s'_*.dta" /* find matching file */
    local last: word count `files'
	/* Filenames are date-suffixed and `dir' returns them sorted, so the last
	   entry is the most recent assessment vintage. */
	local myfile : word `last' of `files' // grab last match
    di "`myfile'"
	local myfile : subinstr local myfile `"""' "", all /* remove embedded quotes */
    local fullpath `"`google_folder'/`myfile'"' // build full path
    di as text "Loading: `fullpath'" 
	copy "`fullpath'" `"$misc_data_cd/`s'.dta"' , replace /*copy files from google drive to misc_data_cd*/
}

display "Finished copying assessment NAA files to misc_data_cd."

