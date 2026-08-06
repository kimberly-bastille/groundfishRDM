################################################################################
# Script:       get_commercial_landings.R
# Purpose:      Pulls annual commercial landings and assumed discards for WGOM cod
#               and GOM haddock from Oracle (CAMS), recodes coarse stat areas into
#               finer stock units, and aggregates to calendar-year and fishing-year
#               removals in metric tons. Bridges the terminal assessment year to
#               the projection year.
# Inputs:       Oracle CAMS tables: cams_garfo.cfg_statarea_stock,
#               cams_garfo.cams_land, cams_garfo.cams_discard_all_years,
#               cams_garfo.cams_subtrip.
# Outputs:      commercial_CY_removals_<date>.Rds and
#               commercial_FY_removals_<date>.Rds in the BLAST source_data folder.
# Dependencies: Oracle credentials (id, novapw, tns_alias) and network access
#               to the BLAST share (//nefscfile/...).
# Pipeline:     Standalone / unwrapped — no confirmed caller (per
#               DATAFLOW_GROUNDFISH.md).
################################################################################

###################################################

# Reference codes used throughout:
#   ITIS: cod = 164712, haddock = 164744
#   "Old" GOM cod stat areas: 511,512,513,514,515,465,464 (GB cod = everything else)

###################################################
# Setup: Load libraries, hear, and date vintage.

library("ROracle")
library("glue")
library("tidyverse")
library("here")
library("conflicted")
conflicts_prefer(dplyr::filter)
conflicts_prefer(lubridate::year)
conflicts_prefer(dplyr::summarise)
conflicts_prefer(dplyr::arrange)

vintage_string<-format(Sys.Date())

pounds_per_mt<-2204.62

#Deal with folders

here::i_am("Code/pre_sim/get_commercial_landings.R")
source(here("Code", "helpers", "developer_setup.R"))
output_folder<-file.path(gf.data.dir, "miscellaneous")

# I'm pulling 2022 to 2026 calendar data, but
# this will have complete
# CY and FY : 2022-2025
# FY and CY 2026 are incomplete (through today's date, non finalized)
# The back end of FY 2021 shows up, but is not saved in the FY table


year_start<-2022
year_end<-2026

###################################################
# End setup
###################################################


###################################################
# Get data
# We need to get live pounds from cams_land, discards from cams_discard_all_years
# and stock area definitions from cams_garfo.cfg_statarea_stock
# we want everything to come in lower case
###################################################

#Set up the oracle connection
drv<-dbDriver("Oracle")
con_name<-eval(nefscdb_con)

# Set up the sql queries
# Query to pull statistical areas and stock names
area_query<-glue("select common_name,itis_tsn,area,species_estimation_region as area_name from cams_garfo.cfg_statarea_stock st where
itis_tsn in (164712, 164744)")


# Query to pull landings, aggregated by the itis, stat area,  year. Just for commercial cod and haddock.
landings_query<-glue("select cl.area, cl.year, cl.month, cl.itis_tsn, sum(nvl(cl.livlb,0)) as landings from cams_garfo.cams_land cl
    where cl.itis_tsn in (164712, 164744) and
    cl.rec=0 and
    cl.year between {year_start} and {year_end}
  group by cl.year, cl.month, cl.itis_tsn,  cl.area")


# Query to pull discards, aggregated by the itis, stat area,  year.
# removing rec discards requires linking to camsid, which I have not done.
discard_query<-glue("select cd.year, EXTRACT(month FROM cd.date_trip) as month, st.area, cd.itis_tsn, sum(nvl(cd.cams_discard,0)) as discards from cams_garfo.cams_discard_all_years cd
    left join cams_garfo.cams_subtrip st
    on cd.camsid=st.camsid and cd.subtrip=st.subtrip
    where cd.itis_tsn in (164712, 164744) and
    cd.year between {year_start} and {year_end}
    group by cd.year, EXTRACT(month FROM cd.date_trip), st.area, cd.itis_tsn ")




# get the data
# stock_areas
message("Querying CAMS commercial landings/discards from Oracle ...")
stock_area_definitions<-dbGetQuery(con_name, area_query)

stock_area_definitions<-stock_area_definitions %>%
  rename_with(tolower)

# Fix the cod stock -- the data only has GOM/GB, but we want EGOM, WGOM, GB, and SNE
stock_area_definitions<-stock_area_definitions %>%
  mutate(area_name= case_when(
    itis_tsn=="164712" & area %in% c("465", "467", "511","512") ~ "EGOM", #Eastern GOM
    itis_tsn=="164712" & area %in% c("513", "514", "515","521","526","541") ~ "WGOM", #Western GOM
    itis_tsn=="164712" & area %in% c("464","522","525","542", "543","551","552","561","562") ~ "GB", #GB
    itis_tsn=="164712" & area %in% c("533", "534", "537","538","539","611","612","613","614","615","616","621","622","623","624",
                                     "625","626","627","628","629","631","632","633","634","635","636","637","638","639","640") ~ "SNE", #Southern New England
    .default = area_name  )
  )


# landings
species_area_landings<-dbGetQuery(con_name, landings_query)
species_area_landings<-species_area_landings %>%
  rename_with(tolower)


# discards
species_st_discards<-dbGetQuery(con_name, discard_query)
species_st_discards<-species_st_discards %>%
  rename_with(tolower)

dbDisconnect(con_name)

###################################################
# End of data query
###################################################



# merge landings to discards
species_area_catch<-species_area_landings %>%
  left_join(species_st_discards, by=join_by(itis_tsn==itis_tsn, area==area, year==year, month==month))

# Fill anything missing with zeros
species_area_catch<-species_area_catch %>%
  mutate(landings=coalesce(landings,0),
         discards=coalesce(discards,0))


# join landings to stock area definitions
  species_area_catch<-species_area_catch %>%
  left_join(stock_area_definitions, by=join_by(itis_tsn==itis_tsn, area==area))


# construct fishing year
# The groundfish fishing year runs May 1 - April 30, so January-April landings
# belong to the previous fishing year.
species_area_catch<-species_area_catch %>%
  mutate(fishing_year=case_when(
  month<=4 ~ year-1,
  .default = year
)
)

# Aggregate to Calendar Year, convert to metric tons

commercial_CY_removals <- species_area_catch %>%
  group_by(itis_tsn, area_name, year) %>%
  summarise(landings=round(sum(landings/pounds_per_mt),2),
            discards=round(sum(discards/pounds_per_mt),2)) %>%
  mutate(total_removals=landings+discards)


# Aggregate to Fishing Year, convert to metric tons, drop the partial first year.

commercial_FY_removals <- species_area_catch %>%
  group_by(itis_tsn, area_name, fishing_year) %>%
  summarise(landings=round(sum(landings/pounds_per_mt),2),
            discards=round(sum(discards/pounds_per_mt),2))%>%
  mutate(total_removals=landings+discards)%>%
  filter(fishing_year>=2022)

# I should just print the commercial_CY_removals instead of
#cat("Western Gulf of Maine Commercial cod removals (mt)in 2023-2026:" \n")
#commercial_CY_removals< %>%
#  filter(itis_tsn==164712 & area_name=="WGOM" & year %in% (2023,2024,2025)

#cat(" Gulf of Maine Commercial haddock removals (mt)in 2023-2026:" \n")
#commercial_CY_removals< %>%
#  filter(itis_tsn==164744 & area_name=="GOM" & year %in% (2023,2024,2025)

WGOM_cod_2023<-commercial_CY_removals %>%
  filter(itis_tsn==164712 & area_name=="WGOM" & year==2023) %>%
  pull(total_removals)

WGOM_cod_2024<-commercial_CY_removals %>%
  filter(itis_tsn==164712 & area_name=="WGOM" & year==2024) %>%
  pull(total_removals)

WGOM_cod_2025<-commercial_CY_removals %>%
  filter(itis_tsn==164712 & area_name=="WGOM" & year==2025) %>%
  pull(total_removals)

GOM_haddock_2023<-commercial_CY_removals %>%
  filter(itis_tsn==164744 & area_name=="GOM" & year==2023) %>%
  pull(total_removals)

GOM_haddock_2024<-commercial_CY_removals %>%
  filter(itis_tsn==164744 & area_name=="GOM" & year==2024) %>%
  pull(total_removals)

GOM_haddock_2025<-commercial_CY_removals %>%
  filter(itis_tsn==164744 & area_name=="GOM" & year==2025) %>%
  pull(total_removals)


cat("Western Gulf of Maine Commercial cod removals in 2023:", WGOM_cod_2023,"mt \n")
cat("Western Gulf of Maine Commercial cod removals in 2024:", WGOM_cod_2024,"mt \n")
cat("Western Gulf of Maine Commercial cod removals in 2025:", WGOM_cod_2025,"mt \n")

cat("Gulf of Maine Commercial haddock removals in 2023:", GOM_haddock_2023,"mt \n")
cat("Gulf of Maine Commercial haddock removals in 2024:", GOM_haddock_2024,"mt \n")
cat("Gulf of Maine Commercial haddock removals in 2025:", GOM_haddock_2025,"mt \n")




# save
saveRDS(commercial_CY_removals,
        file=file.path(output_folder,  glue("commercial_CY_removals_{vintage_string}.Rds")))

saveRDS(commercial_FY_removals,
        file=file.path(output_folder,  glue("commercial_FY_removals_{vintage_string}.Rds")))

