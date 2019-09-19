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

  sql = '
        WITH days_from_hiv AS (
          SELECT  coh.@row_id_field,
                  v.visit_start_date - coh.cohort_start_date AS days
          FROM @cohort_database_schema.@cohort_table coh
          LEFT JOIN @cdm_database_schema.visit_occurrence v ON v.person_id = coh.@row_id_field
          WHERE coh.cohort_definition_id = @cohort_id
          )
        SELECT  @row_id_field, days
        FROM days_from_hiv
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
  res <- querySql(connection, sql)
  if (nrow(res) == 0)
    return(NULL)

  names(res) <- tolower(names(res))
  names(res)[1] <- 'row_id'
  daylists <-
    res %>%
    group_by(row_id) %>%
    do(days = .data$days) %>%
    select(days)

  stats <- daylists %>% mutate(s = list(summary(days))) %>% pull(s) %>% map(bind_rows) %>% bind_rows()

  vars <- daylists %>%
    mutate(visits = length(days),
           obsdays = max(days) - min(days),

           pre_index_visits = sum(days < 0),
           pre_index_obsdays = abs(min(days)),

           post_index_visits = sum(days >=0),
           post_index_obsdays = max(days)
    ) %>%
    bind_cols(stats) %>%
    select(-days)
  t <- as.tibble(vars) %>% add_column(cohort_id=cohort_id, cohort_name=cohort_name, .before = TRUE)
  return(t)

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

  get_qtile_sql <- function(prepost='post', days_or_visits='days') {
    varname <- glue::glue('{days_or_visits}_{prepost}_hiv')
    op <- if_else(prepost=="pre", "<", ">=")
    minmax <- if_else(prepost=="post", "MAX", "MIN")
    vardef <- if_else(days_or_visits=="days",
                        glue::glue('{minmax}(visitday)'),
                        glue::glue('COUNT(visitday)'))
    sql <- glue::glue('
      WITH ntiles AS (
        WITH by_subj AS (
          WITH days AS (
            WITH days_after_hiv AS (
              SELECT  coh.@row_id_field,
                      v.visit_start_date - coh.cohort_start_date AS days
              FROM @cohort_database_schema.@cohort_table coh
              LEFT JOIN @cdm_database_schema.visit_occurrence v ON v.person_id = coh.@row_id_field
              WHERE coh.cohort_definition_id = @cohort_id
              )
            SELECT  @row_id_field,
                    CASE WHEN days {op} 0 THEN days ELSE NULL END AS visitday
            FROM days_after_hiv
          )
          SELECT  @row_id_field,
                  1 AS const,
                  {vardef} AS {varname}
          FROM days
          GROUP BY @row_id_field
        )
        SELECT  {varname}, ntile(4) OVER(ORDER BY({varname})) AS {varname}_qtile
        FROM by_subj
      )
      SELECT  {varname}_qtile AS quartile,
              min({varname}) AS {varname}_q_min,
              max({varname}) AS {varname}_q_max
      FROM ntiles
      GROUP by {varname}_qtile
      ORDER BY {varname}_qtile
      ')
    return(paste(sql))  # i get a weird error in sqlrender without doing this
  }

  get_data <- function(sql) {
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

    t <- as.tibble(res) %>% add_column(cohort_id=cohort_id, cohort_name=cohort_name, .before = TRUE)
    names(t) <- tolower(names(t))
    return(t)
  }

  tbls <- list(
    get_data(get_qtile_sql('pre','days')),
    get_data(get_qtile_sql('pre','visits')),
    get_data(get_qtile_sql('post','days')),
    get_data(get_qtile_sql('post','visits'))
  )

# One more output that Collapses quartiles
# Total mean and SD of it
# Lifetime span of record (in days)
# Span of HIV infection (cohort_start_date-last_visit_date) (in days)
# % of your HIV live/total life  (mean and sd)
# % of HIV patients in my cohort that died (ever)
#
# Person years
# Person days
# Span defined by obs period
# Span defined by visit data


  tbl <-
    tbls[[1]] %>%
    left_join(tbls[[2]], by=c('cohort_id', 'cohort_name', 'quartile')) %>%
    left_join(tbls[[3]], by=c('cohort_id', 'cohort_name', 'quartile')) %>%
    left_join(tbls[[4]], by=c('cohort_id', 'cohort_name', 'quartile'))

  return(tbl)



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

