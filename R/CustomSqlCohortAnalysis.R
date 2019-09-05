#'
#'
#'
#' @export
visits <- function( cohort_id,
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


  # the following query would be nice for showing various distributions, but it includes patient-level data, so not using it
  # sql = "
  # WITH randid AS (
  #   SELECT ROW_NUMBER() OVER (ORDER BY RAND()), @row_id_field
  #   FROM (SELECT DISTINCT @row_id_field FROM @cohort_database_schema.@cohort_table) X
  # )
  # SELECT  DISTINCT
  #         randid.@row_id_field AS randid,
  #         /* coh.cohort_start_date, coh.cohort_end_date, v.visit_start_date,*/
  #         v.visit_start_date - coh.cohort_start_date AS days_since_hiv,
  #         CASE
  #           WHEN v.visit_start_date - coh.cohort_start_date < 0 THEN 'pre-HIV'
  #           WHEN v.visit_start_date - coh.cohort_end_date > 0 THEN 'post-HIV (weird)'
  #           ELSE 'HIV'
  #         END AS daytype,
  #         coh.cohort_end_date - coh.cohort_start_date AS cohort_days
  # FROM onek_results.hiv_cohort_table coh
  # INNER JOIN randid ON coh.@row_id_field = randid.@row_id_field
  # LEFT JOIN onek.visit_occurrence v ON v.person_id = coh.subject_id
  # WHERE coh.cohort_definition_id = @cohort_id
  # "
  sql = '
        SELECT visits, COUNT(*) cnt
        FROM (
        	SELECT  coh.@row_id_field,
                  COUNT(*) visits
          FROM @cohort_database_schema.@cohort_table coh
          LEFT JOIN @cdm_database_schema.visit_occurrence v ON v.person_id = coh.@row_id_field
          WHERE coh.cohort_definition_id = @cohort_id
          GROUP BY coh.@row_id_field
        ) v
        GROUP BY visits
        ORDER BY 1
  '


  sql ='WITH ntiles AS (
  WITH by_subj AS (
  WITH days AS (
  WITH days_after_hiv AS (
  SELECT  coh.subject_id,
  v.visit_start_date - coh.cohort_start_date AS days
  FROM onek_results.hiv_cohort_table coh
  LEFT JOIN onek.visit_occurrence v ON v.person_id = coh.subject_id
  WHERE coh.cohort_definition_id = 1769440
  )
  SELECT subject_id,
  CASE WHEN days < 0 THEN days ELSE 0 END AS visit_pre_hiv,
  CASE WHEN days >= 0 THEN days ELSE 0 END AS visit_post_hiv
  FROM days_after_hiv
  )
  SELECT subject_id,
  1 AS const,
  MIN(visit_pre_hiv) AS first_visit,
  MAX(visit_post_hiv) AS last_visit,
  SUM(CASE WHEN visit_pre_hiv = 0 THEN 0 ELSE 1 END) AS pre_visits,
  SUM(CASE WHEN visit_post_hiv = 0 THEN 0 ELSE 1 END) AS post_visits
  FROM days
  GROUP BY subject_id
  )
  SELECT  first_visit,
  ntile(4) OVER(ORDER BY(first_visit)) AS days_pre,
  last_visit,
  ntile(4) OVER(ORDER BY(last_visit)) AS days_post,
  pre_visits,
  ntile(4) OVER(ORDER BY(pre_visits)) AS pre_visits,
  post_visits,
  ntile(4) OVER(ORDER BY(post_visits)) AS post_visits
  FROM by_subj
  )
  SELECT *
  FROM ntiles
  '

junk <- '

  +-------------+----------+------------+-----------+------------+------------+-------------+-------------+
  | first_visit | days_pre | last_visit | days_post | pre_visits | pre_visits | post_visits | post_visits |
  +-------------+----------+------------+-----------+------------+------------+-------------+-------------+
  |         -48 |        4 |        117 |         1 |          1 |          1 |           1 |           1 |
  |        -369 |        2 |         70 |         1 |         11 |          1 |           2 |           1 |
  |       -1038 |        1 |         19 |         1 |         96 |          4 |           2 |           1 |
  |        -771 |        1 |        124 |         1 |         41 |          3 |           7 |           1 |
  |        -605 |        1 |         36 |         1 |        121 |          4 |           8 |           1 |
  |        -404 |        2 |        603 |         3 |         12 |          2 |           8 |           1 |
  |        -207 |        3 |         69 |         1 |         28 |          2 |           9 |           1 |
  |        -137 |        4 |        371 |         2 |          3 |          1 |           9 |           1 |
  |        -918 |        1 |        107 |         1 |         79 |          4 |           9 |           1 |
  |        -578 |        2 |        397 |         2 |         30 |          2 |          10 |           1 |
  |        -900 |        1 |        108 |         1 |         91 |          4 |          13 |           2 |
  |        -681 |        1 |        168 |         2 |         51 |          3 |          14 |           2 |
  |        -937 |        1 |         99 |         1 |        135 |          4 |          16 |           2 |
  |        -668 |        1 |        129 |         1 |        124 |          4 |          16 |           2 |
  |        -709 |        1 |        216 |         2 |         71 |          3 |          17 |           2 |
  '

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

  tibble(cohort_id = cohort_id, cohort_name = cohort_name, visits = res$VISITS, cnt = res$CNT)
  # tibble(cohort_id = cohort_id, cohort_name = cohort_name, visits = list(res$VISITS), cnt = list(res$CNT))

  # rep(res$VISITS, res$CNT) %>% hist(seq(0, 225, 25), main = "Histogram of Total Visits Per Patient", xlab = "Visits", ylab = "Patients")

  # return(list(cohort_id = cohort_id, cohort_name = cohort_name, visits = paste0(res$VISITS, collapse = ','), cnt = paste0(res$CNT, collapse = ',')))
  # browser()
  # if (nrow(res)) {   # this was for handling the patient-level visit data
  #   visit_days <- res %>% group_by(randid) %>% do(visit_days = paste0(.data$DAYS_SINCE_HIV, collapse = ','))
  #   return(list(visit_days = visit_days))
  #   return(data.frame(cohort_id = cohort_id, cohort_name = cohort_name,
  #                     randid = res$RANDID,
  #                     cohort_days = res$COHORT_DAYS,
  #                     days_since_hiv = res$DAYS_SINCE_HIV,
  #                     day_type = res$DAYTYPE))
  # }
  # return(data.frame(cohort_id=c(), cohort_name=c(), visits=c(), cnt=c()))

  # fname <- paste0("covariates.continuous.", cohorts$cohort_id[[i]], ".", cohorts$cohort_name[[i]], ".csv")
  # fpath <- file.path(exportFolder, fname)
  # write.csv(result, fpath, row.names = FALSE)
  # fname <- paste0("table1.", cohorts$cohort_id[[i]], ".", cohorts$cohort_name[[i]], ".csv")
  # fpath <- file.path(exportFolder, fname)
  # write.csv(result, fpath, row.names = FALSE)
  # writeLines(paste0("Wrote covariates to ", exportFolder,"/", fname))
  # # writeLines(paste0('0 population in ', cohorts$cohort_name[[i]]))
}

