library(DatabaseConnector)
library(SqlRender)
library(tidyverse)
library(FeatureExtraction)

source('~/secret/conn.R')

#VH section

cdmDatabaseSchema <- "lhcdatasci"
cohortDatabaseSchema <- "results"
cohortTable <- "hiv_descriptive"
outputFolder <- "/tmp/study_results" # c:/temp/study_results"
cohortTable <- "hiv_cohort_table"

# studyp <- list(
#   tablePrefix = "",
#   outputFolder = outputFolder,
#   packageName = "HivDescriptive"
# )
# studyp$cohort_table = paste0(studyp$tablePrefix, "hiv_cohort_table")
# cohortTable<-studyp$cohort_table

# Warning: init drops the cohort table and creates an empty one
HivDescriptive::init(connectionDetails = connectionDetails,
                     targetDatabaseSchema = cohortDatabaseS_schema)




# use as example now: https://github.com/OHDSI/StudyProtocols/tree/master/KeppraAngioedema


HivDescriptive::execute(connectionDetails = connectionDetails,
                        connp = connp,
                        studyp = studyp,
                        outputFolder = studyp$outputFolder,
                        studyp$tablePrefix,
                        cohortTable = studyp$cohort_table)








# old section


# set your db, server, port, user and password,
readRenviron('./.env')

# studyp: config var for params related to this study and package but not to the db connection
studyp <- list(
  tablePrefix = "HivDescriptive_",
  outputFolder = Sys.getenv('OUTPUT_FOLDER'), # /tmp/study_results
  packageName = "HivDescriptive"
)
studyp$cohort_table = paste0(studyp$tablePrefix, "cohort")


# from https://github.com/OHDSI/StudyProtocols/blob/master/AlendronateVsRaloxifene/extras/CodeToRun.R
# remove.packages('HivDescriptive')
# setwd("/export/home/goldss/projects/")
# library(devtools)
# install_local('HivDescriptive')
#
# library(HivDescriptive)
# setwd('./HivDescriptive/')




# since connectionDetail doesn't accept more than one schema param
#   or other params we need later, store those in 'connp'
# 'connectionDetails' will only be used for  creating connections, not
# for referencing connection-related parameters as has been the convention
# in other DatabaseConnector-based studies
connp <- list(dbms = "postgresql",
              server = paste0(Sys.getenv("PGHOST"),'/',
                            Sys.getenv('PGDATABASE')),
              port = coalesce(na_if(Sys.getenv("PGPORT"), ""), "5432"),
              user = Sys.getenv('PGUSER'),
              password = Sys.getenv('PGPASSWORD'),
              schema = Sys.getenv('CDM_SCHEMA'),
              vocab_schema = Sys.getenv('VOCAB_SCHEMA'),
              results_schema = Sys.getenv('RESULTS_SCHEMA')
)


connectionDetails <- do.call(
  createConnectionDetails,
  connp[c("dbms","server","port","user","password","schema")])
conn <- connect(connectionDetails)

HivDescriptive::init(connectionDetails = connectionDetails,
                   targetDatabaseSchema = connp$results_schema,
                   tablePrefix = studyp$tablePrefix)

# use as example now: https://github.com/OHDSI/StudyProtocols/tree/master/KeppraAngioedema


HivDescriptive::execute(connectionDetails = connectionDetails,
                        connp = connp,
                        studyp = studyp,
                        outputFolder = studyp$outputFolder,
                        studyp$tablePrefix,
                        cohortTable = studyp$cohort_table)



OhdsiRTools::insertEnvironmentSnapshotInPackage(studyp$packageName)