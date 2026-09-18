FROM rocker/shiny:4.3

ENV GROUNDFISH_AZURE_STORAGE_QUEUE_URL=""

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
    nano \
    && rm -rf /var/lib/apt/lists/*
COPY shiny-server.conf /etc/shiny-server/shiny-server.conf
COPY . /srv/rdmtool
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
    graphics \
    data.table \
    knitr \
    plyr \
    future \
    parallelly \
    furrr \
    DT \
    plotly \
    rlang \
    openssl \
    uuid \
    && chown -R shiny:shiny /srv/rdmtool

CMD ["sh", "-c", "/usr/bin/shiny-server & sleep 2 && tail -F /var/log/shiny-server/*.log"]
