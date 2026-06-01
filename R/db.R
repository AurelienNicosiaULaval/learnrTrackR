#' Initialize a tracking SQLite database
#'
#' Creates a SQLite database if needed, creates the tracking schema, and returns
#' an open DBI connection. Existing data are preserved unless `overwrite = TRUE`.
#'
#' @param path Path to the SQLite database file.
#' @param overwrite If `TRUE`, remove an existing database file before creating
#'   a new one. If `FALSE`, keep the existing file and create missing tables.
#'
#' @return A DBI connection.
#' @export
#'
#' @examples
#' db_path <- tempfile(fileext = ".sqlite")
#' con <- init_tracking_db(db_path, overwrite = TRUE)
#' DBI::dbDisconnect(con)
init_tracking_db <- function(path, overwrite = FALSE) {
  path <- validate_path(path)
  overwrite <- validate_scalar_logical(overwrite, arg = "overwrite")

  parent_dir <- dirname(path)
  if (!dir.exists(parent_dir)) {
    cli::cli_abort("The parent directory of {.arg path} does not exist.")
  }

  if (file.exists(path) && overwrite) {
    unlink(path)

    if (file.exists(path)) {
      cli::cli_abort("Could not remove the existing database at {.path {path}}.")
    }
  }

  con <- DBI::dbConnect(RSQLite::SQLite(), path)

  tryCatch(
    {
      create_schema(con)
      check_required_tables(con)
      con
    },
    error = function(cnd) {
      if (DBI::dbIsValid(con)) {
        DBI::dbDisconnect(con)
      }

      stop(cnd)
    }
  )
}

#' Connect to an existing tracking SQLite database
#'
#' Opens a SQLite database and checks that all required tracking tables are
#' present. Use [init_tracking_db()] to create a new database or to add missing
#' tables to an existing file.
#'
#' @param path Path to an existing SQLite database file.
#'
#' @return A DBI connection.
#' @export
#'
#' @examples
#' db_path <- tempfile(fileext = ".sqlite")
#' con <- init_tracking_db(db_path, overwrite = TRUE)
#' DBI::dbDisconnect(con)
#'
#' con <- connect_tracking_db(db_path)
#' DBI::dbDisconnect(con)
connect_tracking_db <- function(path) {
  path <- validate_path(path)

  if (!file.exists(path)) {
    cli::cli_abort("The database file does not exist: {.path {path}}.")
  }

  con <- DBI::dbConnect(RSQLite::SQLite(), path)

  tryCatch(
    {
      check_required_tables(con)
      con
    },
    error = function(cnd) {
      if (DBI::dbIsValid(con)) {
        DBI::dbDisconnect(con)
      }

      stop(cnd)
    }
  )
}
