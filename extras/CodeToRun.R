library(DatabaseConnector)
library(SqlRender)
library(tidyverse)
library(FeatureExtraction)
library(HivDescriptive)

# set your db, server, port, user and password,
readRenviron('./.env')

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

# for params related to this study and package but not to the db connection,
# use another config variable: studyp:
studyp <- list(
  tablePrefix = "HivDescriptive_",
  outputFolder = getwd(), # Sys.getenv('OUTPUT_FOLDER') # /tmp/study_results
  packageName = "HivDescriptive"
)
studyp$cohort_table = paste0(studyp$tablePrefix, "cohort")

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
                        outputFolder = outputFolder,
                        tablePrefix,
                        cohortTable = studyp$cohort_table)



