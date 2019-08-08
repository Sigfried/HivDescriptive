

# example of site_info:
# site_info <- tibble::tribble(
#   ~fname, ~sitename, ~sitename_in_report,
#   "eunomia.zip", "eunomia", "Site 1234",
#   "onek.zip", "onek", "Site 5678"
# )


unzip_and_compare <- function(zipdir = zipdir,
                              unzipdir = unzipdir,
                              site_info = site_info,
                              outputdir = outputdir,
                              ignore_extra_zipfiles = TRUE,
                              ignore_missing_zipfiles = TRUE)
{
  zipfiles <- list.files(zipdir)
  zipdir.only <- setdiff(zipfiles, site_info$fname)
  if (!ignore_extra_zipfiles & length(zipdir.only)) {
    stop(paste0("zipdir <", zipdir, "> contains files missing from site_info: "), paste(zipdir.only, collapse = ","))
  }
  site_info.only <- setdiff(site_info$fname, zipfiles)
  if (!ignore_missing_zipfiles & length(site_info.only)) {
    stop(paste0("site_info contains files missing from zipdir <", zipdir, ": "), paste(site_info.only, collapse = ","))
  }

  # add fpath = paths to zipfiles
  #     exdir = directories to unzip into
  site_info <- site_info %>%
    mutate(fpath = file.path(zipdir, fname),
           exdir = file.path(unzipdir, sitename_in_report) %>% stringr::str_replace_all(" ","_"))

  # unzip each zipfile
  site_info %>%
    select(fpath, exdir) %>%
    pmap(~unzip(zipfile = ..1, exdir = ..2))

  # add ccpath = paths to CohortCount.cav files from all the unzip directories
  site_info <- site_info %>%
    mutate(ccpath = file.path(exdir, "CohortCounts.csv"))

  cnts <- site_info %>%
    select(ccpath, site = sitename_in_report) %>%
    pmap(function(ccpath, site) { cnts <- read_csv(ccpath); cnts$site = site; cnts}) %>%
    bind_rows() %>%
    mutate(cohort = paste0(cohortName, ":", cohortDefinitionId))


  print("so far so good")
}

unzip_site_files <- function(fname, sitename_in_report, zipdir, unzipdir) {
  exdir <- file.path(unzipdir, sitename_in_report) %>% stringr::str_replace_all(" ","_")
  utils::unzip(file.path(zipdir, fname),
               exdir = exdir,
               setTimes = TRUE)
  return(list(sitename_in_report = sitename_in_report, exdir = exdir))
}

get_counts <- function(sitename_in_report, exdir) {
  ccfname <- "CohortCounts.csv"
  cc <- read_csv(file.path(exdir, ccfname))
  cc$site <- sitename_in_report
  return(list(site = sitename_in_report, cc = cc))
}
