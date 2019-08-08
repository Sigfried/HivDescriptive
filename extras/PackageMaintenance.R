# Copyright 2018 Observational Health Data Sciences and Informatics
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


#devtools::install_github("OHDSI/OhdsiSharing",args="--no-multiarch" )

# add more cohort defs at some point:
#   HIV patients when HIV onset > age 18
#   patients with HIV lab test (temporarily use any, ldl measure table record)

# cohorts loading from public ATLAS server:

# cohortId,atlasId,name
# 1769961,1769961,Male50plus
# 1769440,1769440,HIV_Patient
# 1770612,1770612,HIV_patient_by_LOINC_codes
# 99321,99321,Alendronate
# 99322,99322,Raloxifene
# 99323,99323,HipFracture
# 100792,100792,NoHipVertFx
# 100791,100791,VertebralFracture
# 100793,100793,OsteonecrosisOfJaw
# 100794,100794,EsophagealCancer
# 100795,100795,AtypicalFF
# 1769024,1769024,Thromboembolism
# 1769043,1769043,AcuteStroke%

# things start breaking in CreateCohorts when this one is added:
# 1770614,1770614,HIV_by_1_SNOMED_Dx    # SG, 6/12/2019: this isn't breaking things anymore. not sure why

# Insert cohort definitions from ATLAS into package -----------------------

library(ROhdsiWebApi)

for.debugging <- function() {
  browser()

  ROhdsiWebApi::insertCohortDefinitionInPackage(
    definitionId = 1771506,
    name = "eunomia_onek",
    baseUrl = "http://18.213.176.21:80/WebAPI",# "http://18.213.176.21:80/WebAPI"
    generateStats = FALSE
  )

  OhdsiRTools::insertCohortDefinitionInPackage(
    definitionId = 1771506,
    name = "eunomia_onek",
    baseUrl = "http://18.213.176.21:80/WebAPI",# "http://18.213.176.21:80/WebAPI"
    generateStats = FALSE
  )
  OhdsiRTools::insertCohortDefinitionSetInPackage(fileName = "CohortsToCreate.csv",
                                                  baseUrl = "http://18.213.176.21:80/WebAPI",
                                                  insertTableSql = TRUE,
                                                  insertCohortCreationR = FALSE, #TRUE,
                                                  generateStats = FALSE,
                                                  packageName = 'HivDescriptive'
  )
}
for.debugging()

# Error in readChar(fileName, file.info(fileName)$size) :
#   invalid 'nchars' argument
# In addition: Warning message:
#   In file(con, "rb") :
#   file("") only supports open = "w+" and open = "w+b": using the former

# command above produces error but seems to work. it creates the right files. To do them one by
#   one without error messages, use commands below

#
# OhdsiRTools::insertCohortDefinitionInPackage(
#   definitionId = 1769440,
#   name = "HIV patient",
#   baseUrl = Sys.getenv("WebAPIBaseUrl"),# "http://18.213.176.21:80/WebAPI"
#   generateStats = FALSE
# )

#FeatureExtraction::createAnalysisDetails()
