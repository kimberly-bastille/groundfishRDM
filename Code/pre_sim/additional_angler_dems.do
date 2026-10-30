/*******************************************************************************
 Script:       additional_angler_dems.do
 Purpose:      Assembles the angler demographics that enter the trip utility
               model and merges them onto each catch-per-trip draw file. Draws
               an education group per angler from a 3-category Dirichlet fitted
               to survey education proportions, and attaches preference and
               choice-experiment variables by resampling reference datasets.
 Inputs:       $calib_catch_draws_cd/calib_catch_draws_<i>.dta (i = 1..$ndraws),
               $misc_data_cd/preference_params.dta,
               $misc_data_cd/choice_exp_angler_dems.dta
 Outputs:      Overwrites each $calib_catch_draws_cd/calib_catch_draws_<i>.dta
               with the demographic variables merged in.
 Dependencies: Globals $seed, $ndraws, $calib_catch_draws_cd, $misc_data_cd
               (set in model_wrapper.do).
 Pipeline:     Wrapped by model_wrapper.do, gated by `angler_demogs' (default ON).
*******************************************************************************/

set seed $seed

* Variables needed: 
	* # days fished past 12 months - I get this from the MRIP FES 
	* Do you like saltwater fishing more or less than other recreational activities? - I get this below from the choice experiment survey sample
	* Education - I get this below from Sabrina's 2019 durable survey data
	* Do you own a boat? - I get this below from the choice experiment survey sample
	

/******************************************************************************/
/******************************************************************************/
/* Section A: Derive the population education Dirichlet parameters */
/******************************************************************************/
/******************************************************************************/

* random draws of education levels
* set up the population education information:
/* Population education shares (percent) and their standard errors, used below
   to derive a Dirichlet concentration (alpha0) for resampling education groups. */
local p1  = 5.1869    // percent in education level 1
local se1 = 0.7127    // SE of percent in education level 1

local p2  = 18.9534
local se2 = 1.2590

local p3  = 28.1474
local se3 = 1.4768

local p4  = 25.8252
local se4 = 1.4009

local p5  = 21.8872
local se5 = 1.3107

foreach i in 1 2 3 4 5 {
    scalar p`i'  = `p`i''/100
    scalar v`i'  = (`se`i''/100)^2   // variance of proportion
    scalar a0`i' = p`i'*(1-p`i')/v`i' - 1   // alpha0 candidate from var(p_i)=p_i(1-p_i)/(α0+1)
}

/* Inverse-variance–weighted average of the five per-category alpha0 candidates
   (weight = 1/variance).  */
scalar w1 = 1/v1
scalar w2 = 1/v2
scalar w3 = 1/v3
scalar w4 = 1/v4
scalar w5 = 1/v5
scalar a0 = (w1*a01 + w2*a02 + w3*a03 + w4*a04 + w5*a05) / (w1 + w2 + w3 + w4 + w5)

* 5-category Dirichlet alpha's
forvalues i=1/5 {
    scalar a`i' = p`i' * a0
}

* Group to 3 bins: (1-2), (3-4), (5)
scalar a12 = a1 + a2
scalar a34 = a3 + a4
scalar a5g = a5     // rename to avoid clash with a5 scalar



/******************************************************************************/
/******************************************************************************/
/* Section B: Attach demographics to each catch-per-trip draw */
/******************************************************************************/
/******************************************************************************/

display "Attaching angler demographics to catch-per-trip draws 1..$ndraws ..."

forvalues i = 1/$ndraws {

	*local i=1
	   use "$calib_catch_draws_cd\calib_catch_draws_`i'.dta", clear
	   
	   preserve 
	   keep mode date tripid
	   duplicates drop
	   count
	   local N_needed=`r(N)'
	   gen merge_id=_n
	   tempfile individuals 
	   save `individuals', replace 
	   restore 
	   
	   
	   tempfile base 
	   save `base', replace 
	   
	   u "$misc_data_cd\preference_params.dta", clear
	   count
	   local N=`r(N)'
	   /* Resample the reference file with replacement up to N_needed rows:
	      replicate it enough times to exceed N_needed, then take a random
	      N_needed-row sample. (Same idiom repeats for choice_exp_angler_dems.dta below.) */
	   local expand = (`N_needed'/`N')+1
	   expand `expand'
	   sample `N_needed', count
	   gen merge_id=_n

	   merge 1:1 merge_id using `individuals'
	   drop _merge  merge_id
	   merge 1:m mode date tripid using `base'
	   drop _merge
	   
	   tempfile base
	   save `base', replace
	   
	   u "$misc_data_cd\choice_exp_angler_dems.dta", clear 
	   count
	   local N=`r(N)'
	   local expand = (`N_needed'/`N')+1
	   expand `expand'
	   sample `N_needed', count
	   
	   /* Reseed per draw so each draw i is independently reproducible. */
	   set seed `i'
	   /* Draw the 3-category education shares as a Dirichlet, generated as
	      normalized independent Gamma(alpha,1) variates: (g1,g2,g3)/sum yields
	      a Dirichlet(a12,a34,a5g) vector. */
	   scalar g1 = rgamma(a12,1)
	   scalar g2 = rgamma(a34,1)
	   scalar g3 = rgamma(a5g,1)
	   scalar S  = g1+g2+g3
	   scalar p12 = g1/S
	   scalar p34 = g2/S
	   scalar p5b = g3/S

	   /* Assign each angler to an education bin by inverse-CDF sampling on the
	      Dirichlet shares (uniform draw vs cumulative p12, then p12+p34). */
	   gen rand= runiform()
	   gen byte edu_grp = cond(rand < p12, 1, cond(rand < p12 + p34, 2, 3))
	   label define edu3 1 "Ed 1–2" 2 "Ed 3–4" 3 "Ed 5", replace
	   label values edu_grp edu3
	   tab edu_grp, gen(educ)
	   drop edu_grp rand qtid
	   gen merge_id=_n

	   merge 1:1 merge_id using `individuals'
	   drop _merge  merge_id
	   merge 1:m mode date tripid using `base'
	   drop _merge
	   order draw mode date tripid catch_draw
	   sort draw mode date tripid catch
	   
	   save  "$calib_catch_draws_cd\calib_catch_draws_`i'.dta", replace
	}

display "Finished attaching angler demographics to all $ndraws draws."


			
	

