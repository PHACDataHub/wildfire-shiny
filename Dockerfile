# get shiny server plus tidyverse packages image
FROM rocker/shiny-verse:latest

RUN mkdir -p /opt/services/shinyapp/src
WORKDIR /opt/services/shinyapp/src/
# system libraries
# Try to only install system libraries you actually need
# Package Manager is a good resource to help discover system deps
RUN apt-get update && apt-get install -y \
    libcurl4-gnutls-dev \
    libssl-dev

# add add-apt-repository capability
RUN apt -y install software-properties-common dirmngr apt-transport-https lsb-release ca-certificates

# Add the UbuntuGIS Unstable for proper depencies for `sf` R package
RUN add-apt-repository ppa:ubuntugis/ubuntugis-unstable

# dependencies for `sf` R package
RUN apt-get update && apt-get install -y \
    libudunits2-dev \
    libgdal-dev \
    libgeos-dev \
    libproj-dev 

# install R packages required 
# Change the packages list to suit your needs
# grabs pre-compiled binaries from Posit Package Manager
RUN R -e 'install.packages(c(\
            "shiny", \
            "shinydashboard", \
            "shiny.i18n", \
            "maps", \
            "dplyr", \
            "leaflet", \
            "DT", \
            "leafgl", \
            "shinydashboardPlus" ,\
            "fresh", \
            "shinyWidgets" \
        ))'

# need to install sf from cran
RUN R -e "install.packages('sf', type = 'source', repos = 'https://cran.r-project.org/')"

# clean up
RUN rm -rf /tmp/downloaded_packages/ /tmp/*.rds

COPY . /opt/services/shinyapp/src

EXPOSE 8080
CMD R -e "shiny::runApp(appDir='shinyapp', port=8080, host='0.0.0.0')"