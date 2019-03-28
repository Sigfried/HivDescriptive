# Copyright 2018 Observational Health Data Sciences and Informatics
#
# This file is part of hivTestStudyCharacterization
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


# making cohorts the primitive way, not using insertCohortDefinitionSetInPackage
#   and cohort.csv, etc.


library(tidyverse)
readRenviron('.env')

OhdsiRTools::insertCohortDefinitionInPackage(
  # fileName = "settings.csv",
  #    cat inst/settings/settings.csv
  #    "cohortId","atlasId","name","fullName"
  #    987654321,1769961,"Male50plus","Male > 50"
  definitionId = 1769961,
  name = "Male50plus",
  baseUrl = Sys.getenv("WebAPIBaseUrl"),# "http://18.213.176.21:80/WebAPI"
  generateStats = FALSE
)


# add second cohort def at some point
# cohort 2:
#   HIV patients when HIV onset > age 18

# cohort 3:
#   patients with HIV lab test
#   temporarily use any, ldl measure table record



# don't use settings.csv or cohorts.csv
#
# # Generate CSV of cohort names and IDs for the package
#
# cohortCsv <-
#   "cohortId,cohortName,cohortSql
# 1,Male50plus,Male50plus.sql
# "
# #2,ConditionCount,ConditionCount.sql
#
# writeLines(cohortCsv, "inst/settings/cohorts.csv")


# Insert cohort definitions from ATLAS into package -----------------------

# couldn't get the Set version of insertCohortDefinition<Set>InPackage with
#      /inst/settings/settings.csv:
#      "cohortId","atlasId","name","fullName"
#     987654321,1769961,"Male50plus","Male > 50"

# OhdsiRTools::insertCohortDefinitionSetInPackage(
#   fileName = "settings.csv",
#   baseUrl = Sys.getenv("WebAPIBaseUrl"),# "http://18.213.176.21:80/WebAPI"
#   insertTableSql = TRUE,
#   insertCohortCreationR = TRUE,
#   generateStats = FALSE,
#   packageName="hivTestStudy")
  # Inserting cohort: Male50plus
  # Error in readChar(fileName, file.info(fileName)$size) :
  #   invalid 'nchars' argument
  # In addition: Warning message:
  #   In file(con, "rb") :
  #   file("") only supports open = "w+" and open = "w+b": using the former

# so, don't need settings.csv, and loading from single public ATLAS/WebAPI cohort def:




