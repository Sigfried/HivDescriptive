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
                             exportFolder,
                             covarOutput = 'big.data.frame' # or 'table1'
                             ) {
  # copied code from vignette: https://raw.githubusercontent.com/OHDSI/FeatureExtraction/master/inst/doc/CreatingCovariatesUsingCohortAttributes.pdf

  # sql <- SqlRender::loadRenderTranslateSql(
  #   "LengthOfObsCohortAttr.sql",
  #   packageName = "HivDescriptive",
  #   dbms = attr(connection, "dbms"),
  #   cdm_database_schema = cdmDatabaseSchema,
  #   cohort_database_schema = cohortDatabaseSchema,
  #   cohort_table = "hiv_cohort_table",
  #   cohort_attribute_table = "loo_cohort_attr",
  #   attribute_definition_table = "loo_attr_def",
  #   cohort_definition_ids = cohorts$cohortId)
  # cat(sql)
  # executeSql(connection, sql)
  covariateSettings <- createCovariateSettings(useDemographicsGender = TRUE,
                                               useDemographicsAgeGroup = TRUE,
                                               useDemographicsRace = TRUE,
                                               useDemographicsEthnicity = TRUE,
                                               useConditionOccurrenceAnyTimePrior = TRUE,
                                               useDrugExposureAnyTimePrior = TRUE,
                                               useChads2Vasc = TRUE,
                                               useMeasurementAnyTimePrior = TRUE
  )

  # looCovSet <- createCohortAttrCovariateSettings(attrDatabaseSchema = cohortDatabaseSchema,
  #                                                cohortAttrTable = "loo_cohort_attr",
  #                                                attrDefinitionTable = "loo_attr_def")
  #
  # covariateSettingsList <- list(covariateSettings, looCovSet)
  # browser()

  # result = NULL
  for (i in 1:nrow(cohorts)) {
    writeLines(paste("Creating covariates for cohort", cohorts$name[i]))
    covariates <- getDbCovariateData(connection = connection,
                                     cdmDatabaseSchema = cdmDatabaseSchema,
                                     cohortDatabaseSchema = cohortDatabaseSchema,
                                     cohortTable = "hiv_cohort_table",
                                     cohortId = cohorts$cohortId[i],
                                     # covariateSettings = covariateSettingsList
                                     covariateSettings = covariateSettings
    )
    # browser()

    if (covariates$metaData$populationSize) {
      aggcovariates <- aggregateCovariates(covariates)

      covariates$covariatesContinuous %>% ff::as.ram() -> cvcont
      covariates$covariateRef %>% ff::as.ram() -> cvref
      covariates$covariates %>% ff::as.ram() -> cvs
      covariates$analysisRef %>% ff::as.ram() -> aref

      aggcovariates$covariatesContinuous %>% ff::as.ram() -> acvcont
      aggcovariates$covariateRef %>% ff::as.ram() -> acvref
      aggcovariates$covariates %>% ff::as.ram() -> acvs
      aggcovariates$analysisRef %>% ff::as.ram() -> aaref
      aggcovariates$covariatesContinuous %>% ff::as.ram() -> acvc

      result <- NULL
      if (covarOutput == 'big.data.frame') {
        result <-
          acvs %>%
          left_join(acvref) %>%
          left_join(aaref) %>%
          group_by(analysisId) %>%
          top_n(10, sumValue) %>% arrange(analysisName, -sumValue)
          # full_join(acvc)
      } else if (covarOutput == 'table1') {
        result <- createTable1(aggcovariates,
                               specifications = getDefaultTable1Specifications(),
                               output = "one column")
      } else {
        warning(paste0('unknown covarOutput type: ', covarOutput))
      }
      # result$cohortId <- cohorts$cohortId[[i]]
      # result$cohortName <- toString(cohorts$name[[i]])
      fname <- paste0("covariates.", cohorts$cohortId[[i]], ".", cohorts$name[[i]], ".csv")
      fpath <- file.path(exportFolder, fname)
      write.csv(result, fpath, row.names = FALSE)

      writeLines(paste0("Wrote covariates to ", exportFolder,"/", fname))

      # browser()

      # if( is.null(result)) {
      #   result <- cresult
      # } else {
      #   if (ncol(result) != ncol(cresult)) {
      #     browser()
      #   }
      #   result <- rbind(result, cresult)
      # }
    } else{
      writeLines(paste0('0 population in ', cohorts$name[[i]]))
    }
  }
}
# return(result)
    # # Fetch cohort counts:
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

mrg <- function(df1, df2) {
  return(full_join(ff::as.ram(df1), ff::as.ram(df2)))
}

