#'
#'
#'
#' @export
customSqlCohortAnalysis <- function(cohort_id,
                                    cohort_name,
                                    connection,
                                    cohorts = c(), # coming from CohortsToCreate.csv
                                    covariateSettings = basicCovariateSettings(),
                                    min_cell_count = 11,
                                    top_n_meds = 10,
                                    row_id_field = "subject_id",
                                    cdmDatabaseSchema,
                                    vocabularyDatabaseSchema = cdmDatabaseSchema,
                                    cohortDatabaseSchema,
                                    cohortTable,
                                    oracleTempSchema,
                                    exportFolder
                                    ) {

  # sql = '
  #       SELECT visits, COUNT(*) cnt
  #       FROM (
  #       	SELECT  coh.@row_id_field,
  #                 COUNT(*) visits
  #         FROM @cohort_database_schema.@cohort_table coh
  #         LEFT JOIN @cdm_database_schema.visit_occurrence v ON v.person_id = coh.@row_id_field
  #         WHERE coh.cohort_definition_id = @cohort_id
  #         GROUP BY coh.@row_id_field
  #       ) v
  #       GROUP BY visits
  #       ORDER BY 1
  # '
  sql = "
  WITH randid AS (
    SELECT ROW_NUMBER() OVER (ORDER BY RAND()), @row_id_field
    FROM (SELECT DISTINCT @row_id_field FROM @cohort_database_schema.@cohort_table) X
  )
  SELECT  DISTINCT
          randid.@row_id_field AS randid,
          /* coh.cohort_start_date, coh.cohort_end_date, v.visit_start_date,*/
          v.visit_start_date - coh.cohort_start_date AS days_since_hiv,
          CASE
            WHEN v.visit_start_date - coh.cohort_start_date < 0 THEN 'pre-HIV'
            WHEN v.visit_start_date - coh.cohort_end_date > 0 THEN 'post-HIV (weird)'
            ELSE 'HIV'
          END AS daytype,
          coh.cohort_end_date - coh.cohort_start_date AS cohort_days
  FROM onek_results.hiv_cohort_table coh
  INNER JOIN randid ON coh.@row_id_field = randid.@row_id_field
  LEFT JOIN onek.visit_occurrence v ON v.person_id = coh.subject_id
  WHERE coh.cohort_definition_id = @cohort_id
  "


  sql <- SqlRender::render(sql,
            # dbms = attr(connection, "dbms"),
            cdm_database_schema = cdmDatabaseSchema,
            cohort_database_schema = cohortDatabaseSchema,
            cohort_table = "hiv_cohort_table",
            cohort_id = cohort_id,
            row_id_field = row_id_field
          )
  sql <- SqlRender::translate(sql, attr(connection, "dbms"))
  # cat(sql)
  res <- querySql(connection, sql)

  # rep(res$VISITS, res$CNT) %>% hist(seq(0, 225, 25), main = "Histogram of Total Visits Per Patient", xlab = "Visits", ylab = "Patients")

  # return(list(cohort_id = cohort_id, cohort_name = cohort_name, visits = paste0(res$VISITS, collapse = ','), cnt = paste0(res$CNT, collapse = ',')))
  if (nrow(res)) {
    return(data.frame(cohort_id = cohort_id, cohort_name = cohort_name,
                      randid = res$RANDID,
                      cohort_days = res$COHORT_DAYS,
                      days_since_hiv = res$DAYS_SINCE_HIV,
                      day_type = res$DAYTYPE))
  }
  return(data.frame(cohort_id=c(), cohort_name=c(), visits=c(), cnt=c()))

  # fname <- paste0("covariates.continuous.", cohorts$cohort_id[[i]], ".", cohorts$cohort_name[[i]], ".csv")
  # fpath <- file.path(exportFolder, fname)
  # write.csv(result, fpath, row.names = FALSE)
  # fname <- paste0("table1.", cohorts$cohort_id[[i]], ".", cohorts$cohort_name[[i]], ".csv")
  # fpath <- file.path(exportFolder, fname)
  # write.csv(result, fpath, row.names = FALSE)
  # writeLines(paste0("Wrote covariates to ", exportFolder,"/", fname))
  # # writeLines(paste0('0 population in ', cohorts$cohort_name[[i]]))
}

