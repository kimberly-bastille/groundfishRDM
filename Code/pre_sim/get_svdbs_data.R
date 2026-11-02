################################################################################
# Script:       get_svdbs_data.R
# Purpose:      Pulls survey(svdbs) data from Oracle
#
# Inputs:       Live Oracle connection with the ability to select on SVDBS
#
# Outputs:      gf.data.dir/miscellaneous/NEFSC_trawl_hadd.csv,
#               gf.data.dir/miscellaneous/NEFSC_trawl_cod.csv,
#               gf.data.dir/miscellaneous/NEFSC_cruises.csv,
# Dependencies: Sources developer_setup.R (for gf.data.dir). Requires Oracle
#               access.
# Pipeline:     Part of initial data setup. Gated by get_svdbs_data
################################################################################

library("here")
library("ROracle")
library("tidyverse")
library("DBI")
library("glue")
library("conflicted")
conflicts_prefer(dplyr::filter)

# standard "here", username setup, and paths
here::i_am("Code/pre_sim/get_mrip_site_list.R")
source(here("Code", "helpers", "developer_setup.R"))
output_folder<-file.path(gf.data.dir, "miscellaneous")

#for help with versioning
todaysdate<-Sys.Date()

# Connect to Oracle
drv<-dbDriver("Oracle")
con_name<-eval(nefscdb_con)


querystring<-glue("select cruise6, stratum, svspp,length, age, count(nvl(age,0)) as count from SVDBS.FSCS_SVBIO
        where cruise6 in
            (select distinct cruise6 from svdbs.svdbs_cruises
                where purpose_code in(10,11) and status_code=10
                and season in ( 'SPRING', 'FALL'))
          and svspp in(73,74)
          and cruise6>=201201
          and age is not null
          group by svspp, cruise6, stratum, length, age")




message("Pulling svdbs_data")
NEFSC_trawl<-dbGetQuery(con_name, querystring)


NEFSC_trawl_cod<-NEFSC_trawl %>%
  filter(SVSPP=="073")


NEFSC_trawl_haddock<-NEFSC_trawl %>%
  filter(SVSPP=="074")



# NEFSC_trawl_haddock<-dbGetQuery(con_name, querystring)


cruises<-glue("select cruise6, season, year from svdbs.svdbs_cruises
              where year>=2007 and
              purpose_code=10 and
              status_code=10 and
              season in ('SPRING', 'FALL')
              order by cruise6")


NEFSC_cruises<-dbGetQuery(con_name, cruises)




dbDisconnect(con_name)

write_csv(NEFSC_trawl_cod, file=file.path(output_folder, "NEFSC_trawl_cod"))
write_csv(NEFSC_trawl_haddock, file=file.path(output_folder, "NEFSC_trawl_haddock"))
write_csv(NEFSC_cruises, file=file.path(output_folder, "NEFSC_cruises"))

