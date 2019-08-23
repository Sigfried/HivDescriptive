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
                             min_cell_count = 5,
                             cdmDatabaseSchema,
                             vocabularyDatabaseSchema = cdmDatabaseSchema,
                             cohortDatabaseSchema,
                             cohortTable,
                             oracleTempSchema,
                             exportFolder,
                             covarOutput = c("table1", "big.data.frame")
                             ) {

  looCovSet <- createLooCovariateSettings()

  covariateSettingsList <- list(covariateSettings, looCovSet)
    for (i in 1:nrow(cohorts)) {
    # writeLines(paste("Creating covariates for cohort", cohorts$name[i]))
    covariates <- getDbCovariateData(connection = connection,
                                     cdmDatabaseSchema = cdmDatabaseSchema,
                                     cohortDatabaseSchema = cohortDatabaseSchema,
                                     cohortTable = cohortTable,
                                     cohortId = cohorts$cohortId[i],
                                     covariateSettings = covariateSettingsList,
                                     aggregated = FALSE
    )
    if (covariates$metaData$populationSize) {
      aggcovariates <- aggregateCovariates(covariates)

      # covariates$covariatesContinuous %>% ff::as.ram() -> cvcont
      # covariates$covariateRef %>% ff::as.ram() -> cvref
      # covariates$covariates %>% ff::as.ram() -> cvs
      # covariates$analysisRef %>% ff::as.ram() -> aref

      aggcovariates$covariateRef %>% ff::as.ram() -> acvref
      aggcovariates$covariates %>% ff::as.ram() -> acvs
      aggcovariates$analysisRef %>% ff::as.ram() -> aaref
      aggcovariates$covariatesContinuous %>% ff::as.ram() -> acvc

      # if taking more covars, only those with cnt >= 11


      result <- NULL
      if ('big.data.frame' %in% covarOutput) {
        result <-
          acvs %>%
          filter(is.numeric(sumValue) & sumValue >= min_cell_count) %>%
          dplyr::left_join(acvref) %>%
          dplyr::left_join(aaref) %>%
          dplyr::group_by(analysisId) %>%
          dplyr::top_n(10, sumValue) %>% dplyr::arrange(analysisName, -sumValue)
        fname <- paste0("covariates.", cohorts$cohortId[[i]], ".", cohorts$name[[i]], ".csv")
        fpath <- file.path(exportFolder, fname)
        write.csv(result, fpath, row.names = FALSE)

        result <-
          acvc %>%
          filter(is.numeric(countValue) & countValue >= min_cell_count) %>%
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

createLooCovariateSettings <- function(useLengthOfObs = TRUE) {
  covariateSettings <- list(useLengthOfObs = useLengthOfObs)
  attr(covariateSettings, "fun") <- "getDbLooCovariateData"
  class(covariateSettings) <- "covariateSettings"
  return(covariateSettings)
}

getDbLooCovariateData <- function(connection,
                                  oracleTempSchema = NULL,
                                  cdmDatabaseSchema,
                                  cohortTable = "#cohort_person",
                                  cohortId = -1,
                                  cdmVersion = "5",
                                  rowIdField = "subject_id",
                                  covariateSettings,
                                  aggregated = FALSE) {
  writeLines("Constructing length of observation covariates")
  if (covariateSettings$useLengthOfObs == FALSE) {
    return(NULL)
  }
  if (aggregated)
    stop("Aggregation not supported")
  # Some SQL to construct the covariate:
  sql <- paste("SELECT @row_id_field AS row_id, 1 AS covariate_id,",
               "DATEDIFF(DAY, observation_period_start_date, cohort_start_date)",
               "AS covariate_value",
               "FROM @cohort_table c",
               "INNER JOIN @cdm_database_schema.observation_period op",
               "ON op.person_id = c.subject_id",
               "WHERE cohort_start_date >= observation_period_start_date",
               "AND cohort_start_date <= observation_period_end_date",
               "{@cohort_id != -1} ? {AND cohort_definition_id = @cohort_id}")
  sql <- SqlRender::render(sql,
                           cohort_table = cohortTable,
                           cohort_id = cohortId,
                           row_id_field = rowIdField,
                           cdm_database_schema = cdmDatabaseSchema)
  sql <- SqlRender::translate(sql, targetDialect = attr(connection, "dbms"))
  # Retrieve the covariate:
  covariates <- DatabaseConnector::querySql.ffdf(connection, sql)
  # Convert colum names to camelCase:
  colnames(covariates) <- SqlRender::snakeCaseToCamelCase(colnames(covariates))
  # Construct covariate reference:
  covariateRef <- data.frame(covariateId = 1,
                             covariateName = "Length of observation",
                             analysisId = 1,
                             conceptId = 0)
  covariateRef <- ff::as.ffdf(covariateRef)
  # Construct analysis reference:
  analysisRef <- data.frame(analysisId = 1,
                            analysisName = "Length of observation",
                            domainId = "Demographics",
                            startDay = 0,
                            endDay = 0,
                            isBinary = "N",
                            missingMeansZero = "Y")
  analysisRef <- ff::as.ffdf(analysisRef)
  # Construct analysis reference:
  metaData <- list(sql = sql, call = match.call())
  result <- list(covariates = covariates,
                 covariateRef = covariateRef,
                 analysisRef = analysisRef,
                 metaData = metaData)
  class(result) <- "covariateData"
  return(result)
}
