library(DatabaseConnector)
library(SqlRender)
library(FeatureExtraction)

# remove.packages('HivDescriptive')
# setwd("/export/home/goldss/projects/")
# library(devtools)
# install_local('HivDescriptive')
library(HivDescriptive)


run <- function() {
  #setwd('./HivDescriptive/')
  source('~/secret/conn.R')

  cdm_database_schema <- cdmDatabaseSchema <- "onek"
  resultsDatabaseSchema <- cohortDatabaseSchema <- "onek_results"
  #convention:   resultSchema = cohortDatabaseSchema = workSchema (if we need them for copied code)
  # cdmDatabaseSchema <- "mimic2omop"
  # cohortDatabaseSchema <- "mimic2omop_results"
  cohortTable <- "hiv_descriptive"
  outputFolder <- "~/temp/study_results" # c:/temp/study_results"
  cohortTable <- "hiv_cohort_table"

  connectionDetails <- createConnectionDetails(dbms = dbms,
                                               user = user,
                                               password = pw,
                                               server = server,
                                               port = port,
                                               schema = cdmDatabaseSchema)
  connection <- DatabaseConnector::connect(connectionDetails)

  covariates <- HivDescriptive::execute(connectionDetails = connectionDetails,
                                        conn = connection,
                                        cdmDatabaseSchema = cdmDatabaseSchema,
                                        cohortDatabaseSchema = cohortDatabaseSchema,
                                        cohortTable = cohortTable,
                                        oracleTempSchema = NULL,
                                        outputFolder = outputFolder,
                                        createCohorts = TRUE,
                                        createCovariates = FALSE,
                                        packageResults = TRUE,
                                        return = "covariates" # or "conn" or nothing
  )
  return(connection)
}
connection <- run()
DatabaseConnector::disconnect(connection)

# in order to have the cohort names connected to the cohort ids somewhere in the database:
# create table CohortsToCreate (cohortId int, atlasId int, name text);
# \copy CohortsToCreate from '/export/home/goldss/projects/HivDescriptive/inst/settings/CohortsToCreate.csv' with csv header;
# select name, cohortid, count(*), count(distinct subject_id) from hiv_cohort_table_c ct join cohortstocreate cc on ct.cohort_definition_id = cc.cohortid group by 1,2 order by 1;
# +--------------------+----------+-------+-------+
# |        name        | cohortid | count | count |
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