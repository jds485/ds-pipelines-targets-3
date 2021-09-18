summarize_targets <- function(ind_file, timeseries_collection) {
  ind_tbl <- tar_meta(all_of(timeseries_collection)) %>%
    select(tar_name = name, filepath = path, hash = data) %>%
    mutate(filepath = unlist(filepath))

  readr::write_csv(ind_tbl, ind_file)
  return(ind_file)
}
