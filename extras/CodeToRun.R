library(DatabaseConnector)
library(SqlRender)
library(FeatureExtraction)

# from https://github.com/OHDSI/StudyProtocols/blob/master/AlendronateVsRaloxifene/extras/CodeToRun.R
# remove.packages('HivDescriptive')
# setwd("/export/home/goldss/projects/")
# library(devtools)
# install_local('HivDescriptive')

library(HivDescriptive)
#setwd('./HivDescriptive/')

source('~/secret/conn.R')

#VH section
cdmDatabaseSchema <- "onek"
cohortDatabaseSchema <- "onek_results"
cohortTable <- "hiv_descriptive"
outputFolder <- "~/temp/study_results" # c:/temp/study_results"
cohortTable <- "hiv_cohort_table_C"

connectionDetails <- createConnectionDetails(dbms = dbms,
                                             user = user,
                                             password = pw,
                                             server = server,
                                             port = port,
                                             schema = cdmDatabaseSchema)

#convention   resultSchema = cohortDatabaseSchema = workSchema)

HivDescriptive::execute(connectionDetails = connectionDetails,
                        cdmDatabaseSchema = cdmDatabaseSchema,
                        cohortDatabaseSchema = cohortDatabaseSchema,
                        cohortTable = cohortTable,
                        oracleTempSchema = NULL,
                        outputFolder = outputFolder,
                        createCohorts = TRUE,
                        packageResults = TRUE
)



#VH troubleshooting
# oracleTempSchema = NULL
# #disconnect(connection)
# connection <- DatabaseConnector::connect(connectionDetails)
#
# DatabaseConnector::getTableNames(connection,databaseSchema = cdmDatabaseSchema)
#
# DatabaseConnector::getTableNames(connection,databaseSchema = cohortDatabaseSchema)

# not sure what the next line was for. keeping it (commented out) in case it was something we should put back in
#OhdsiRTools::insertEnvironmentSnapshotInPackage(studyp$packageName)