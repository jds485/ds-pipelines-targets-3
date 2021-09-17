
library(targets)
library(tarchetypes)
library(tibble)
suppressPackageStartupMessages(library(dplyr))

options(tidyverse.quiet = TRUE)
tar_option_set(packages = c("tidyverse", "dataRetrieval", "urbnmapr", "rnaturalearth", "cowplot", "lubridate", 'leaflet', 'leafpop', 'htmlwidgets'))

# Load functions needed by targets below
source("1_fetch/src/find_oldest_sites.R")
source("1_fetch/src/get_site_data.R")
source("2_process/src/tally_site_obs.R")
source("2_process/src/summarize_targets.R")
source("3_visualize/src/map_sites.R")
source("3_visualize/src/plot_site_data.R")
source("3_visualize/src/plot_data_coverage.R")
source("3_visualize/src/map_timeseries.R")

# Configuration
states <- c('WI','MN','MI', 'IL', 'IN', 'IA')
#states <- c('WI','MN','MI', 'IN', 'IA')
parameter <- c('00060')

# Target map object for pulling site data
mapped_by_state_targets <- tar_map(
  values = tibble(state_abb = states) %>%
    mutate(state_plot_files = sprintf("3_visualize/out/timeseries_%s.png", state_abb)),
  tar_target(nwis_inventory, get_state_inventory(sites_info = oldest_active_sites, state_abb)),
  tar_target(nwis_data, get_site_data(nwis_inventory, state_abb, parameter)),
  tar_target(tally, tally_site_obs(site_data = nwis_data)),
  tar_target(timeseries_png, plot_site_data(out_file = state_plot_files, site_data = nwis_data, parameter = parameter), format = 'file'),
  names = state_abb,
  unlist = FALSE
)

# Targets
list(
  # Identify oldest sites
  tar_target(oldest_active_sites, find_oldest_sites(states, parameter)),

  # PULL SITE DATA - in object outside of list
  mapped_by_state_targets,

  # Combine tally data
  tar_combine(name = obs_tallies,
              mapped_by_state_targets$tally,
              command = combine_obs_tallies(!!!.x)),

  # Summarize targets
  tar_combine(summary_state_timeseries_csv,
              mapped_by_state_targets$timeseries_png,
              command = summarize_targets('3_visualize/log/summary_state_timeseries.csv', !!!.x),
              format = 'file'),

  # Plot data coverage
  tar_target(coverage_plot_png,
             command = plot_data_coverage(oldest_site_tallies = obs_tallies,
                                          parameter = parameter,
                                          out_file = "3_visualize/out/coverage_plot.png"),
             format = 'file'),

  # Map oldest sites
  tar_target(
    site_map_png,
    map_sites("3_visualize/out/site_map.png", oldest_active_sites),
    format = "file"
  ),

  # Map site timeseries interactively
  tar_target(
    timeseries_map_html,
    command = map_timeseries(site_info = oldest_active_sites,
                             plot_info_csv = summary_state_timeseries_csv,
                             out_file = "3_visualize/out/timeseries_map.html"),
    format = 'file'
  )

)
