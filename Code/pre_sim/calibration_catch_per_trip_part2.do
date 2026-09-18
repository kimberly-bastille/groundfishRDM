/*******************************************************************************
 Script:       calibration_catch_per_trip_part2.do
 Status:       Refactored September 2026 to remove copy-paste duplication.
               Validated before it replaced the original: with both versions
               run from the same RNG state, every output file matched exactly
               (cf + datasignature, or byte-for-byte for CSV) at $ndraws = 101.
               The pre-refactor original is in git history:
                 git show fc318d1:Code/pre_sim/<this file name>
 Purpose:      Assembles the per-iteration calibration catch-draw files that the
               R simulation consumes. First builds an angler demographics pool
               (age and avidity) from the FES 12-month person files. Then, for
               each of $ndraws model iterations, expands every directed-trip day
               to 50 simulated trips x 30 catch draws, attaches a resampled trip
               cost and angler demographics (drawn once per iteration), samples
               catch-per-trip outcomes from the copula output for that iteration
               (by mode and month), and saves one calib_catch_draws_`i'.dta.
 Inputs:       $misc_data_cd/fes_person_final_2023`w'.dta (waves 1-6),
               $misc_data_cd/directed_trip_draws.csv,
               $misc_data_cd/trip_costs.dta,
               $calib_catch_draws_cd/calib_catch_draws_raw_`i'.dta (copula output).
 Outputs:      $misc_data_cd/angler_dems.dta,
               $calib_catch_draws_cd/calib_catch_draws_`i'.dta (i = 1..$ndraws).
 Dependencies: Globals $misc_data_cd, $calib_catch_draws_cd, $ndraws (set in
               model_wrapper.do). User commands distinct, dsconcat, renvarlab.
               Must run AFTER copula_modeling_calibration.R, which writes
               calib_catch_draws_raw_*.
 Pipeline:     Step 5c. Gated by `catch_per_trip2' in model_wrapper.do. Outputs
               feed compare_calibration_data_to_MRIP.do and the R simulation.

 Each output file contains, per directed-trip day in the calibration year: 50
 trips, each with 30 draws of catch-per-trip, plus per-trip demographics that
 are held constant across the 30 catch draws.

 RNG note: this file draws random samples (sample ..., count) but, like the
 original, does NOT set a seed. It inherits the session RNG state. The
 validation harness (since removed) set an identical state before the old and
 the new run. The number and order of RNG-consuming calls is
 unchanged from the original.

 What changed relative to the original (line numbers below refer to the
 pre-refactor file at git commit fc318d1):
   - The four-line sample-with-replacement idiom that appeared three times
     (original lines 274-277, 313-316, 371-374) is the program
     sample_with_replacement, defined once below.
   - The 20 repeated "distinct group if <key>==k" blocks (original 157-161,
     173-207, 220-236) are three short loops.
   - Everything else is unchanged apart from semicolon delimiting and
     comment style. In particular the three within-key id blocks (mode_id,
     month_id, wave_id) and the two resample loops are verbatim, because
     their sort behaviour decides which resampled row lands on which trip.
   Known oddities in the original are preserved on purpose and marked
   "PRESERVED" below.
*******************************************************************************/

#delimit ;

/******************************************************************************
 sample_with_replacement
 Turns the dataset in memory (a pool) into exactly n randomly chosen rows,
 sampling with replacement: the pool is duplicated ceil(n / rows) times so it
 has at least n rows, then exactly n rows are drawn at random. This is the
 idiom the original used three times. "sample" is the only RNG-consuming call
 and it is issued exactly as before.
 Parameters:
   n : number of rows the dataset must have on exit
******************************************************************************/
capture program drop sample_with_replacement ;
program define sample_with_replacement ;
    syntax , N(integer) ;

    quietly count ;
    local mult = ceil(`n'/r(N)) ;
    expand `mult' ;
    sample `n', count ;
end ;


/******************************************************************************/
/******************************************************************************/
/* Section A: Build the angler demographics pool (age and avidity)            */
/******************************************************************************/
/******************************************************************************/
/* Demographics: age and avidity (number trips past 12 months).
   Ages and avidity come from the fishing effort survey 12 MONTH files.
   These data are NOT publicly available and the data have not been processed
   for QA/QC like the publicly available 2-month files.
   Data from 2018-2023 was delivered by Lucas Johanssen on 4/23/2025. A few
   notes/caveats from Lucas:
     "FES QC processes focus on the 2-month reference periods, and we do very
      little evaluation and editing of 12-month effort responses.
      Responses for these fields are essentially unedited, raw data.
      The final weight trimming procedures focus on reducing the impacts of
      outlier values on wave-level estimates.
      The data may include records that are highly influential with respect
      to 12-month effort and any estimates may be highly variable.
      Wave data will produce independent estimates of 12-month effort."
   I will use the most recent year of FES survey data available (2023). */

global dems ;
local wvs 1 2 3 4 5 6 ;
foreach w of local wvs {;

    u  "$misc_data_cd\fes_person_final_2023`w'.dta", clear ;

    /* PRESERVED: this state block has no ME (23) or NH (33) lines, unlike
       part1's, and the next keep drops every unlabelled state. The pool
       therefore ends up MA-only after the inlist() at the end of Section A
       Kept as in the original. */
    gen state="MA" if st==25 ;
    replace state="MD" if st==24 ;
    replace state="RI" if st==44 ;
    replace state="CT" if st==9 ;
    replace state="NY" if st==36 ;
    replace state="NJ" if st==34 ;
    replace state="DE" if st==10 ;
    replace state="VA" if st==51 ;
    replace state="NC" if st==37 ;
    keep if state!="" ;

    tempfile dems`w' ;
    save `dems`w'', replace ;
    global dems "$dems "`dems`w''" " ;

};
clear ;
dsconcat $dems ;

gen total_trips_12=boat_trips_12+shore_trips_12 ;
gen total_trips_2=boat_trips+shore_trips ;

/* Lou's QA/QC on the FES data */

/* drop missing ages */
drop if age==-3 ;
/* drop anglers below the minimum age required for license to align the age
   distribution with choice experiment sampling frame, which is based on
   licensees (16+) */
keep if age>=16 ;

replace total_trips_2=round(total_trips_2) ;
replace total_trips_12=round(total_trips_12) ;
/* drop if total trips 2 months>total trips 12 months */
drop if total_trips_2>total_trips_12 ;

/* drop if total trips 2 months>60 */
drop if total_trips_2>=62 ;
/* drop if total trips 12 months>365 */
drop if total_trips_12>=365 ;

/* sum of weights is almost 300 million, so proportionally reduce the weights
   so Stata doesn't blow up */
replace final=final/100 ;
replace final=round(final) ;

expand final ;
su total_trips_12, detail ;

/* drop total_trips_12 above the 99.95 percentile */
egen p9995 = pctile(total_trips_12), p(99.95) ;
drop if total_trips_12>p9995 ;

keep age total_trips_12 wave state ;
keep if inlist(state, "ME", "NH", "MA") ;
save "$misc_data_cd\angler_dems.dta", replace ;


/******************************************************************************/
/******************************************************************************/
/* Section B: Generate the per-iteration catch-draw files                     */
/******************************************************************************/
/******************************************************************************/
di "Section B: generating catch-draw files for $ndraws iterations" ;

import delimited using "$misc_data_cd\directed_trip_draws.csv", clear ;

/* PRESERVED: the next block relies on Stata variable-name abbreviation
   exactly as the original does. "format date %td" on the first line below
   runs before a variable named date exists, so it formats date_num (the
   only match). Later "gen date_y2=date_num" runs after date_num has been
   dropped, so it reads date_num_y2. Every *_y2 variable is then dropped. */
gen double date_num = date(day, "DMY") ;
gen byte   month    = month(date_num) ;
gen str2   month1   = string(month, "%02.0f") ;
gen byte   wave     = cond(inlist(month,1,2),1,
                        cond(inlist(month,3,4),2,
                        cond(inlist(month,5,6),3,
                        cond(inlist(month,7,8),4,
                        cond(inlist(month,9,10),5,6))))) ;

format date %td ;
gen date=date_num ;
drop date_num day ;

gen double date_num_y2 = date(day_y2, "DMY") ;
format date %td ;
gen date_y2=date_num ;

drop date_num_y2 day_y2 ;
drop if dtrip==0 ;

drop  dtrip *_bag* *_min* *_y2 ;
drop month1 ;

tempfile base ;
save `base', replace ;

/*-----------------------------------------
  Loop draws
-----------------------------------------*/
quietly forvalues i=1/$ndraws {;
    noisily disp "Draw `i' started" ;
    use `base', clear ;
    keep if draw==`i' ;

    /* Expand to 50 trips x 30 catch draws within each (mode,date) */
    egen long dom = group(mode date) ;
    expand 50 ;
    bysort mode date: gen int tripid = _n ;
    expand 30 ;
    bysort mode date tripid: gen byte catch_draw = _n ;

    egen group=group(date tripid mode) ;

    /* Count distinct trip-groups within each mode, month, and wave. n_pr and
       n_fh size the cost resample (by mode) and n_wave1..6 size the
       demographics resample (by wave) below, so each stratum is filled to
       exactly the right size.
       PRESERVED: n_month1..12 and month_id are computed but never used
       afterwards. They are kept because the month_id merge
       re-sorts the data and later steps inherit that order. */
    foreach md in pr fh {;
        qui distinct group if mode=="`md'" ;
        local n_`md' = `r(ndistinct)' ;
    };

    /* PRESERVED: no explicit sort before "by mode:". It works because
       duplicates drop leaves the data sorted on mode date tripid (dataset
       variable order). The month and wave blocks below sort explicitly. The
       three blocks are deliberately left verbatim. */
    preserve ;
    keep date mode tripid ;
    duplicates drop ;
    by mode: gen mode_id=_n ;
    tempfile mode_id ;
    save `mode_id', replace ;
    restore ;

    merge m:1 date mode tripid using `mode_id', keep(3) nogen ;

    forvalues m=1/12 {;
        qui distinct group if month==`m' ;
        local n_month`m' = `r(ndistinct)' ;
    };

    preserve ;
    keep date month tripid ;
    duplicates drop ;
    sort date month tripid ;
    bysort month: gen month_id=_n ;
    tempfile month_id ;
    save `month_id', replace ;
    restore ;

    merge m:1 date month tripid using `month_id', keep(3) nogen ;

    forvalues w=1/6 {;
        qui distinct group if wave==`w' ;
        local n_wave`w' = `r(ndistinct)' ;
    };

    preserve ;
    keep date wave tripid ;
    duplicates drop ;
    sort date wave tripid ;
    bysort wave: gen wave_id=_n ;
    tempfile wave_id ;
    save `wave_id', replace ;
    restore ;

    merge m:1 date wave tripid using `wave_id', keep(3) nogen ;

    /*-------------------------------
      Costs: resample ONCE per draw
    -------------------------------*/
    preserve ;
        use "$misc_data_cd\trip_costs.dta", clear ;
        keep  mode cost ;
        tempfile costspool ;
        save `costspool', replace ;
    restore ;

    preserve ;
        clear ;
        tempfile costs50 ;
        save `costs50', emptyok replace ;

        foreach md in fh pr {;
            use `costspool', clear ;
            keep if mode=="`md'" ;

            local n_needed = cond("`md'"=="pr", `n_pr', `n_fh') ;

            sample_with_replacement, n(`n_needed') ;
            gen int mode_id = _n ;

            keep mode mode_id cost ;
            append using `costs50' ;
            save `costs50', replace ;
        };
    restore ;

    merge m:1 mode mode_id using `costs50', keep(3) nogen ;

    /*--------------------------------
      Dems: resample ONCE per draw
    --------------------------------*/
    preserve ;
        use "$misc_data_cd\angler_dems.dta", clear ;
        tempfile demspool ;
        save `demspool', replace ;
    restore ;

    preserve ;
        clear ;
        tempfile dems50 ;
        save `dems50', emptyok replace ;

        forvalues w=1/6 {;
            use `demspool', clear ;
            keep if wave==`w' ;

            local n_needed = cond(`w'==1, `n_wave1',
                             cond(`w'==2, `n_wave2',
                             cond(`w'==3, `n_wave3',
                             cond(`w'==4, `n_wave4',
                             cond(`w'==5, `n_wave5', `n_wave6'))))) ;

            sample_with_replacement, n(`n_needed') ;

            gen wave_id = _n ;
            keep wave wave_id age total_trips_12 ;
            append using `dems50' ;
            save `dems50', replace ;
        };
    restore ;

    merge m:1 wave wave_id using `dems50', keep(3) nogen ;

    preserve ;
        u "$calib_catch_draws_cd\calib_catch_draws_raw_`i'.dta", clear ;
        split my_dom_id_string, parse(_) ;
        rename my_dom_id_string1 month ;
        rename my_dom_id_string2 mode ;
        drop my_dom_id_string3 ;
        keep my_dom_id_string month mode  cod_* hadd_* ;
        destring month, replace ;
        tempfile excelpool ;
        save `excelpool', replace ;
    restore ;

    /*---------------------------------------
      Sample catch outcomes by (mode, month)
    ---------------------------------------*/
    egen long g = group(mode month) ;
    bysort g: gen long gid = _n ;
    bysort g: gen long n_g = _N ;
    levelsof g, local(gs) ;

    tempfile trips_expanded ;
    save `trips_expanded', replace ;

    /* Build catch outcomes dataset with keys (g, gid) */
    clear ;
    tempfile catchall ;
    save `catchall', emptyok replace ;
    local seeded 0 ;

    foreach gg of local gs {;
        use `trips_expanded', clear ;
        keep if g==`gg' ;
        keep mode month ;
        local md  = mode[1] ;
        local mnth  = month[1] ;
        local n_needed = _N ;
        di "`md'" ;
        di "`mnth'" ;
        di `n_needed' ;
        use `excelpool', clear ;
        keep if month==`mnth' & mode=="`md'" ;

        sample_with_replacement, n(`n_needed') ;

        /* Ensure enough rows were produced before continuing */
        quietly count ;
        if (r(N) < `n_needed') {;
            di as error "Not enough catch rows for  draw=`i' mode=`md' month=`mnth' need=`n_needed' have=" r(N) ;
            continue ;
        };

        gen long g   = `gg' ;
        gen long gid = _n ;

        tempfile chunk ;
        save `chunk', replace ;

        if (`seeded'==0) {;
            use `chunk', clear ;
            save `catchall', replace ;
            local seeded 1 ;
        };
        else {;
            use `catchall', clear ;
            append using `chunk' ;
            save `catchall', replace ;
        };
    };

    /* Merge sampled catch onto trips by (g,gid) */
    use `trips_expanded', clear ;
    merge 1:1 g gid using `catchall', keep(3) nogen ;

    drop g gid n_g ;
    compress ;

    sort date tripid catch_ ;
    gen cod_cat  = cod_keep + cod_rel ;
    gen hadd_cat = hadd_keep + hadd_rel ;

    keep  draw
          cod_keep cod_cat cod_rel
          hadd_keep hadd_rel hadd_cat
          mode month date
          tripid catch_draw age total_trips_12 cost ;

    renvarlab cod_keep cod_cat cod_rel hadd_keep hadd_rel hadd_cat, postfix(_sim) ;

    order mode date tripid catch ;
    sort mode date tripid catch ;
    compress ;

    save "$calib_catch_draws_cd\calib_catch_draws_`i'.dta", replace ;
    noisily disp "Draw `i' finished" ;

};

#delimit cr
