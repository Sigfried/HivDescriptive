#' Create covariate settings and covariates
#'
#' @details
#' This function initializes the HivDescriptive Study tables.
#'
#' @param connection           An object of type \code{connection} as created using the
#'                             \code{\link[DatabaseConnector]{connect}} function in the
#'                             DatabaseConnector package.
#' @param targetDatabaseSchema The schema to contain the study results tables
#'
#' @param tablePrefix          A prefix to add to the study tables
#'
#' @examples
#' \dontrun{
#' connectionDetails <- DatatbaseConnector:: createConnectionDetails(dbms = "postgresql",
#'                                              user = "joe",
#'                                              password = "secret",
#'                                              server = "myserver")
#' conn <- DatabaseConnector::connect(connectionDetails)
#' execute(conn,
#'         targetDatabaseSchema = "studyDB.endoStudy",
#'         ...)
#' }
#'
#' @export
createCovariates <- function(connection,
                             cohorts = c(), # coming from CohortsToCreate.csv
                             cdmDatabaseSchema,
                             vocabularyDatabaseSchema = cdmDatabaseSchema,
                             cohortDatabaseSchema,
                             cohortTable,
                             oracleTempSchema,
                             outputFolder) {
  # copied code from vignette: https://raw.githubusercontent.com/OHDSI/FeatureExtraction/master/inst/doc/CreatingCovariatesUsingCohortAttributes.pdf

  sql <- SqlRender::loadRenderTranslateSql(
    "LengthOfObsCohortAttr.sql",
    packageName = "HivDescriptive",
    dbms = attr(connection, "dbms"),
    cdm_database_schema = cdmDatabaseSchema,
    cohort_database_schema = cohortDatabaseSchema,
    cohort_table = "hiv_cohort_table",
    cohort_attribute_table = "loo_cohort_attr",
    attribute_definition_table = "loo_attr_def",
    cohort_definition_ids = cohorts$cohortId)

  cat(sql)
  browser()

  executeSql(connection, sql)


  covariateSettings <- createCovariateSettings(useDemographicsGender = TRUE,
                                               useDemographicsAgeGroup = TRUE,
                                               useDemographicsRace = TRUE,
                                               useDemographicsEthnicity = TRUE,
                                               useConditionOccurrenceAnyTimePrior = TRUE,
                                               useDrugExposureAnyTimePrior = TRUE,
                                               useChads2Vasc = TRUE,
                                               useMeasurementAnyTimePrior = TRUE
  )

  looCovSet <- createCohortAttrCovariateSettings(attrDatabaseSchema = cohortDatabaseSchema,
                                                 cohortAttrTable = "loo_cohort_attr",
                                                 attrDefinitionTable = "loo_attr_def")

  covariateSettingsList <- list(covariateSettings, looCovSet)

  covariates <- getDbCovariateData(connection = connection,
                                   cdmDatabaseSchema = cdmDatabaseSchema,
                                   cohortDatabaseSchema = resultsDatabaseSchema,
                                   cohortTable = "hiv_cohort_table",
                                   # cohortId = 1769961,
                                   covariateSettings = covariateSettingsList)
  return(covariates)

  #
  # covariateSettings <- createDefaultCovariateSettings()
  #
  # covariateData <- getDbCovariateData(#connectionDetails = connectionDetails,
  #   connection = conn,
  #   cdmDatabaseSchema = cdmDatabaseSchema,
  #   cohortDatabaseSchema = resultsDatabaseSchema,
  #   cohortTable = cohortTable,
  #   cohortId = 1769961,
  #   rowIdField = "subject_id",
  #   covariateSettings = covariateSettings)
  # covariateData2 <- aggregateCovariates(covariateData)
  #
  # # summary(covariateData)
  # # covariateData$covariates
  # # saveCovariateData(covariateData, "covariates")
  #
  # tidyCovariates <- tidyCovariateData(covariateData,
  #                                     minFraction = 0.001,
  #                                     normalize = TRUE,
  #                                     removeRedundancy = TRUE)
  #
  # result <- createTable1(covariateData2)
  # print(result, row.names = FALSE, right = FALSE)
  #
  # result <- createTable1(covariateData2, specifications = getDefaultTable1Specifications()[1:5,])
  #
  # for (i in 1:nrow(cohorts)) {
  #   writeLines(paste("Creating covariates for cohort", cohortsToCreate$name[i]))
  #   sql <- SqlRender::loadRenderTranslateSql(sqlFilename = paste0(cohorts$name[i], ".sql"),
  #                                            packageName = "HivDescriptive",
  #                                            dbms = attr(connection, "dbms"),
  #                                            oracleTempSchema = oracleTempSchema,
  #                                            cdm_database_schema = cdmDatabaseSchema,
  #                                            vocabulary_database_schema = vocabularyDatabaseSchema,
  #
  #                                            target_database_schema = cohortDatabaseSchema,
  #                                            target_cohort_table = cohortTable,
  #                                            target_cohort_id = cohorts$cohortId[i])
  #   DatabaseConnector::executeSql(connection, sql)
  # }




  # Instantiate cohorts:

  # Fetch cohort counts:
  # sql <- "SELECT cohort_definition_id, COUNT(*) AS count FROM @cohort_database_schema.@cohort_table GROUP BY cohort_definition_id"
  # sql <- SqlRender::render(sql,
  #                          cohort_database_schema = cohortDatabaseSchema,
  #                          cohort_table = cohortTable)
  # sql <- SqlRender::translate(sql, targetDialect = attr(connection, "dbms"))
  # counts <- DatabaseConnector::querySql(connection, sql)
  # names(counts) <- SqlRender::snakeCaseToCamelCase(names(counts))
  # counts <- merge(counts, data.frame(cohortDefinitionId = cohortsToCreate$cohortId,
  #                                    cohortName  = cohortsToCreate$name))
  # write.csv(counts, file.path(outputFolder, "CohortCounts.csv"), row.names = FALSE)
  # writeLines(paste0("Wrote cohort counts to ", outputFolder,"/CohortCounts.csv"))
}

