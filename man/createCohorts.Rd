% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/CreateCohorts.R
\name{createCohorts}
\alias{createCohorts}
\title{Initialize HivDescriptive Tables}
\usage{
createCohorts(connection, cdmDatabaseSchema,
  vocabularyDatabaseSchema = cdmDatabaseSchema, cohortDatabaseSchema,
  cohortTable, oracleTempSchema, outputFolder)
}
\arguments{
\item{connectionDetails}{An object of type \code{connectionDetails} as created using the
\code{\link[DatabaseConnector]{createConnectionDetails}} function in the
DatabaseConnector package.}

\item{targetDatabaseSchema}{The schema to contain the study results tables}

\item{tablePrefix}{A prefix to add to the study tables}
}
\description{
Initialize HivDescriptive Tables
}
\details{
This function initializes the HivDescriptive Study tables.
}
\examples{
\dontrun{
connectionDetails <- DatatbaseConnector:: createConnectionDetails(dbms = "postgresql",
                                             user = "joe",
                                             password = "secret",
                                             server = "myserver")

execute(connectionDetails,
        targetDatabaseSchema = "studyDB.endoStudy",
        tablePrefix="endo_")
}

}
