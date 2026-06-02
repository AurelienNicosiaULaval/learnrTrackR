empty_config_tibble <- function() {
  tibble::tibble()
}

as_config_tibble <- function(x, name) {
  if (is.null(x)) {
    return(empty_config_tibble())
  }

  if (is.data.frame(x)) {
    return(tibble::as_tibble(x))
  }

  if (is.list(x)) {
    if (length(x) == 0) {
      return(empty_config_tibble())
    }

    return(tibble::as_tibble(dplyr::bind_rows(x)))
  }

  cli::cli_abort(
    "{.field {name}} in the tracking configuration must be a table or list."
  )
}

read_optional_config_csv <- function(path, name) {
  csv_path <- file.path(path, paste0(name, ".csv"))

  if (!file.exists(csv_path)) {
    return(empty_config_tibble())
  }

  readr::read_csv(csv_path, show_col_types = FALSE)
}

read_tracking_config_directory <- function(path) {
  config <- list(
    courses = read_optional_config_csv(path, "courses"),
    tutorials = read_optional_config_csv(path, "tutorials"),
    students = read_optional_config_csv(path, "students"),
    questions = read_optional_config_csv(path, "questions")
  )

  if (all(vapply(config, nrow, integer(1)) == 0)) {
    cli::cli_abort(
      "No configuration CSV files were found in {.path {path}}."
    )
  }

  config
}

read_tracking_config_yaml <- function(path) {
  if (!requireNamespace("yaml", quietly = TRUE)) {
    cli::cli_abort(
      "Package {.pkg yaml} is required to read YAML tracking configuration files."
    )
  }

  raw_config <- yaml::read_yaml(path)

  if (is.null(raw_config) || !is.list(raw_config)) {
    cli::cli_abort(
      "The YAML tracking configuration must contain a top-level mapping."
    )
  }

  list(
    courses = as_config_tibble(raw_config$courses, "courses"),
    tutorials = as_config_tibble(raw_config$tutorials, "tutorials"),
    students = as_config_tibble(raw_config$students, "students"),
    questions = as_config_tibble(raw_config$questions, "questions")
  )
}

#' Read a tracking configuration
#'
#' Reads a declarative tracking configuration from either a YAML file or a
#' directory of CSV files. CSV directories may contain `courses.csv`,
#' `tutorials.csv`, `students.csv`, and `questions.csv`.
#'
#' @param path Path to a YAML file or a directory of CSV files.
#'
#' @return A list with `courses`, `tutorials`, `students`, and `questions`
#'   tibbles.
#' @export
#'
#' @examples
#' config_dir <- tempfile()
#' dir.create(config_dir)
#' readr::write_csv(
#'   data.frame(course_id = "stat101"),
#'   file.path(config_dir, "courses.csv")
#' )
#' read_tracking_config(config_dir)
read_tracking_config <- function(path) {
  path <- validate_path(path, arg = "path")

  if (!file.exists(path)) {
    cli::cli_abort("The configuration path does not exist: {.path {path}}.")
  }

  if (dir.exists(path)) {
    return(read_tracking_config_directory(path))
  }

  extension <- tolower(tools::file_ext(path))

  if (extension %in% c("yaml", "yml")) {
    return(read_tracking_config_yaml(path))
  }

  cli::cli_abort(
    "Tracking configuration must be a YAML file or a directory of CSV files."
  )
}

register_config_questions <- function(con,
                                      questions,
                                      overwrite_questions,
                                      timestamp) {
  if (nrow(questions) == 0) {
    return(get_questions(con))
  }

  if (!"tutorial_id" %in% names(questions)) {
    cli::cli_abort(
      "{.field questions} must contain a {.field tutorial_id} column."
    )
  }

  tutorial_ids <- unique(as.character(questions$tutorial_id))

  for (current_tutorial_id in tutorial_ids) {
    current_questions <- questions[
      as.character(questions$tutorial_id) == current_tutorial_id,
      ,
      drop = FALSE
    ]

    register_questions(
      con,
      tutorial_id = current_tutorial_id,
      questions = current_questions,
      overwrite = overwrite_questions,
      timestamp = timestamp
    )
  }

  get_questions(con)
}

#' Load a tracking configuration into a database
#'
#' Reads a YAML or CSV-directory tracking configuration and registers courses,
#' tutorials, students, and questions in the tracking database.
#'
#' @param con A DBI connection.
#' @param path Path to a YAML file or a directory containing configuration CSV
#'   files.
#' @param overwrite_questions If `TRUE`, replace existing registered questions
#'   for tutorials included in the configuration. If `FALSE`, upsert supplied
#'   questions and keep other registered questions.
#' @param timestamp Creation timestamp for inserted rows. Defaults to
#'   `Sys.time()`.
#'
#' @return A list with registered `courses`, `tutorials`, `students`, and
#'   `questions` tibbles.
#' @export
#'
#' @examples
#' config_dir <- tempfile()
#' dir.create(config_dir)
#' readr::write_csv(
#'   data.frame(course_id = "stat101"),
#'   file.path(config_dir, "courses.csv")
#' )
#'
#' db_path <- tempfile(fileext = ".sqlite")
#' con <- init_tracking_db(db_path, overwrite = TRUE)
#' load_tracking_config(con, config_dir)
#' DBI::dbDisconnect(con)
load_tracking_config <- function(con,
                                 path,
                                 overwrite_questions = FALSE,
                                 timestamp = Sys.time()) {
  check_required_tables(con)

  overwrite_questions <- validate_scalar_logical(
    overwrite_questions,
    arg = "overwrite_questions"
  )
  timestamp <- normalize_timestamp(timestamp)
  config <- read_tracking_config(path)

  if (nrow(config$courses) > 0) {
    register_courses(con, config$courses, timestamp = timestamp)
  }

  if (nrow(config$tutorials) > 0) {
    register_tutorials(con, config$tutorials, timestamp = timestamp)
  }

  if (nrow(config$students) > 0) {
    register_students(con, config$students, timestamp = timestamp)
  }

  if (nrow(config$questions) > 0) {
    register_config_questions(
      con,
      questions = config$questions,
      overwrite_questions = overwrite_questions,
      timestamp = timestamp
    )
  }

  list(
    courses = get_courses(con),
    tutorials = get_tutorials(con),
    students = get_students(con),
    questions = get_questions(con)
  )
}
