library(SqlRender)

# needed this for windows install
# Sys.setenv(JAVA_HOME = "C:/Program Files/Java/jre1.8.0_221")
# devtools::install_git('https://github.com/OHDSI/DatabaseConnector', ref = 'master', INSTALL_opts=c("--no-multiarch"))
# devtools::install_git('https://github.com/OHDSI/FeatureExtraction', ref = 'master', INSTALL_opts=c("--no-multiarch")) # needed this to load develop branch, but master is updated now
# install.packages("xml2")
# install.packages("digest")
# devtools::install_git('https://github.com/OHDSI/ohdsiSharing', ref = 'master', INSTALL_opts=c("--no-multiarch"))

# needed the following when having to add some debugging code to FeatureExtraction
# cloned from git, then:
# devtools::install_local("../FeatureExtraction", source = TRUE, ref = "develop", force = TRUE)

library(FeatureExtraction)

library(tidyverse)

# build this package now
library(HivDescriptive)



run <- function() {

  vertext <- readLines(pipe("./current_version_commit_and_state.sh"))
  write(vertext, "./version.txt")

  #setwd('./HivDescriptive/')
  source('~/secret/conn.R')
  dbms <- "postgresql"
  user <- Sys.getenv('PGUSER')
  pw <- Sys.getenv('PGPASSWORD')
  server <- paste0(Sys.getenv('PGHOST'), '/', Sys.getenv('PGDATABASE'))
  port <- Sys.getenv('PGPORT')
  cdm_database_schema <- cdmDatabaseSchema <- "onek"
  resultsDatabaseSchema <- cohortDatabaseSchema <- "onek_results"


  min_cell_count = 5 # SHOULD BE 11!! 5 for now for onek CDM@
  top_n_meds = 10

  # cdm_database_schema <- cdmDatabaseSchema <- "eunomia"
  # resultsDatabaseSchema <- cohortDatabaseSchema <- "eunomia_results"

  # cdmDatabaseSchema <- "mimic2omop"
  # cohortDatabaseSchema <- "mimic2omop_results"

  #convention:   resultSchema = cohortDatabaseSchema = workSchema (if we need them for copied code)
  cohortTable <- "hiv_cohort_table"

  outputFolder <- "~/temp/study_results" # c:/temp/study_results"
  if (TRUE) {  #

  }
  outputFolder <-
    paste(outputFolder, cdm_database_schema, Sys.time()) %>%
    stringr::str_replace_all(" ","_") %>%
    stringr::str_replace_all(":","-") # windows paths can't include :
  unlink(outputFolder, recursive = TRUE)

  connectionDetails <- createConnectionDetails(dbms = dbms,
                                               user = user,
                                               password = pw,
                                               server = server,
                                               port = port,
                                               schema = cdmDatabaseSchema)
  connection <- DatabaseConnector::connect(connectionDetails)

  # covariates <-
  HivDescriptive::execute(connectionDetails = connectionDetails,
                                        conn = connection,
                                        cdmDatabaseSchema = cdmDatabaseSchema,
                                        cohortDatabaseSchema = cohortDatabaseSchema,
                                        cohortTable = cohortTable,
                                        oracleTempSchema = NULL,
                                        outputFolder = outputFolder,
                                        createCohorts = TRUE,
                                        createCovariates = TRUE,
                                        # covariateSettings = HivDescriptive::maxCovariateSettings(),
                                        covariateSettings = HivDescriptive::basicCovariateSettings(),
                                        min_cell_count = min_cell_count,
                                        top_n_meds = top_n_meds,
                                        covarOutput = c("table1", "big.data.frame"),
                                        packageResults = TRUE
                                        # return = "covariates" # or "conn" or nothing
  )
  return(connection)
}
connection <- run()
DatabaseConnector::disconnect(connection)



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


cp_compare_results <- unzip_and_compare(
  zipdir = zipdir,
  unzipdir = unzipdir,
  site_info = site_info,
  outputdir = outputdir
  # , ignore_extra_zipfiles = FALSE,
  # , ignore_missing_zipfiles = FALSE
  )



# in order to have the cohort names connected to the cohort ids somewhere in the database:
# create table CohortsToCreate (cohort_id int, atlas_id int, cohort_name text);
# \copy CohortsToCreate from '/export/home/goldss/projects/HivDescriptive/inst/settings/CohortsToCreate.csv' with csv header;
# select name, cohort_id, count(*), count(distinct subject_id) from hiv_cohort_table_c ct join cohortstocreate cc on ct.cohort_definition_id = cc.cohort_id group by 1,2 order by 1;
# +--------------------+----------+-------+-------+
# | cohort_name        | cohort_id| count | count |
# +--------------------+----------+-------+-------+
# | AcuteStroke        |  1769043 |    88 |    44 |
# | AtypicalFF         |   100795 |    26 |    13 |
# | HIV_by_1_SNOMED_Dx |  1770614 |    78 |    39 |
# | HIV_Patient        |  1769440 |    78 |    39 |
# | Male50plus         |  1769961 |   916 |   458 |
# | NoHipVertFx        |   100792 |    32 |    16 |
# | OsteonecrosisOfJaw |   100793 |    44 |    22 |
# | Thromboembolism    |  1769024 |   440 |   220 |
# +--------------------+----------+-------+-------+


# getTableNames(conn, cohortDatabaseSchema)


# write this into the export folder and tag release!!


# VH troubleshooting
# oracleTempSchema = NULL
# #disconnect(connection)
# connection <- DatabaseConnector::connect(connectionDetails)
#
# DatabaseConnector::getTableNames(connection,databaseSchema = cdmDatabaseSchema)
#
# DatabaseConnector::getTableNames(connection,databaseSchema = cohortDatabaseSchema)

# not sure what the next line was for. keeping it (commented out) in case it was something we should put back in
#OhdsiRTools::insertEnvironmentSnapshotInPackage(studyp$packageName)