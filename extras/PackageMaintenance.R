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

# Insert cohort definitions from ATLAS into package -----------------------
OhdsiRTools::insertCohortDefinitionSetInPackage(fileName = "CohortsToCreate.csv",
                                                baseUrl = "http://18.213.176.21:80/WebAPI",
                                                insertTableSql = TRUE,
                                                insertCohortCreationR = FALSE, #TRUE,
                                                generateStats = FALSE,
                                                packageName = 'HivDescriptive'
                                                )
# Error in readChar(fileName, file.info(fileName)$size) :
#   invalid 'nchars' argument
# In addition: Warning message:
#   In file(con, "rb") :
#   file("") only supports open = "w+" and open = "w+b": using the former

# command above produces error but seems to work. it creates the right files. To do them one by
#   one without error messages, use commands below

# OhdsiRTools::insertCohortDefinitionInPackage(
#   definitionId = 1769961,
#   name = "Male50plus",
#   baseUrl = Sys.getenv("WebAPIBaseUrl"),# "http://18.213.176.21:80/WebAPI"
#   generateStats = FALSE
# )
#
# OhdsiRTools::insertCohortDefinitionInPackage(
#   definitionId = 1769440,
#   name = "HIV patient",
#   baseUrl = Sys.getenv("WebAPIBaseUrl"),# "http://18.213.176.21:80/WebAPI"
#   generateStats = FALSE
# )

#FeatureExtraction::createAnalysisDetails()
