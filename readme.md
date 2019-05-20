# HIV


This study aims to study HIV.

Detailed information is available in the [protocol](https://github.com/Sigfried/HivDescriptive/blob/master/extras/HIV_protocol.docx?raw=true).

Requirements
============

- A database in [Common Data Model version 5](https://github.com/OHDSI/CommonDataModel) in one of these platforms: SQL Server, Oracle, PostgreSQL, IBM Netezza, Apache Impala, Amazon RedShift, or Microsoft APS.
- R version 3.4.0 or newer
- On Windows: [RTools](http://cran.r-project.org/bin/windows/Rtools/)
- [Java](http://java.com)
- 25 GB of free disk space

See [this video](https://youtu.be/K9_0s2Rchbo) for instructions on how to set up the R environment on Windows.

How to run
==========
1. In `R`, use the following code to install the study package and its dependencies:
```r
	install.packages("devtools")
	library(devtools)
	install_github("ohdsi/SqlRender")
	install_github("ohdsi/DatabaseConnector")
	install_github("ohdsi/OhdsiRTools")
	install_github("ohdsi/OhdsiSharing")
	install_github("ohdsi/FeatureExtraction")
	install_github("ohdsi/CohortMethod")
	install_github("sigfried/HiVDescriptive")
```

	If you experience problems on Windows where rJava can't find Java, one solution may be to add `args = "--no-multiarch"` to each `install_github` call, for example:
	
	```r
	install_github("ohdsi/SqlRender", args = "--no-multiarch")
	```
	
	Alternatively, ensure that you have installed both 32-bit and 64-bit JDK versions, as mentioned in the [video tutorial](https://youtu.be/K9_0s2Rchbo).
	
2. Once installed, you can execute the study by modifying and using the following code:
	
	```r
	library(HivDescritive)
	
	connectionDetails <- createConnectionDetails(dbms = "postgresql",
																						 user = "joe",
																						 password = "secret",
																						 server = "myserver")
	cdmDatabaseSchema <- "cdm_data"
	cohortDatabaseSchema <- "results"
	cohortTable <- "hiv_descriptive"
	outputfolder <- "c:/temp/study_results"
	
	execute(connectionDetails = connectionDetails,
				cdmDatabaseSchema = cdmDatabaseSchema,
				cohortDatabaseSchema = cohortDatabaseSchema,
				cohortTable = cohortTable,
				oracleTempSchema = NULL,
				outputFolder = outputfolder,
				createCohorts = TRUE,
				runAnalyses = TRUE,
				packageResults = TRUE,
				#maxCores = 30
				)
	```

	* For details on how to configure```createConnectionDetails``` in your environment type this for help:
	```r
	?createConnectionDetails
	```
	* ```cdmDatabaseSchema``` should specify the schema name where your data in OMOP CDM format resides. Note that for SQL Server, this should include both the database and schema name, for example 'cdm_data.dbo'.
	
	* ```cohortDatabaseSchema``` should specify the schema name where intermediate results can be stored. Note that for SQL Server, this should include both the database and schema name, for example 'results.dbo'.
	
	* ```cohortTable``` should specify the name of the table that will be created in the work database schema where the exposure and outcomes cohorts will be stored. The default value is 'ohdsi_alendronate_raloxifene'.
	
	* ```oracleTempSchema``` should be used only by Oracle users to specify a schema where the user has write priviliges for storing temporary tables. This can be the same as the work database schema.
	
	* ```outputFolder``` a location in your local file system where results can be written. Make sure to use forward slashes (/). Do not use a folder on a network drive since this greatly impacts performance. 
	


3. Email the file (or use the uplaod)  ```export/studyResult.zip``` in the output folder to the study coordinator:
		```r
		submitResults("c:/temp/study_results/export", key = "<key>", secret = "<secret>")
		```
		Where ```key``` and ```secret``` are the credentials provided to you personally by the study coordinator.

## Getting Involved

* Developer questions/comments/feedback: <a href="http://forums.ohdsi.org/c/developers">OHDSI Forum</a>
* We use the <a href="../../issues">GitHub issue tracker</a> for all bugs/issues/enhancements




## Development

Package  was developed in R Studio.

### Development status

In development and testing.
In production. We're running this study at multiple sites.
