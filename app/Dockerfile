FROM rocker/shiny:4.4.1

RUN apt-get update && apt-get install -y --no-install-recommends \
    libpq-dev \
    && rm -rf /var/lib/apt/lists/*

RUN R -e "install.packages(c('shinyjs', 'pool', 'RPostgres', 'DBI', 'shinymanager', 'httr', 'openssl', 'qrcode'))"

COPY . /srv/shiny-server/app
WORKDIR /srv/shiny-server/app

EXPOSE 3838

CMD ["R", "-e", "shiny::runApp('/srv/shiny-server/app', host = '0.0.0.0', port = as.integer(Sys.getenv('PORT', 3838)))"]
