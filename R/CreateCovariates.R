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
                             min_cell_count = 11,
                             top_n_meds = 10,
                             row_id_field = "subject_id",
                             cdmDatabaseSchema,
                             vocabularyDatabaseSchema = cdmDatabaseSchema,
                             cohortDatabaseSchema,
                             cohortTable = "hiv_cohort_table",
                             oracleTempSchema,
                             exportFolder,
                             covarOutput = c("table1", "big.data.frame")
                             ) {

  cohort_table = cohortTable

  looCovSet <- createLooCovariateSettings()
  # topNMedsCovSet <- createCohortAttrCovariateSettings(attrDatabaseSchema = cohortDatabaseSchema,
  #                                                     cohortAttrTable = "top_n_meds_cohort_attr",
  #                                                     attrDefinitionTable = "top_n_meds_attr_def")
  covariateSettingsList <- list(covariateSettings, looCovSet) #, topMedsCovSet

  # sql <- SqlRender::loadRenderTranslateSql(
  #   "TopNMedsCohortAttr.sql",
  #   block_to_run = "clear tables",
  #   packageName = "HivDescriptive",
  #   dbms = attr(connection, "dbms"),
  #   cohort_database_schema = cohortDatabaseSchema,
  #   cohort_attribute_table = "top_n_meds_cohort_attr",
  #   attribute_definition_table = "top_n_meds_attr_def",
  #   cohort_ids = paste(cohorts$cohort_id, collapse = ','),
  #   min_cell_count = min_cell_count,
  #   row_id_field = row_id_field
  # )

  for (i in 1:nrow(cohorts)) {
    # writeLines(paste("Creating covariates for cohort", cohorts$cohort_name[i]))

    # creating custom covarirate from cohort attribute, but can't aggregate:
    # looCovSet <- createCohortAttrCovariateSettings(attrDatabaseSchema = cohortDatabaseSchema,
    #                                                cohortAttrTable = "loo_cohort_attr",
    #                                                attrDefinitionTable = "loo_attr_def")

    # couldn't get top_n_med covariates working, giving up for now
    # sql <- SqlRender::loadRenderTranslateSql(
    #   "TopNMedsCohortAttr.sql",
    #   block_to_run = "top drug ids",
    #   packageName = "HivDescriptive",
    #   dbms = attr(connection, "dbms"),
    #   cdm_database_schema = cdmDatabaseSchema,
    #   cohort_database_schema = cohortDatabaseSchema,
    #   cohort_table = "hiv_cohort_table",
    #   cohort_attribute_table = "top_n_meds_cohort_attr",
    #   attribute_definition_table = "top_n_meds_attr_def",
    #   # cohort_ids = paste(cohorts$cohort_id, collapse = ','),
    #   cohort_id = cohorts$cohort_id[[i]],
    #   min_cell_count = min_cell_count,
    #   row_id_field = row_id_field
    # )
    # cat(sql)
    # res <- querySql(connection, sql)
    # med_settings <- res %>%
    #   head(top_n_meds) %>%
    #   select(covariate_id=COVARIATE_ID, covariate_name = COVARIATE_NAME) %>%
    #   pmap(function(covariate_id, covariate_name) {
    #     createTopMedCovariateSettings(covariate_id = covariate_id, covariate_name = covariate_name)
    #   })
    #
    #
    # covariateSettingsList <- med_settings %>%
    #   prepend(looCovSet) %>%
    #   prepend(covariateSettings)
    #

    cohort_ids = if_else('cohortId' %in% cohorts, cohorts$cohortId[i], cohorts$cohort_id[i])
    covariates <- getDbCovariateData(connection = connection,
                                     cdmDatabaseSchema = cdmDatabaseSchema,
                                     cohortDatabaseSchema = cohortDatabaseSchema,
                                     cohortTable = cohortTable,
                                     cohortId = cohort_ids[i],
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
          dplyr::top_n(min_cell_count, sumValue) %>% dplyr::arrange(analysisName, -sumValue)
        fname <- paste0("covariates.", cohorts$cohort_id[[i]], ".", cohorts$cohort_name[[i]], ".csv")
        fpath <- file.path(exportFolder, fname)
        write.csv(result, fpath, row.names = FALSE)

        result <-
          acvc %>%
          filter(is.numeric(countValue) & countValue >= min_cell_count) %>%
          dplyr::left_join(acvref) %>%
          dplyr::left_join(aaref) %>%
          dplyr::group_by(analysisId)
        fname <- paste0("covariates.continuous.", cohorts$cohort_id[[i]], ".", cohorts$cohort_name[[i]], ".csv")
        fpath <- file.path(exportFolder, fname)
        write.csv(result, fpath, row.names = FALSE)
      }
      if ('table1' %in% covarOutput) {
        result <- createTable1(aggcovariates,
                               specifications = getDefaultTable1Specifications(),
                               output = "one column")
        fname <- paste0("table1.", cohorts$cohort_id[[i]], ".", cohorts$cohort_name[[i]], ".csv")
        fpath <- file.path(exportFolder, fname)
        write.csv(result, fpath, row.names = FALSE)
      }
      # result$cohort_id <- cohorts$cohort_id[[i]]
      # result$cohortName <- toString(cohorts$cohort_name[[i]])

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
      writeLines(paste0('0 population in ', cohorts$cohort_name[[i]]))
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
    # counts <- merge(counts, data.frame(cohortDefinitionId = cohortsToCreate$cohort_id,
    #                                    cohortName  = cohortsToCreate$cohort_name))
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
  #   cohort_id = 1769961,
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
    useConditionOccurrenceLongTerm = TRUE,
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

  cohort_id = cohortId
  cohort_table = cohortTable
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
  # browser()
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

# createTopMedCovariateSettings <- function(covariate_id = NULL,
#                                          covariate_name = NULL)
# {
#   covariateSettings <- list(covariate_id = covariate_id,
#                             covariate_name = covariate_name)
#   attr(covariateSettings, "fun") <- "getDbTopMedCovariateData"
#   class(covariateSettings) <- "covariateSettings"
#   return(covariateSettings)
# }

# getDbTopMedCovariateData <- function(connection,
#                                   oracleTempSchema = NULL,
#                                   cdmDatabaseSchema,
#                                   cohortTable = "#cohort_person",
#                                   cohortId = -1,
#                                   cdmVersion = "5",
#                                   rowIdField = "subject_id",
#                                   covariateSettings,
#                                   aggregated = FALSE) {
#   return(list())
#   stop("stopping in getDbTopMedCovariateData")
#   writeLines(paste("Constructing top med covariates:", covariateSettings$covariate_name))
#   browser()
#   # if (aggregated)
#     stop("Aggregation not supported here, use aggregateCovariates()")
#   # Some SQL to construct the covariate:
#
#
#   # sql <- paste("WITH cohort_drugs AS (",
#   #              "  SELECT @row_id_field AS row_id, ",
#   #              "          2 AS covariate_id, ",
#   #              "          de.drug_concept_id",
#   #              "  FROM @cohort_table c ",
#   #              "  INNER JOIN @cdm_database_schema.drug_exposure de ON de.person_id = c.subject_id ",
#   #              "  WHERE cohort_start_date <= de.drug_exposure_start_date AND ",
#   #              "        cohort_end_date >= de.drug_exposure_startsla_date AND ",
#   #              "        {@cohort_id != -1} ? {AND cohort_definition_id = @cohort_id}",
#   #              ")",
#   #              "SELECT drug_concept_id, count(*) cnt",
#   #              "FROM cohort_drugs",
#   #              "GROUP BY 1",     #   fix to not be postgres specific!!!!!!
#   #              "HAVING count(*) >= @min_cell_count",
#   #              "ORDER by 2 DESC",
#   #              "LIMIT @top_n_meds",
#   #              "SELECT c.concept_name as drug_name, cd.row_id, count(*) cnt",
#   #              "FROM (",
#   #              "  SELECT drug_concept_id, count(*) cnt",
#   #              "  FROM cohort_drugs",
#   #              "  GROUP BY 1",
#   #              "  HAVING count(*) >= @min_cell_count",
#   #              "  ORDER by 2 DESC",
#   #              "  LIMIT @top_n_meds",
#   #              ") topdrugs",
#   #              "INNER JOIN cohort_drugs cd ON topdrugs.drug_concept_id = cd.drug_concept_id",
#   #              "INNER JOIN @cdm_database_schema.concept c ON topdrugs.drug_concept_id = c.concept_id",
#   #              "GROUP BY 1,2")
#   # sql <- SqlRender::render(sql,
#   #                          cohort_table = cohortTable,
#   #                          cohort_id = cohortId,
#   #                          row_id_field = rowIdField,
#   #                          cdm_database_schema = cdmDatabaseSchema,
#   #                          min_cell_count = covariateSettings$min_cell_count,
#   #                          top_n_meds = covariateSettings$top_n_meds)
#   # sql <- SqlRender::translate(sql, targetDialect = attr(connection, "dbms"))
#   # writeLines('top meds sql:')
#   # writeLines(sql)
#   # Retrieve the covariate:
#   covariates <- DatabaseConnector::querySql.ffdf(connection, sql)
#   # Convert colum names to camelCase:
#   colnames(covariates) <- SqlRender::snakeCaseToCamelCase(colnames(covariates))
#   # Construct covariate reference:
#   covariateRef <- data.frame(covariateId = 1,
#                              covariateName = "whoops",    #    this is going to be multiple covariates, isn't it?
#                              analysisId = 1,
#                              conceptId = 0)
#   covariateRef <- ff::as.ffdf(covariateRef)
#   # Construct analysis reference:
#   analysisRef <- data.frame(analysisId = 1,
#                             analysisName = "Length of observation",
#                             domainId = "Demographics",
#                             startDay = 0,
#                             endDay = 0,
#                             isBinary = "N",
#                             missingMeansZero = "Y")
#   analysisRef <- ff::as.ffdf(analysisRef)
#   # Construct analysis reference:
#   metaData <- list(sql = sql, call = match.call())
#   result <- list(covariates = covariates,
#                  covariateRef = covariateRef,
#                  analysisRef = analysisRef,
#                  metaData = metaData)
#   class(result) <- "covariateData"
#   return(result)
# }
