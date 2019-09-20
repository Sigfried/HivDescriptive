library(tidyverse)

# central processing

# need cohorts that include patients from both sites:
# select array_agg(condition_concept_id)
# from (
#   select co1.condition_concept_id,
#           c.concept_name,
#           count(distinct co1.person_id),
#           count(distinct co2.person_id)
#   from onek.condition_occurrence co1
#   inner join eunomia.condition_occurrence co2 on co1.condition_concept_id = co2.condition_concept_id
#   inner join onek.concept c on co1.condition_concept_id = c.concept_id
#   group by 1,2
#   order by count(distinct co1.person_id) + count(distinct co2.person_id) desc
#   limit 20) x

# 80180,260139,372328,28060,81151,257012,378001,78272,313217,317576,192671,439777,140673,30753,80502,81893,195588,255848,378419,440086

# "/export/home/goldss/temp/study_results_onek_2019-08-07_07:04:37/export/StudyResults.zip"
# "/export/home/goldss/temp/study_results_eunomia_2019-08-07_07:04:02/export/StudyResults.zip"
# temp cp study_results_eunomia_2019-08-07_07:04:02/export/StudyResults.zip zipfiles/eunomia.zip
# temp cp study_results_onek_2019-08-07_07:04:37/export/StudyResults.zip zipfiles/onek.zip

zipdir <- "/export/home/goldss/temp/zipfiles"
unzipdir <- "/export/home/goldss/temp/unzipfiles"
outputdir <- "/export/home/goldss/temp/central_processing_output"

unlink(unzipdir, recursive = TRUE)
unlink(outputdir, recursive = TRUE)
dir.create(outputdir, recursive = TRUE)

site_info <- tibble::tribble(
  ~fname, ~sitename, ~sitename_in_report,
  "eunomia.zip", "eunomia", "Site 1234x",
  "onek.zip", "onek", "Site 5678"
  # , "junk.zip", "junk", "Junk Site"
  )


results <- HivDescriptive::unzip_and_compare(
  zipdir = zipdir,
  unzipdir = unzipdir,
  site_info = site_info,
  outputdir = outputdir
  # , ignore_extra_zipfiles = FALSE,
  # , ignore_missing_zipfiles = FALSE
  )

imap(results, function(res, name) {
  write_csv(res, file.path(outputdir, paste0(name,".long.csv")))
  write_csv(res %>% spread(site, count), file.path(outputdir, paste0(name,".by_site.csv")))
  write_csv(res %>% spread(cohort, count), file.path(outputdir, paste0(name,".by_cohort.csv")))
})

