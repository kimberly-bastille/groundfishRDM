FROM rocker/shiny:4.3
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
    nano \
    && rm -rf /var/lib/apt/lists/*
COPY shiny-server.conf /etc/shiny-server/shiny-server.conf
COPY . /srv/app/
RUN install2.r -e -s \
    shiny \
    shinyjs \
    shinyWidgets \
    magrittr \
    readr \
    here \
    dplyr \
    tidyr \
    stringr \
    lubridate \
    tibble \
    arrow \
    graphics \
    data.table \
    knitr \
    openxlsx \
    plyr \
    markdown \
    future \
    parallelly \
    furrr \
    DT \
    plotly \
    rlang \
    conflicted \
    && chown -R shiny:shiny /srv/app
