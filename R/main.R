# Copyright 2018 Observational Health Data Sciences and Informatics
#
# This file is part of HivDescriptive
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.



#' Execute HivDescriptive Study
#'
#' @details
#' This function executes the HivDescriptive Study.
#'
#' @param connectionDetails    An object of type \code{connectionDetails} as created using the
#'                             \code{\link[DatabaseConnector]{createConnectionDetails}} function in the
#'                             DatabaseConnector package.
#' @param cdmDatabaseSchema    Schema name where your patient-level data in OMOP CDM format resides.
#'                             Note that for SQL Server, this should include both the database and
#'                             schema name, for example 'cdm_data.dbo'.
#' @param oracleTempSchema     Should be used in Oracle to specify a schema where the user has write
#'                             priviliges for storing temporary tables.
#' @param tablePrefix          The prefix for the study tables, should be same value used in init()
#' @param outputFolder         Name of local folder to place results; make sure to use forward slashes
#'                             (/). Do not use a folder on a network drive since this greatly impacts
#'                             performance.
#'
#' @examples
#' \dontrun{
#' connectionDetails <- createConnectionDetails(dbms = "postgresql",
#'                                              user = "joe",
#'                                              password = "secret",
#'                                              server = "myserver")
#'
#' execute(connectionDetails,
#'         cdmDatabaseSchema = "cdm_data",
#'         targetDatabaseSchema = "results",
#'         oracleTempSchema = NULL,
#'         tablePrefix = "endo_",
#'         outputFolder = "c:/temp/study_results")
#' }
#'
#' @export
execute <- function(connectionDetails,
                    cdmDatabaseSchema,
                    cohortDatabaseSchema,
                    createCohorts = TRUE,
                    cohortTable = 'hiv_cohort',  #consider removing the prefixes for cohort table
                    oracleTempSchema = NULL,
                    outputFolder,
                    packageResults = TRUE) {
  #1. prepare folder, and create cohorts
  outputFolder <- studyp$outputFolder
	if (!file.exists(outputFolder))
		dir.create(outputFolder, recursive = TRUE)

  #create export folder
  exportFolder <- file.path(outputFolder, "export")
  if (!file.exists(exportFolder))
    dir.create(exportFolder)

  conn <- DatabaseConnector::connect(connectionDetails)
  #TODO create all the cohorts here
  # sql <- SqlRender::loadRenderTranslateSql(sqlFilename = "Male50plus.sql",
  #                                          # Male50plus requires target_cohort_id
  #                                          target_cohort_id = 1,
  #                                          packageName = packageName(),
  #                                          dbms,
  #                                          cdm_database_schema = connp$schema,
  #                                          vocabulary_database_schema = connp$vocab_schema,
  #                                          target_database_schema = connp$results_schema,
  #                                          target_cohort_table = cohortTable)
  #
  # DatabaseConnector::executeSql(conn, sql)
  if (createCohorts) {
    createCohorts(connection = connectionDetails,
                  cdmDatabaseSchema = cdmDatabaseSchema,
                  cohortDatabaseSchema = cohortDatabaseSchema,
                  cohortTable = cohortTable,
                  oracleTempSchema = NULL,
                  outputFolder = outputfolder)
  }
  print("ran createCohorts")
  return()

  #consider removing this later
  outputFile <- file(paste0(outputFolder, '/outputLog.txt'))

	# OhdsiRTools::addDefaultFileLogger(file.path(outputFolder, "log.txt"))

  #2. count it with group by
	# Fetch cohort counts:
	sql <- "SELECT cohort_definition_id, COUNT(*) AS count FROM @cohort_database_schema.@cohort_table GROUP BY cohort_definition_id"
  #	'SELECT COUNT(*) FROM @target_database_schema.@target_cohort_table',
	# target_database_schema=connp$results_schema,
	# target_cohort_table = cohortTable)
  sql <- SqlRender::renderSql(sql,
	                            cohort_database_schema = connp$results_schema,
	                            cohort_table = cohortTable)$sql
	sql <- SqlRender::translateSql(sql, targetDialect = attr(connection, "dbms"))$sql
	counts <- DatabaseConnector::querySql(connection, sql)
	#trying to stick the the style of OHDSI
	names(counts) <- SqlRender::snakeCaseToCamelCase(names(counts))

	#since we are in execute, we don't have the cohortToCreate object so commenting it out
	# counts <- merge(counts, data.frame(cohortDefinitionId = cohortsToCreate$cohortId,
	#                                    cohortName  = cohortsToCreate$name))
	write.csv(counts, file.path(exportFolder, "CohortCounts.csv"))


	if (packageResults) {
	  #OhdsiRTools::logInfo("Packaging results")
	 packageResults(connectionDetails = connectionDetails,
	                 cdmDatabaseSchema = cdmDatabaseSchema,
	                 outputFolder = outputFolder,
	                 minCellCount = minCellCount)
	}

#   #create a a csv file into export folder (with the counts) (pick your design, e.g., one line per cohort
#
# 	#custom age categories (bin thresholds) #forum to Martijn (vignete may not cover it)
#
# 	####################### featureExtraction ################################
#
# 	# new weirdness: createCovariateSettings with params below only results in one covar ()
#
# 	covariateSettings <- createDefaultCovariateSettings()
#
# 	covariateSettings <- createCovariateSettings(
# 	  useDemographicsAge = TRUE
# 	  , useDemographicsRace = TRUE
# 	  , useDemographicsEthnicity = TRUE
# 	  , useDemographicsIndexYear = TRUE
# 	  ,useDemographicsAgeGroup = TRUE
# 	  # useDemographicsIndexMonth = FALSE, useDemographicsPriorObservationTime = FALSE,
# 	  # useDemographicsPostObservationTime = FALSE, useDemographicsTimeInCohort = FALSE,
# 	  # useDemographicsIndexYearMonth = FALSE, useConditionOccurrenceAnyTimePrior = FALSE,
# 	  # useConditionOccurrenceLongTerm = FALSE, useConditionOccurrenceMediumTerm = FALSE,
# 	  # useConditionOccurrenceShortTerm = FALSE, useConditionOccurrencePrimaryInpatientAnyTimePrior = FALSE,
# 	  # useConditionOccurrencePrimaryInpatientLongTerm = FALSE,
# 	  # useConditionOccurrencePrimaryInpatientMediumTerm = FALSE,
# 	  # useConditionOccurrencePrimaryInpatientShortTerm = FALSE,
# 	  # useConditionEraAnyTimePrior = FALSE, useConditionEraLongTerm = FALSE,
# 	  # useConditionEraMediumTerm = FALSE, useConditionEraShortTerm = FALSE,
# 	  # useConditionEraOverlapping = FALSE, useConditionEraStartLongTerm = FALSE,
# 	  # useConditionEraStartMediumTerm = FALSE, useConditionEraStartShortTerm = FALSE,
# 	  , useConditionOccurrenceAnyTimePrior = TRUE
# 	  , useDemographicsGender = TRUE
# 	  , useCharlsonIndex = TRUE
# 	  # , useChads2Vasc = F,  # this one is causing an error:
# 	  #, useDcsi = FALSE
# 	 )
# 	settings2 <- convertPrespecSettingsToDetailedSettings(covariateSettings)
#
#
# 	# dcd <- getDbDefaultCovariateData(conn,
# 	#                           covariateSettings = covariateSettings,
# 	#                           cdmDatabaseSchema = connp$schema,
# 	#                           targetDatabaseSchema = connp$results_schema,
# 	#                           cohortTable = paste0(connp$results_schema, '.', studyp$cohort_table))
# 	#
# 	# function (connection, oracleTempSchema = NULL, cdmDatabaseSchema,
# 	#           cohortTable = "#cohort_person", cohortId = -1, cdmVersion = "5",
# 	#           rowIdField = "subject_id", covariateSettings, targetDatabaseSchema,
# 	#           targetCovariateTable, targetCovariateRefTable, targetAnalysisRefTable,
# 	#           aggregated = FALSE)
#
#
# 	# browser()
# 	covariateData2 <- getDbCovariateData(
# 	                                     connectionDetails = connectionDetails,
# 	                                     # connection = conn,
# 	                                     cdmDatabaseSchema = connp$schema,
# 	                                     cohortDatabaseSchema = connp$results_schema,
# 	                                     cohortTable = cohortTable,
# 	                                     cohortId = 1, #target_cohort_id,
# 	                                     #rowIdField = "subject_id", # sometimes uncommenting this is necessary, but not always
# 	                                     # aggregated = TRUE,
# 	                                     # covariateSettings = covariateSettings
# 	                                     covariateSettings = settings2
# 	                                     # createTable1 requires aggregated = TRUE
# 	                                     # tidyCovariateData requires aggregated = FALSE
# 	   # failing at getDbDefaultCovariateData
# 	   # getDbDefaultCovariateData(conn, covariateSettings = covariateSettings, cdmDatabaseSchema = connp$schema, targetDatabaseSchema = connp$results_schema, cohortTable = "onek_results.HivDescriptive_cohort")
# 	)
# 	summary(covariateData2)
#
#   # # not working: (from http://ohdsi.github.io/FeatureExtraction/articles/UsingFeatureExtraction.html#removing-infrequent-covariates-normalizing-and-removing-redundancy)
# 	# # (worked after setting aggregated = FALSE above)
# 	# tcd <- tidyCovariateData(covariateData2, minFraction = 0.01, normalize = T, removeRedundancy = F)
# 	#
# 	atcd <- aggregateCovariates(covariateData2)
# 	result <- createTable1(atcd)
#
# 	result <- createTable1(covariateData2)
#
# 	result
#
#
# 	querySql(conn, 'SELECT *
#     FROM (
#     SELECT row_id, covariate_id, covariate_value FROM cov_1 UNION ALL
#     SELECT row_id, covariate_id, covariate_value FROM cov_2 UNION ALL
#     SELECT row_id, covariate_id, covariate_value FROM cov_3
#     ) all_covariates;')
#

	DatabaseConnector::disconnect(conn)

	invisible(NULL)
	return(result)
}
  # cut from execute function:
  # if (createCohorts) {
  #   # instantiate cohorts
  #   .createCohorts(connection = conn,
  #                  cdmDatabaseSchema = cdmDatabaseSchema,
  #                  targetDatabaseSchema = targetDatabaseSchema,
  #                  oracleTempSchema = oracleTempSchema,
  #                  cohortTable = paste0(tablePrefix, "cohort"))
  # }
  #
  # pathToCsv <- system.file("settings", "cohorts.csv", package = packageName())
  #
  # cohortsCsv<- read.csv(pathToCsv,stringsAsFactors = FALSE)
  #
  # cohortTable <- paste0(tablePrefix, "cohort")
  #
  # for (i in 1:nrow(cohortsCsv)) {
  #
  #   # Total Counts
  #   OhdsiRTools::logInfo(paste0("Total Counts for cohort: ", cohortsCsv$shortName[i]))
  #
  #   totalCountSql <- SqlRender::loadRenderTranslateSql(sqlFilename = "TotalCount.sql",
  #                                                      packageName = packageName(),
  #                                                      dbms = attr(conn, "dbms"),
  #                                                      cohortId = cohortsCsv$cohortId[i],
  #                                                      target_database_schema = targetDatabaseSchema,
  #                                                      target_cohort_table = cohortTable)
  #   totalCount <- DatabaseConnector::querySql(conn, totalCountSql);
  #
  #   fileName <- file.path(outputFolder, paste0("total_count_", cohortsCsv$shortName[i], ".csv"))
  #   write.csv(totalCount, file = fileName, row.names=FALSE, na="")
  #
  #
  #   # Counts with DE Prior
  #   OhdsiRTools::logInfo(paste0("Persons with DE Prior for cohort: ", cohortsCsv$shortName[i]))
  #
  #   dePriorCountSql <- SqlRender::loadRenderTranslateSql(sqlFilename = "CountWithDEPrior.sql",
  #                                                        packageName = packageName(),
  #                                                        dbms = attr(conn, "dbms"),
  #                                                        CDM_schema = cdmDatabaseSchema,
  #                                                        cohortId = cohortsCsv$cohortId[i],
  #                                                        target_database_schema = targetDatabaseSchema,
  #                                                        target_cohort_table = cohortTable)
  #   dePriorCount <- DatabaseConnector::querySql(conn, dePriorCountSql);
  #
  #   fileName <- file.path(outputFolder, paste0("total_count_", cohortsCsv$shortName[i],"_DE_before_cohort_start.csv"))
  #   write.csv(dePriorCount, file = fileName, row.names=FALSE, na="")
  #
  #   # Counts with CO Prior
  #   OhdsiRTools::logInfo(paste0("Persons with CO Prior for cohort: ", cohortsCsv$shortName[i]))
  #
  #   coPriorCountSql <- SqlRender::loadRenderTranslateSql(sqlFilename = "CountWithCOPrior.sql",
  #                                                        packageName = packageName(),
  #                                                        dbms = attr(conn, "dbms"),
  #                                                        CDM_schema = cdmDatabaseSchema,
  #                                                        cohortId = cohortsCsv$cohortId[i],
  #                                                        target_database_schema = targetDatabaseSchema,
  #                                                        target_cohort_table = cohortTable)
  #   coPriorCount <- DatabaseConnector::querySql(conn, coPriorCountSql);
  #
  #   fileName <- file.path(outputFolder, paste0("total_count_", cohortsCsv$shortName[i],"_CO_before_cohort_start.csv"))
  #   write.csv(coPriorCount, file = fileName, row.names=FALSE, na="")
  #
  #   # Drug Counts, prior to index
  #   OhdsiRTools::logInfo(paste0("Drug Counts prior to index for cohort: ", cohortsCsv$shortName[i]))
  #
  #   drugCountSql <- SqlRender::loadRenderTranslateSql(sqlFilename = "DrugCount.sql",
  #                                                     packageName = packageName(),
  #                                                     dbms = attr(conn, "dbms"),
  #                                                     CDM_schema = cdmDatabaseSchema,
  #                                                     cohortId = cohortsCsv$cohortId[i],
  #                                                     target_database_schema = targetDatabaseSchema,
  #                                                     target_cohort_table = cohortTable)
  #   drugCount <- DatabaseConnector::querySql(conn, drugCountSql);
  #
  #   fileName <- file.path(outputFolder, paste0("drugs_", cohortsCsv$shortName[i], ".csv"))
  #   write.csv(drugCount, file = fileName, row.names=FALSE, na="")
  #
  #   # Condition Counts, prior to index
  #   OhdsiRTools::logInfo(paste0("Condition Counts prior to index for cohort: ", cohortsCsv$shortName[i]))
  #
  #   conditionCountSql <- SqlRender::loadRenderTranslateSql(sqlFilename = "ConditionCount.sql",
  #                                                          packageName = packageName(),
  #                                                          dbms = attr(conn, "dbms"),
  #                                                          CDM_schema = cdmDatabaseSchema,
  #                                                          cohortId = cohortsCsv$cohortId[i],
  #                                                          target_database_schema = targetDatabaseSchema,
  #                                                          target_cohort_table = cohortTable)
  #   conditionCount <- DatabaseConnector::querySql(conn, conditionCountSql);
  #
  #   fileName <- file.path(outputFolder, paste0("conditions_", cohortsCsv$shortName[i], ".csv"))
  #   write.csv(conditionCount, file = fileName, row.names=FALSE, na="")
  #
  #   # Counts with ERVisits, prior to index
  #   OhdsiRTools::logInfo(paste0("Persons with ER Visits prior to index for cohort: ", cohortsCsv$shortName[i]))
  #
  #   erVisitCountSql <- SqlRender::loadRenderTranslateSql(sqlFilename = "ERVisitCount.sql",
  #                                                        packageName = packageName(),
  #                                                        dbms = attr(conn, "dbms"),
  #                                                        CDM_schema = cdmDatabaseSchema,
  #                                                        cohortId = cohortsCsv$cohortId[i],
  #                                                        target_database_schema = targetDatabaseSchema,
  #                                                        target_cohort_table = cohortTable)
  #   erVisitCount <- DatabaseConnector::querySql(conn, erVisitCountSql);
  #
  #   fileName <- file.path(outputFolder, paste0("ER_visits_", cohortsCsv$shortName[i], ".csv"))
  #   write.csv(erVisitCount, file = fileName, row.names=FALSE, na="")
  #
  # }
