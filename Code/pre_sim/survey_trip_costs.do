
/*******************************************************************************
 Script:       survey_trip_costs.do
 Purpose:      Builds simulated trip-cost distributions by mode/species-domain
               from the survey expenditure data using a two-part ("hurdle")
               model: a survey-weighted probability of any spending, plus a
               lognormal for positive costs calibrated so the simulated
               positive-cost mean matches the survey estimate. Adjusts for
               inflation and caps simulated costs at the observed max by mode.
 Inputs:       $misc_data_cd/gulf_atl_2022.dta (expenditure survey),
               $misc_data_cd/prim1.dta, $misc_data_cd/prim2.dta.
 Outputs:      $misc_data_cd/trip_costs.dta
 Dependencies: Globals $seed, $inflation_expansion, $misc_data_cd
               (set in model_wrapper.do).
 Pipeline:     Wrapped by model_wrapper.do, gated by `costs_per_trip' (default ON;
               commented in the wrapper as a "run 1x" step).
 Note:         The original comment described this as "Sabrina's 2017 trip
               expenditure survey," but the code loads gulf_atl_2022.dta and later
               comments reference the 2022 data — the "2017" appears stale.
*******************************************************************************/

set seed $seed

/******************************************************************************/
/******************************************************************************/
/* Section A: Load and clean the survey expenditure data */
/******************************************************************************/
/******************************************************************************/

*Enter a directory with the expenditure survey data
u "$misc_data_cd\gulf_atl_2022.dta", clear
renvarlab *, lower


* As per Sabrina Lovell, run the following code before using the 2022 data. This code sets certain expenditure variables to missing depending on the trip mode. 
* Begin Sabrina's code recommendation:
* For-Hire trips: set boat fuel and boat rental to missing
replace bfuelexp = . if mode == "For-Hire"
replace brentexp = . if mode == "For-Hire"

* Private Boat trips: set guide costs and crew tips to missing
replace guideexp = . if mode == "Private Boat"
replace crewexp  = . if mode == "Private Boat"

* Shore trips: set all of those to missing
replace bfuelexp = . if mode == "Shore"
replace crewexp  = . if mode == "Shore"
replace guideexp = . if mode == "Shore"
replace brentexp = . if mode == "Shore"
* End Sabrina's code recommendation

*keep only the states we need (ME, NH, MA) 
keep if inlist(st, 23, 33, 25)

mvencode afuelexp arentexp ptransexp lodgexp grocexp restexp baitexp iceexp parkexp bfuelexp brentexp guideexp crewexp procexp feesexp giftsexp  othexp, mv(0) override



*replace some non-trip expenses included in "other" category as zero
replace othexp=0 if inlist(oth_cat, "2 LICENSES", "BOAT REPAIR", "Boat Towing", "CART", "FISHING LICENSE")
replace othexp=0 if inlist(oth_cat,"LICENSE", "LICENSES", "MONEY SPENT AT CASINO", "NEW ROD", "SEATOW", "SPA", "HAT")
replace othexp=0 if inlist(oth_cat,"ALL WATERS LICENSE", "ANGLER GOT A SPEEDING TICKET", "BOAT CLEANING", "CASINOS", "ENTERTAINMENT")
replace othexp=0 if inlist(oth_cat,"FIREWOOD", "POOL", "REGISTRATION", "SUNGLASSES", "TAKING BOAT TO CAR WASH", "WATER PARK", "WOOD")

* Compute total trip expenditure
egen total_exp=rowtotal(afuelexp arentexp ptransexp lodgexp grocexp restexp baitexp iceexp parkexp bfuelexp brentexp guideexp crewexp procexp feesexp giftsexp othexp) 

svyset psu_id [pweight= sample_wt], strata(var_id) singleunit(certainty)

*merge prim1 (numeric id for species) to prim1_common (common_name identified) in order to estimates trip costs for the species of interest, rather than for all species
merge m:1 prim1 using "$misc_data_cd\prim1.dta", keep(1 3) nogen 
merge m:1 prim2 using "$misc_data_cd\prim2.dta", keep(1 3) nogen 

gen st2 = string(st,"%02.0f")
gen state="CT" if st2=="09" 
replace state="DE" if st2=="10"
replace state="ME" if st2=="23"
replace state="MD" if st2=="24"
replace state="MA" if st2=="25"
replace state="NJ" if st2=="34"
replace state="NY" if st2=="36"
replace state="NC" if st2=="37"
replace state="RI" if st2=="44"
replace state="VA" if st2=="51"
replace state="NH" if st2=="33"

*Sabrina's definition of for-hire mode include both headboat and charter boats
*Survey mode definitions:
	*3=shore
	*4=headboat
	*5=charter
	*7=private boat

gen mode1="sh" if inlist(mode_fx, "1", "2", "3")
replace mode1="fh" if inlist(mode_fx, "4", "5")
replace mode1="pr" if inlist(mode_fx,  "7")

*Adjust for inflation
replace total_exp = total_exp*$inflation_expansion

*computes trip cost distribution based on directed trips for cod, haddock, or pollock
gen common_dom="1" if inlist(prim1_common, "HADDOCK", "ATLANTIC COD", "POLLOCK") |  inlist(prim2_common, "HADDOCK", "ATLANTIC COD", "POLLOCK")
replace common_dom="2" if common_dom==""
*gen common_dom="1" 


gen domain=mode1+"_"+common_dom
encode domain, gen(domain2)

preserve
keep domain domain2
duplicates drop 
tempfile domains
save `domains', replace 
restore


/******************************************************************************/
/******************************************************************************/
/* Section B: Survey-weighted observed cost means by mode-species domain */
/******************************************************************************/
/******************************************************************************/

preserve
svy: mean total_exp, over(domain2)

xsvmat, from(r(table)') rownames(rname) names(col) norestor
split rname, parse("@")
drop rname1
split rname2, parse(.)
drop rname2 rname22
rename rname21 domain2
destring domain2, replace
merge 1:1 domain2 using `domains'

drop rname domain2 _merge 
order domain

split domain, parse(_)
rename domain1 mode
rename domain2 common_dom

renam b cost 
keep  mode common_dom cost se  ll ul
order  mode common_dom cost se  ll ul
tempfile observed 
save `observed', replace 
restore


/******************************************************************************/
/******************************************************************************/
/* Section C: Two-part hurdle parameters (spend probability + lognormal) */
/******************************************************************************/
/******************************************************************************/

*Two-part ("hurdle") simulation with a calibrated lognormal for positive costs, by mode domain.
drop domain
egen str4 domain = concat(mode1 common_dom), punct("_")
encode domain, gen(dom2)

svy: mean total_exp, over(dom2)
gen cost=total_exp

preserve
keep if common_dom=="1"
keep cost mode1  
bysort mode1: egen max_cost=max(cost)
keep mode1 max
rename mode1 mode
duplicates drop 
tempfile max_cost
save `max_cost', replace 
restore

* Observed cap (e.g., 99th percentile) for positive costs
/*
preserve
keep if cost>0 & !missing(cost, dom2)

tempfile caps
postfile C int dom2 double cap99 using `caps', replace

levelsof dom2, local(domlist)
foreach d of local domlist {
     _pctile cost [pw=sample_wt] if dom2==`d', p(99)
    scalar cap =  r(r1)
    post C (`d') (cap)
}
postclose C
use `caps', clear
save `caps', replace
restore
*/
*----------------------------
* Cost indicators
*----------------------------
gen byte pos_cost = cost > 0 if !missing(cost)

gen double lncost  = ln(cost)  if cost > 0
gen double lncost2 = lncost^2  if cost > 0

svy: mean pos_cost, over(dom2)



*Estimate the mean positive cost by domain (survey-weighted)
*used to calibrate the lognormal so the simulated positive-cost mean matches the survey positive-cost mean.
preserve
keep if cost>0 & !missing(dom2)

tempfile meanpos
postfile M int dom2 double mean_pos using `meanpos', replace

levelsof dom2, local(domlist)
foreach d of local domlist {
    quietly svy, subpop(if dom2==`d'): mean cost
    matrix b = e(b)
    post M (`d') (b[1,1])
}
postclose M
use `meanpos', clear
save `meanpos', replace
restore



*estimate survey conditional mean of positive costs by domain
*provides Bernoulli probability used later in simulation: spend = (runiform() < p_hat)
preserve
tempfile p_pos
postfile P int dom2 str4 domain double p_hat se_p long N using `p_pos', replace

levelsof dom2, local(domlist)

foreach d of local domlist {
    quietly svy, subpop(if dom2==`d'): mean pos_cost
    matrix b = e(b)
    matrix V = e(V)

    scalar p  = b[1,1]
    scalar se = sqrt(V[1,1])

    quietly count if dom2==`d'
    local domname : label (dom2) `d'

    post P (`d') ("`domname'") (p) (se) (r(N))
}
postclose P
restore


*Estimate lognormal dispersion for positive costs by domain (survey-weighted)
*gives the shape/variance of the positive-cost distribution on the log scale.
preserve
keep if cost > 0 & !missing(dom2, lncost, lncost2)

tempfile ln_parms
postfile L int dom2 str4 domain double mu_hat m2_hat sig2_hat double v11 v22 v12 long N using `ln_parms', replace

levelsof dom2, local(domlist)

foreach d of local domlist {
    quietly svy, subpop(if dom2==`d'): mean lncost lncost2
    matrix b = e(b)
    matrix V = e(V)

    scalar mu  = b[1,1]
    scalar m2  = b[1,2]
    scalar s2  = m2 - mu^2
    if (s2 < 1e-10) scalar s2 = 1e-10

    quietly count if dom2==`d'
    local domname : label (dom2) `d'

    post L (`d') ("`domname'") ///
        (mu) (m2) (s2) ///
        (V[1,1]) (V[2,2]) (V[1,2]) ///
        (r(N))
}
postclose L
restore

use `p_pos', clear
merge 1:1 dom2 using `ln_parms', nogen
*merge 1:1 dom2 using `caps', nogen
merge 1:1 dom2 using `meanpos', nogen

*calibrate the lognormal mean to match mean_pos
*simulated positive-cost mean should line up with the survey-estimated positive-cost mean (up to Monte Carlo error), while keeping the estimated log-variance sig2_hat
gen double mu_adj = ln(mean_pos) - 0.5*sig2_hat

/******************************************************************************/
/******************************************************************************/
/* Section D: Simulate trip costs (two-part hurdle) and cap at observed max */
/******************************************************************************/
/******************************************************************************/

display "Simulating trip-cost distributions by domain ..."
local n_draws = 10000

expand `n_draws'
bysort dom2: gen long draw = _n


*Simulate trip costs 
*Part A - zero costs:
gen byte spend = runiform() < p_hat

* Part B  - Positive costs
gen double cost_sim = 0
replace cost_sim = exp(rnormal(mu_adj, sqrt(sig2_hat))) if spend==1

* Check mass at zero
by dom2: egen share_zero = mean(cost_sim==0)
list dom2 domain p_hat share_zero in 1/10
*replace cost_sim = cap99 if cost_sim > cap99 & spend==1

split domain, parse(_)
rename domain1 mode
rename domain2 common_dom
rename draw tripid
keep mode cost tripid  common_dom
compress

format cost %9.2f
order  mode common_dom tripid cost
keep if common_dom=="1"

*when cost_sim>max(observed cost), set cost_sim=cost_sim>max(observed cost), by region or state-mode 
merge m:1 mode using `max_cost'
replace cost=max if cost_sim>max
drop max  common _merge 
/*
*compare simulated versus observed

collapse (mean) cost_sim=cost (sd) sd_cost=cost, by( mode common_dom)
merge 1:1  mode common_dom using `observed'
gen se_sim=sqrt(sd)

order  mode common_dom cost_sim cost se_sim se
gen pct_dif=((cost_sim-cost)/cost)*100

su pct_dif
*/

save "$misc_data_cd\trip_costs.dta", replace 


