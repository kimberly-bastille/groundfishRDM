

library(shiny)
library(shinyjs)

#### Start UI ####
ui <- fluidPage(
  useShinyjs(),
  titlePanel("Western Gulf of Maine Cod and Haddock Recreational Fisheries Decision Support Tool"),
  #### Regulation Selection ####
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
             #uiOutput("summary_regs_table"),
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
                       sliderInput(inputId = "CodFH_seas1", label ="For Hire Season 1",
                                   min = as.Date("2025-05-01","%Y-%m-%d"),
                                   max = as.Date("2026-04-30","%Y-%m-%d"),
                                   value =c(as.Date("2025-05-01","%Y-%m-%d"),as.Date("2025-05-31","%Y-%m-%d")),
                                   timeFormat = "%Y-%m-%d", ticks = FALSE),
                       fluidRow(
                         column(4,
                                numericInput(inputId = "CodFH_1_bag", label = "Bag Limit",
                                             min = 0, max = 100, value = 1)),
                         column(5,
                                sliderInput(inputId = "CodFH_1_len", label = "Min Length",
                                            min = 15, max = 30, value = 23, step = 1))),

                       sliderInput(inputId = "CodPR_seas1", label ="Private Season 1",
                                   min = as.Date("2025-05-01","%Y-%m-%d"),
                                   max = as.Date("2026-04-30","%Y-%m-%d"),
                                   value =c(as.Date("2025-05-01","%Y-%m-%d"),as.Date("2025-05-31","%Y-%m-%d")),
                                   timeFormat = "%Y-%m-%d", ticks = FALSE),
                       fluidRow(
                         column(4,
                                numericInput(inputId = "CodPR_1_bag", label = "Bag Limit",
                                             min = 0, max = 100, value = 1)),
                         column(5,
                                sliderInput(inputId = "CodPR_1_len", label = "Min Length",
                                            min = 15, max = 30, value = 23, step = 1))),


                       sliderInput(inputId = "CodFH_seas2", label ="For Hire Season 2",
                                   min = as.Date("2025-05-01","%Y-%m-%d"),
                                   max = as.Date("2026-04-30","%Y-%m-%d"),
                                   value =c(as.Date("2025-09-01","%Y-%m-%d"),as.Date("2025-10-31","%Y-%m-%d")),
                                   timeFormat = "%Y-%m-%d", ticks = FALSE),
                       fluidRow(
                         column(4,
                                numericInput(inputId = "CodFH_2_bag", label = "Bag Limit",
                                             min = 0, max = 100, value = 1)),
                         column(5,
                                sliderInput(inputId = "CodFH_2_len", label = "Min Length",
                                            min = 15, max = 30, value = 23, step = 1))),
                       sliderInput(inputId = "CodPR_seas2", label ="Private Open Season 2",
                                   min = as.Date("2025-05-01","%Y-%m-%d"),
                                   max = as.Date("2026-04-30","%Y-%m-%d"),
                                   value =c(as.Date("2025-09-01","%Y-%m-%d"),as.Date("2025-10-31","%Y-%m-%d")),
                                   timeFormat = "%Y-%m-%d", ticks = FALSE),
                       fluidRow(
                         column(4,
                                numericInput(inputId = "CodPR_2_bag", label = "Bag Limit",
                                             min = 0, max = 100, value = 1)),
                         column(5,
                                sliderInput(inputId = "CodPR_2_len", label = "Min Length",
                                            min = 15, max = 30, value = 23, step = 1))),



                       actionButton("CODaddSeason", "Add Season"),
                       shinyjs::hidden( div(ID = "CodSeason3",
                                            sliderInput(inputId = "CodFH_seas3", label ="For Hire Season 3",
                                                        min = as.Date("2025-05-01","%Y-%m-%d"),
                                                        max = as.Date("2026-04-30","%Y-%m-%d"),
                                                        value=c(as.Date("2026-01-01","%Y-%m-%d"),as.Date("2026-01-01","%Y-%m-%d")),
                                                        timeFormat = "%Y-%m-%d", ticks = FALSE),
                                            fluidRow(
                                              column(4,
                                                     numericInput(inputId = "CodFH_3_bag", label ="Bag Limit",
                                                                  min = 0, max = 20, value = 0)),
                                              column(6,
                                                     sliderInput(inputId = "CodFH_3_len", label ="Min Length",
                                                                 min = 15, max = 25, value = 23, step = 1))),
                                            sliderInput(inputId = "CodPR_seas3", label ="Private Season 3",
                                                        min = as.Date("2025-05-01","%Y-%m-%d"),
                                                        max = as.Date("2026-04-30","%Y-%m-%d"),
                                                        value=c(as.Date("2026-01-01","%Y-%m-%d"),as.Date("2026-01-01","%Y-%m-%d")),
                                                        timeFormat = "%Y-%m-%d", ticks = FALSE),
                                            fluidRow(
                                              column(4,
                                                     numericInput(inputId = "CodPR_3_bag", label ="Bag Limit",
                                                                  min = 0, max = 20, value = 0)),
                                              column(6,
                                                     sliderInput(inputId = "CodPR_3_len", label ="Min Length",
                                                                 min = 15, max = 25, value = 23, step = 1)))))),
                column(6,
                       titlePanel("Haddock"),
                       sliderInput(inputId = "HadFH_seas1", label ="For Hire Season 1",
                                   min = as.Date("2025-05-01","%Y-%m-%d"),
                                   max = as.Date("2026-04-30","%Y-%m-%d"),
                                   value =c(as.Date("2025-05-01","%Y-%m-%d"),as.Date("2026-02-28","%Y-%m-%d")),
                                   timeFormat = "%Y-%m-%d", ticks = FALSE),
                       fluidRow(
                         column(4,
                                numericInput(inputId = "HadFH_1_bag", label = "Bag Limit",
                                             min = 0, max = 100, value = 15)),
                         column(5,
                                sliderInput(inputId = "HadFH_1_len", label = "Min Length",
                                            min = 15, max = 30, value = 17, step = 1))),
                       sliderInput(inputId = "HadPR_seas1", label ="Private Season 1",
                                   min = as.Date("2025-05-01","%Y-%m-%d"),
                                   max = as.Date("2026-04-30","%Y-%m-%d"),
                                   value =c(as.Date("2025-05-01","%Y-%m-%d"),as.Date("2026-02-28","%Y-%m-%d")),
                                   timeFormat = "%Y-%m-%d", ticks = FALSE),
                       fluidRow(
                         column(4,
                                numericInput(inputId = "HadPR_1_bag", label = "Bag Limit",
                                             min = 0, max = 100, value = 15)),
                         column(5,
                                sliderInput(inputId = "HadPR_1_len", label = "Min Length",
                                            min = 15, max = 30, value = 17, step = 1))),

                       sliderInput(inputId = "HadFH_seas2", label ="For Hire Season 2",
                                   min = as.Date("2025-05-01","%Y-%m-%d"),
                                   max = as.Date("2026-04-30","%Y-%m-%d"),
                                   value =c(as.Date("2026-04-01","%Y-%m-%d"),as.Date("2026-04-30","%Y-%m-%d")),
                                   timeFormat = "%Y-%m-%d", ticks = FALSE),
                       fluidRow(
                         column(4,
                                numericInput(inputId = "HadFH_2_bag", label = "Bag Limit",
                                             min = 0, max = 100, value = 15)),
                         column(5,
                                sliderInput(inputId = "HadFH_2_len", label = "Min Length",
                                            min = 15, max = 30, value = 17, step = 1))),
                       sliderInput(inputId = "HadPR_seas2", label ="Private Season 2",
                                   min = as.Date("2025-05-01","%Y-%m-%d"),
                                   max = as.Date("2026-04-30","%Y-%m-%d"),
                                   value =c(as.Date("2026-04-01","%Y-%m-%d"),as.Date("2026-04-30","%Y-%m-%d")),
                                   timeFormat = "%Y-%m-%d", ticks = FALSE),
                       fluidRow(
                         column(4,
                                numericInput(inputId = "HadPR_2_bag", label = "Bag Limit",
                                             min = 0, max = 100, value = 15)),
                         column(5,
                                sliderInput(inputId = "HadPR_2_len", label = "Min Length",
                                            min = 15, max = 30, value = 17, step = 1))),

                       actionButton("HADaddSeason", "Add Season"),
                       shinyjs::hidden( div(ID = "HadSeason3",
                                            sliderInput(inputId = "HadFH_seas3", label ="For Hire Season 3",
                                                        min = as.Date("2025-05-01","%Y-%m-%d"),
                                                        max = as.Date("2026-04-30","%Y-%m-%d"),
                                                        value=c(as.Date("2026-01-01","%Y-%m-%d"),as.Date("2026-01-01","%Y-%m-%d")),
                                                        timeFormat = "%Y-%m-%d", ticks = FALSE),
                                            fluidRow(
                                              column(4,
                                                     numericInput(inputId = "HadFH_3_bag", label ="Bag Limit",
                                                                  min = 0, max = 20, value = 0)),
                                              column(6,
                                                     sliderInput(inputId = "HadFH_3_len", label ="Min Length",
                                                                 min = 15, max = 30, value = 17, step = 1))),
                                            sliderInput(inputId = "HadPR_seas3", label ="Private Season 3",
                                                        min = as.Date("2025-05-01","%Y-%m-%d"),
                                                        max = as.Date("2026-04-30","%Y-%m-%d"),
                                                        value=c(as.Date("2026-01-01","%Y-%m-%d"),as.Date("2026-01-01","%Y-%m-%d")),
                                                        timeFormat = "%Y-%m-%d", ticks = FALSE),
                                            fluidRow(
                                              column(4,
                                                     numericInput(inputId = "HadPR_3_bag", label ="Bag Limit",
                                                                  min = 0, max = 20, value = 0)),
                                              column(6,
                                                     sliderInput(inputId = "HadPR_3_len", label ="Min Length",
                                                                 min = 15, max = 30, value = 17, step = 1))))))))#,

  ))

####### Start Server ###################
server <- function(input, output, session){

  library(magrittr)
  library(ggplot2)
  #library(webshot)

  observeEvent(input$updatedat,{
    print("updating")
    shinyjs::js$refresh_page();
  })

  outputs <- function(){
    fnames <- list.files(path=here::here("output/"),pattern = "*.csv",full.names = T)

    fnames2<- as.data.frame(fnames) %>%
      tidyr::separate(fnames, into = c("a", "b"), sep = "_") %>%
      dplyr::mutate(b = ifelse(stringr::str_detect(b, "202501"),  "NA", b),
                    c=c(1:nrow(.)),
                    run_name = dplyr::case_when(b != "NA" ~ b, TRUE ~ as.character(c))) %>%
      dplyr::select(run_name)

    df <- fnames %>%
      purrr::map_df(~data.table::fread(.,stringsAsFactors=F,check.names=T,strip.white=T))

    return(df)
  }

  outputs_collected <-outputs()

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

  Run_Name <- function(){
    if(stringr::str_detect(input$Run_Name, "_")){
      Run_Name <-  gsub("_", "-", input$Run_Name)
    }else {
      Run_Name <- input$Run_Name
    }
    print(Run_Name)
    return(Run_Name)
  }

  regs<- function(){
    flist <- list.files(path = here::here("saved_regs/"), pattern = "\\.csv$", full.names = TRUE)

    regs_data <- flist %>%
      purrr::map_dfr(readr::read_csv)
    return(regs_data)
  }

  regs_collected<-regs()

  output$DTout <- DT::renderDT({
    catch_agg<- outputs_collected %>%
      #dat %>%
      dplyr::filter(metric %in% c("keep_weight", "discmort_weight"),
                    mode == "all modes") %>%
      dplyr::group_by(model, species,draw) %>%
      dplyr::summarise(Value = sum(as.numeric(value))) %>%
      dplyr::mutate(Value = Value * lb_to_mt()) %>%
      dplyr::mutate(under_acl = dplyr::case_when(species == "cod" & Value <= cod_acl() ~ 1, TRUE ~ 0),
                    under_acl = dplyr::case_when(species == "had" & Value <= had_acl() ~ 1, TRUE ~ under_acl)) %>%
      dplyr::group_by(model, species) %>%
      dplyr::summarise(under_acl = sum(under_acl),
                       Value = round(median(Value),0)) %>%
      tidyr::pivot_wider(names_from = species, values_from = c(Value, under_acl))

    # regs<- regs %>%

    regs1 <- regs_collected %>%
      dplyr::rename("model" = "run_name") %>%
      dplyr::left_join(catch_agg, by = c("model")) %>%
      tidyr::separate(input, into =c("Species", "season", "Var"), sep = "_") %>%
      tidyr::pivot_wider(names_from = Var, values_from = c(value)) %>%
      tidyr::separate(Species, into = c("Species", "mode"), sep = 3)


    seasons <- regs1 %>%
      dplyr::filter(!is.na(op), !is.na(cl)) %>%
      dplyr::mutate(season = paste(op, cl, sep = "-"),
                    Species = ifelse(grepl("cod", Species), "cod", "haddock")) %>%
      dplyr::group_by(model, mode, Species) %>%
      dplyr::summarise(season = paste(unique(season), collapse = ";"), .groups = "drop") %>%
      tidyr::pivot_wider(names_from = Species, values_from = season, names_glue = "{Species}season")

    bags <- regs1 %>%
      dplyr::filter(!is.na(bag)) %>%
      dplyr::mutate(Species = ifelse(grepl("cod", Species), "cod", "haddock")) %>%
      dplyr::group_by(model, mode, Species) %>%
      dplyr::summarise(baglimit = max(bag), .groups = "drop") %>%
      tidyr::pivot_wider(names_from = Species, values_from = baglimit, names_glue = "{Species}baglimit")

    minsizes <- regs1 %>%
      dplyr::filter(!is.na(len)) %>%
      dplyr::mutate(Species = ifelse(grepl("cod", Species), "cod", "haddock")) %>%
      dplyr::group_by(model, mode, Species) %>%
      dplyr::summarise(minsize = max(len), .groups = "drop") %>%
      tidyr::pivot_wider(names_from = Species,values_from = minsize,names_glue = "{Species}minsize")

    acl <- regs1 %>%
      dplyr::select(model, mode, under_acl_cod, under_acl_hadd) %>%
      dplyr::distinct()

    final_table <- seasons %>%
      dplyr::left_join(bags, by = c("model", "mode")) %>%
      dplyr::left_join(minsizes, by = c("model", "mode")) %>%
      dplyr::left_join(acl, by = c("model", "mode")) %>%
      dplyr::rename(Mode = mode,
                    `Run Identifier` = model,
                    `Cod Bag Limit` = codbaglimit,
                    `Cod Minimum Size (in)` = codminsize,
                    `Cod Season(s)` = codseason,
                    `Haddock Bag Limit` = haddockbaglimit,
                    `Haddock Minimum Size (in)` = haddockminsize,
                    `Haddock Season(s)` = haddockseason,
                    `% under Cod ACL` = under_acl_cod,
                    `% under Haddock ACL` = under_acl_hadd)


    DT::datatable(final_table)
  })

  # output$summary_regs_table <- DT::renderDT({
  #   regs1 <- regs_collected %>%
  #      dplyr::rename("model" = "run_name") %>%
  #      dplyr::left_join(catch_agg, by = c("model")) %>%
  #     tidyr::separate(input, into =c("Species", "season", "Var"), sep = "_") %>%
  #     tidyr::pivot_wider(names_from = Var, values_from = c(value)) %>%
  #     tidyr::separate(Species, into = c("Species", "mode"), sep = 3)
  #
  #
  #   seasons <- regs1 %>%
  #     dplyr::filter(!is.na(op), !is.na(cl)) %>%
  #     dplyr::mutate(season = paste(op, cl, sep = "-"),
  #                   Species = ifelse(grepl("cod", Species), "cod", "haddock")) %>%
  #     dplyr::group_by(model, mode, Species) %>%
  #     dplyr::summarise(season = paste(unique(season), collapse = ";"), .groups = "drop") %>%
  #     tidyr::pivot_wider(names_from = Species, values_from = season, names_glue = "{Species}season")
  #
  #   bags <- regs1 %>%
  #     dplyr::filter(!is.na(bag)) %>%
  #     dplyr::mutate(Species = ifelse(grepl("cod", Species), "cod", "haddock")) %>%
  #     dplyr::group_by(model, mode, Species) %>%
  #     dplyr::summarise(baglimit = max(bag), .groups = "drop") %>%
  #     tidyr::pivot_wider(names_from = Species, values_from = baglimit, names_glue = "{Species}baglimit")
  #
  #   minsizes <- regs1 %>%
  #     dplyr::filter(!is.na(len)) %>%
  #     dplyr::mutate(Species = ifelse(grepl("cod", Species), "cod", "haddock")) %>%
  #     dplyr::group_by(model, mode, Species) %>%
  #     dplyr::summarise(minsize = max(len), .groups = "drop") %>%
  #     tidyr::pivot_wider(names_from = Species,values_from = minsize,names_glue = "{Species}minsize")
  #
  #   final_table <- seasons %>%
  #     dplyr::left_join(bags, by = c("model", "mode")) %>%
  #     dplyr::left_join(minsizes, by = c("model", "mode")) %>%
  #     dplyr::rename(Mode = mode,
  #                   `Run Identifier` = model,
  #                   `Cod Bag Limit` = codbaglimit,
  #                   `Cod Minimum Size (in)` = codminsize,
  #                   `Cod Season(s)` = codseason,
  #                   `Haddock Bag Limit` = haddockbaglimit,
  #                   `Haddock Minimum Size (in)` = haddockminsize,
  #                   `Haddock Season(s)` = haddockseason)
  #
  # })

  output$totCatch <- plotly::renderPlotly({

    catch_agg<- outputs_collected %>%
      #dat %>%
      dplyr::filter(metric %in% c("keep_weight", "discmort_weight"),
                    mode == "all modes")%>%
      dplyr::group_by(model, species,draw) %>%
      dplyr::summarise(Value = sum(as.numeric(value))) %>%
      dplyr::mutate(Value = Value * lb_to_mt()) %>%
      dplyr::mutate(under_acl = dplyr::case_when(species == "cod" & Value <= cod_acl() ~ 1, TRUE ~ 0),
                    under_acl = dplyr::case_when(species == "had" & Value <= had_acl() ~ 1, TRUE ~ under_acl)) %>%
      dplyr::group_by(model, species) %>%
      dplyr::summarise(under_acl = sum(under_acl),
                       Value = round(median(Value),0)) %>%
      tidyr::pivot_wider(names_from = species, values_from = c(Value, under_acl))

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
      ggplot2::scale_size_manual(values = c("50-59%" = 1, "60-69%" = 1,
                                            "70-79%" = 1,"80-89%" = 1,
                                            "90-100%" = 1, "Less than 50%" = 1))+
      ggplot2::labs(colour="% of simulations under cod ACL",
                    size="% of simulations under haddock ACL")+
      ggplot2::geom_text(ggplot2::aes(label = model), check_overlap = TRUE)+
      ggplot2::geom_vline( xintercept =cod_acl(), linetype="dashed")+
      ggplot2::geom_hline( yintercept =had_acl(), color="grey45")+
      ggplot2::annotate(geom="text", x=cod_acl(), label="Cod ACL", y=1200) +
      ggplot2::annotate(geom="text", y=had_acl(), label="Had ACL", x=80) +
      ggplot2::guides(size = "none")+
      ggplot2::ggtitle("Cod and Haddock Mortality")+
      ggplot2::ylab("Median Recreational Haddock Mortality (mt)")+
      ggplot2::xlab("Median Recreational Cod Mortality (mt)")

    fig<- plotly::ggplotly(p) %>% #,
      plotly::style(textposition = "top center")
    fig
  })

  output$addCVCod <- renderUI({

    if(any("Angler Satisfaction" == input$fig)){

      plotly::renderPlotly({

        welfare <-  outputs_collected %>%
          dplyr::filter(metric == c("CV"),
                        mode == "all modes") %>%
          dplyr::group_by(model,  draw) %>%
          dplyr::summarise(value = sum(as.numeric(value))) %>%
          tidyr::pivot_wider(names_from = model, values_from = value) %>%
          tidyr::pivot_longer(-draw, names_to = "model", values_to = "value") %>%
          dplyr::group_by(draw) %>%
          dplyr::mutate(SQ_value = (value[model == "SQ"]),
                 pct_diff = 100 * (value - SQ_value) / SQ_value) %>%
          dplyr::ungroup()

        catch<- outputs_collected %>%
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
          dplyr::summarise(`Angler Satisfaction($)` = median(pct_diff),
                           cod = median(cod),
                           hadd = median(hadd))

        p1<- catch %>% ggplot2::ggplot(ggplot2::aes(x = `Angler Satisfaction($)`, y = cod))+
          ggplot2::geom_point() +
          ggplot2::geom_hline( yintercept =cod_acl())+
          ggplot2::geom_text(ggplot2::aes(label=model), check_overlap = TRUE)+
          ggplot2::geom_text(ggplot2::aes(y=cod_acl(), label="Cod ACL", x=1000000)) +
          ggplot2::xlab("Relative Change in Angler Satisfaction ($)")+
          ggplot2::ylab("Total Recreational Cod Mortality (mt)")+
          ggplot2::labs(title = "Cod Mortality (mt) compared to Angler Satisfaction (Compared to status-quo regulations, how much better- or worse-off are anglers, in dollars?)",
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
        welfare <-  outputs_collected %>%
          dplyr::filter(metric == c("CV"),
                        mode == "all modes") %>%
          dplyr::group_by(model,  draw) %>%
          dplyr::summarise(value = sum(as.numeric(value))) %>%
          tidyr::pivot_wider(names_from = model, values_from = value) %>%
          tidyr::pivot_longer(-draw, names_to = "model", values_to = "value") %>%
          dplyr::group_by(draw) %>%
          dplyr::mutate(SQ_value = (value[model == "SQ"]),
                 pct_diff = 100 * (value - SQ_value) / SQ_value) %>%
          dplyr::ungroup()

        catch<- outputs_collected %>%
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
          dplyr::summarise(`Angler Satisfaction($)` = median(pct_diff),
                           cod = median(cod),
                           hadd = median(hadd))

        p2<- catch %>% ggplot2::ggplot(ggplot2::aes(x = `Angler Satisfaction($)`, y = hadd))+
          ggplot2::geom_point() +
          ggplot2::geom_hline( yintercept =had_acl())+
          ggplot2::geom_text(ggplot2::aes(label=model), check_overlap = TRUE)+
          ggplot2::xlab("Relative Change in Angler Satisfaction ($)")+
          ggplot2::ylab("Total Recreational Haddock Mortality (mt)")+
          ggplot2::geom_text(ggplot2::aes(x=had_acl(), label="Had ACL", y=1075)) +
          ggplot2::labs(title = "Haddock Mortality (mt) compared to Angler Satisfaction (Compared to status-quo regulations, how much better- or worse-off are anglers, in dollars?)",
                        subtitle = "testing")+
          ggplot2::theme(legend.position = "none")

        fig2<- plotly::ggplotly(p2) %>%
          # graphics::layout(title = list(text = paste0('Haddock Mortality (mt) compared to Angler Satisfaction',
          #                                   '<br>',
          #                                   '<sup>',
          #                                   'More descirptuon of CV','</sup>'))) %>%
          plotly::style(textposition = "top center")
        fig2
      })

    }
  })

  output$addReleaseCod <- renderUI({

    if(any("Discards" == input$fig)){

      plotly::renderPlotly({

        discmort <-  outputs_collected %>%
          dplyr::filter(metric == c("discmort_weight"),
                        mode == "all modes") %>%
          dplyr::group_by(model,  draw) %>%
          dplyr::mutate(disc_mort = value * lb_to_mt())  %>%
          dplyr::select(!c(metric,value))

        catch<- outputs_collected %>%
          #dat %>%
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
          ggplot2::geom_text(ggplot2::aes(y=cod_acl(), label="Cod ACL", x=50)) +
          ggplot2::xlab("Cod Discard Mortality (mt)")+
          ggplot2::ylab("Total Recreational Cod Mortality (mt)")+
          ggplot2::labs(title = "Total Cod Mortality (mt) compared to Discard Mortality(mt)",
                        subtitle = "")+
          ggplot2::theme(legend.position = "none")

        fig3<- plotly::ggplotly(p3)%>%
          # graphics::layout(title = list(text = paste0('Cod Mortality (mt) compared to Cod Releases (mt)'))) %>%
          plotly::style(textposition = "top center")
        fig3
      })
    }
  })

  output$addReleaseHad <- renderUI({
    if(any("Discards" == input$fig)){


      plotly::renderPlotly({
        discmort <-  outputs_collected %>%
          dplyr::filter(metric == c("discmort_weight"),
                        mode == "all modes") %>%
          dplyr::group_by(model,  draw) %>%
          dplyr::mutate(disc_mort = value * lb_to_mt())  %>%
          dplyr::select(!c(metric,value))

        catch<- outputs_collected %>%
          #dat %>%
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
          ggplot2::geom_text(ggplot2::aes(y=had_acl(), label="Had ACL", x=300)) +
          ggplot2::xlab("Haddock Discard Mortality (mt)")+
          ggplot2::ylab("Total Recreational Haddock Mortality (mt)")+
          ggplot2::labs(title = "Total Haddock Mortality (mt) compared to Discard Mortality (mt)",
                        subtitle = "testing")+
          ggplot2::theme(legend.position = "none")

        fig4<- plotly::ggplotly(p4)%>%
          # graphics::layout(title = list(text = paste0('Haddock Mortality (mt) compared to Haddock Releases (mt)'))) %>%
          plotly::style(textposition = "top center")
        fig4

      })
    }
  })


  output$addTripsCod <- renderUI({
    if(any("Trips" == input$fig)){

      plotly::renderPlotly({

        trips <-  outputs_collected %>%
          dplyr::filter(metric == c("predicted_trips"),
                        mode == "all modes") %>%
          dplyr::group_by(model,  draw) %>%
          dplyr::summarise(value = sum(as.numeric(value))) %>%
          dplyr::ungroup()

        catch<- outputs_collected %>%
          #dat %>%
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
          ggplot2::geom_text(ggplot2::aes(y=cod_acl(), label="Cod ACL", x=167000), angle=90) +
          ggplot2::xlab("Number of Trips")+
          ggplot2::ylab("Total Recreational Cod Mortality (mt)")+
          ggplot2::labs(title = "Cod Mortality (mt) compared to Total Number of Trips",
                        subtitle = "testing")+
          ggplot2::theme(legend.position = "none")

        fig5<- plotly::ggplotly(p5)%>%
          #graphics::layout(title = list(text = paste0('Cod Mortality (mt) compared to Total Number of Trips'))) %>%
          plotly::style(textposition = "top center")
        fig5

      })
    }
  })


  output$addTripsHad <- renderUI({
    if(any("Trips" == input$fig)){

      plotly::renderPlotly({
        trips <- outputs_collected %>%
          dplyr::filter(metric == c("predicted_trips"),
                        mode == "all modes") %>%
          dplyr::group_by(model,  draw) %>%
          dplyr::summarise(value = sum(as.numeric(value))) %>%
          dplyr::ungroup()

        catch<- outputs_collected %>%
          #dat %>%
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
          ggplot2::geom_text(ggplot2::aes(y=had_acl(), label="Had ACL", x=167000)) +
          ggplot2::xlab("Number of Trips")+
          ggplot2::ylab("Total Recreational Haddock Mortality (mt)")+
          ggplot2::labs(title = "Haddock Mortality (mt) compared to Total Number of Trips",
                        subtitle = "testing")+
          ggplot2::theme(legend.position = "none")

        fig6<- plotly::ggplotly(p6)%>%
          #layout(title = list(text = paste0('Haddock Mortality (mt) compared to Total Number of Trips'))) %>%
          plotly::style(textposition = "top center")
        fig6
      })
    }
  })

  #### Toggle extra seasons on UI ####
  # Allows for extra seasons to show and hide based on click
  shinyjs::onclick("CODaddSeason",
                   shinyjs::toggle(id = "CodSeason3", anim = TRUE))
  shinyjs::onclick("HADaddSeason",
                   shinyjs::toggle(id = "HadSeason3", anim = TRUE))


  pred <- eventReactive(input$runmeplease,{
    print("STarting this process")
    source(here::here(paste0("RecDST/model_run.R")), local = TRUE)
    return(predictions_out10)
    print("predicitions out")
  })

  predictions <- reactive({

    #test<- read.csv(here::here("output/output_help_20250106_133859.csv"))
    predictions_out <- read.csv(here::here("data-raw/SQ_predictions_cm.csv")) %>%
      #dplyr::mutate(option = c("SQ")) %>%
      #dplyr::select(!X) %>%
      #rbind(predictions_out10) %>%
      rbind(pred()) %>%
      dplyr::mutate(Value = dplyr::case_when(number_weight == "Weight" ~ as.numeric(Value)/2205, TRUE ~ as.numeric(Value)))
    return(predictions_out)
  })

  #### Regulations ####
  regulations <- observeEvent(input$runmeplease,{
    library(httr)
    library(jsonlite)
    library(openssl)
    library(uuid)

    enqueue_simple_sas <- function(run_name, queue_url_sas = Sys.getenv("AZURE_STORAGE_QUEUE_URL")) {
      stopifnot(nzchar(run_name), nzchar(queue_url_sas))
      payload <- list(
        runName = run_name,
        submissionId = UUIDgenerate(),
        submittedAt = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
      )
      msg_b64 <- base64_encode(charToRaw(toJSON(payload, auto_unbox = TRUE)))
      xml_body <- sprintf("<QueueMessage><MessageText>%s</MessageText></QueueMessage>", msg_b64)

      res <- POST(
        url = queue_url_sas,
        body = xml_body,
        content_type_xml(),
        add_headers(`x-ms-version` = "2020-10-02")
      )
      stop_for_status(res)
      invisible(TRUE)
    }


    regulations <- NULL
    print("where am i")
    #if(any( )) will run all selected check boxes on UI-regulations selection tab
    codregs <- data.frame(run_name = c(Run_Name()),
                          input =  c("codFH_seas1_op", "codFH_seas1_cl", "codPR_seas1_op", "codPR_seas1_cl",
                                     "codFH_seas2_op", "codFH_seas2_cl", "codPR_seas2_op", "codPR_seas2_cl",
                                     "codFH_seas3_op", "codFH_seas3_cl", "codPR_seas3_op", "codPR_seas3_cl",

                                     "codFH_1_bag",   "codFH_1_len",    "codPR_1_bag",   "codPR_1_len",
                                     "codFH_2_bag" ,  "codFH_2_len",    "codPR_2_bag",   "codPR_2_len",
                                     "codFH_3_bag",   "codFH_3_len",    "codPR_3_bag",   "codPR_3_len"),
                          value =  c(as.character(input$CodFH_seas1[1]), as.character(input$CodFH_seas1[2]),
                                     as.character(input$CodFH_seas2[1]), as.character(input$CodFH_seas2[2]),
                                     as.character(input$CodFH_seas3[1]), as.character(input$CodFH_seas3[2]),

                                     as.character(input$CodPR_seas1[1]), as.character(input$CodPR_seas1[2]),
                                     as.character(input$CodPR_seas2[1]), as.character(input$CodPR_seas2[2]),
                                     as.character(input$CodPR_seas3[1]), as.character(input$CodPR_seas3[2]),

                                     as.character(input$CodFH_1_bag), as.character(input$CodPR_1_bag),
                                     as.character(input$CodFH_2_bag), as.character(input$CodPR_2_bag),
                                     as.character(input$CodFH_3_bag), as.character(input$CodPR_3_bag),

                                     as.character(input$CodFH_1_len), as.character(input$CodPR_1_len),
                                     as.character(input$CodFH_2_len), as.character(input$CodPR_2_len),
                                     as.character(input$CodFH_3_len), as.character(input$CodPR_3_len)))


    hadregs <- data.frame(run_name = c(Run_Name()),
                          input =  c("hadFH_seas1_op", "hadFH_seas1_cl", "hadPR_seas1_op", "hadPR_seas1_cl",
                                     "hadFH_seas2_op", "hadFH_seas2_cl", "hadPR_seas2_op", "hadPR_seas2_cl",
                                     "hadFH_seas3_op", "hadFH_seas3_cl", "hadPR_seas3_op", "hadPR_seas3_cl",

                                     "hadFH_1_bag",   "hadFH_1_len",    "hadPR_1_bag",   "hadPR_1_len",
                                     "hadFH_2_bag" ,  "hadFH_2_len",    "hadPR_2_bag",   "hadPR_2_len",
                                     "hadFH_3_bag",   "hadFH_3_len",    "hadPR_3_bag",   "hadPR_3_len"),


                          value =  c(as.character(input$HadFH_seas1[1]), as.character(input$HadFH_seas1[2]),
                                     as.character(input$HadFH_seas2[1]), as.character(input$HadFH_seas2[2]),
                                     as.character(input$HadFH_seas3[1]), as.character(input$HadFH_seas3[2]),

                                     as.character(input$HadPR_seas1[1]), as.character(input$HadPR_seas1[2]),
                                     as.character(input$HadPR_seas2[1]), as.character(input$HadPR_seas2[2]),
                                     as.character(input$HadPR_seas3[1]), as.character(input$HadPR_seas3[2]),

                                     as.character(input$HadFH_1_bag), as.character(input$HadPR_1_bag),
                                     as.character(input$HadFH_2_bag), as.character(input$HadPR_2_bag),
                                     as.character(input$HadFH_3_bag), as.character(input$HadPR_3_bag),

                                     as.character(input$HadFH_1_len), as.character(input$HadPR_1_len),
                                     as.character(input$HadFH_2_len), as.character(input$HadPR_2_len),
                                     as.character(input$HadFH_3_len), as.character(input$HadPR_3_len)))


    regulations <- regulations %>% rbind(codregs, hadregs)
    print("made regulations MA")


    readr::write_csv(regulations, file = here::here(paste0("saved_regs/regs_", input$Run_Name, ".csv")))
    print("saved_inputs")

    enqueue_simple_sas(input$Run_Name)

    return(regulations)

  })

  observeEvent(input$runmeplease, {
    output$message <- renderText("Regulations saved - we will run these soon be sure to change run name before clicking again.")
  })

  # Get list of files from the folder
  available_files <- reactive({
    folder_path <- here::here("output/")
    if (dir.exists(folder_path)) {
      files <- list.files(folder_path, full.names = FALSE)
      if (length(files) > 0) {
        return(files)
      }
    }
    return(character(0))
  })

  file_mapping <- reactive({
    files <- available_files()
    if (length(files) > 0) {
      # Remove file extensions for display names
      display_names <- files %>%
        stringr::str_remove("^output_") %>%         # remove prefix
        stringr::str_remove("_[0-9]+")  %>%
        stringr::str_remove("_[0-9]+") %>%
        stringr::str_remove(".csv")
      # Create named vector: display_name = full_filename
      names(files) <- display_names
      return(files)
    }
    return(character(0))
  })

  # Update dropdown choices when app starts
  observe({
    file_map <- file_mapping()
    if (length(file_map) > 0) {
      updateSelectInput(
        session,
        "file_choice",
        choices = file_map,
        selected = file_map[1]
      )
    } else {
      updateSelectInput(
        session,
        "file_choice",
        choices = "No files available",
        selected = NULL
      )
    }
  })

  # Display file information
  output$file_info <- renderText({
    if (is.null(input$file_choice) || input$file_choice == "No files available") {
      return("No file selected or no files available.")
    }

    file_path <- file.path("output", input$file_choice)

    if (file.exists(file_path)) {
      file_info <- file.info(file_path)
      # Get the display name (without extension) for the selected file
      display_name <- tools::file_path_sans_ext(input$file_choice)
      paste(
        "Display name:", display_name,
        "\nFull filename:", input$file_choice,
        "\nFile size:", round(file_info$size / 1024, 2), "KB",
        "\nLast modified:", format(file_info$mtime, "%Y-%m-%d %H:%M:%S"),
        sep = "\n"
      )
    } else {
      "File not found."
    }
  })

  # Handle file download
  output$download_file <- downloadHandler(
    filename = function() {
      # Return the selected filename (full filename with extension)
      if (!is.null(input$file_choice) && input$file_choice != "No files available") {
        return(input$file_choice)
      } else {
        return("file.txt")  # Fallback filename
      }
    },
    content = function(file) {
      # Copy the selected file to the download location
      if (!is.null(input$file_choice) && input$file_choice != "No files available") {
        file_path <- file.path("output", input$file_choice)
        if (file.exists(file_path)) {
          file.copy(file_path, file)
        } else {
          # If file doesn't exist, create an error file
          writeLines("Error: File not found.", file)
        }
      } else {
        writeLines("Error: No file selected.", file)
      }
    }
  )

  # ##### Catch ###########
  # which_catch_out<- reactiveVal(TRUE)
  # catch_agg <- reactive({
  #
  #   catch_agg<- predictions() %>%
  #     #dat %>%
  #     dplyr::filter(catch_disposition %in% c("keep", "Discmortality"),
  #                   number_weight == "Weight") %>%
  #     dplyr::group_by(option, Category, draw_out) %>%
  #     dplyr::summarise(Value = sum(Value)) %>%
  #     dplyr::mutate(under_acl = dplyr::case_when(Category == "cod" & Value <= cod_acl() ~ 1, TRUE ~ 0),
  #                   under_acl = dplyr::case_when(Category == "had" & Value <= had_acl() ~ 1, TRUE ~ under_acl)) %>%
  #     dplyr::group_by(option, Category) %>%
  #     dplyr::summarise(under_acl = sum(under_acl),
  #                      Value = median(Value)) %>%
  #     tidyr::pivot_wider(names_from = c(option), values_from = c(Value, under_acl)) %>%
  #     dplyr::mutate(Category = dplyr::recode(Category, "cod" = "Cod",
  #                                            "had" = "Haddock")) %>%
  #     dplyr::select(Category, Value_SQ, under_acl_SQ, Value_alt, under_acl_alt) %>%
  #     dplyr::rename(Species = Category, `SQ Total Mortality (mt)` = Value_SQ, `SQ % Under ACL (Out of 100 runs)` = under_acl_SQ,
  #                   `Alternative Total Mortality (mt)` = Value_alt, `Atlernative % Under ACL (Out of 100 runs)` = under_acl_alt)
  #
  #   return(catch_agg)
  # })
  #
  # catch_by_mode <- reactive({
  #
  #   print("start catch mode")
  #   catch_by_mode<- predictions() %>%
  #     #dat %>% #test %>%
  #     dplyr::filter(catch_disposition %in% c("keep", "Discmortality"),
  #                   number_weight == "Weight") %>%
  #     dplyr::group_by(option, Category, draw_out, mode) %>%
  #     dplyr::summarise(Value = sum(Value)) %>%
  #     dplyr::mutate(under_acl = dplyr::case_when(Category == "cod" & Value <= 99000 ~ 1, TRUE ~ 0),
  #                   under_acl = dplyr::case_when(Category == "had" & Value <= 1075000 ~ 1, TRUE ~ under_acl)) %>%
  #     dplyr::group_by(option, Category, mode) %>%
  #     dplyr::summarise(under_acl = sum(under_acl),
  #                      Value = median(Value)) %>%
  #     tidyr::pivot_wider(names_from = c(option), values_from = c(Value, under_acl)) %>%
  #     dplyr::mutate(Category = dplyr::recode(Category, "cod" = "Cod",
  #                                            "had" = "Haddock"),
  #                   mode = dplyr::recode(mode, "fh" = "For Hire",
  #                                        "pr" = "Private")) %>%
  #     dplyr::select(Category, Value_SQ, Value_alt,  mode) %>%
  #     dplyr::rename(Species = Category, `SQ Total Mortality (mt)` = Value_SQ,
  #                   `Alternative Total Mortality (mt)` = Value_alt, `Mode` = mode)
  #
  #   return(catch_by_mode)
  # })
  #
  # #### keep release discards ####
  # which_keep_out<- reactiveVal(TRUE)
  # keep_agg <- reactive({
  #
  #   # sq<- read.csv(here::here("data-raw/sq_predictions_cm.csv"))%>%
  #   #   dplyr::mutate(Value = dplyr::case_when(number_weight == "Weight" ~ as.numeric(Value)/2205, TRUE ~ as.numeric(Value)))
  #   #  out<- read.csv(here::here("output/output_alt1_20250113_102706.csv"))%>%
  #   #    dplyr::mutate(Value = dplyr::case_when(number_weight == "Weight" ~ as.numeric(Value)/2205, TRUE ~ as.numeric(Value)))
  #   #  dat<- rbind(sq, out)
  #
  #   keep_agg<- predictions() %>%
  #     #dat %>% #redictions_out %>%
  #     dplyr::filter(catch_disposition %in% c("keep", "release", "Discmortality")) %>%
  #     dplyr::group_by(option, Category, catch_disposition, number_weight, draw_out) %>%
  #     dplyr::summarise(Value = sum(as.numeric(Value))) %>%
  #     dplyr::group_by(option, Category, catch_disposition, number_weight) %>%
  #     tidyr::pivot_wider(names_from = c(option, number_weight), values_from = Value) %>%
  #     dplyr::mutate(perc_diff_num = ((alt_Number-SQ_Number)/SQ_Number) * 100,
  #                   perc_diff_wt = ((alt_Weight-SQ_Weight)/SQ_Weight) * 100) %>%
  #     dplyr::filter(!perc_diff_num == "NA",
  #                   !perc_diff_wt == "NA") %>%
  #     dplyr::summarise(SQ_Number = median(SQ_Number), SQ_Weight = median(SQ_Weight),
  #                      alt_Number = median(alt_Number), alt_Weight = median(alt_Weight),
  #                      perc_diff_num = median(perc_diff_num), perc_diff_wt = median(perc_diff_wt)) %>%
  #     dplyr::select(!c(SQ_Number, SQ_Weight)) %>%
  #     dplyr::mutate(Category = dplyr::recode(Category, "cod" = "Cod",
  #                                            "had" = "Haddock"),
  #                   catch_disposition = dplyr::recode(catch_disposition, "keep" = "Harvest",
  #                                                     "Discmortality" = "Dead Discards",
  #                                                     "release" = "Discards")) %>%
  #     dplyr::select(Category, catch_disposition, alt_Number, perc_diff_num, alt_Weight, perc_diff_wt) %>%
  #     dplyr::rename(Species = Category, Variable = catch_disposition,
  #                   `Total number of fish` = alt_Number, `% difference from SQ for number of fish` = perc_diff_num,
  #                   `Total Weight (mt)` = alt_Weight, `% difference from SQ for weight of fish` = perc_diff_wt)
  #
  #   return(keep_agg)
  #
  # })
  #
  #
  # keep_by_mode <- reactive({
  #   keep_by_mode<- predictions() %>%
  #     #dat %>% #predictions_out %>%
  #     dplyr::filter(catch_disposition %in% c("keep", "release", "Discmortality")) %>%
  #     dplyr::group_by(option, Category, catch_disposition, number_weight, draw_out, mode) %>%
  #     dplyr::summarise(Value = sum(as.numeric(Value))) %>%
  #     dplyr::group_by(option, Category, catch_disposition, number_weight, mode) %>%
  #     dplyr::summarise(Value = median(Value)) %>%
  #     tidyr::pivot_wider(names_from = c(option, number_weight), values_from = Value) %>%
  #     dplyr::mutate(perc_diff_num = ((alt_Number-SQ_Number)/SQ_Number) * 100,
  #                   perc_diff_wt = ((alt_Weight-SQ_Weight)/SQ_Weight) * 100) %>%
  #     dplyr::group_by(Category, catch_disposition, mode) %>%
  #     dplyr::filter(!perc_diff_num == "NA",
  #                   !perc_diff_wt == "NA") %>%
  #     dplyr::summarise(SQ_Number = median(SQ_Number), SQ_Weight = median(SQ_Weight),
  #                      alt_Number = median(alt_Number), alt_Weight = median(alt_Weight),
  #                      perc_diff_num = median(perc_diff_num), perc_diff_wt = median(perc_diff_wt)) %>%
  #     dplyr::select(!c(SQ_Number, SQ_Weight)) %>%
  #     dplyr::mutate(Category = dplyr::recode(Category, "cod" = "Cod",
  #                                            "had" = "Haddock"),
  #                   catch_disposition = dplyr::recode(catch_disposition, "keep" = "Harvest",
  #                                                     "Discmortality" = "Dead Discards",
  #                                                     "release" = "Discards"),
  #                   mode = dplyr::recode(mode, "fh" = "For Hire",
  #                                        "pr" = "Private")) %>%
  #     dplyr::select(Category, catch_disposition, mode, alt_Number, perc_diff_num, alt_Weight, perc_diff_wt) %>%
  #     dplyr::rename(Species = Category, Variable = catch_disposition,
  #                   `Total Number of fish` = alt_Number, `% difference in number of fish` = perc_diff_num,
  #                   `Total Weight (mt)` = alt_Weight, `% difference in weight of fish` = perc_diff_wt, `Mode` = mode)
  #   return(keep_by_mode)
  # })
  # #####################
  #
  # ##### Ntrips & welfare #######
  # which_welfare_out<- reactiveVal(TRUE)
  # welfare_agg <- reactive({
  #
  #   #     sq<- read.csv(here::here("data-raw/sq_predictions_cm.csv"))
  #   #      out<- read.csv(here::here("predictions2.csv")) %>%
  #   #        dplyr::select(!X)
  #   #      dat<- rbind(sq, out)
  #   # #
  #   welfare2_agg <- predictions() %>%
  #     #dat %>%
  #     dplyr::filter(Category =="CV")%>%
  #     dplyr::group_by( draw_out, option) %>%
  #     dplyr::summarise(Value = sum(as.numeric(Value))) %>%
  #     tidyr::pivot_wider(names_from = option, values_from = Value) %>%
  #     dplyr::mutate(Value_diff = SQ - alt) %>%
  #     dplyr::filter(!Value_diff == "NA") %>%
  #     dplyr::ungroup() %>%
  #     dplyr::summarise(median_cv = median(Value_diff)) %>%
  #     dplyr::rename(`Relative change in Angler Satisfaction ($)` = median_cv)
  #
  #
  #   trips_agg<- predictions() %>%
  #     #dat %>%
  #     dplyr::filter(Category =="ntrips" & option == "alt") %>%
  #     dplyr::group_by( draw_out) %>%
  #     dplyr::summarise(Value = sum(as.numeric(Value))) %>%
  #     dplyr::summarise(Value = median(Value)) %>%
  #     dplyr::select(Value) %>%
  #     dplyr::ungroup() %>%
  #     dplyr::rename(`Total number of Angler Trips` = Value) %>%
  #     dplyr::select(`Total number of Angler Trips`)
  #
  #
  #   welfare_agg<- cbind(welfare2_agg, trips_agg)
  #
  #   return(welfare_agg)
  #
  # })
  #
  #
  # welfare_by_mode <- reactive({
  #
  #   welfare_by_mode2 <- predictions() %>%
  #     #predictions_out %>%
  #     dplyr::filter(Category == "CV") %>%
  #     dplyr::group_by( draw_out, option, mode) %>%
  #     dplyr::summarise(Value = sum(as.numeric(Value))) %>%
  #     tidyr::pivot_wider(names_from = option, values_from = Value) %>%
  #     dplyr::mutate(Value_diff = SQ - alt) %>%
  #     dplyr::filter(!Value_diff == "NA") %>%
  #     dplyr::group_by(mode) %>%
  #     dplyr::summarise(median_cv = median(Value_diff)) %>%
  #     dplyr::rename(`Relative change in Angler Satisfaction ($)` = median_cv) %>%
  #     dplyr::ungroup()
  #
  #
  #   trips_by_mode<- predictions() %>%
  #     #predictions_out %>%
  #     dplyr::filter(Category =="ntrips" & option == "alt") %>%
  #     dplyr::group_by(draw_out, mode) %>%
  #     dplyr::summarise(Value = sum(as.numeric(Value))) %>%
  #     dplyr::group_by( mode) %>%
  #     dplyr::summarise(Value = median(Value)) %>%
  #     dplyr::select(Value) %>%
  #     dplyr::ungroup() %>%
  #     dplyr::rename(`Total number of Angler Trips` = Value) %>%
  #     dplyr::select(`Total number of Angler Trips`)
  #
  #
  #   welfare_by_mode<- cbind(welfare_by_mode2, trips_by_mode) %>%
  #     dplyr::mutate(mode = dplyr::recode(mode, "fh" = "For Hire",
  #                                        "pr" = "Private"))
  #   return(welfare_by_mode)
  # })

  ###Output Tables
  output$regtableout <- renderTable({
    regs_agg()
  })

  #### Catch tables
  observeEvent(input$bymode, {
    which_catch_out(!which_catch_out())
  })

  which_catch<- reactive({
    if(which_catch_out()){
      catch_agg()
    } else{
      catch_by_mode()
    }
  })

  output$catch_tableout <- renderTable({
    which_catch()
  })

  ### Keep Release
  observeEvent(input$bymode, {
    which_keep_out(!which_keep_out())
  })

  which_keep<- reactive({
    if(which_keep_out()){
      keep_agg()
    } else{
      keep_by_mode()
    }
  })

  output$keep_tableout <- renderTable({
    which_keep()
  })


  #### Welfare
  observeEvent(input$bymode, {
    which_welfare_out(!which_welfare_out())
  })

  which_welfare<- reactive({
    if(which_welfare_out()){
      welfare_agg()
    } else{
      welfare_by_mode()
    }
  })

  output$welfare_tableout <- renderTable({
    which_welfare()
  })

  ### Save data
  observeEvent(input$runmeplease, {
    dat<- pred()

    Regs<- data.frame(Category = c("Cod1_FH_bag", "Cod1_FH_size", "Cod1_FH_Season",
                                   "Cod1_PR_bag", "Cod1_PR_size", "Cod1_PR_Season",
                                   "Had1_FH_bag", "Had1_FH_size", "Had1_FH_Season",
                                   "Had1_PR_bag", "Had1_PR_size", "Had1_PR_Season",
                                   "Had2_FH_bag", "Had2_FH_size", "Had2_FH_Season",
                                   "Had2_PR_bag", "Had2_PR_size", "Had2_PR_Season",
                                   "Cod2_FH_bag", "Cod2_FH_size", "Cod2_FH_Season",
                                   "Cod2_PR_bag", "Cod2_PR_size", "Cod2_PR_Season",
                                   "Had3_FH_bag", "Had3_FH_size", "Had3_FH_Season",
                                   "Had3_PR_bag", "Had3_PR_size", "Had3_PR_Season"),
                      Value = c(input$CodFH_1_bag, input$CodFH_1_len, paste0(input$CodFH_seas1[1], " - ", input$CodFH_seas1[2]),
                                input$CodPR_1_bag, input$CodPR_1_len, paste0(input$CodPR_seas1[1], " - ", input$CodPR_seas1[2]),
                                input$HadFH_1_bag, input$HadFH_1_len, paste0(input$HadFH_seas1[1], " - ", input$HadFH_seas1[2]),
                                input$HadPR_1_bag, input$HadPR_1_len, paste0(input$HadPR_seas1[1], " - ", input$HadPR_seas1[2]),
                                input$HadFH_2_bag, input$HadFH_2_len, paste0(input$HadFH_seas2[1], " - ", input$HadFH_seas2[2]),
                                input$HadPR_2_bag, input$HadPR_2_len, paste0(input$HadPR_seas2[1], " - ", input$HadPR_seas2[2]),
                                input$CodFH_2_bag, input$CodFH_2_len, paste0(input$CodFH_seas2[1], " - ", input$CodFH_seas2[2]),
                                input$CodPR_2_bag, input$CodPR_2_len, paste0(input$CodPR_seas2[1], " - ", input$CodPR_seas2[2]),
                                input$HadFH_3_bag, input$HadFH_3_len, paste0(input$HadFH_seas3[1], " - ", input$HadFH_seas3[2]),
                                input$HadPR_3_bag, input$HadPR_3_len, paste0(input$HadPR_seas3[1], " - ", input$HadPR_seas3[2])),
                      mode = c("NA"), catch_disposition = c("NA"), param = c("NA"), number_weight = c("NA"),
                      season = c("NA"), draw_out = c("NA"), mrip_index = c("NA"),option= c("NA"))

    dat_out<- dat %>% rbind(Regs)
    Run_Name = Run_Name()
    readr::write_csv(dat_out, file = here::here(paste0("output/output_", Run_Name, "_", format(Sys.time(), "%Y%m%d_%H%M%S"),  ".csv")))

  })

  output$downloadData <- downloadHandler(
    filename = function(){"RecDSToutput.xlsx"},
    content = function(filename) {
      df_list <- list(Regulations=regs_agg(), Catch_Mortality_aggregated = catch_agg(), Catch_Mortality_by_mode = catch_by_mode(),
                      Keep_Release_aggregated = keep_agg(), Keep_Release_by_mode = keep_by_mode(),
                      Satisfaction_trips_aggregated = welfare_agg(), Satisfaction_trips_by_mode = welfare_by_mode())
      openxlsx::write.xlsx(append = TRUE, x = df_list , file = filename, row.names = FALSE)
    })

}
shiny::shinyApp(ui = ui, server = server)
