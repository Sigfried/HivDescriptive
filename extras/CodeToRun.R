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

library(OhdsiSharing)
library(SqlRender)
library(FeatureExtraction)

library(tidyverse)

# build this package now
library(HivDescriptive)



run <- function() {

  # vertext <- readLines(pipe("./current_version_commit_and_state.sh"))
  # can't run that shell script in Windows. rewriting in R
  # luckily pipe still works

  ver <- readLines(pipe('grep Version DESCRIPTION'))  %>% paste0(collapse = '\n')
  gitcommit <- readLines(pipe('git rev-parse --verify HEAD')) %>% paste0(collapse = '\n')
  gitstatus <- readLines(pipe('git status')) %>% paste0(collapse = '\n')

  vertext <- glue::glue("
{ver}

Current commit {gitcommit}

Current git status
{gitstatus}
")

  write(vertext, "./version.txt")

  #setwd('./HivDescriptive/')
  source('~/secret/conn.R')
  dbms <- "postgresql"
  # user <- Sys.getenv('PGUSER')
  # pw <- Sys.getenv('PGPASSWORD')
  # server <- paste0(Sys.getenv('PGHOST'), '/', Sys.getenv('PGDATABASE'))
  # port <- Sys.getenv('PGPORT')
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



# nice idea, but not using I don't think:
# in order to have the cohort names connected to the cohort ids somewhere in the database:
# create table cohorts2create (cohort_id int, atlas_id int, cohort_name text);
# \copy cohorts2create from '/export/home/goldss/projects/HivDescriptive/inst/settings/CohortsToCreate.csv' with csv header;

# would allow queries like this:

# select name, cohort_id, count(*), count(distinct subject_id)
# from hiv_cohort_table_c ct
# join cohorts2create cc on ct.cohort_definition_id = cc.cohort_id
# group by 1,2 order by 1;

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

