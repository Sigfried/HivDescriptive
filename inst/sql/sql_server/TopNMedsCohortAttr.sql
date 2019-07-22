/***********************************
File LengthOfObsCohortAttr.sql
***********************************/

IF OBJECT_ID('@cohort_database_schema.@cohort_attribute_table', 'U') IS NOT NULL
	DROP TABLE @cohort_database_schema.@cohort_attribute_table;

IF OBJECT_ID('@cohort_database_schema.@attribute_definition_table', 'U') IS NOT NULL
	DROP TABLE @cohort_database_schema.@attribute_definition_table;

/* SqlRender not translating these:
DROP TABLE IF EXISTS @cohort_database_schema.@cohort_attribute_table;
DROP TABLE IF EXISTS @cohort_database_schema.@attribute_definition_table;
*/

SELECT 1 AS attribute_definition_id,
  'top ' || @top_n || ' drug' AS attribute_name
INTO @cohort_database_schema.@attribute_definition_table;

WITH cohort_drugs AS (
  SELECT @row_id_field AS row_id,
         @covariate_id AS covariate_id,
         de.drug_concept_id
  FROM @cohort_table c
  INNER JOIN @cdm_database_schema.drug_exposure de ON de.person_id = c.subject_id
  WHERE cohort_start_date <= de.drug_exposure_start_date AND
        cohort_end_date >= de.drug_exposure_startsla_date AND
        {@cohort_id != -1} ? {AND cohort_definition_id = @cohort_id}

        /*
          {@cohort_definition_ids != ''} ? {
            AND cohort_definition_id IN (@cohort_definition_ids)
        */
)
SELECT c.concept_name as drug_name, cd.row_id, count(*) cnt
FROM (
  SELECT drug_concept_id, count(*) cnt
  FROM cohort_drugs
  GROUP BY 1
  HAVING count(*) >= @min_cell_count
  ORDER by 2 DESC
  LIMIT @top_n
) topdrugs
INNER JOIN cohort_drugs cd ON topdrugs.drug_concept_id = cd.drug_concept_id
INNER JOIN concept c ON topdrugs.drug_concept_id = c.concept_id
GROUP BY 1,2
ORDER BY 1,2;
