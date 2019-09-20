# Copyright 2019 Observational Health Data Sciences and Informatics
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


# SG (5/21/2019): Deleting init() in main.R because all it was doing (probably
# because we deleted code from it after copying main.R from somewhere), which
# is redundant with this script. But I did grab the documentation header, which
# is not yet correct, but maybe we'll want to hold on to it and fix it.


#' Initialize HivDescriptive Tables
#'
#' @details
#' This function initializes the HivDescriptive Study tables.
#'
#' @param connectionDetails    An object of type \code{connectionDetails} as created using the
#'                             \code{\link[DatabaseConnector]{createConnectionDetails}} function in the
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
#'
#' execute(connectionDetails,
#'         targetDatabaseSchema = "studyDB.endoStudy",
#'         tablePrefix="endo_")
#' }
#'
#' @export
createCohorts <- function(connection,
                          cohortsToCreate = cohortsToCreate,
                          cdmDatabaseSchema,
                          vocabularyDatabaseSchema = cdmDatabaseSchema,
                          cohortDatabaseSchema,
                          cohortTable,
                          oracleTempSchema,
                          outputFolder) {

  # Create study cohort table structure:
  sql <- SqlRender::loadRenderTranslateSql(sqlFilename = "CreateCohortTable.sql",
                                           packageName = "HivDescriptive",
                                           dbms = attr(connection, "dbms"),
                                           oracleTempSchema = oracleTempSchema,
                                           cohort_database_schema = cohortDatabaseSchema,
                                           cohort_table = cohortTable)
  DatabaseConnector::executeSql(connection = connection, sql = sql, progressBar = FALSE, reportOverallTime = FALSE)

  # Instantiate cohorts:
  for (i in 1:nrow(cohortsToCreate)) {
    writeLines(paste("Creating cohort:", cohortsToCreate$cohort_name[i]))
    sql <- SqlRender::loadRenderTranslateSql(sqlFilename = paste0(cohortsToCreate$cohort_name[i], ".sql"),
                                             packageName = "HivDescriptive",
                                             dbms = attr(connection, "dbms"),
                                             oracleTempSchema = oracleTempSchema,
                                             cdm_database_schema = cdmDatabaseSchema,
                                             vocabulary_database_schema = vocabularyDatabaseSchema,

                                             target_database_schema = cohortDatabaseSchema,
                                             target_cohort_table = cohortTable,
                                             target_cohort_id = cohortsToCreate$cohort_id[i])
    DatabaseConnector::executeSql(connection, sql)
  }


  counts <- get_cohort_counts(cohortDatabaseSchema, cohortTable, connection)
  counts <- fake_cohorts_if_empty(counts, cohortsToCreate, cohortDatabaseSchema, cohortTable, connection)

  counts <- merge(counts, data.frame(cohortDefinitionId = cohortsToCreate$cohort_id,
                                     cohortName  = cohortsToCreate$cohort_name))
  write.csv(counts, file.path(outputFolder, "CohortCounts.csv"), row.names = FALSE)
  writeLines(paste0("Wrote cohort counts to ", outputFolder,"/CohortCounts.csv"))
}

get_cohort_counts <- function(cohortDatabaseSchema, cohortTable, connection) {
  sql <- "SELECT cohort_definition_id, COUNT(*) AS count FROM @cohort_database_schema.@cohort_table GROUP BY cohort_definition_id"
  sql <- SqlRender::render(sql,
                           cohort_database_schema = cohortDatabaseSchema,
                           cohort_table = cohortTable)
  sql <- SqlRender::translate(sql, targetDialect = attr(connection, "dbms"))
  counts <- DatabaseConnector::querySql(connection, sql)
  names(counts) <- SqlRender::snakeCaseToCamelCase(names(counts))
  return(counts)
}

fake_cohorts_if_empty <- function(counts, cohortsToCreate, cohortDatabaseSchema, cohortTable, connection) {
  # browser()
  empties <- setdiff(cohortsToCreate$cohort_id, counts$cohortDefinitionId)
  sql <- "
          insert into eunomia_results.hiv_cohort_table (
            select @cohort_id, p.person_id, min(o.observation_date) start_date, max(o.observation_date) end_date
            from eunomia.person p
            tablesample system(10)
            join eunomia.observation o on p.person_id = o.person_id
            group by 1,2
            limit 100)"
  stuff <- empties %>% map(function(cohort_id) {
    sql <- SqlRender::render(sql,
                             cohort_database_schema = cohortDatabaseSchema,
                             cohort_table = cohortTable,
                             cohort_id = cohort_id)
    sql <- SqlRender::translate(sql, targetDialect = attr(connection, "dbms"))
    DatabaseConnector::executeSql(connection, sql)
  })
  return(get_cohort_counts(cohortDatabaseSchema, cohortTable, connection))
}
