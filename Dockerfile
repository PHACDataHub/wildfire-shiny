# get shiny server and a version of R from the rocker project
FROM rocker/shiny-verse:latest

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
              "DT", \
              "leafgl" \
            ))'

# need to install sf from cran
RUN R -e "install.packages('sf', type = 'source', repos = 'https://cran.r-project.org/')"          

# clean up
RUN rm -rf /tmp/downloaded_packages/ /tmp/*.rds

# Copy shiny app into the Docker image
COPY app /srv/shiny-server/

# Make the ShinyApp available at port 5000
EXPOSE 5000

# Copy shiny app execution file into the Docker image
COPY shiny-server.sh /usr/bin/shiny-server.sh

USER shiny

# run app
CMD ["/usr/bin/shiny-server"]