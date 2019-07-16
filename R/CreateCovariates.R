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
                             covariateSettings = basicCovariateSettings(),
                             cdmDatabaseSchema,
                             vocabularyDatabaseSchema = cdmDatabaseSchema,
                             cohortDatabaseSchema,
                             cohortTable,
                             oracleTempSchema,
                             exportFolder,
                             covarOutput = c("table1", "big.data.frame")
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
  covariateSettings <- maxCovariateSettings()

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

      # covariates$covariatesContinuous %>% ff::as.ram() -> cvcont
      # covariates$covariateRef %>% ff::as.ram() -> cvref
      # covariates$covariates %>% ff::as.ram() -> cvs
      # covariates$analysisRef %>% ff::as.ram() -> aref

      aggcovariates$covariatesContinuous %>% ff::as.ram() -> acvcont
      aggcovariates$covariateRef %>% ff::as.ram() -> acvref
      aggcovariates$covariates %>% ff::as.ram() -> acvs
      aggcovariates$analysisRef %>% ff::as.ram() -> aaref
      aggcovariates$covariatesContinuous %>% ff::as.ram() -> acvc

      # if taking more covars, only those with cnt >= 11


      result <- NULL
      if ('big.data.frame' %in% covarOutput) {
        result <-
          acvs %>%
          dplyr::left_join(acvref) %>%
          dplyr::left_join(aaref) %>%
          dplyr::group_by(analysisId) %>%
          dplyr::top_n(10, sumValue) %>% dplyr::arrange(analysisName, -sumValue)
        fname <- paste0("covariates.", cohorts$cohortId[[i]], ".", cohorts$name[[i]], ".csv")
        fpath <- file.path(exportFolder, fname)
        write.csv(result, fpath, row.names = FALSE)

        result <-
          acvc %>%
          dplyr::left_join(acvref) %>%
          dplyr::left_join(aaref) %>%
          dplyr::group_by(analysisId)
        fname <- paste0("covariates.continuous.", cohorts$cohortId[[i]], ".", cohorts$name[[i]], ".csv")
        fpath <- file.path(exportFolder, fname)
        write.csv(result, fpath, row.names = FALSE)
      }
      if ('table1' %in% covarOutput) {
        result <- createTable1(aggcovariates,
                               specifications = getDefaultTable1Specifications(),
                               output = "one column")
        fname <- paste0("table1.", cohorts$cohortId[[i]], ".", cohorts$name[[i]], ".csv")
        fpath <- file.path(exportFolder, fname)
        write.csv(result, fpath, row.names = FALSE)
      }
      # result$cohortId <- cohorts$cohortId[[i]]
      # result$cohortName <- toString(cohorts$name[[i]])

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

basicCovariateSettings <- function() {
  return(createCovariateSettings(
    useDemographicsGender = TRUE,
    useDemographicsAgeGroup = TRUE,
    useDemographicsRace = TRUE,
    useDemographicsEthnicity = TRUE,
    useConditionOccurrenceAnyTimePrior = TRUE,
    useDrugExposureAnyTimePrior = TRUE,
    useChads2Vasc = TRUE,
    useMeasurementAnyTimePrior = TRUE))
}
maxCovariateSettings <- function() {
  return(createCovariateSettings(
    useDemographicsGender = TRUE,
    useDemographicsAge = TRUE,
    useDemographicsAgeGroup = TRUE,
    useDemographicsRace = TRUE,
    useDemographicsEthnicity = TRUE,
    useDemographicsIndexYear = TRUE,
    useDemographicsIndexMonth = TRUE,
    useDemographicsPriorObservationTime = TRUE,
    useDemographicsPostObservationTime = TRUE,
    useDemographicsTimeInCohort = TRUE,
    useDemographicsIndexYearMonth = TRUE,
    useConditionOccurrenceAnyTimePrior = TRUE,
    useConditionOccurrenceLongTerm = TRUE,
    useConditionOccurrenceMediumTerm = TRUE,
    useConditionOccurrenceShortTerm = TRUE,
    useConditionOccurrencePrimaryInpatientAnyTimePrior = TRUE,
    useConditionOccurrencePrimaryInpatientLongTerm = TRUE,
    useConditionOccurrencePrimaryInpatientMediumTerm = TRUE,
    useConditionOccurrencePrimaryInpatientShortTerm = TRUE,
    useConditionEraAnyTimePrior = TRUE,
    useConditionEraLongTerm = TRUE,
    useConditionEraMediumTerm = TRUE,
    useConditionEraShortTerm = TRUE,
    useConditionEraOverlapping = TRUE,
    useConditionEraStartLongTerm = TRUE,
    useConditionEraStartMediumTerm = TRUE,
    useConditionEraStartShortTerm = TRUE,
    useConditionGroupEraAnyTimePrior = TRUE,
    useConditionGroupEraLongTerm = TRUE,
    useConditionGroupEraMediumTerm = TRUE,
    useConditionGroupEraShortTerm = TRUE,
    useConditionGroupEraOverlapping = TRUE,
    useConditionGroupEraStartLongTerm = TRUE,
    useConditionGroupEraStartMediumTerm = TRUE,
    useConditionGroupEraStartShortTerm = TRUE,
    useDrugExposureAnyTimePrior = TRUE,
    useDrugExposureLongTerm = TRUE,
    useDrugExposureMediumTerm = TRUE,
    useDrugExposureShortTerm = TRUE,
    useDrugEraAnyTimePrior = TRUE,
    useDrugEraLongTerm = TRUE,
    useDrugEraMediumTerm = TRUE,
    useDrugEraShortTerm = TRUE,
    useDrugEraOverlapping = TRUE,
    useDrugEraStartLongTerm = TRUE,
    useDrugEraStartMediumTerm = TRUE,
    useDrugEraStartShortTerm = TRUE,
    useDrugGroupEraAnyTimePrior = TRUE,
    useDrugGroupEraLongTerm = TRUE,
    useDrugGroupEraMediumTerm = TRUE,
    useDrugGroupEraShortTerm = TRUE,
    useDrugGroupEraOverlapping = TRUE,
    useDrugGroupEraStartLongTerm = TRUE,
    useDrugGroupEraStartMediumTerm = TRUE,
    useDrugGroupEraStartShortTerm = TRUE,
    useProcedureOccurrenceAnyTimePrior = TRUE,
    useProcedureOccurrenceLongTerm = TRUE,
    useProcedureOccurrenceMediumTerm = TRUE,
    useProcedureOccurrenceShortTerm = TRUE,
    useDeviceExposureAnyTimePrior = TRUE,
    useDeviceExposureLongTerm = TRUE,
    useDeviceExposureMediumTerm = TRUE,
    useDeviceExposureShortTerm = TRUE,
    useMeasurementAnyTimePrior = TRUE,
    useMeasurementLongTerm = TRUE,
    useMeasurementMediumTerm = TRUE,
    useMeasurementShortTerm = TRUE,
    useMeasurementValueAnyTimePrior = TRUE,
    useMeasurementValueLongTerm = TRUE,
    useMeasurementValueMediumTerm = TRUE,
    useMeasurementValueShortTerm = TRUE,
    useMeasurementRangeGroupAnyTimePrior = TRUE,
    useMeasurementRangeGroupLongTerm = TRUE,
    useMeasurementRangeGroupMediumTerm = TRUE,
    useMeasurementRangeGroupShortTerm = TRUE,
    useObservationAnyTimePrior = TRUE,
    useObservationLongTerm = TRUE,
    useObservationMediumTerm = TRUE,
    useObservationShortTerm = TRUE,
    useCharlsonIndex = TRUE,
    useDcsi = TRUE,
    useChads2 = TRUE,
    useChads2Vasc = TRUE,
    useHfrs = TRUE,
    useDistinctConditionCountLongTerm = TRUE,
    useDistinctConditionCountMediumTerm = TRUE,
    useDistinctConditionCountShortTerm = TRUE,
    useDistinctIngredientCountLongTerm = TRUE,
    useDistinctIngredientCountMediumTerm = TRUE,
    useDistinctIngredientCountShortTerm = TRUE,
    useDistinctProcedureCountLongTerm = TRUE,
    useDistinctProcedureCountMediumTerm = TRUE,
    useDistinctProcedureCountShortTerm = TRUE,
    useDistinctMeasurementCountLongTerm = TRUE,
    useDistinctMeasurementCountMediumTerm = TRUE,
    useDistinctMeasurementCountShortTerm = TRUE,
    useDistinctObservationCountLongTerm = TRUE,
    useDistinctObservationCountMediumTerm = TRUE,
    useDistinctObservationCountShortTerm = TRUE,
    useVisitCountLongTerm = TRUE,
    useVisitCountMediumTerm = TRUE,
    useVisitCountShortTerm = TRUE,
    useVisitConceptCountLongTerm = TRUE,
    useVisitConceptCountMediumTerm = TRUE,
    useVisitConceptCountShortTerm = TRUE,
    longTermStartDays = -365,
    mediumTermStartDays = -180,
    shortTermStartDays = -30,
    endDays = 0))
}
