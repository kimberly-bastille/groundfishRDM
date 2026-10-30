/******************************************************************************/
/******************************************************************************/
/* Script:  directed_trips_calibration.do                                     
                                                                              
   Purpose: Turns MRIP survey estimates of directed groundfish trips into the 
            per-day, per-draw trip counts that the simulation runs on. It:    
              1) estimates directed trips and their standard error at the     
                 year x month x kind-of-day (weekend incl. federal holidays / 
                 weekday) x mode (pr/fh) level over the calibration period,   
              2) uses those estimates to create $ndraws random draws of       
                 directed trips for each stratum,                             
              3) divides each draw by the number of days in that stratum to   
                 get trips per day,                                           
              4) computes a calendar-year adjustment for each stratum,        
                 = (calendar days in that stratum in the projection period) / 
                   (calendar days in that stratum in the calibration period), 
                 correcting for the fact that a given month has a different   
                 mix of weekdays and weekend days from one year to the next,  
              5) sets baseline and projection year regulations by calling     
                 set_regulations.do, and                                      
              6) (Part C) re-estimates MRIP directed-trip totals by mode,     
                 mode-month and mode-season for later comparison with the     
                 simulated totals.                                            
                                                                              
   Inputs:  $triplist, $catchlist -- stacked MRIP trip and catch files        
            $misc_data_cd/MRIP_COD_ALL_SITE_LIST.csv                          
                                                                              
   Outputs: $misc_data_cd/cod_open_season_dates.dta                           
            $misc_data_cd/directed_trip_draws.csv                             
            $misc_data_cd/next_year_calendar_adjustments.csv                  
            $misc_data_cd/mrip_dtrip_by_mode.dta                              
            $misc_data_cd/mrip_dtrip_by_mode_month.dta                        
            $misc_data_cd/mrip_dtrip_by_mode_season.dta                       
                                                                              
   Dependencies: Called from model_wrapper.do, which must already have set    
            $seed, $ndraws, $triplist, $catchlist, $calibration_year,         
            $calibration_date_start, $calibration_date_end, $leap_yr_days,    
            $fed_holidays, $misc_data_cd and $input_code_cd. Calls            
            set_regulations.do. Requires the user-written dsconcat, xsvmat    
            and renvarlab commands.                                           
                                                                              
   Pipeline: Pre-simulation, and one of the earliest steps: directed_trip_    
            draws.csv is read by the catch-per-trip calibration, by           
            compare_calibration_data_to_MRIP.do, and by the R simulation.     
            The mrip_dtrip_by_* files are the MRIP side of the comparison in  
            compare_calibration_data_to_MRIP.do.                              
                                                                              
   Note 1:  Part C consists of three near-identical ~160-line blocks that     
            differ only in the domain string used for the svy: total.         
   Note 2:  Two renames in this file rely on Stata's variable-name            
            abbreviation rather than being no-ops; they are annotated where   
            they occur.     */
					
/******************************************************************************/
/******************************************************************************/



/******************************************************************************/
/******************************************************************************/
/* Section A: Estimate directed trips by stratum from MRIP                    */
/******************************************************************************/
/******************************************************************************/

set seed $seed

di "directed_trips_calibration: estimating directed trips from MRIP; this may take a while ..."

clear
tempfile tl1 cl1
dsconcat $triplist

/*dtrip will be used to estimate total directed trips*/
gen dtrip=1

sort year strat_id psu_id id_code
save `tl1'

clear

dsconcat $catchlist
sort year strat_id psu_id id_code
replace common=subinstr(lower(common)," ","",.)
save `cl1'

use `tl1'
merge 1:m year strat_id psu_id id_code using `cl1', keep(1 3)
replace common=subinstr(lower(common)," ","",.)
replace prim1_common=subinstr(lower(prim1_common)," ","",.)
replace prim2_common=subinstr(lower(prim2_common)," ","",.)

drop _merge
 
keep if $calibration_year


/* THIS IS THE END OF THE DATA MERGING CODE */

 /* ensure only relevant states */
keep if inlist(st, 23, 33, 25)


 /* Classify trips into dom_id=1 (DOMAIN OF INTEREST) and dom_id=2 ('OTHER'
    DOMAIN). A trip counts as directed at groundfish if it either targeted
    (prim1_common) or caught (common) cod or haddock. The whole sample is kept
    rather than filtered, because a survey-weighted domain estimate needs the
    out-of-domain records to get the variance right. */
gen str1 dom_id="2"
replace dom_id="1" if strmatch(common, "atlanticcod") 
replace dom_id="1" if strmatch(prim1_common, "atlanticcod") 

replace dom_id="1" if strmatch(common, "haddock") 
replace dom_id="1" if strmatch(prim1_common, "haddock") 

tostring wave, gen(w2)
tostring year, gen(year2)
gen st2 = string(st,"%02.0f")

gen state="MA" if st==25
replace state="MD" if st==24
replace state="RI" if st==44
replace state="CT" if st==9
replace state="NY" if st==36
replace state="NJ" if st==34
replace state="DE" if st==10
replace state="VA" if st==51
replace state="NC" if st==37
replace state="ME" if st==23
replace state="NH" if st==33

gen mode1="sh" if inlist(mode_fx, "1", "2", "3")
replace mode1="pr" if inlist(mode_fx, "7")
replace mode1="fh" if inlist(mode_fx, "4", "5")

gen date=substr(id_code, 6,8)
gen month1=substr(date, 5, 2)
gen day1=substr(date, 7, 2)
drop if inlist(day1,"9x", "xx") 
destring day1, replace


/* Deal with group catch. MRIP records catch for a group of anglers against a
   single "leader" interview, so an individual angler's record can show no cod
   or haddock even though the group kept some. Within each
   strat_id-psu_id-leader group this takes the lowest dom_id (1 if anyone in
   the group was in the domain) and the largest domain claim (fish kept and
   available for identification), and promotes the trip to dom_id=1 if the
   group both was in the domain and had claimed groundfish. */

replace claim=0 if claim==.

gen domain_claim=claim if inlist(common, "atlanticcod", "haddock") 
mvencode domain_claim, mv(0) override

bysort strat_id psu_id leader (dom_id): gen gc_flag=dom_id[1]
bysort strat_id psu_id leader (domain_claim): gen claim_flag=domain_claim[_N]
replace dom_id="1" if strmatch(dom_id,"2") & claim_flag>0 & claim_flag!=. & strmatch(gc_flag,"1")


* Generate estimation strata

*MRIP-Western GoM site allocations
preserve 
import delimited using "$misc_data_cd/MRIP_COD_ALL_SITE_LIST.csv", clear 
keep if inlist(state, "MA", "ME")
keep state intsite nmfs_stock_area nmfs_stat_area
sort intsite nmfs_stock_area  
replace nmfs_stock_area="WGOM" if inlist(nmfs_stat_area, 521, 526, 541, 514, 513, 515)
replace nmfs_stock_area="XX" if !inlist(nmfs_stat_area, 521, 526, 541, 514, 513, 515)
keep nmfs_stock_area intsite nmfs_stat_area state
duplicates drop
tempfile mrip_sites
save `mrip_sites', replace 
restore

merge m:1 intsite state using `mrip_sites',  keep(1 3)

/*classify into WGOM or not WGOM */
gen str3 area_s="XX"
replace area_s="WGOM" if st2=="33"
replace area_s=nmfs_stock_area if inlist(st2, "25", "23") 


/* generate the estimation strata - year, month, kind-of-day (weekend including fed holidays/weekday), mode (pr/fh)*/
gen my_dom_id_string=area_s+"_"+year2+"_"+month1+"_"+kod+"_"+mode1+"_"+ dom_id
replace my_dom_id_string=ltrim(rtrim(my_dom_id_string))

/* total with over(<overvar>) requires a numeric variable */
encode my_dom_id_string, gen(my_dom_id)

/* Keep 1 observation per year-strat-psu-id_code. Sorting by dom_id first means
   the retained record is dom_id=1 if the trip targeted or caught cod or
   haddock, and dom_id=2 otherwise. */
bysort year wave strat_id psu_id id_code (dom_id): gen count_obs1=_n
keep if count_obs1==1


/* Negative trip weights occasionally appear in MRIP and are not usable as
   pweights; zeroing them drops those records from the estimate. */
replace wp_int=0 if wp_int<=0
svyset psu_id [pweight= wp_int], strata(strat_id) singleunit(certainty)


preserve
keep my_dom_id my_dom_id_string
duplicates drop 
tostring my_dom_id, gen(my_dom_id2)
keep my_dom_id2 my_dom_id_string
tempfile domains
save `domains', replace 
restore

encode mode1, gen(mode2)

svy: total dtrip, over(my_dom_id)  

/* svy: total leaves its results in the r(table) matrix, indexed by rows named
   like "dtrip@3.my_dom_id". xsvmat turns that matrix into a dataset; the two
   splits below peel off the "@" and the "." to recover the numeric domain id,
   which is then merged back to its readable label. */
xsvmat, from(r(table)') rownames(rname) names(col) norestor
split rname, parse("@")
drop rname1
split rname2, parse(.)
drop rname2 rname22
rename rname21 my_dom_id2
merge 1:1 my_dom_id2 using `domains'
drop rname my_dom_id2 _merge 
order my_dom_id_string

keep my b se  ll ul
gen pse=(se/b)*100

split my, parse(_)
rename my_dom_id_string1 area_s
rename my_dom_id_string2 year
rename my_dom_id_string3 month1
rename my_dom_id_string4 kod
rename my_dom_id_string5 mode
rename my_dom_id_string6 dom_id
drop my_dom_id_string
rename b dtrip

*keep if the trip was a cod/haddock trip in the WGoM
keep if dom_id=="1"
keep if area_s=="WGOM"

su dtrip
return list

/* A stratum estimated from a single PSU has no computable SE. Setting the SE
   equal to the point estimate gives those strata a wide but finite spread when
   the draws are taken below, rather than dropping them. */
replace se=dtrip if se==.
replace pse=(se/dtrip)*100

drop ll ul pse

*drop shore trips
drop if mode=="sh"


count
local num=`r(N)'
di `num'

tempfile new
save `new', replace 

/******************************************************************************/
/******************************************************************************/
/* Section B: Draw directed trips for each stratum                            */
/******************************************************************************/
/******************************************************************************/

di "directed_trips_calibration: drawing $ndraws directed-trip draws per stratum ..."

/* One stratum at a time: draw $ndraws values from a normal centered on the MRIP
   point estimate with that stratum's SE, then truncate at zero. The bias this
   truncation introduces is corrected further below. */
global drawz
forv d = 1/`num'{
u `new', clear

keep if _n==`d'
su dtrip
local est = `r(mean)'

su se
local sd = `r(mean)'

expand $ndraws
gen dtrip_not_trunc=rnormal(`est', `sd')
gen dtrip_new=max(dtrip_not_trunc, 0)

 
gen draw=_n

tempfile drawz`d'
save `drawz`d'', replace
global drawz "$drawz "`drawz`d''" " 
}

clear
dsconcat $drawz


/* Diagnostic: how much did truncating at zero shift the total? */
su dtrip_not
return list
local not_truc = `r(sum)'

su dtrip_new
return list
local new = `r(sum)'

di ((`new'-`not_truc')/`not_truc')*100


/*The following attempts to correct for bias that occurs when drawing from uncertain MRIP estimates. 
	*When an MRIP estimate is very uncertain, some draws of x from a normal distribution can result in x_i<0. Because trip outcomes cannot 
	*be negative, I change these to 0. But doing so results in an upwardly shifted mean across draws. To correct for this, I sum x_i
	*across draws where x_i<0, and subtract this value from each draw where x_i>0 in proportion to the amount that each x_i>0 contributes to the total 
	*number of trips across x_i's>0.
	*This partly corrects for the issue; however, subtracting a fixed value from x_i where x_i>0 leads to some of these x_i's now <0. I replace these values as 0. */

/*I have tried parameterizing non-negative distributions using the MRIP point
  estimate and SE, but these resulted in larger differences in the mean trip
  estimates across all draws by domain (month, kind-of-day, and mode) than the
  approach used here. Can work on this in the future. */
 
gen domain=month1+"_"+kod+"_"+mode

gen tab=1 if dtrip_not<0
egen sum_neg=sum(dtrip_not) if tab==1, by(domain)
sort domain
egen mean_sum_neg=mean(sum_neg), by(domain)

egen sum_non_neg=sum(dtrip_not) if dtrip_not>0 , by(domain)
gen prop=dtrip_not/sum_non_neg
gen adjust=prop*mean_sum_neg

/*
egen pctile_x=pctile(dtrip_not) , p(10) by(domain)
gen tab2=1 if dtrip_not>0 & dtrip_not>pctile_x
egen sumtab2=sum(tab2), by(domain)
gen adjust=mean_sum_neg/sumtab2
*/

gen dtrip_new2=dtrip_new+adjust if dtrip_new!=0 & adjust !=.
replace dtrip_new2=dtrip_new if dtrip_new2==.
replace dtrip_new2=0 if dtrip_new2<0


*check differences between original and adjusted draws 
/*
su dtrip_new2 
return list
local new = `r(sum)'

su dtrip_not
return list
local not_truc = `r(sum)'
di ((`new'-`not_truc')/`not_truc')*100
*/

su dtrip_new2
return list
local new = `r(sum)'

su dtrip_not
return list
local old = `r(sum)'

di ((`new'-`old')/`old')*100

replace dtrip_new=dtrip_new2

drop area domain dom_id dtrip_not tab sum_neg sum_non_neg prop mean_sum_neg adjust dtrip_new2 
rename month1 month 

sort mode month kod draw 

tempfile new1
save `new1'

/******************************************************************************/
/******************************************************************************/
/* Section C: Spread stratum trips over the days of the calendar year         */
/******************************************************************************/
/******************************************************************************/

di "directed_trips_calibration: building the calendar and computing trips per day ..."

/* Build a one-row-per-calendar-day skeleton for the calibration year, label
   each day as weekend or weekday, replicate it across the three modes, and
   merge each draw's stratum totals onto it. Dividing the stratum total by the
   number of days in that stratum gives trips per day, which is what the
   simulation consumes. */
global drawz2

forv d = 1/$ndraws{
	u `new1', clear 
	keep if draw==`d'

	tempfile dtrips`d'
	save `dtrips`d'', replace 
	
clear 
set obs 2
gen day=$calibration_date_start if _n==1
replace day=$calibration_date_end if _n==2
format day %td
/* Drop February 29 so calibration and projection years have the same length */
drop if day==$leap_yr_days
/* Only the two endpoints were entered; tsfill materializes every day between */
tsset day
tsfill, full
gen day_i=_n

gen dow = dow(day)  //0=Sunday,...,6=Saturday

/* Friday, Saturday and Sunday count as "weekend" days for effort purposes */
gen kod="we" if inlist(dow, 5, 6, 0)
replace kod="wd" if inlist(dow, 1, 2, 3, 4)

//add the 12 federal holidays as weekends
replace kod="we" if $fed_holidays

gen year=year(day)				
gen month=month(day)				
gen month2 = string(month,"%02.0f")
tostring year, replace
drop month
rename month2 month
gen mode="sh"
expand 2, gen(dup)
replace mode="pr" if dup==1
drop dup
expand 2 if mode=="pr", gen(dup)
replace mode="fh" if dup==1
drop dup

merge m:1  kod month mode using `dtrips`d''
*gen draw=`d'
tempfile drawz2`d'
save `drawz2`d'', replace
global drawz2 "$drawz2 "`drawz2`d''" " 

}
clear
dsconcat $drawz2
sort day  mode draw

bysort day mode: gen draw2=_n
order draw2
replace draw=draw2 if draw==.
drop draw2

mvencode dtrip dtrip_new, mv(0) override

*number of weekend/weekday days per state, month, and mode, and draw
gen tab=1
bysort month kod mode draw:egen sum_days=sum(tab)
order sum_days

sort draw mode day 
order draw
sort day
drop dtrip
rename dtrip_new dtrip
mvencode dtrip, mv(0) override
gen trips_per_day=dtrip/sum_days
mvencode trips_per_day, mv(0) override 
order dtrip trips_per_day

order mode year month kod dow day day_i trips_per_day draw
drop dtrip sum_days se _merge tab 

sort  draw mode day 
rename trips_per_day dtrip

sort day 

gen day1=day(day)
gen month1=month(day)


/* set_regulations.do attaches the bag limits, minimum sizes and open/closed
   status for the calibration year and both projection-year scenarios to each
   calendar day, and creates day_y2 (the matching day in the projection year). */
do "$input_code_cd/set_regulations.do"

preserve
keep if cod_bag!=0
keep day
duplicates drop 
rename day date
gen cod_season_open=1
save  "$misc_data_cd\cod_open_season_dates.dta",  replace 
restore 

preserve
keep mode day draw cod_bag cod_min hadd_bag hadd_min day_y2 dtrip ///
			cod_bag_y2 cod_min_y2 hadd_bag_y2 hadd_min_y2 ///
			cod_bag_y2_alt cod_min_y2_alt hadd_bag_y2_alt hadd_min_y2_alt
compress

export delimited using "$misc_data_cd\directed_trip_draws.csv",  replace 
restore

/******************************************************************************/
/******************************************************************************/
/* Section D: Calendar-year adjustment factors                                */
/******************************************************************************/
/******************************************************************************/

/* A calendar date that is a weekday in the calibration year may be a weekend
   day in the projection year, and effort differs sharply between the two. For
   each draw, this matches every projection-year day to the calibration-year
   stratum with the same mode-month-kind-of-day, then computes an expansion
   factor = projection-year trips / calibration-year trips by month and mode. */
keep mode day draw cod_bag cod_min hadd_bag hadd_min day_y2 kod kod_y2 dtrip ///
			cod_bag_y2 cod_min_y2 hadd_bag_y2 hadd_min_y2 ///
			cod_bag_y2_alt cod_min_y2_alt hadd_bag_y2_alt hadd_min_y2_alt
			
gen month_y1=month(day)
gen month_y2=month(day_y2)
tostring month_y1, replace
tostring month_y2, replace

tempfile base 
save `base', replace 

global drawz

levelsof draw, local(drawss)
foreach d of local drawss{

u `base', clear

keep if draw==`d'
gen domain_y1=mode+"_"+month_y1+"_"+kod
gen domain_y2=mode+"_"+month_y2+"_"+kod_y2

/* Where the day keeps the same mode-month-kind-of-day in both years, carry the
   trips straight across; otherwise fill in from the mean of the calibration
   year days that do match the projection-year stratum. */
gen dtrip_y2=dtrip if domain_y1==domain_y2

levelsof domain_y2 if dtrip_y2==., local(domains)
foreach p of local domains{
	su dtrip if domain_y1=="`p'"
	return list
	replace dtrip_y2=`r(mean)' if  domain_y2=="`p'" & dtrip_y2==.
	
}
collapse (sum) dtrip dtrip_y2, by(month_y1 mode)
gen expansion_factor = dtrip_y2/dtrip
gen draw=`d'

tempfile drawz`d'
save `drawz`d'', replace
global drawz "$drawz "`drawz`d''" " 
}

dsconcat $drawz

/* Missing expansion factor means no adjustment, i.e. a factor of 1 */
mvencode expansion_factor, mv(1) override

su dtrip
return list

su dtrip_y2
return list

gen check =dtrip*expansion
su check
return list

drop check
/* Not a no-op: the collapse left month_y1 rather than month, so "month"
   abbreviates uniquely to month_y1 and is renamed to month here. */
rename month month
destring month, replace
compress
export delimited using "$misc_data_cd\next_year_calendar_adjustments.csv",  replace 



/******************************************************************************/
/******************************************************************************/
/* Section E (Part C): MRIP directed-trip totals by mode                      */
/******************************************************************************/
/******************************************************************************/

/* Sections E, F and G re-derive the MRIP directed-trip estimates at three
   coarser aggregations. These are the reference values that
   compare_calibration_data_to_MRIP.do plots the simulated totals against; they
   are not used by the simulation itself. Each block repeats the data assembly
   of Section A verbatim and differs only in the domain string built for
   svy: total below. */

di "directed_trips_calibration: estimating MRIP directed-trip totals by mode ..."

clear
tempfile tl1 cl1
dsconcat $triplist

/*dtrip will be used to estimate total directed trips*/
gen dtrip=1

sort year strat_id psu_id id_code
save `tl1'

clear

dsconcat $catchlist
sort year strat_id psu_id id_code
replace common=subinstr(lower(common)," ","",.)
save `cl1'

use `tl1'
merge 1:m year strat_id psu_id id_code using `cl1', keep(1 3)
replace common=subinstr(lower(common)," ","",.)
replace prim1_common=subinstr(lower(prim1_common)," ","",.)
replace prim2_common=subinstr(lower(prim2_common)," ","",.)

drop _merge
 
keep if $calibration_year


/* THIS IS THE END OF THE DATA MERGING CODE */

 /* ensure only relevant states */
keep if inlist(st,23, 33, 25)


 /* Classify trips into dom_id=1 (DOMAIN OF INTEREST) and dom_id=2 ('OTHER'
    DOMAIN). A trip counts as directed at groundfish if it either targeted
    (prim1_common) or caught (common) cod or haddock. The whole sample is kept
    rather than filtered, because a survey-weighted domain estimate needs the
    out-of-domain records to get the variance right. */
gen str1 dom_id="2"
replace dom_id="1" if strmatch(common, "atlanticcod") 
replace dom_id="1" if strmatch(prim1_common, "atlanticcod") 

replace dom_id="1" if strmatch(common, "haddock") 
replace dom_id="1" if strmatch(prim1_common, "haddock") 

tostring wave, gen(w2)
tostring year, gen(year2)
gen st2 = string(st,"%02.0f")

gen state="MA" if st==25
replace state="MD" if st==24
replace state="RI" if st==44
replace state="CT" if st==9
replace state="NY" if st==36
replace state="NJ" if st==34
replace state="DE" if st==10
replace state="VA" if st==51
replace state="NC" if st==37
replace state="ME" if st==23
replace state="NH" if st==33

gen mode1="sh" if inlist(mode_fx, "1", "2", "3")
replace mode1="pr" if inlist(mode_fx, "7")
replace mode1="fh" if inlist(mode_fx, "4", "5")

*drop shore trips
drop if mode1=="sh"

gen date=substr(id_code, 6,8)
gen month1=substr(date, 5, 2)
gen day1=substr(date, 7, 2)
drop if inlist(day1,"9x", "xx") 
destring day1, replace


/* Deal with group catch. MRIP records catch for a group of anglers against a
   single "leader" interview, so an individual angler's record can show no cod
   or haddock even though the group kept some. Within each
   strat_id-psu_id-leader group this takes the lowest dom_id (1 if anyone in
   the group was in the domain) and the largest domain claim (fish kept and
   available for identification), and promotes the trip to dom_id=1 if the
   group both was in the domain and had claimed groundfish. */

replace claim=0 if claim==.

gen domain_claim=claim if inlist(common, "atlanticcod", "haddock") 
mvencode domain_claim, mv(0) override

bysort strat_id psu_id leader (dom_id): gen gc_flag=dom_id[1]
bysort strat_id psu_id leader (domain_claim): gen claim_flag=domain_claim[_N]
replace dom_id="1" if strmatch(dom_id,"2") & claim_flag>0 & claim_flag!=. & strmatch(gc_flag,"1")


* generate estimation strata

*MRIP-Western GoM site allocations
preserve 
import delimited using "$misc_data_cd/MRIP_COD_ALL_SITE_LIST.csv", clear 
keep if inlist(state, "MA", "ME")
keep state intsite nmfs_stock_area nmfs_stat_area
sort intsite nmfs_stock_area  
replace nmfs_stock_area="WGOM" if inlist(nmfs_stat_area, 521, 526, 541, 514, 513, 515)
replace nmfs_stock_area="XX" if !inlist(nmfs_stat_area, 521, 526, 541, 514, 513, 515)
keep nmfs_stock_area intsite nmfs_stat_area state
duplicates drop
tempfile mrip_sites
save `mrip_sites', replace 
restore

merge m:1 intsite state using `mrip_sites',  keep(1 3)

/*classify into WGOM or not WGOM */
gen str3 area_s="XX"
replace area_s="WGOM" if st2=="33"
replace area_s=nmfs_stock_area if inlist(st2, "25", "23") 

/* Estimation domain for this block: mode only */
gen my_dom_id_string=mode1+"_"+ dom_id
replace my_dom_id_string=ltrim(rtrim(my_dom_id_string))

/* total with over(<overvar>) requires a numeric variable */
encode my_dom_id_string, gen(my_dom_id)

/* Keep 1 observation per year-strat-psu-id_code. Sorting by dom_id first means
   the retained record is dom_id=1 if the trip targeted or caught cod or
   haddock, and dom_id=2 otherwise. */
bysort year wave strat_id psu_id id_code (dom_id): gen count_obs1=_n
keep if count_obs1==1

keep if dom_id=="1"
keep if area_s=="WGOM"

/* Negative trip weights occasionally appear in MRIP and are not usable as
   pweights; zeroing them drops those records from the estimate. */
replace wp_int=0 if wp_int<=0
svyset psu_id [pweight= wp_int], strata(strat_id) singleunit(certainty)


preserve
keep my_dom_id my_dom_id_string
duplicates drop 
tostring my_dom_id, gen(my_dom_id2)
keep my_dom_id2 my_dom_id_string
tempfile domains
save `domains', replace 
restore

encode mode1, gen(mode2)

svy: total dtrip, over(my_dom_id)  

/* svy: total leaves its results in the r(table) matrix, indexed by rows named
   like "dtrip@3.my_dom_id". xsvmat turns that matrix into a dataset; the two
   splits below peel off the "@" and the "." to recover the numeric domain id,
   which is then merged back to its readable label. */
xsvmat, from(r(table)') rownames(rname) names(col) norestor
split rname, parse("@")
drop rname1
split rname2, parse(.)
drop rname2 rname22
rename rname21 my_dom_id2
merge 1:1 my_dom_id2 using `domains'
drop rname my_dom_id2 _merge 
order my_dom_id_string
rename b dtrip 
sort dtrip  my_dom_id
keep dtrip se my_dom_id_string  ll ul
replace my_dom="fh" if my_dom=="fh_1"
replace my_dom="pr" if my_dom=="pr_1"
rename my mode
ds mode, not
renvarlab `r(varlist)', postfix(_mrip)

save "$misc_data_cd\mrip_dtrip_by_mode.dta", replace 




/******************************************************************************/
/******************************************************************************/
/* Section F (Part C): MRIP directed-trip totals by mode and month            */
/******************************************************************************/
/******************************************************************************/

di "directed_trips_calibration: estimating MRIP directed-trip totals by mode and month ..."

clear
 

tempfile tl1 cl1
dsconcat $triplist

/*dtrip will be used to estimate total directed trips*/
gen dtrip=1

sort year strat_id psu_id id_code
save `tl1'

clear

dsconcat $catchlist
sort year strat_id psu_id id_code
replace common=subinstr(lower(common)," ","",.)
save `cl1'

use `tl1'
merge 1:m year strat_id psu_id id_code using `cl1', keep(1 3)
replace common=subinstr(lower(common)," ","",.)
replace prim1_common=subinstr(lower(prim1_common)," ","",.)
replace prim2_common=subinstr(lower(prim2_common)," ","",.)

drop _merge
 
keep if $calibration_year


/* THIS IS THE END OF THE DATA MERGING CODE */

 /* ensure only relevant states */
keep if inlist(st,23, 33, 25)


 /* Classify trips into dom_id=1 (DOMAIN OF INTEREST) and dom_id=2 ('OTHER'
    DOMAIN). A trip counts as directed at groundfish if it either targeted
    (prim1_common) or caught (common) cod or haddock. The whole sample is kept
    rather than filtered, because a survey-weighted domain estimate needs the
    out-of-domain records to get the variance right. */
gen str1 dom_id="2"
replace dom_id="1" if strmatch(common, "atlanticcod") 
replace dom_id="1" if strmatch(prim1_common, "atlanticcod") 

replace dom_id="1" if strmatch(common, "haddock") 
replace dom_id="1" if strmatch(prim1_common, "haddock") 

tostring wave, gen(w2)
tostring year, gen(year2)
gen st2 = string(st,"%02.0f")

gen state="MA" if st==25
replace state="MD" if st==24
replace state="RI" if st==44
replace state="CT" if st==9
replace state="NY" if st==36
replace state="NJ" if st==34
replace state="DE" if st==10
replace state="VA" if st==51
replace state="NC" if st==37
replace state="ME" if st==23
replace state="NH" if st==33

gen mode1="sh" if inlist(mode_fx, "1", "2", "3")
replace mode1="pr" if inlist(mode_fx, "7")
replace mode1="fh" if inlist(mode_fx, "4", "5")

*drop shore trips
drop if mode1=="sh"

gen date=substr(id_code, 6,8)
gen month1=substr(date, 5, 2)
gen day1=substr(date, 7, 2)
drop if inlist(day1,"9x", "xx") 
destring day1, replace


/* Deal with group catch. MRIP records catch for a group of anglers against a
   single "leader" interview, so an individual angler's record can show no cod
   or haddock even though the group kept some. Within each
   strat_id-psu_id-leader group this takes the lowest dom_id (1 if anyone in
   the group was in the domain) and the largest domain claim (fish kept and
   available for identification), and promotes the trip to dom_id=1 if the
   group both was in the domain and had claimed groundfish. */

replace claim=0 if claim==.

gen domain_claim=claim if inlist(common, "atlanticcod", "haddock") 
mvencode domain_claim, mv(0) override

bysort strat_id psu_id leader (dom_id): gen gc_flag=dom_id[1]
bysort strat_id psu_id leader (domain_claim): gen claim_flag=domain_claim[_N]
replace dom_id="1" if strmatch(dom_id,"2") & claim_flag>0 & claim_flag!=. & strmatch(gc_flag,"1")


* generate estimation strata

*MRIP-Western GoM site allocations
preserve 
import delimited using "$misc_data_cd/MRIP_COD_ALL_SITE_LIST.csv", clear 
keep if inlist(state, "MA", "ME")
keep state intsite nmfs_stock_area nmfs_stat_area
sort intsite nmfs_stock_area  
replace nmfs_stock_area="WGOM" if inlist(nmfs_stat_area, 521, 526, 541, 514, 513, 515)
replace nmfs_stock_area="XX" if !inlist(nmfs_stat_area, 521, 526, 541, 514, 513, 515)
keep nmfs_stock_area intsite nmfs_stat_area state
duplicates drop
tempfile mrip_sites
save `mrip_sites', replace 
restore

merge m:1 intsite state using `mrip_sites',  keep(1 3)

/*classify into WGOM or not WGOM */
gen str3 area_s="XX"
replace area_s="WGOM" if st2=="33"
replace area_s=nmfs_stock_area if inlist(st2, "25", "23") 

/* Estimation domain for this block: month x mode */
gen my_dom_id_string=month+"_"+mode1+"_"+ dom_id
replace my_dom_id_string=ltrim(rtrim(my_dom_id_string))

/* total with over(<overvar>) requires a numeric variable */
encode my_dom_id_string, gen(my_dom_id)

/* Keep 1 observation per year-strat-psu-id_code. Sorting by dom_id first means
   the retained record is dom_id=1 if the trip targeted or caught cod or
   haddock, and dom_id=2 otherwise. */
bysort year wave strat_id psu_id id_code (dom_id): gen count_obs1=_n
keep if count_obs1==1

keep if dom_id=="1"
keep if area_s=="WGOM"

/* Negative trip weights occasionally appear in MRIP and are not usable as
   pweights; zeroing them drops those records from the estimate. */
replace wp_int=0 if wp_int<=0
svyset psu_id [pweight= wp_int], strata(strat_id) singleunit(certainty)


preserve
keep my_dom_id my_dom_id_string
duplicates drop 
tostring my_dom_id, gen(my_dom_id2)
keep my_dom_id2 my_dom_id_string
tempfile domains
save `domains', replace 
restore

encode mode1, gen(mode2)

svy: total dtrip, over(my_dom_id)  

/* svy: total leaves its results in the r(table) matrix, indexed by rows named
   like "dtrip@3.my_dom_id". xsvmat turns that matrix into a dataset; the two
   splits below peel off the "@" and the "." to recover the numeric domain id,
   which is then merged back to its readable label. */
xsvmat, from(r(table)') rownames(rname) names(col) norestor
split rname, parse("@")
drop rname1
split rname2, parse(.)
drop rname2 rname22
rename rname21 my_dom_id2
merge 1:1 my_dom_id2 using `domains'
drop rname my_dom_id2 _merge 
order my_dom_id_string
rename b dtrip 
sort dtrip  my_dom_id
keep dtrip se my_dom_id_string ll ul
split my, parse(_)
rename my_dom_id_string1 month 
rename my_dom_id_string2 mode
drop  my_dom_id_string3
drop my
ds month mode, not
renvarlab `r(varlist)', postfix(_mrip)

save "$misc_data_cd\mrip_dtrip_by_mode_month.dta", replace 


/******************************************************************************/
/******************************************************************************/
/* Section G (Part C): MRIP directed-trip totals by mode and season           */
/******************************************************************************/
/******************************************************************************/

di "directed_trips_calibration: estimating MRIP directed-trip totals by mode and season ..."

clear
 

tempfile tl1 cl1
dsconcat $triplist

/*dtrip will be used to estimate total directed trips*/
gen dtrip=1

sort year strat_id psu_id id_code
save `tl1'

clear

dsconcat $catchlist
sort year strat_id psu_id id_code
replace common=subinstr(lower(common)," ","",.)
save `cl1'

use `tl1'
merge 1:m year strat_id psu_id id_code using `cl1', keep(1 3)
replace common=subinstr(lower(common)," ","",.)
replace prim1_common=subinstr(lower(prim1_common)," ","",.)
replace prim2_common=subinstr(lower(prim2_common)," ","",.)

drop _merge
 
keep if $calibration_year


/* THIS IS THE END OF THE DATA MERGING CODE */

 /* ensure only relevant states */
keep if inlist(st,23, 33, 25)


 /* Classify trips into dom_id=1 (DOMAIN OF INTEREST) and dom_id=2 ('OTHER'
    DOMAIN). A trip counts as directed at groundfish if it either targeted
    (prim1_common) or caught (common) cod or haddock. The whole sample is kept
    rather than filtered, because a survey-weighted domain estimate needs the
    out-of-domain records to get the variance right. */
gen str1 dom_id="2"
replace dom_id="1" if strmatch(common, "atlanticcod") 
replace dom_id="1" if strmatch(prim1_common, "atlanticcod") 

replace dom_id="1" if strmatch(common, "haddock") 
replace dom_id="1" if strmatch(prim1_common, "haddock") 

tostring wave, gen(w2)
tostring year, gen(year2)
gen st2 = string(st,"%02.0f")

gen state="MA" if st==25
replace state="MD" if st==24
replace state="RI" if st==44
replace state="CT" if st==9
replace state="NY" if st==36
replace state="NJ" if st==34
replace state="DE" if st==10
replace state="VA" if st==51
replace state="NC" if st==37
replace state="ME" if st==23
replace state="NH" if st==33

gen mode1="sh" if inlist(mode_fx, "1", "2", "3")
replace mode1="pr" if inlist(mode_fx, "7")
replace mode1="fh" if inlist(mode_fx, "4", "5")

*drop shore trips
drop if mode1=="sh"

gen date=substr(id_code, 6,8)
gen month1=substr(date, 5, 2)
gen day1=substr(date, 7, 2)
drop if inlist(day1,"9x", "xx") 
destring day1, replace


/* Deal with group catch. MRIP records catch for a group of anglers against a
   single "leader" interview, so an individual angler's record can show no cod
   or haddock even though the group kept some. Within each
   strat_id-psu_id-leader group this takes the lowest dom_id (1 if anyone in
   the group was in the domain) and the largest domain claim (fish kept and
   available for identification), and promotes the trip to dom_id=1 if the
   group both was in the domain and had claimed groundfish. */

replace claim=0 if claim==.

gen domain_claim=claim if inlist(common, "atlanticcod", "haddock") 
mvencode domain_claim, mv(0) override

bysort strat_id psu_id leader (dom_id): gen gc_flag=dom_id[1]
bysort strat_id psu_id leader (domain_claim): gen claim_flag=domain_claim[_N]
replace dom_id="1" if strmatch(dom_id,"2") & claim_flag>0 & claim_flag!=. & strmatch(gc_flag,"1")


* generate estimation strata

*MRIP-Western GoM site allocations
preserve 
import delimited using "$misc_data_cd/MRIP_COD_ALL_SITE_LIST.csv", clear 
keep if inlist(state, "MA", "ME")
keep state intsite nmfs_stock_area nmfs_stat_area
sort intsite nmfs_stock_area  
replace nmfs_stock_area="WGOM" if inlist(nmfs_stat_area, 521, 526, 541, 514, 513, 515)
replace nmfs_stock_area="XX" if !inlist(nmfs_stat_area, 521, 526, 541, 514, 513, 515)
keep nmfs_stock_area intsite nmfs_stat_area state
duplicates drop
tempfile mrip_sites
save `mrip_sites', replace 
restore

merge m:1 intsite state using `mrip_sites',  keep(1 3)

/*classify into WGOM or not WGOM */
gen str3 area_s="XX"
replace area_s="WGOM" if st2=="33"
replace area_s=nmfs_stock_area if inlist(st2, "25", "23") 

gen season= "winter" if inlist(month, "09", "10", "11", "12", "01", "02", "03", "04")
replace season="summer" if inlist(month, "05", "06", "07", "08")

/* Estimation domain for this block: season x mode */
gen my_dom_id_string=season+"_"+mode1+"_"+ dom_id
replace my_dom_id_string=ltrim(rtrim(my_dom_id_string))

/* total with over(<overvar>) requires a numeric variable */
encode my_dom_id_string, gen(my_dom_id)

/* Keep 1 observation per year-strat-psu-id_code. Sorting by dom_id first means
   the retained record is dom_id=1 if the trip targeted or caught cod or
   haddock, and dom_id=2 otherwise. */
bysort year wave strat_id psu_id id_code (dom_id): gen count_obs1=_n
keep if count_obs1==1

keep if dom_id=="1"
keep if area_s=="WGOM"

/* Negative trip weights occasionally appear in MRIP and are not usable as
   pweights; zeroing them drops those records from the estimate. */
replace wp_int=0 if wp_int<=0
svyset psu_id [pweight= wp_int], strata(strat_id) singleunit(certainty)


preserve
keep my_dom_id my_dom_id_string
duplicates drop 
tostring my_dom_id, gen(my_dom_id2)
keep my_dom_id2 my_dom_id_string
tempfile domains
save `domains', replace 
restore

encode mode1, gen(mode2)

svy: total dtrip, over(my_dom_id)  

/* svy: total leaves its results in the r(table) matrix, indexed by rows named
   like "dtrip@3.my_dom_id". xsvmat turns that matrix into a dataset; the two
   splits below peel off the "@" and the "." to recover the numeric domain id,
   which is then merged back to its readable label. */
xsvmat, from(r(table)') rownames(rname) names(col) norestor
split rname, parse("@")
drop rname1
split rname2, parse(.)
drop rname2 rname22
rename rname21 my_dom_id2
merge 1:1 my_dom_id2 using `domains'
drop rname my_dom_id2 _merge 
order my_dom_id_string
rename b dtrip 
sort dtrip  my_dom_id
keep dtrip se my_dom_id_string ll ul
split my, parse(_)
rename my_dom_id_string1 season 
rename my_dom_id_string2 mode
drop  my_dom_id_string3
drop my
ds season mode, not
renvarlab `r(varlist)', postfix(_mrip)

save "$misc_data_cd\mrip_dtrip_by_mode_season.dta", replace 
