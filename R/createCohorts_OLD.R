# Instantiate cohorts:

.createCohorts <- function(connection,
													 cdmDatabaseSchema,
													 vocabularyDatabaseSchema = cdmDatabaseSchema,
													 targetDatabaseSchema = cohortDatabaseSchema,
													 oracleTempSchema,
													 cohortTable) {

	pathToCsv <- system.file("settings", "cohorts.csv", package = packageName())

	cohortsCsv<- read.csv(pathToCsv,stringsAsFactors = FALSE)

	for (i in 1:nrow(cohortsCsv)) {
		writeLines(paste("Creating cohort:", cohortsCsv$cohortName[i]))
		sql <- SqlRender::loadRenderTranslateSql(sqlFilename = cohortsCsv$cohortSql[i],
																						 packageName = packageName(),
																						 dbms = attr(connection, "dbms"),
																						 oracleTempSchema = oracleTempSchema,
																						 cdm_database_schema = cdmDatabaseSchema,
																						 vocabulary_database_schema = vocabularyDatabaseSchema,
																						 target_database_schema = targetDatabaseSchema,
																						 target_cohort_table = cohortTable,
																						 target_cohort_id = cohortsCsv$cohortId[i])
		DatabaseConnector::executeSql(connection, sql)
	}
}
