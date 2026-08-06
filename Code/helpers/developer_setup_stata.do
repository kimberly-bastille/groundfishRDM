/*******************************************************************************
 Script:       developer_setup_stata.do  (helpers)
 Purpose:      Sets global $gfdatadir to the data root for the current developer
               ($developer). LCH points at an external E: drive; TP/ML/KB use a
               repo-relative ${here}\Data folder. Asserts $developer is one of
               the four allowed codes before proceeding.
 Inputs:       Global $developer (one of "LCH","TP","ML","KB"), set externally
               (e.g. the user's profile.do). Global $here (set by the `here`
               package in model_wrapper.do).
 Outputs:      Global $gfdatadir; creates that directory if absent.
 Dependencies: $developer and $here must be set before this runs.
 Pipeline:     Called unconditionally near the top of model_wrapper.do (line 83).
               Stata twin of developer_setup.R.
*******************************************************************************/

assert inlist("$developer", "LCH", "TP", "ML", "KB")

if inlist("$developer","LCH") {
	global gfdatadir "E:\Lou_projects\groundfishRDM\2027_mgt_cycle"
} 
else if inlist("$developer","TP", "ML","KB"){
	global gfdatadir "${here}\Data\2027_mgt_cycle"
}
/* make this directory if it doesn't exist.*/
capture mkdir $gfdatadir 


display "Hello $developer.  Use the global gfdatadir in place of \${here}\Data\YYYY mgmt cycle)."
display "The value of datadir is: $gfdatadir"


