#'
#'
#'
#' @export
customSqlCohortAnalysis <- function(connection,
                                    cohorts = c(), # coming from CohortsToCreate.csv
                                    covariateSettings = basicCovariateSettings(),
                                    min_cell_count = 11,
                                    top_n_meds = 10,
                                    row_id_field = "subject_id",
                                    cdmDatabaseSchema,
                                    vocabularyDatabaseSchema = cdmDatabaseSchema,
                                    cohortDatabaseSchema,
                                    cohortTable,
                                    cohort_id,
                                    cohort_name,
                                    oracleTempSchema,
                                    exportFolder
                                    ) {

  sql = '
    SELECT AVG(visit_cnt) avg_visits
    FROM (
          SELECT  coh.@row_id_field,
                  count(*) visit_cnt
          FROM @cohort_database_schema.@cohort_table coh
          LEFT JOIN @cdm_database_schema.visit_occurrence v ON v.person_id = coh.@row_id_field
          GROUP BY coh.@row_id_field
    ) visits
  '

  sql <- SqlRender::render(sql,
            dbms = attr(connection, "dbms"),
            cdm_database_schema = cdmDatabaseSchema,
            cohort_database_schema = cohortDatabaseSchema,
            cohort_table = "hiv_cohort_table",
            cohort_id = cohort_id,
            row_id_field = row_id_field
          )
  sql <- SqlRender::translate(sql, attr(connection, "dbms"))
  cat(sql)
  res <- querySql(connection, sql)

  return(list(avg_visits = res$AVG_VISITS, cohort_id = cohort_id))

  # fname <- paste0("covariates.continuous.", cohorts$cohortId[[i]], ".", cohorts$name[[i]], ".csv")
  # fpath <- file.path(exportFolder, fname)
  # write.csv(result, fpath, row.names = FALSE)
  # fname <- paste0("table1.", cohorts$cohortId[[i]], ".", cohorts$name[[i]], ".csv")
  # fpath <- file.path(exportFolder, fname)
  # write.csv(result, fpath, row.names = FALSE)
  # writeLines(paste0("Wrote covariates to ", exportFolder,"/", fname))
  # # writeLines(paste0('0 population in ', cohorts$name[[i]]))
}

