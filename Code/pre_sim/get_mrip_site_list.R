################################################################################
# Script:       get_mrip_site_list.R
# Purpose:      Pulls MRIP site list from Oracle
#
# Inputs:       Live Oracle connection
#
# Outputs:      <gf.data.dir>/miscellaneous/MRIP_COD_ALL_SITE_LIST.csv
# Dependencies: Sources developer_setup.R (for gf.data.dir). Requires Oracle
#               access.
# Pipeline:     Part of initial data setup. Gated by get_mrip_site_list.
################################################################################

library("here")
library("ROracle")
library("tidyverse")
library("DBI")
library("glue")
library("conflicted")


# standard "here", username setup, and paths
here::i_am("Code/pre_sim/get_mrip_site_list.R")
source(here("Code", "helpers", "developer_setup.R"))
output_folder<-file.path(gf.data.dir, "miscellaneous")

#for help with versioning
todaysdate<-Sys.Date()

# Connect to Oracle
drv<-dbDriver("Oracle")
con_name<-eval(nefscdb_con)


querystring<-glue("select * from RECDBS.MRIP_COD_ALL_SITE_LIST")

message("Pulling MRIP site list from Oracle (this can take a while) ...")
MRIP_COD_ALL_SITE_LIST<-dbGetQuery(con_name, querystring)
dbDisconnect(con_name)

write_csv(MRIP_COD_ALL_SITE_LIST, file=file.path(output_folder, "MRIP_COD_ALL_SITE_LIST.csv"))

