/*******************************************************************************
 Script:       verify_settings.do
 Purpose:      Prints settings as a double check. This is mandatory before we put
               something into production.
               
 Outputs:      None.  
 Dependencies: Global $misc_data_cd (set in model_wrapper.do). Google Drive
               mounted to D:.
 Pipeline:     Step 0 of model_wrapper.do, gated by `verify_settings' (default ON).
*******************************************************************************/

pause on

di "The value of calibration_year is ${calibration_year}"
di "This is used to set define MRIP data in the calibration year." 
pause

di "This should conform to the calibration_date_start of ${calibration_date_start}"
di "And the calibration_date_end of ${calibration_date_end}"
pause


di "The value of projection_date_start is ${projection_date_start}. For 2027 it should be May 1, 2027"
di "The value of projection_date_end is ${projection_date_end}. For 2027, it should be April 31, 2028"
pause


di "The value of global ndraws is ${ndraws}".
di "This controsl the number of simulations and should be 101 for groundfish."
di "If it is not, it has been overwritten by proto"
pause

di "The MRIP calibration type is ${mrip_cal_type}. It should be the 2018 calibration"

assert "$mrip_cal_type"=="cal_2018"

di "The first calendar year of mrip data we need is  first_mrip_year 2023
global last_mrip_year 2025
"

/*
assert $projection_date_start==td(01may2027)
assert $projection_date_end==td(30apr2028)
*/
pause off