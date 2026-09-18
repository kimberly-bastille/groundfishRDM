/*******************************************************************************
 Script:       catch_at_length_projection.do
 Status:       Refactored September 2026 to remove copy-paste duplication.
               Validated before it replaced the original: with both versions
               run from the same RNG state, every output file matched exactly
               (cf + datasignature, or byte-for-byte for CSV) at $ndraws = 101.
               The pre-refactor original is in git history:
                 git show fc318d1:Code/pre_sim/<this file name>
 Purpose:      Produces the projection-year catch-at-length probability
               distribution for WGOM cod and GOM haddock. The idea is to hold
               recreational selectivity at length fixed at what was observed
               in the calibration year, and let the length composition of the
               catch change only because the projected stock has a different
               age (and therefore length) composition.
 Method (the numbered sections below follow these steps):
   1. Read baseline recreational catch-at-length.
   2. Build cod and haddock age-length keys (ALKs) from recent NEFSC trawl
      data: pull the survey data, smooth counts across lengths within each
      age with a LOWESS (bandwidth 0.3), then compute the proportion of
      fish of age a that are length l.
   3. Convert baseline stock assessment numbers-at-age (NAA) into baseline
      numbers-at-length (NAL).
   4. Merge baseline NAL to observed baseline catch-at-length and compute
      an empirical recreational selectivity ("fraction caught") at length
      by species, season, draw and length.
   5. Convert projected NAA into projected NAL using the same ALKs.
   6. Apply baseline selectivity-at-length to projected NAL to obtain
      projected catch-at-length.
   7. Smooth projected catch-at-length into a probability distribution by
      fitting a gamma to each species-season-draw.
   8. Export projected fitted probabilities by draw/species/season/length.
 Inputs:       $misc_data_cd/baseline_catch_at_length_observed.csv
               $misc_data_cd/baseline_catch_at_length.csv
               $misc_data_cd/NEFSC_cruises.csv
               $misc_data_cd/NEFSC_trawl_cod.csv, NEFSC_trawl_hadd.csv
               $misc_data_cd/WGOM_Cod_historical_NAA.dta,
                             WGOM_Cod_projected_NAA.dta
               $misc_data_cd/GOM_Haddock_historical_NAA.dta,
                             GOM_Haddock_projected_NAA.dta
 Outputs:      $misc_data_cd/projected_catch_at_length.csv
 Dependencies: catch_at_length_calibration.do (writes both baseline CSVs)
               and the assessment scripts get_cod_assessment_data.R /
               get_haddock_assessment_data.R (write the NAA files). Expects
               $seed, $ndraws, $misc_data_cd, $input_code_cd,
               $trawl_survey_start_year, $cod_NAA_base_year,
               $hadd_NAA_base_year, $cod_NAA_proj_year and
               $hadd_NAA_proj_year to be set by model_wrapper.do. Loads
               catch_at_length_programs.do (same folder). User command
               renvarlab.
 Pipeline:     Step 10, gated by `catch_at_length_project' in
               model_wrapper.do. The exported CSV is what the R simulation
               reads to decide the size composition of projection-year catch.

 What changed relative to the original (line numbers below refer to the
 pre-refactor file at git commit fc318d1):
   The original did Sections 2, 3 and 5 once for cod and once for haddock.
   The parts that were identical apart from species-specific values are
   now programs defined once below:
     build_alk         original lines 90-158 / 163-230
     base_naa_to_nal   original lines 262-280 / 295-309
     proj_naa_to_nal   original lines 418-442 / 471-494
   The species-specific reshaping of the assessment NAA (including the two
   sample $ndraws calls) is unchanged. The gamma fit (original 551-660) and
   the truncate/renormalize loop (original 717-726) are shared with the
   calibration script and live in catch_at_length_programs.do:
     fit_gamma_by_domain, truncate_to_observed
   Everything else is the original, re-delimited with semicolons.
   Known oddities in the original are preserved on purpose, because this
   file must match the original exactly. They are marked "PRESERVED" below.
*******************************************************************************/

/* Shared programs. Loaded before switching delimiters so the nested do-file
   starts and ends in the default (carriage-return) delimiter state. */
do "$input_code_cd/catch_at_length_programs.do"

#delimit ;

/******************************************************************************/
/******************************************************************************/
/* Programs (defined once, used for cod and for haddock)                      */
/******************************************************************************/
/******************************************************************************/

/******************************************************************************
 build_alk
 Age-length key for one species from NEFSC trawl survey data:
   a. pull the trawl records from $trawl_survey_start_year on, pooling ages
      at and above the plus-group;
   b. fill empty length bins within each age (tsset/tsfill), then smooth
      counts across lengths within each age with a LOWESS (bandwidth 0.3),
      truncating negative smoothed counts at zero;
   c. compute the proportion of fish of age a that are length l, both from
      the smoothed and from the raw counts.
 The cruise list is re-imported on every call, as the original did for each
 species. The survey-year range and per-age counts are displayed for the log.
 Parameters:
   trawlfile : NEFSC trawl CSV for one species
   plusage   : oldest age; all older ages are pooled into this plus-group
               (cod 6, haddock 9). Also sets the s0-s<plusage> range that
               folds the per-age lowess columns back into one.
   saveas    : caller-created tempfile path that receives the ALK
               (age length count smoothed prop_smoothed prop_raw)
   countvar  : if given and not "count", that column of the CSV is renamed
               to count first. The cod file calls it countage; the haddock
               file already calls it count (F-B8).
******************************************************************************/
capture program drop build_alk ;
program define build_alk ;
    syntax , TRAWLFILE(string) PLUSAGE(string) SAVEAS(string) [ COUNTVAR(name) ] ;

    /* 2a */
    import delimited using "$misc_data_cd/NEFSC_cruises.csv", clear ;
    renvarlab, lower ;
    tempfile cruises ;
    sort year ;
    save `cruises', replace ;

    import delimited using "`trawlfile'", clear ;
    renvarlab, lower ;
    if "`countvar'" != "" & "`countvar'" != "count" {;
        rename `countvar' count ;
    };
    merge m:1 cruise6 using `cruises' ;
    collapse (sum) count, by(year season svspp age length) ;
    keep if year>=$trawl_survey_start_year ;
    collapse (sum) count, by(year age length) ;

    su year ;
    local min_svy_yr=`r(min)' ;
    local max_svy_yr=`r(max)' ;
    di `min_svy_yr' ;
    tabstat count, stat(sum) by(age) ;
    replace age=`plusage' if age>=`plusage' ;
    collapse (sum) count, by (age length) ;
    drop if age==. | length==. ;

    /* Treat age as the panel and length as the time index so tsfill inserts
       the length bins with no sampled fish; mvencode then makes those counts
       zero, so every age spans the same contiguous length range before
       smoothing. */
    tsset age length ;
    tsfill, full ;

    sort age length ;
    mvencode count, mv(0) override ;

    /* 2b. lowess writes its smoothed values into a separate variable per age,
       and each of those is missing outside that age's rows; the rowtotal
       below folds them back into one column. Negative smoothed counts are
       truncated at zero. PRESERVED: s0-s<plusage> is a variable range, so it
       assumes age 0 is present in the data and that the s<age> columns were
       generated in age order, exactly as the original assumed. */
    levelsof age, local(ages) ;
    foreach a of local ages {;
        lowess count length if age==`a' , adjust bwidth(.3) gen(s`a') nograph ;
        replace s`a'=0 if s`a'<=0 ;
    };

    egen smoothed=rowtotal(s0-s`plusage') ;
    drop s0-s`plusage' ;

    egen sum=sum(smoothed), by(age) ;
    gen prop_smoothed=smoothed/sum ;

    /* 2c. */
    egen sum_raw=sum(count), by(age) ;
    gen prop_raw=count/sum_raw ;

    drop if age==0 ;
    drop sum sum_raw ;
    save "`saveas'", replace ;
end ;

/******************************************************************************
 base_naa_to_nal
 Converts one species' baseline numbers-at-age (in memory: one row per age,
 variables age nfish) to numbers-at-length using its ALK, then copies the
 result to both seasons. NAA are annual, so the same numbers-at-length go to
 winter and summer; seasonal differences in catch composition come entirely
 from the season-specific selectivity estimated in Section 4. On exit the
 data in memory are one row per length x season
 (length base_nal_raw base_nal_smooth species season).
 Parameters:
   alkfile : tempfile written by build_alk for this species
   species : label written into the species variable ("cod" or "hadd")
******************************************************************************/
capture program drop base_naa_to_nal ;
program define base_naa_to_nal ;
    syntax , ALKFILE(string) SPECIES(string) ;

    merge 1:m age using "`alkfile'", keep(3) nogen ;
    sort  age length ;

    gen base_nal_raw = prop_raw*nfish ;
    gen base_nal_smooth = prop_smoothed*nfish ;

    drop count  prop* nfish smoothed ;
    collapse (sum) base_nal*, by(length) ;

    sort length ;
    gen species="`species'" ;
    expand 2, gen(dup) ;
    gen season="winter" if dup==0 ;
    replace season="summer" if dup==1 ;
    drop dup ;
end ;

/******************************************************************************
 proj_naa_to_nal
 Converts one species' projected numbers-at-age (in memory: one row per
 draw x age, variables draw age nfish and the replicate id) to numbers-at-
 length by draw, then copies the result to both seasons. One ALK is
 estimated for all draws, so it is replicated across draws first to make the
 merge to the per-draw projected NAA a clean 1:m. On exit the data in memory
 are one row per length x draw x season
 (length draw <repvar> proj_nal_raw proj_nal_smooth species season).
 Parameters:
   alkfile : tempfile written by build_alk for this species
   species : label written into the species variable ("cod" or "hadd")
   repvar  : the species' assessment-replicate id variable, carried through
             the collapse (cod_replicate or hadd_replicate)
******************************************************************************/
capture program drop proj_naa_to_nal ;
program define proj_naa_to_nal ;
    syntax , ALKFILE(string) SPECIES(string) REPVAR(name) ;

    preserve ;
    use "`alkfile'", clear ;
    expand $ndraws ;
    bysort length age: gen draw=_n ;
    tempfile alk_expand ;
    save `alk_expand', replace ;
    restore ;

    merge 1:m age draw using `alk_expand', keep(3) nogen ;
    sort  draw age length ;

    gen proj_nal_raw = prop_raw*nfish ;
    gen proj_nal_smooth = prop_smoothed*nfish ;

    /* D-B1: the original dropped these before the collapse for cod only;
       collapse discards them anyway, so the result is identical for both. */
    drop count  prop* nfish smoothed ;
    collapse (sum) proj_nal*, by(length draw `repvar') ;

    sort length ;
    gen species="`species'" ;
    expand 2, gen(dup) ;
    gen season="winter" if dup==0 ;
    replace season="summer" if dup==1 ;
    drop dup ;
end ;

/******************************************************************************/
/******************************************************************************/
/* Section 1: Pull in baseline catch-at-lengths                               */
/******************************************************************************/
/******************************************************************************/

set seed $seed ;

import delimited using "$misc_data_cd/baseline_catch_at_length_observed.csv", clear ;
keep if draw<= $ndraws ;
sort draw season species length ;

tempfile cal ;
save `cal', replace ;

/******************************************************************************/
/******************************************************************************/
/* Section 2: Age-length keys from NEFSC trawl survey data                    */
/******************************************************************************/
/******************************************************************************/

di "catch_at_length_projection: building cod and haddock age-length keys ..." ;

tempfile al_cod al_hadd ;

/* Cod ALK - ages 1 through 6+. There are few observations at age 7+, so those
   ages are pooled into a 6+ plus-group. The cod trawl file names its count
   column countage. */
build_alk , trawlfile("$misc_data_cd/NEFSC_trawl_cod.csv") plusage(6)
            saveas("`al_cod'") countvar(countage) ;

/* Haddock ALK - ages 1 through 9, with a 9+ plus-group */
build_alk , trawlfile("$misc_data_cd/NEFSC_trawl_hadd.csv") plusage(9)
            saveas("`al_hadd'") ;

/* Optional diagnostics, kept from the original (one copy per species there).
   To use, run inside build_alk after prop_raw is created, with `a' the age
   and the species name in the title.

levelsof age, local(ages)
foreach a of local ages{
twoway(scatter prop_raw length if age==`a',   connect(direct) lcol(red)   lpat(solid) msymbol(i) ) ///
			(scatter prop_smoothed length if age==`a', connect(direct) lcol(blue) title("cod age `a' NEFSC trawl `min_svy_yr'-`max_svy_yr'", size(small)) ///
			ytitle("proportion of fish that are age-a", size(small)) ytick(, angle(horizontal) labsize(small)) xtitle(length cms, size(small)) xlab(, labsize(small)) ///
			ylab(, labsize(small) angle(horizontal)) xtick(, labsize(small)) lpat(solid) msymbol(i)  name(dom`a', replace))
 local graphnames `graphnames' dom`a'
}

grc1leg `graphnames'
graph export "$figure_cd/cod_prop_length_at_age.png", as(png) replace
*/

/******************************************************************************/
/******************************************************************************/
/* Section 3: Baseline numbers-at-age -> baseline numbers-at-length           */
/******************************************************************************/
/******************************************************************************/

/* cod */
use "$misc_data_cd/WGOM_Cod_historical_NAA.dta", clear ;
keep if year==$cod_NAA_base_year ;
split metric, parse(" ") ;
rename metric6 age ;
keep age value year ;
destring age, replace ;
reshape wide value, i(year) j(age) ;

/* Collapse ages 6-9 into the 6+ plus-group used by the cod ALK. PRESERVED:
   the rename is not a no-op: value6 has just been dropped, so "value6"
   abbreviates uniquely to value6_plus, which is renamed back to value6 so
   the subsequent reshape produces age==6. */
egen value6_plus=rowtotal(value6-value9) ;
drop value6 value7 value8 value9 ;
rename value6 value6 ;
reshape long value, i(year) j(new) ;
/* Assessment NAA are reported in thousands of fish */
replace value=value*1000 ;
rename value nfish ;
rename new age ;
drop year ;

base_naa_to_nal , alkfile("`al_cod'") species(cod) ;

tempfile naa_cod ;
save `naa_cod', replace ;

/* haddock */
use "$misc_data_cd/GOM_Haddock_historical_NAA.dta", clear ;
keep if year==$hadd_NAA_base_year ;
split metric, parse(" ") ;
rename metric6 age ;
keep age value ;
replace value=value*1000 ;
rename value nfish ;
destring age, replace ;

base_naa_to_nal , alkfile("`al_hadd'") species(hadd) ;

append using  `naa_cod' ;

tempfile base_naa ;
save `base_naa', replace ;

/******************************************************************************/
/******************************************************************************/
/* Section 4: Empirical selectivity at length (fraction of the population     */
/*            at each length that the recreational fishery caught)            */
/******************************************************************************/
/******************************************************************************/

merge 1:m species season length using `cal', keep(2 3) ;
drop if draw==. ;

rename n_fish catch ;
mvencode catch base_nal* , mv(0) override ;
sort species season  draw length ;

/* PRESERVED: these two fractions are recomputed after the collapse below,
   which discards this first version; kept because the original did it. */
gen frac_caught_smooth = catch / base_nal_smooth if base_nal_smooth > 0 ;
gen frac_caught_raw    = catch / base_nal_raw    if base_nal_raw > 0 ;

sort species season  draw length ;
drop if catch==0 ;
mvencode frac_caught*, mv(0) override ;

/* catch_l > population_l adjustment.
   MRIP occasionally reports caught fish at lengths where the assessment-derived
   population is exactly zero, which would make the fraction caught undefined.
   This block moves any such catch to the nearest length inside the population's
   support, so it is retained rather than dropped.
   It does not address cases where catch > base_nal_smooth at lengths where the
   population is nonzero but small, which produce frac_caught_smooth > 1. That
   is acceptable because "fraction caught" is only used as a scaling factor. */

egen min_length_pop=min(length) if base_nal_smooth!=0, by(species season draw) ;
egen max_length_pop=max(length) if base_nal_smooth!=0, by(species season draw) ;

egen min_length_catch=min(length) if catch!=0, by(species season draw) ;
egen max_length_catch=max(length) if catch!=0, by(species season draw) ;

/* The egens above are defined only on the rows satisfying their if-condition;
   this loop broadcasts each one to every row of its species-season-draw group.
   PRESERVED: the list names max_length_pop twice and the *_catch bounds are
   never used below; both are harmless, and left as-is. */
local vars min_length_pop max_length_pop min_length_catch max_length_pop max_length_catch ;
foreach v of local vars {;
    egen mean_`v'=mean(`v'), by(species season draw) ;
    replace `v'= mean_`v' ;
    drop mean_`v' ;
};

replace length=max_length_pop if catch>0 & base_nal_smooth==0 & length>max_length_pop ;
replace length=min_length_pop if catch>0 & base_nal_smooth==0 & length<min_length_pop ;

collapse (sum) catch base_nal*,  by(species season  draw length ) ;
drop if catch==0 ;

gen frac_caught_smooth = catch / base_nal_smooth if base_nal_smooth > 0 ;
gen frac_caught_raw    = catch / base_nal_raw    if base_nal_raw > 0 ;

sort species season draw length ;

mvencode frac_caught*, mv(0) override ;

tempfile selectivity ;
save `selectivity', replace ;

/******************************************************************************/
/******************************************************************************/
/* Section 5: Projected numbers-at-age -> projected numbers-at-length         */
/******************************************************************************/
/******************************************************************************/

di "catch_at_length_projection: converting projected NAA to numbers-at-length ..." ;

/* cod */
use "$misc_data_cd/WGOM_Cod_projected_NAA.dta", clear ;
keep if year==$cod_NAA_proj_year ;

split metric, parse(" ") ;
rename metric5 age ;
keep age value year replicate ;
destring age, replace ;
reshape wide value, i(year replicate) j(age) ;
/* The assessment projection supplies many stochastic replicates; take a random
   $ndraws of them and treat each as one model draw. This is how assessment
   uncertainty propagates into the recreational model. */
sample $ndraws, count ;
gen draw=_n ;
egen value6_plus=rowtotal(value6-value9) ;
drop value6 value7 value8 value9 ;
/* PRESERVED: abbreviation rename, as in Section 3 */
rename value6 value6 ;
reshape long value, i(year replicate draw) j(new) ;
replace value=value*1000 ;
rename value nfish ;
rename new age ;

/* check to validate - increase the proportion of large fish
   replace nfish=nfish*20 if age>=6 */

drop year ;
sort draw age ;
rename replicate cod_replicate ;

proj_naa_to_nal , alkfile("`al_cod'") species(cod) repvar(cod_replicate) ;

tempfile proj_naa_cod ;
save `proj_naa_cod', replace ;

/* haddock */
use "$misc_data_cd/GOM_Haddock_projected_NAA.dta", clear ;

keep if year==$hadd_NAA_proj_year ;
split metric, parse(" ") ;
rename metric5 age ;
keep age value replicate ;
replace value=value*1000 ;
rename value nfish ;
destring age, replace ;

/* check to validate - increase the proportion of large fish
   replace nfish=nfish*20 if age>=6 */

reshape wide nfish, i( replicate) j(age) ;
/* The assessment projection supplies many stochastic replicates; take a random
   $ndraws of them and treat each as one model draw. This is how assessment
   uncertainty propagates into the recreational model. */
sample $ndraws, count ;
gen draw=_n ;
reshape long nfish, i( draw replicate) j(new) ;
rename new age ;
rename replicate hadd_replicate ;

proj_naa_to_nal , alkfile("`al_hadd'") species(hadd) repvar(hadd_replicate) ;

sort season draw length ;

append using  `proj_naa_cod' ;

/******************************************************************************/
/******************************************************************************/
/* Section 6: Apply baseline selectivity-at-length to projected NAL           */
/******************************************************************************/
/******************************************************************************/

/* This assumes that the length-specific recreational catchability/
   selectivity observed in the baseline year remains constant in the
   projection year, while projected stock composition changes according to
   projected NAA translated to NAL using the ALK. */

merge 1:1 species season length draw using `selectivity' ;
sort species season draw length ;

gen catch_proj= frac_caught_smooth*proj_nal_smooth ;
mvencode catch*, mv(0) ;

keep length species season draw  catch catch_proj cod_replicate hadd_replicate proj_* base* ;
tostring draw, gen(draw2) ;
gen domain=species+"_"+season+"_"+draw2 ;

egen sum=sum(catch), by(species season draw domain) ;
gen observed_prob_base=catch/sum ;
egen sum_proj=sum(catch_proj), by(species season draw domain) ;
gen observed_prob_proj=catch_proj/sum_proj ;
format sum* %20.0gc ;
drop sum* ;

preserve ;
rename length fitted_length ;
keep fitted_length observed_prob*  species season domain draw proj_* base* ;
duplicates drop ;
tempfile observed_prob ;
save `observed_prob', replace ;
restore ;

/******************************************************************************/
/******************************************************************************/
/* Section 7: Smooth projected catch-at-length with a fitted gamma            */
/******************************************************************************/
/******************************************************************************/

/* D-B6: the original's message had a semicolon, which would end the command
   under the semicolon delimiter. Replaced by a comma. Display text only. */
di "catch_at_length_projection: fitting gamma distributions by domain, this may take a while ..." ;

/* Same method-of-moments gamma fit as catch_at_length_calibration; see
   fit_gamma_by_domain in catch_at_length_programs.do. Applied here to
   projected rather than baseline catch. */

tempfile new ;
save `new', replace ;

/* Fix the storage type of domain so the generated merge key is not strL.
   PRESERVED: in the else branch the trimmed domain is not re-saved to `new',
   exactly as in the original; domain never has surrounding spaces, so the
   trim is a no-op in practice. */
use `new', clear ;

capture confirm strL variable domain ;
if !_rc {;
    gen str244 domain_fixed = strtrim(domain) ;
    drop domain ;
    rename domain_fixed domain ;
    save `new', replace ;
};
else {;
    replace domain = strtrim(domain) ;
};

local domain_type : type domain ;

fit_gamma_by_domain , source(`new') weight(catch_proj) domtype(`domain_type') ;

if r(nfit)==0 {;
    display as error "No domains produced usable fitted-size distributions." ;
    exit 2000 ;
};

rename gammafit fitted_length ;
sort domain fitted_length ;

/* Confirm that the merge keys uniquely identify fitted observations */
isid fitted_length domain ;

merge 1:1 fitted_length domain using `observed_prob' ;

sort domain fitted_length ;
mvencode fitted_prob observed_prob*, mv(0) override ;

split domain, parse(_) ;
replace season=domain2 ;
replace species=domain1 ;
drop draw ;
replace domain=species+"_"+season+"_"+domain3 ;
rename domain3 draw ;
destring draw, replace ;
rename fitted_length length ;

drop _merge nfish sumnfish ;
order species season domain draw length ;
drop domain1 domain2 ;
rename fitted_prob fitted_prob_proj ;

preserve ;
import delimited using "$misc_data_cd/baseline_catch_at_length.csv", clear ;
keep if draw<= $ndraws ;
tempfile baseyr ;
save `baseyr', replace ;
restore ;

merge 1:1  species season draw length using `baseyr' ;
sort species season draw length ;

keep species season domain draw length fitted* observed* proj_nal* ;
mvencode fitted* observed* proj_nal*, mv(0) override ;
drop observed_prob ;
rename fitted_prob fitted_prob_base ;

merge m:1 length species season using  `base_naa' ;

sort draw species season length ;
local vars base_nal_raw base_nal_smooth proj_nal_raw proj_nal_smooth ;
foreach v of local vars {;
    egen sum_`v'=sum(`v'), by(draw species season) ;
    gen prop_`v'=`v'/sum_`v' ;
    drop sum_`v' ;
};

/* Truncate the fitted distribution to the range of lengths actually observed
   in the baseline catch, then renormalize so each domain's probabilities sum
   to one; see truncate_to_observed in catch_at_length_programs.do. */
truncate_to_observed , obsvar(observed_prob_base) fitvar(fitted_prob_proj) ;

/* Optional diagnostics, kept from the original: plots of base and projected
   catch-at-length, evaluated at the mean by length. The original carried
   seven copies of this block differing only in the two variables plotted;
   the pairs it plotted are listed after the block.

collapse (mean) observed* fitted* prop* base_nal* proj_nal*, by(species season length)
gen domain=season+"_"+species

levelsof domain , local(domz)
foreach d of local domz{
	twoway (scatter observed_prob_base length if domain=="`d'" ,   cmissing(no) connect(direct) lcol(gray) lwidth(med)  lpat(solid) msymbol(o) mcol(gray) $graphoptions) ///
		    (scatter observed_prob_proj length if  domain=="`d'"  , cmissing(no) connect(direct) lcol(black)   lwidth(med)  lpat(solid) msymbol(i)   ///
			xtitle("Length (cm)", yoffset(-2)) ytitle("Prob")    ylab(, angle(horizontal) labsize(vsmall)) ///
			legend(lab(1 "observed_catch_at_length_prob_base") lab(2 "observed_catch_at_length_prob_proj") cols() yoffset(-2) region(color(none)))   title("`d'", size(small))  name(dom`d', replace))
 local graphnames `graphnames' dom`d'
}

grc1leg `graphnames', rows(2)

   Pairs plotted by the original's other copies:
     fitted_prob_base     vs fitted_prob_proj
     observed_prob_proj   vs fitted_prob_proj
     observed_prob_base   vs fitted_prob_base
     prop_base_nal_raw    vs prop_proj_nal_raw
     prop_base_nal_smooth vs prop_proj_nal_smooth   (twice)
*/

/******************************************************************************/
/******************************************************************************/
/* Section 8: Export projected fitted probabilities                           */
/******************************************************************************/
/******************************************************************************/

keep draw length species season  fitted_prob_proj ;
drop if missing(fitted_prob_proj) | fitted_prob_proj == 0 ;
rename fitted_prob_proj fitted_prob ;
compress ;
export delimited using "$misc_data_cd/projected_catch_at_length.csv", replace ;

di "catch_at_length_projection: done." ;

#delimit cr
