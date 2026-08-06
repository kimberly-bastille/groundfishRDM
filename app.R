################################################################################
################################################################################
# Script:  app.R
#
# Purpose: Shiny front end for the Western Gulf of Maine cod/haddock
#          Recreational Decision Support Tool. It does two separable jobs:
#          (1) browse results of model runs that have already finished -- a
#              sortable regulations/mortality table plus a cod-vs-haddock
#              mortality scatter and optional supplemental figures; and
#          (2) let a user compose a new set of regulations (seasons, bag
#              limits, minimum sizes by species and mode), write them to
#              saved_regs/, and enqueue a job so the model is run elsewhere.
#          The app itself never runs the simulation -- see Dependencies.
#
# Inputs:  output/*.csv       -- long-format results, one file per policy run,
#                                with columns model, species, mode, draw,
#                                metric, value
#          saved_regs/*.csv   -- regulation sets previously submitted through
#                                this app (run_name, input, value)
#          Environment variable GROUNDFISH_AZURE_STORAGE_QUEUE_URL -- a SAS
#                                URL for the Azure Storage queue that the
#                                model worker listens on
#
# Outputs: saved_regs/regs_<Run_Name>.csv -- the regulations the user composed
#          One Azure Storage queue message naming that run
#
# Dependencies: A separate worker process consumes the queue and executes the
#          projection (Run_Model.R / RecDST/model_run.R), writing results back
#          into output/. Nothing in this file triggers that work directly, so
#          the Results page stays unchanged until the worker finishes and the
#          user clicks "Update" (which reloads the page).
#
# Pipeline: Terminal, user-facing layer. Everything it reads is produced
#          upstream by the Stata pre_sim scripts -> R sim scripts chain
#          described in DATAFLOW_GROUNDFISH.md.
################################################################################
################################################################################

library(shiny)
library(shinyjs)

################################################################################
################################################################################
# Section A: User interface
################################################################################
################################################################################

ui <- fluidPage(
  useShinyjs(),
  titlePanel("Western Gulf of Maine Cod and Haddock Recreational Fisheries Decision Support Tool"),
  # Two tabs: a read-only summary of completed runs, then the form used to
  # compose and submit a new run.
  tabsetPanel(
    tabPanel("Cod and Haddock Model Summary",
             p("This page summarizes models results for sets of policies that have been run to date. These are
               intended as a jumping off point for your own model runs."),
             p("Hover over each point to view the detailed statistics for each model run. The first section contains
               a table of recreational management measures. The second section contains graphs of mortality. The third
               section has graphs of other performance measures, including relative change in Angler Satisfaction, Trips, and Discards."),

             shinyjs::useShinyjs(),
             shinyjs::extendShinyjs(text = "shinyjs.refresh_page = function() { location.reload(); }", functions = "refresh_page"),
             actionButton("updatedat", "Update"),

             plotly::plotlyOutput(outputId = "totCatch"),

             DT::DTOutput(outputId = "DTout"),

             shinyWidgets::awesomeCheckboxGroup(
               inputId = "fig",
               label = "Supplemental Figures",
               choices = c( "Angler Satisfaction","Discards", "Trips"),
               inline = TRUE,
               status = "danger"),
             uiOutput("addCVCod"),
             uiOutput("addCVHad"),
             uiOutput("addReleaseCod"),
             uiOutput("addReleaseHad"),
             uiOutput("addTripsCod"),
             uiOutput("addTripsHad")),


    tabPanel( "Regulation Selection",
              strong(div("Use this page to set up the regulations that you would like to simulate.  Only click the button ONCE before clicking over to Results tab. We have pre-loaded the status quo regulations.", style = "color:blue")), # Warning for users
              #Run Button
              actionButton("runmeplease", "Run Me"),
              textInput("Run_Name", "Please name this using your initials and the number of the run (ex. AB1)."),

              fluidRow(
                column(6,
                       titlePanel("Cod"),
                       dateRangeInput(inputId = "CodFH_seas1", label = "For Hire Season 1",
                                      min = as.Date("2027-05-01"), max = as.Date("2028-04-30"),
                                      start = as.Date("2027-09-01"), end = as.Date("2027-10-31")),
                       fluidRow(
                         column(4,
                                numericInput(inputId = "CodFH_1_bag", label = "Bag Limit",
                                             min = 0, max = 100, value = 1)),
                         column(5,
                                sliderInput(inputId = "CodFH_1_len", label = "Min Length",
                                            min = 15, max = 30, value = 23, step = 1))),

                       dateRangeInput(inputId = "CodPR_seas1", label = "Private Season 1",
                                      min = as.Date("2027-05-01"), max = as.Date("2028-04-30"),
                                      start = as.Date("2027-09-01"), end = as.Date("2027-10-31")),
                       fluidRow(
                         column(4,
                                numericInput(inputId = "CodPR_1_bag", label = "Bag Limit",
                                             min = 0, max = 100, value = 1)),
                         column(5,
                                sliderInput(inputId = "CodPR_1_len", label = "Min Length",
                                            min = 15, max = 30, value = 23, step = 1))),

                       actionButton("CODaddSeason", "Add Season"),
                       shinyjs::hidden(div(id = "CodSeason2",
                                           dateRangeInput(inputId = "CodFH_seas2", label = "For Hire Season 2",
                                                          min = as.Date("2027-05-01"), max = as.Date("2028-04-30"),
                                                          start = as.Date("2028-01-01"), end = as.Date("2028-01-01")),
                                           fluidRow(
                                             column(4,
                                                    numericInput(inputId = "CodFH_2_bag", label = "Bag Limit",
                                                                 min = 0, max = 20, value = 0)),
                                             column(6,
                                                    sliderInput(inputId = "CodFH_2_len", label = "Min Length",
                                                                min = 15, max = 25, value = 23, step = 1))),
                                           dateRangeInput(inputId = "CodPR_seas2", label = "Private Season 2",
                                                          min = as.Date("2027-05-01"), max = as.Date("2028-04-30"),
                                                          start = as.Date("2028-01-01"), end = as.Date("2028-01-01")),
                                           fluidRow(
                                             column(4,
                                                    numericInput(inputId = "CodPR_2_bag", label = "Bag Limit",
                                                                 min = 0, max = 20, value = 0)),
                                             column(6,
                                                    sliderInput(inputId = "CodPR_2_len", label = "Min Length",
                                                                min = 15, max = 25, value = 23, step = 1)))))),
                column(6,
                       titlePanel("Haddock"),
                       dateRangeInput(inputId = "HadFH_seas1", label = "For Hire Season 1",
                                      min = as.Date("2027-05-01"), max = as.Date("2028-04-30"),
                                      start = as.Date("2027-05-01"), end = as.Date("2028-02-29")),
                       fluidRow(
                         column(4,
                                numericInput(inputId = "HadFH_1_bag", label = "Bag Limit",
                                             min = 0, max = 100, value = 15)),
                         column(5,
                                sliderInput(inputId = "HadFH_1_len", label = "Min Length",
                                            min = 15, max = 30, value = 17, step = 1))),

                       dateRangeInput(inputId = "HadPR_seas1", label = "Private Season 1",
                                      min = as.Date("2027-05-01"), max = as.Date("2028-04-30"),
                                      start = as.Date("2027-05-01"), end = as.Date("2028-02-29")),
                       fluidRow(
                         column(4,
                                numericInput(inputId = "HadPR_1_bag", label = "Bag Limit",
                                             min = 0, max = 100, value = 15)),
                         column(5,
                                sliderInput(inputId = "HadPR_1_len", label = "Min Length",
                                            min = 15, max = 30, value = 17, step = 1))),

                       dateRangeInput(inputId = "HadFH_seas2", label = "For Hire Season 2",
                                      min = as.Date("2027-05-01"), max = as.Date("2028-04-30"),
                                      start = as.Date("2028-04-01"), end = as.Date("2028-04-30")),
                       fluidRow(
                         column(4,
                                numericInput(inputId = "HadFH_2_bag", label = "Bag Limit",
                                             min = 0, max = 100, value = 15)),
                         column(5,
                                sliderInput(inputId = "HadFH_2_len", label = "Min Length",
                                            min = 15, max = 30, value = 17, step = 1))),

                       dateRangeInput(inputId = "HadPR_seas2", label = "Private Season 2",
                                      min = as.Date("2027-05-01"), max = as.Date("2028-04-30"),
                                      start = as.Date("2028-04-01"), end = as.Date("2028-04-30")),
                       fluidRow(
                         column(4,
                                numericInput(inputId = "HadPR_2_bag", label = "Bag Limit",
                                             min = 0, max = 100, value = 15)),
                         column(5,
                                sliderInput(inputId = "HadPR_2_len", label = "Min Length",
                                            min = 15, max = 30, value = 17, step = 1))),

                       actionButton("HADaddSeason", "Add Season"),
                       shinyjs::hidden(div(id = "HadSeason3",
                                           dateRangeInput(inputId = "HadFH_seas3", label = "For Hire Season 3",
                                                          min = as.Date("2027-05-01"), max = as.Date("2028-04-30"),
                                                          start = as.Date("2028-01-01"), end = as.Date("2028-01-01")),
                                           fluidRow(
                                             column(4,
                                                    numericInput(inputId = "HadFH_3_bag", label = "Bag Limit",
                                                                 min = 0, max = 20, value = 0)),
                                             column(6,
                                                    sliderInput(inputId = "HadFH_3_len", label = "Min Length",
                                                                min = 15, max = 30, value = 17, step = 1))),
                                           dateRangeInput(inputId = "HadPR_seas3", label = "Private Season 3",
                                                          min = as.Date("2027-05-01"), max = as.Date("2028-04-30"),
                                                          start = as.Date("2028-01-01"), end = as.Date("2028-01-01")),
                                           fluidRow(
                                             column(4,
                                                    numericInput(inputId = "HadPR_3_bag", label = "Bag Limit",
                                                                 min = 0, max = 20, value = 0)),
                                             column(6,
                                                    sliderInput(inputId = "HadPR_3_len", label = "Min Length",
                                                                min = 15, max = 30, value = 17, step = 1)))))))
    )))

################################################################################
################################################################################
# Section B: Server -- shared data access and constants
################################################################################
################################################################################

server <- function(input, output, session){

  library(magrittr)
  library(ggplot2)
  #library(webshot)

  # There is no incremental refresh: "Update" reloads the whole browser page,
  # which re-evaluates outputs() and so picks up any result files the worker
  # has written since the session started.
  observeEvent(input$updatedat,{
    print("updating")
    shinyjs::js$refresh_page();
  })

  #' @title Read all completed model results
  #' @description Stacks every CSV in output/ into one long-format table. Each
  #'   file is one model run; the run identifier travels in the files' own
  #'   "model" column, so no filename parsing is needed.
  #' @return A data.table with columns model, species, mode, draw, metric, value.
  outputs <- reactive({
    fnames <- list.files(path=here::here("output/"),pattern = "*.csv",full.names = T)

    # fnames2 derives a run_name from the filename but is never used
    # downstream; superseded by the "model" column carried inside each file.
    fnames2<- as.data.frame(fnames) %>%
      tidyr::separate(fnames, into = c("a", "b"), sep = "_") %>%
      dplyr::mutate(b = ifelse(stringr::str_detect(b, "202501"),  "NA", b),
                    c=c(1:nrow(.)),
                    run_name = dplyr::case_when(b != "NA" ~ b, TRUE ~ as.character(c))) %>%
      dplyr::select(run_name)

    df <- fnames %>%
      purrr::map_df(~data.table::fread(.,stringsAsFactors=F,check.names=T,strip.white=T))

    return(df)
  })

  # Reference points and unit conversion, written as zero-argument functions so
  # they read the same way as the reactives above. cod_acl and had_acl are the
  # recreational annual catch limits in metric tons; results arrive in pounds.
  cod_acl <- function(){
    cod_acl = 118
    return(cod_acl)
  }

  had_acl <- function(){
    had_acl = 1146
    return(had_acl)
  }

  lb_to_mt <- function(){
    lb_to_mt = 0.000454
    return(lb_to_mt)
  }

  #' @title Sanitize the user-supplied run name
  #' @description Replaces underscores with hyphens, because "_" is the
  #'   delimiter used when result and regulation file names are split apart.
  #'   Note the saved_regs file name below is built from the raw input$Run_Name,
  #'   not from this sanitized version.
  #' @return The run name as a single string.
  Run_Name <- function(){
    if(stringr::str_detect(input$Run_Name, "_")){
      Run_Name <-  gsub("_", "-", input$Run_Name)
    }else {
      Run_Name <- input$Run_Name
    }
    print(Run_Name)
    return(Run_Name)
  }

  #' @title Read every regulation set ever submitted
  #' @description Stacks all saved_regs/*.csv into one long table. Each row is
  #'   one regulation element (e.g. "codFH_1_bag") for one run.
  #' @return A tibble with columns run_name, input, value.
  regs<- function(){
    flist <- list.files(path = here::here("saved_regs/"), pattern = "\\.csv$", full.names = TRUE)

    regs_data <- flist %>%
      purrr::map_dfr(readr::read_csv)
    return(regs_data)
  }

################################################################################
################################################################################
# Section C: Summary table and the cod-vs-haddock mortality scatter
################################################################################
################################################################################

  output$DTout <- DT::renderDT({
    # Total recreational mortality = landed weight + dead discards, summed
    # across seasons within a draw, then converted from pounds to metric tons.
    # under_acl counts the draws in which that total stayed under the ACL; the
    # column is later labelled "%", which is only literally true when the model
    # is run with 100 draws.
    catch_agg<- outputs() %>%
        dplyr::filter(metric %in% c("keep_weight", "discmort_weight"),
                      mode == "all modes") %>%
        dplyr::group_by(model, species,draw) %>%
        dplyr::summarise(Value = sum(as.numeric(value))) %>%
        dplyr::mutate(Value = Value * lb_to_mt()) %>%
        dplyr::mutate(under_acl = dplyr::case_when(species == "cod" & Value <= cod_acl() ~ 1, TRUE ~ 0),
                      under_acl = dplyr::case_when(species == "hadd" & Value <= had_acl() ~ 1, TRUE ~ under_acl)) %>%
        dplyr::group_by(model, species) %>%
        dplyr::summarise(under_acl = sum(under_acl),
                         Value = round(median(Value),0)) %>%
        tidyr::pivot_wider(names_from = species, values_from = c(Value, under_acl))

    # The saved regulations arrive as opaque name/value pairs, so species, mode,
    # season number and season endpoint (op/cl) are recovered by pattern
    # matching on the input name (e.g. "codFH_seas2_op"). The year prefix is
    # stripped from dates so seasons display as MM-DD. Any species/mode/season
    # group containing a 0 (an unused extra season) is dropped.
    regs1 <- regs() %>%
      dplyr::rename("model" = "run_name") %>%
      dplyr::mutate(
        species = stringr::str_extract(input, "^[a-z]+"),
        mode    = stringr::str_extract(input, "(FH|PR)"),
        season  = stringr::str_extract(input, "\\d+"),
        bound   = stringr::str_extract(input, "(op|cl)"),
        value    = stringr::str_remove(value, "^\\d{4}-")  # remove year
      ) %>%
      dplyr::group_by(model, species, mode, season) %>%
      dplyr::filter(!any(value == 0))

    seasons <- regs1 %>%
      dplyr::select(!input) %>%
      dplyr::filter(bound %in% c("op", "cl")) %>%
      tidyr::pivot_wider(names_from = bound,values_from = value) %>%
      dplyr::mutate(season_range = paste(op, "-", cl)) %>%
      dplyr::group_by(model, species, mode) %>%
      dplyr::summarise(season = paste(season_range, collapse = " ; "),.groups = "drop") %>%
      tidyr::pivot_wider(names_from = species, values_from = season, names_glue = "{species}season")

    bags <- regs1 %>%
      dplyr::filter(stringr::str_detect(input, "bag")) %>%
      dplyr::mutate(bag_type = paste0(species, "bag")) %>%
      dplyr::group_by(model, mode, bag_type) %>%
      dplyr::summarise(bag = dplyr::first(value), .groups = "drop") %>%
      tidyr::pivot_wider(names_from = bag_type,values_from = bag)

    minsizes <- regs1 %>%
      dplyr::filter(stringr::str_detect(input, "len")) %>%
      dplyr::mutate(size_type = paste0(species, "len")) %>%
      dplyr::group_by(model, mode, size_type) %>%
      dplyr::summarise(size = dplyr::first(value), .groups = "drop") %>%
      tidyr::pivot_wider(names_from = size_type,values_from = size)

    final_table <- seasons %>%
      dplyr::left_join(bags, by = c("model", "mode")) %>%
      dplyr::left_join(minsizes, by = c("model", "mode")) %>%
      dplyr::left_join(catch_agg, by = c("model")) %>%
      dplyr::select(model, mode, codseason, codbag, codlen, hadseason, hadbag, hadlen, Value_cod, Value_hadd, under_acl_cod, under_acl_hadd) %>%
      dplyr::rename(Mode = mode,
                    `Run Identifier` = model,
                    `Cod Bag Limit` = codbag,
                    `Cod Minimum Size (in)` = codlen,
                    `Cod Season(s)` = codseason,
                    `Haddock Bag Limit` = hadbag,
                    `Haddock Minimum Size (in)` = hadlen,
                    `Haddock Season(s)` = hadseason,
                    `% under Cod ACL` = under_acl_cod,
                    `% under Haddock ACL` = under_acl_hadd,
                    `Cod Total Catch` = Value_cod,
                    `Haddock Total Catch` = Value_hadd)

    DT::datatable(final_table)
  })

  output$totCatch <- plotly::renderPlotly({

    catch_agg<- outputs() %>%
      dplyr::filter(metric %in% c("keep_weight", "discmort_weight"),
                    mode == "all modes")%>%
      dplyr::group_by(model, species,draw) %>%
      dplyr::summarise(Value = sum(as.numeric(value))) %>%
      dplyr::mutate(Value = Value * lb_to_mt()) %>%
      dplyr::mutate(under_acl = dplyr::case_when(species == "cod" & Value <= cod_acl() ~ 1, TRUE ~ 0),
                    under_acl = dplyr::case_when(species == "hadd" & Value <= had_acl() ~ 1, TRUE ~ under_acl)) %>%
      dplyr::group_by(model, species) %>%
      dplyr::summarise(under_acl = sum(under_acl),
                       Value = round(median(Value),0)) %>%
      tidyr::pivot_wider(names_from = species, values_from = c(Value, under_acl))

    # Bin the draw counts into the discrete legend categories used by the
    # colour scale. Written as a chain of case_when()s that each fall through
    # to the previously assigned value rather than one multi-arm case_when.
    catch_agg2<- catch_agg %>%
      dplyr::mutate(under_acl_cod2 = dplyr::case_when(under_acl_cod < 50 ~ "Less than 50%", TRUE ~ ""),
                    under_acl_cod2 = dplyr::case_when(under_acl_cod >= 50 & under_acl_cod < 60 ~ "50-59%", TRUE ~ under_acl_cod2),
                    under_acl_cod2 = dplyr::case_when(under_acl_cod >= 60 & under_acl_cod < 70~ "60-69%", TRUE ~ under_acl_cod2),
                    under_acl_cod2 = dplyr::case_when(under_acl_cod >= 70 & under_acl_cod < 80 ~ "70-79%", TRUE ~ under_acl_cod2),
                    under_acl_cod2 = dplyr::case_when(under_acl_cod >= 80 & under_acl_cod < 90 ~ "80-89%", TRUE ~ under_acl_cod2),
                    under_acl_cod2 = dplyr::case_when(under_acl_cod >= 90 & under_acl_cod <=100 ~ "90-100%", TRUE ~ under_acl_cod2)) %>%
      dplyr::mutate(under_acl_had2 = dplyr::case_when(under_acl_hadd < 50 ~ "Less than 50%", TRUE ~ ""),
                    under_acl_had2 = dplyr::case_when(under_acl_hadd >= 50 & under_acl_hadd < 60 ~ "50-59%", TRUE ~ under_acl_had2),
                    under_acl_had2 = dplyr::case_when(under_acl_hadd >= 60 & under_acl_hadd < 70~ "60-69%", TRUE ~ under_acl_had2),
                    under_acl_had2 = dplyr::case_when(under_acl_hadd >= 70 & under_acl_hadd < 80 ~ "70-79%", TRUE ~ under_acl_had2),
                    under_acl_had2 = dplyr::case_when(under_acl_hadd >= 80 & under_acl_hadd < 90 ~ "80-89%", TRUE ~ under_acl_had2),
                    under_acl_had2 = dplyr::case_when(under_acl_hadd >= 90 & under_acl_hadd <=100 ~ "90-100%", TRUE ~ under_acl_had2)) %>%
      dplyr::rename(`Cod Mortality`=Value_cod) %>%
      dplyr::rename(`Haddock Mortality`=Value_hadd) %>%
      dplyr::ungroup()

    p<- catch_agg2 %>%
      ggplot2::ggplot(ggplot2::aes(x = `Cod Mortality`, y = `Haddock Mortality`))+
      ggplot2::geom_point(ggplot2::aes(colour = under_acl_cod2, size = under_acl_had2)) +
      ggplot2::scale_color_manual(values = c("50-59%" = "#A9DFBF", "60-69%" = "#7DCEA0",
                                             "70-79%" = "#52BE80","80-89%" = "#27AE60",
                                             "90-100%" = "#1B5E20", "Less than 50%" = "red3"))+
      # Every size is mapped to 1 and the size legend is suppressed below, so
      # the haddock ACL bin currently has no visible effect on the plot.
      ggplot2::scale_size_manual(values = c("50-59%" = 1, "60-69%" = 1,
                                            "70-79%" = 1,"80-89%" = 1,
                                            "90-100%" = 1, "Less than 50%" = 1))+
      ggplot2::labs(colour="% of simulations under cod ACL",
                    size="% of simulations under haddock ACL")+
      ggplot2::geom_text(ggplot2::aes(label = model), check_overlap = TRUE)+
      ggplot2::geom_vline( xintercept =cod_acl(), linetype="dashed")+
      ggplot2::geom_hline( yintercept =had_acl(), color="grey45")+
      ggplot2::annotate(geom="text", x=cod_acl(), label="Cod ACL", y=1200) +
      ggplot2::annotate(geom="text", y=had_acl(), label="Had ACL", x=100) +
      ggplot2::guides(size = "none")+
      ggplot2::ggtitle("Cod and Haddock Mortality")+
      ggplot2::ylab("Median Recreational Haddock Mortality (mt)")+
      ggplot2::xlab("Median Recreational Cod Mortality (mt)")

    fig<- plotly::ggplotly(p) %>%
      plotly::style(textposition = "top center")
    fig
  })

################################################################################
################################################################################
# Section D: Supplemental figures (shown only when the user ticks the box)
################################################################################
################################################################################

  # The six blocks below follow one template: guard on the checkbox group, then
  # render a scatter of a performance measure against mortality for one
  # species. Each block recomputes the same per-model median mortality table
  # independently, so a change to that calculation must be made in all six.


  # CV is compensating variation: dollars per choice occasion associated
  # in change in trip outcomes from baseline summed over
  # the year, i.e. how much better or worse off anglers are under this
  # policy. The figures use the level, CV.
  output$addCVCod <- renderUI({

    if(any("Angler Satisfaction" == input$fig)){

      plotly::renderPlotly({


        welfare <-  outputs() %>%
          dplyr::filter(metric == c("CV"),
                        mode == "all modes") %>%
          dplyr::group_by(model,  draw) %>%
          dplyr::summarise(value = sum(as.numeric(value))) %>%
          tidyr::pivot_wider(names_from = model, values_from = value) %>%
          tidyr::pivot_longer(-draw, names_to = "model", values_to = "value") %>%
          dplyr::group_by(draw) %>%
          dplyr::mutate(SQ_value = (value[model == "SQproposed"]),
                        pct_diff = 100 * (value - SQ_value) / SQ_value) %>%
          dplyr::ungroup() %>%
          dplyr::mutate(CV = value)

        catch<- outputs() %>%
          dplyr::filter(metric %in% c("keep_weight", "discmort_weight"),
                        mode == "all modes")%>%
          dplyr::group_by(model, species,draw) %>%
          dplyr::summarise(Value = sum(as.numeric(value))) %>%
          dplyr::mutate(Value = Value * lb_to_mt()) %>%
          dplyr::group_by(model, draw, species) %>%
          dplyr::summarise(Value =round(median(Value),0)) %>%
          tidyr::pivot_wider(names_from = species, values_from = Value) %>%
          dplyr::left_join(welfare) %>%
          dplyr::group_by(model) %>%
          dplyr::summarise(`Angler Satisfaction($)` = median(CV)/1000000,
                           cod = median(cod),
                           hadd = median(hadd))

        p1<- catch %>% ggplot2::ggplot(ggplot2::aes(x = `Angler Satisfaction($)`, y = cod))+
          ggplot2::geom_point() +
          ggplot2::geom_hline( yintercept =cod_acl())+
          ggplot2::geom_text(ggplot2::aes(label=model), check_overlap = TRUE)+
          ggplot2::geom_text(ggplot2::aes(y=cod_acl(), label="Cod ACL", x=0)) +
          ggplot2::xlab("Change in Angler Satisfaction ($M)")+
          ggplot2::ylab("Total Recreational Cod Mortality (mt)")+
          ggplot2::labs(title = "Cod Mortality (mt) compared to Angler Satisfaction (Compared to the past year, how much better- or worse-off are anglers, in dollars?)",
                        subtitle = "testing")+
          ggplot2::theme(legend.position = "none")

        fig1<- plotly::ggplotly(p1) %>%
          plotly::style(textposition = "top center")

        fig1
      })

    }
  })


  output$addCVHad <- renderUI({

    if(any("Angler Satisfaction" == input$fig)){

      plotly::renderPlotly({
        welfare <-  outputs() %>%
          dplyr::filter(metric == c("CV"),
                        mode == "all modes") %>%
          dplyr::group_by(model,  draw) %>%
          dplyr::summarise(value = sum(as.numeric(value))) %>%
          tidyr::pivot_wider(names_from = model, values_from = value) %>%
          tidyr::pivot_longer(-draw, names_to = "model", values_to = "value") %>%
          dplyr::group_by(draw) %>%
          dplyr::mutate(SQ_value = (value[model == "SQproposed"]),
                        pct_diff = 100 * (value - SQ_value) / SQ_value) %>%
          dplyr::ungroup() %>%
          dplyr::mutate(CV = value)

        catch<- outputs() %>%
          #dat %>%
          dplyr::filter(metric %in% c("keep_weight", "discmort_weight"),
                        mode == "all modes")%>%
          dplyr::group_by(model, species,draw) %>%
          dplyr::summarise(Value = sum(as.numeric(value))) %>%
          dplyr::mutate(Value = Value * lb_to_mt()) %>%
          dplyr::group_by(model, draw, species) %>%
          dplyr::summarise(Value =round(median(Value),0)) %>%
          tidyr::pivot_wider(names_from = species, values_from = Value) %>%
          dplyr::left_join(welfare) %>%
          dplyr::group_by(model) %>%
          dplyr::summarise(`Angler Satisfaction($)` = median(CV)/1000000,
                           cod = median(cod),
                           hadd = median(hadd))

        p2<- catch %>% ggplot2::ggplot(ggplot2::aes(x = `Angler Satisfaction($)`, y = hadd))+
          ggplot2::geom_point() +
          ggplot2::geom_hline( yintercept =had_acl())+
          ggplot2::geom_text(ggplot2::aes(label=model), check_overlap = TRUE)+
          ggplot2::xlab("Change in Angler Satisfaction ($M)")+
          ggplot2::ylab("Total Recreational Haddock Mortality (mt)")+
          ggplot2::geom_text(ggplot2::aes(x=0, label="Had ACL", y=had_acl())) +
          ggplot2::labs(title = "Haddock Mortality (mt) compared to Angler Satisfaction (Compared to the past year, how much better- or worse-off are anglers, in dollars?)",
                        subtitle = "testing")+
          ggplot2::theme(legend.position = "none")

        fig2<- plotly::ggplotly(p2) %>%
          plotly::style(textposition = "top center")
        fig2
      })

    }
  })

  output$addReleaseCod <- renderUI({

    if(any("Discards" == input$fig)){

      plotly::renderPlotly({

        discmort <-  outputs() %>%
          dplyr::filter(metric == c("discmort_weight"),
                        mode == "all modes") %>%
          dplyr::group_by(model,  draw) %>%
          dplyr::mutate(disc_mort = value * lb_to_mt())  %>%
          dplyr::select(!c(metric,value))

        catch<- outputs() %>%
          dplyr::filter(metric %in% c("keep_weight", "discmort_weight"),
                        mode == "all modes")%>%
          dplyr::group_by(model, species,draw) %>%
          dplyr::summarise(Value = sum(as.numeric(value))) %>%
          dplyr::mutate(Value = Value * lb_to_mt()) %>%
          dplyr::group_by(model, draw, species) %>%
          dplyr::summarise(tot_mort =round(median(Value),0)) %>%

          dplyr::left_join(discmort) %>%
          dplyr::group_by(model, draw, mode) %>%
          tidyr::pivot_wider(names_from = species, values_from = c(tot_mort, disc_mort)) %>%
          dplyr::group_by(model) %>%
          dplyr::summarise(`Cod Total Mortality` = median(tot_mort_cod),
                           `Haddock Total Mortality` = median(tot_mort_hadd),
                           `Cod Discard Mortality` = median(disc_mort_cod),
                           `Haddock Discard Mortality` = median(disc_mort_hadd))

        p3<- catch %>% ggplot2::ggplot(ggplot2::aes(x = `Cod Discard Mortality`, y = `Cod Total Mortality`))+
          ggplot2::geom_point() +
          ggplot2::geom_hline( yintercept =cod_acl())+
          ggplot2::geom_text(ggplot2::aes(label=model), check_overlap = TRUE)+
          ggplot2::geom_text(ggplot2::aes(y=cod_acl(), label="Cod ACL", x=35)) +
          ggplot2::xlab("Cod Discard Mortality (mt)")+
          ggplot2::ylab("Total Recreational Cod Mortality (mt)")+
          ggplot2::labs(title = "Total Cod Mortality (mt) compared to Discard Mortality(mt)",
                        subtitle = "")+
          ggplot2::theme(legend.position = "none")

        fig3<- plotly::ggplotly(p3)%>%
          plotly::style(textposition = "top center")
        fig3
      })
    }
  })

  output$addReleaseHad <- renderUI({
    if(any("Discards" == input$fig)){

      plotly::renderPlotly({
        discmort <-  outputs() %>%
          dplyr::filter(metric == c("discmort_weight"),
                        mode == "all modes") %>%
          dplyr::group_by(model,  draw) %>%
          dplyr::mutate(disc_mort = value * lb_to_mt())  %>%
          dplyr::select(!c(metric,value))

        catch<- outputs() %>%
          dplyr::filter(metric %in% c("keep_weight", "discmort_weight"),
                        mode == "all modes")%>%
          dplyr::group_by(model, species,draw) %>%
          dplyr::summarise(Value = sum(as.numeric(value))) %>%
          dplyr::mutate(Value = Value * lb_to_mt()) %>%
          dplyr::group_by(model, draw, species) %>%
          dplyr::summarise(tot_mort =round(median(Value),0)) %>%

          dplyr::left_join(discmort) %>%
          dplyr::group_by(model, draw, mode) %>%
          tidyr::pivot_wider(names_from = species, values_from = c(tot_mort, disc_mort)) %>%
          dplyr::group_by(model) %>%
          dplyr::summarise(`Cod Total Mortality` = median(tot_mort_cod),
                           `Haddock Total Mortality` = median(tot_mort_hadd),
                           `Cod Discard Mortality` = median(disc_mort_cod),
                           `Haddock Discard Mortality` = median(disc_mort_hadd))

        p4<- catch %>% ggplot2::ggplot(ggplot2::aes(x = `Haddock Discard Mortality`, y = `Haddock Total Mortality`))+
          ggplot2::geom_point() +
          ggplot2::geom_hline( yintercept =had_acl())+
          ggplot2::geom_text(ggplot2::aes(label=model), check_overlap = TRUE)+
          ggplot2::geom_text(ggplot2::aes(y=had_acl(), label="Had ACL", x=290)) +
          ggplot2::xlab("Haddock Discard Mortality (mt)")+
          ggplot2::ylab("Total Recreational Haddock Mortality (mt)")+
          ggplot2::labs(title = "Total Haddock Mortality (mt) compared to Discard Mortality (mt)",
                        subtitle = "testing")+
          ggplot2::theme(legend.position = "none")

        fig4<- plotly::ggplotly(p4)%>%
          plotly::style(textposition = "top center")
        fig4

      })
    }
  })

  output$addTripsCod <- renderUI({
    if(any("Trips" == input$fig)){

      plotly::renderPlotly({

        trips <-  outputs() %>%
          dplyr::filter(metric == c("predicted_trips"),
                        mode == "all modes") %>%
          dplyr::group_by(model,  draw) %>%
          dplyr::summarise(value = sum(as.numeric(value))) %>%
          dplyr::ungroup()

        catch<- outputs() %>%
          dplyr::filter(metric %in% c("keep_weight", "discmort_weight"),
                        mode == "all modes")%>%
          dplyr::group_by(model, species,draw) %>%
          dplyr::summarise(Value = sum(as.numeric(value))) %>%
          dplyr::mutate(Value = Value * lb_to_mt()) %>%
          dplyr::group_by(model, draw, species) %>%
          dplyr::summarise(Value =round(median(Value),0)) %>%
          tidyr::pivot_wider(names_from = species, values_from = Value) %>%
          dplyr::left_join(trips) %>%
          dplyr::group_by(model) %>%
          dplyr::summarise(Trips = median(value),
                           cod = median(cod),
                           hadd = median(hadd))

        p5<- catch %>% ggplot2::ggplot(ggplot2::aes(x = Trips, y = `cod`))+
          ggplot2::geom_point() +
          ggplot2::geom_hline( yintercept = cod_acl())+
          ggplot2::geom_text(ggplot2::aes(label=model), check_overlap = TRUE)+
          ggplot2::geom_text(ggplot2::aes(y=cod_acl(), label="Cod ACL", x=220000), angle=90) +
          ggplot2::xlab("Number of Trips")+
          ggplot2::ylab("Total Recreational Cod Mortality (mt)")+
          ggplot2::labs(title = "Cod Mortality (mt) compared to Total Number of Trips",
                        subtitle = "testing")+
          ggplot2::theme(legend.position = "none")

        fig5<- plotly::ggplotly(p5)%>%
          plotly::style(textposition = "top center")
        fig5

      })
    }
  })


  output$addTripsHad <- renderUI({
    if(any("Trips" == input$fig)){

      plotly::renderPlotly({
        trips <- outputs() %>%
          dplyr::filter(metric == c("predicted_trips"),
                        mode == "all modes") %>%
          dplyr::group_by(model,  draw) %>%
          dplyr::summarise(value = sum(as.numeric(value))) %>%
          dplyr::ungroup()

        catch<- outputs() %>%
          dplyr::filter(metric %in% c("keep_weight", "discmort_weight"),
                        mode == "all modes") %>%
          dplyr::group_by(model, species,draw) %>%
          dplyr::summarise(Value = sum(as.numeric(value))) %>%
          dplyr::mutate(Value = Value * lb_to_mt()) %>%
          dplyr::group_by(model, draw, species) %>%
          dplyr::summarise(Value =round(median(Value),0)) %>%
          tidyr::pivot_wider(names_from = species, values_from = Value) %>%
          dplyr::left_join(trips) %>%
          dplyr::group_by(model) %>%
          dplyr::summarise(Trips = median(value),
                           cod = median(cod),
                           hadd = median(hadd))


        p6<- catch %>% ggplot2::ggplot(ggplot2::aes(x =Trips , y = hadd))+
          ggplot2::geom_point() +
          ggplot2::geom_hline( yintercept = had_acl())+
          ggplot2::geom_text(ggplot2::aes(label=model), check_overlap = TRUE)+
          ggplot2::geom_text(ggplot2::aes(y=had_acl(), label="Had ACL", x=220000)) +
          ggplot2::xlab("Number of Trips")+
          ggplot2::ylab("Total Recreational Haddock Mortality (mt)")+
          ggplot2::labs(title = "Haddock Mortality (mt) compared to Total Number of Trips",
                        subtitle = "testing")+
          ggplot2::theme(legend.position = "none")

        fig6<- plotly::ggplotly(p6)%>%
          plotly::style(textposition = "top center")
        fig6
      })
    }
  })

################################################################################
################################################################################
# Section E: Regulation submission
################################################################################
################################################################################

  shinyjs::onclick("CODaddSeason",
                   shinyjs::toggle(id = "CodSeason2", anim = TRUE))
  shinyjs::onclick("HADaddSeason",
                   shinyjs::toggle(id = "HadSeason3", anim = TRUE))

  # Fires once per click of "Run Me": flattens the form into a long
  # name/value table, writes it to saved_regs/, and puts a message on the
  # queue that the model worker polls.
  regulations <- observeEvent(input$runmeplease,{
    library(httr)
    library(jsonlite)
    library(openssl)
    library(uuid)

    #' @title Put a run request on the Azure Storage queue
    #' @description Posts a small JSON payload naming the run. Authentication
    #'   comes entirely from the shared-access-signature token embedded in the
    #'   URL, so no credentials are handled here. Azure requires the message to
    #'   be base64-encoded inside a <QueueMessage> XML envelope.
    #' @param run_name The run identifier the worker should look for in
    #'   saved_regs/.
    #' @param queue_url_sas Full SAS URL of the queue; read from the
    #'   GROUNDFISH_AZURE_STORAGE_QUEUE_URL environment variable by default.
    #' @return TRUE invisibly; raises an error on a non-success HTTP status.
    enqueue_simple_sas <- function(run_name, queue_url_sas = Sys.getenv("GROUNDFISH_AZURE_STORAGE_QUEUE_URL")) {
      stopifnot(nzchar(run_name), nzchar(queue_url_sas))

      # Clean and ensure /messages endpoint
      queue_url_sas <- trimws(queue_url_sas, whitespace = "\" ")
      post_url <- if (grepl("/messages/?$", queue_url_sas)) {
        queue_url_sas
      } else {
        paste0(sub("/$", "", queue_url_sas), "/messages")
      }

      payload <- list(
        runName = run_name,
        submissionId = UUIDgenerate(),
        submittedAt = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
      )
      msg_b64 <- base64_encode(charToRaw(toJSON(payload, auto_unbox = TRUE)))
      xml_body <- sprintf("<QueueMessage><MessageText>%s</MessageText></QueueMessage>", msg_b64)

      res <- POST(
        url = post_url,
        body = xml_body,
        content_type_xml()
      )
      stop_for_status(res)
      invisible(TRUE)
    }

    print(Sys.getenv("GROUNDFISH_AZURE_STORAGE_QUEUE_URL"))

    regulations <- NULL
    # The naming convention in `input` is what downstream code parses:
    # <species><mode>_seas<n>_<op|cl> for season endpoints, and
    # <species><mode>_<n>_<bag|len> for bag limits and minimum sizes.

    codregs <- data.frame(run_name = c(Run_Name()),
                          input =  c("codFH_seas1_op", "codFH_seas1_cl", "codPR_seas1_op", "codPR_seas1_cl",
                                     "codFH_seas2_op", "codFH_seas2_cl", "codPR_seas2_op", "codPR_seas2_cl",

                                     "codFH_1_bag", "codPR_1_bag", "codFH_2_bag" , "codPR_2_bag",

                                     "codFH_1_len", "codPR_1_len", "codFH_2_len", "codPR_2_len",),
                          value =  c(as.character(input$CodFH_seas1[1]), as.character(input$CodFH_seas1[2]),
                                     as.character(input$CodPR_seas1[1]), as.character(input$CodPR_seas1[2]),
                                     as.character(input$CodFH_seas2[1]), as.character(input$CodFH_seas2[2]),
                                     as.character(input$CodPR_seas2[1]), as.character(input$CodPR_seas2[2]),

                                     as.character(input$CodFH_1_bag), as.character(input$CodPR_1_bag),
                                     as.character(input$CodFH_2_bag), as.character(input$CodPR_2_bag),

                                     as.character(input$CodFH_1_len), as.character(input$CodPR_1_len),
                                     as.character(input$CodFH_2_len), as.character(input$CodPR_2_len)))


    hadregs <- data.frame(run_name = c(Run_Name()),
                          input =  c("hadFH_seas1_op", "hadFH_seas1_cl", "hadPR_seas1_op", "hadPR_seas1_cl",
                                     "hadFH_seas2_op", "hadFH_seas2_cl", "hadPR_seas2_op", "hadPR_seas2_cl",
                                     "hadFH_seas3_op", "hadFH_seas3_cl", "hadPR_seas3_op", "hadPR_seas3_cl",

                                     "hadFH_1_bag", "hadPR_1_bag", "hadFH_2_bag" , "hadPR_2_bag", "hadFH_3_bag", "hadPR_3_bag",

                                     "hadFH_1_len", "hadPR_1_len", "hadFH_2_len", "hadPR_2_len",  "hadFH_3_len", "hadPR_3_len"),


                          value =  c(as.character(input$HadFH_seas1[1]), as.character(input$HadFH_seas1[2]),
                                     as.character(input$HadPR_seas1[1]), as.character(input$HadPR_seas1[2]),
                                     as.character(input$HadFH_seas2[1]), as.character(input$HadFH_seas2[2]),
                                     as.character(input$HadPR_seas2[1]), as.character(input$HadPR_seas2[2]),
                                     as.character(input$HadFH_seas3[1]), as.character(input$HadFH_seas3[2]),
                                     as.character(input$HadPR_seas3[1]), as.character(input$HadPR_seas3[2]),

                                     as.character(input$HadFH_1_bag), as.character(input$HadPR_1_bag),
                                     as.character(input$HadFH_2_bag), as.character(input$HadPR_2_bag),
                                     as.character(input$HadFH_3_bag), as.character(input$HadPR_3_bag),

                                     as.character(input$HadFH_1_len), as.character(input$HadPR_1_len),
                                     as.character(input$HadFH_2_len), as.character(input$HadPR_2_len),
                                     as.character(input$HadFH_3_len), as.character(input$HadPR_3_len)))


    regulations <- regulations %>% rbind(codregs, hadregs)

    print("before regs write")
    # File name uses the raw input, while the run_name column inside the file
    # uses the underscore-sanitized Run_Name(); the two can therefore differ.
    readr::write_csv(regulations, file = here::here(paste0("saved_regs/regs_", input$Run_Name, ".csv")))

    print("enqueue triggered")
    enqueue_simple_sas(input$Run_Name)
    print("enqueued")

    return(regulations)

  })

  observeEvent(input$runmeplease, {
    output$message <- renderText(paste0("Policy ", input$Run_Name," saved - your model run has been queued. Results will appear when the processing completes. Be sure to change the policy name before submitting again."))
  })
}
  shiny::shinyApp(ui = ui, server = server)
