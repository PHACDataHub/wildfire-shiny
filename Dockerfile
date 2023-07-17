# get shiny server and a version of R from the rocker project
FROM rocker/shiny:4.3.0

# system libraries
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
    
# grabs pre-compiled binaries from Posit Package Manager
RUN R -e 'install.packages(c(\
              "shiny", \
              "shinydashboard", \
              "shiny.i18n", \
              "maps", \
              "dplyr", \
              "leaflet", \
              "DT" \
            ))'

# need to install sf from cran
RUN R -e "install.packages('sf', type = 'source', repos = 'https://cran.r-project.org/')"          

# copy the app directory into the image
COPY ./shiny-app/ /srv/shiny-server/

# make all app files readable (solves issue when dev in Windows, but building in Ubuntu)
RUN chmod -R 755 /srv/shiny-server/

# listen on port 80 instead of default
RUN sed -i -e 's/\blisten 3838\b/listen 80/g' /etc/shiny-server/shiny-server.conf

# run app
CMD ["/usr/bin/shiny-server"]