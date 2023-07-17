# get shiny server and a version of R from the rocker project
FROM rocker/shiny:4.3.0

# system libraries
RUN apt-get update && apt-get install -y \
    libcurl4-gnutls-dev \
    libssl-dev
  

# install R packages required 
# Change the packages list to suit your needs

RUN R -e 'install.packages(c(\
              "shiny", \
              "shinydashboard", \
              "shiny.i18n", \
              "sf", \
              "maps", \
              "dplyr" \
              "leaflet" \
              "DT" \
            ), \
            repos="https://packagemanager.rstudio.com/cran/__linux__/focal/2023-07-17"\
          )'


# copy the app directory into the image
COPY ./shiny-app/* /srv/shiny-server/

# make all app files readable (solves issue when dev in Windows, but building in Ubuntu)
RUN chmod -R 755 /srv/shiny-server/

# run app
CMD ["/usr/bin/shiny-server"]