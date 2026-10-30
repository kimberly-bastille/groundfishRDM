/*******************************************************************************
 Script:       catch_at_length_programs.do
 Status:       Shared programs for catch_at_length_calibration.do and
               catch_at_length_projection.do (added in the September 2026
               refactor). Each of those files
               loads this one at its top with
                 do "$input_code_cd/catch_at_length_programs.do"
               so model_wrapper.do needs no change. It is safe to load more
               than once: every program is dropped before it is defined.
 Purpose:      Defines the two operations that were copy-pasted between the
               calibration and projection scripts:
                 fit_gamma_by_domain   original cal 507-601 / proj 551-660
                 truncate_to_observed  original cal 648-658 / proj 717-726
               (line numbers in the pre-refactor files at git commit fc318d1:
               git show fc318d1:Code/pre_sim/catch_at_length_<cal|proj>.do)
               Each body is the original loop verbatim with the variable names
               that differed between the two copies turned into parameters.
 Inputs:       None of its own. The programs act on the dataset in memory.
 Outputs:      None of its own.
 Dependencies: Called with the data the two scripts already have in memory.
               fit_gamma_by_domain consumes the RNG (rgamma); callers must
               have set the seed, as both scripts do at their top.
 Pipeline:     Loaded by steps 9 and 10 of model_wrapper.do via those two
               files. Not run on its own.
*******************************************************************************/

#delimit ;

/******************************************************************************
 fit_gamma_by_domain
 For every value of the string variable domain (species_season_draw), fits a
 gamma distribution to length by weighted method of moments, then simulates
 round(total fish) draws from it and tabulates them into a discretized fitted
 length distribution. Method of moments is used rather than maximum
 likelihood because the ML fit failed to converge for the sparser domains.
 The fitted distributions of all domains are accumulated in one tempfile.
 On exit:
   r(nfit) = 1 and the accumulated fitted data are in memory
             (gammafit nfish sumnfish fitted_prob domain), sorted as the
             append left them; or
   r(nfit) = 0 and the data are cleared, if no domain could be fitted.
   The caller decides what to do about r(nfit)==0 (the calibration script
   prints a message and continues; the projection script exits).
 The RNG is consumed once per fitted domain (set obs + rgamma). The domain
 order is levelsof order, exactly as in the originals.
 Parameters:
   source  : path of a caller-created tempfile holding the long dataset with
             variables domain, length and the weight variable (one row per
             domain x length). Reloaded for each domain, as the originals did.
   weight  : fish count at length used as the frequency weight
             (calibration: n_fish; projection: catch_proj)
   domtype : optional storage type for the domain variable in the fitted
             output. The projection script passes the type it captured from
             its own data; the calibration script omits it and lets Stata
             size the string, exactly as each original did.
******************************************************************************/
capture program drop fit_gamma_by_domain ;
program define fit_gamma_by_domain, rclass ;
    syntax , SOURCE(string) WEIGHT(name) [ DOMTYPE(string) ] ;

    tempfile fitted_sizes_all ;

    levelsof domain, local(regs) ;

    /* Identifies the first successfully fitted domain */
    local first_result = 1 ;

    quietly foreach r of local regs {;
        use "`source'", clear ;
        keep if domain == "`r'" ;
        noisily display as text "Fitting domain: `r'" ;

        keep length `weight' ;
        drop if missing(length) | missing(`weight') ;
        drop if `weight' <= 0 ;
        replace `weight' = round(`weight') ;

        quietly summarize `weight', meanonly ;
        local tot_n_fish = r(sum) ;

        /* Gamma distribution requires strictly positive support */
        drop if length <= 0 ;

        /* Skip domains without usable observations */
        if _N == 0 | missing(`tot_n_fish') | `tot_n_fish' <= 0 {;
            noisily display as error "Skipping domain `r': no usable observations" ;
            continue ;
        };

        /* (A) Estimate gamma parameters using weighted method of moments */
        quietly summarize length [fw=`weight'], meanonly ;
        local mu = r(mean) ;

        /* Weighted variance: Var(x) = E(x^2) - [E(x)]^2 */
        generate double length2 = length^2 ;
        quietly summarize length2 [fw=`weight'], meanonly ;
        local ex2 = r(mean) ;
        local v = `ex2' - (`mu'^2) ;

        /* If the variance is zero or numerically negligible, approximate a
           degenerate distribution concentrated near the weighted mean */
        if missing(`v') | missing(`mu') | `mu' <= 0 | `v' <= 1e-10 {;
            local alpha = 1e6 ;
            local beta = `mu'/`alpha' ;
        };
        else {;
            /* Gamma shape and scale from the first two moments */
            local alpha = (`mu'^2)/`v' ;
            local beta = `v'/`mu' ;
        };

        /* (B) Simulate a discretized length distribution from the fitted gamma */
        local ndraw = round(`tot_n_fish') ;

        clear ;
        set obs `ndraw' ;

        generate double gammafit = rgamma(`alpha', `beta') ;
        replace gammafit = round(gammafit) ;

        generate long nfish = 1 ;
        collapse (sum) nfish, by(gammafit) ;

        egen double sumnfish = total(nfish) ;
        generate double fitted_prob = nfish/sumnfish ;
        generate `domtype' domain = "`r'" ;

        /* Safely accumulate results in one tempfile */
        if `first_result' {;
            save `fitted_sizes_all', replace ;
            local first_result = 0 ;
        };
        else {;
            append using `fitted_sizes_all' ;
            save `fitted_sizes_all', replace ;
        };
    };

    /* Load the combined fitted distributions, or leave memory clear */
    if `first_result' {;
        clear ;
        return scalar nfit = 0 ;
    };
    else {;
        use `fitted_sizes_all', clear ;
        return scalar nfit = 1 ;
    };
end ;

/******************************************************************************
 truncate_to_observed
 The gamma has unbounded support, so this trims each domain's fitted
 distribution back to the smallest and largest lengths at which the observed
 probability is nonzero for that domain, then renormalizes the fitted
 probabilities within each domain to sum to one. Leaves sum_fitted_prob in
 the data, as the originals did; the callers' later keep drops it.
 Parameters:
   obsvar : observed-probability variable that defines the observed range
            (calibration: observed_prob; projection: observed_prob_base)
   fitvar : fitted-probability variable to truncate and renormalize
            (calibration: fitted_prob; projection: fitted_prob_proj)
******************************************************************************/
capture program drop truncate_to_observed ;
program define truncate_to_observed ;
    syntax , OBSVAR(name) FITVAR(name) ;

    levelsof domain, local(doms) ;
    foreach d of local doms {;
        quietly summarize length if `obsvar'!=0 & !missing(`obsvar') & domain=="`d'" ;
        local minL = `r(min)' ;
        local maxL = `r(max)' ;
        drop if (length<`minL' | length>`maxL') & domain=="`d'" ;
    };

    egen sum_fitted_prob=sum(`fitvar'), by(domain) ;
    replace `fitvar'=`fitvar'/sum_fitted_prob ;
end ;

#delimit cr
