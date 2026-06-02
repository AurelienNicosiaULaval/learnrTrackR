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

tracking_config_template_tables <- function() {
  list(
    courses = tibble::tibble(
      course_id = "stat101",
      course_label = "Statistics 101",
      semester = "W2026"
    ),
    tutorials = tibble::tibble(
      tutorial_id = "module_01",
      course_id = "stat101",
      tutorial_label = "Module 1",
      version = "0.0.1"
    ),
    students = tibble::tibble(
      student_id = c("student_001", "student_002"),
      student_label = c("Student 001", "Student 002"),
      email = c("student_001@example.org", "student_002@example.org"),
      group_id = c("A", "A")
    ),
    questions = tibble::tibble(
      tutorial_id = "module_01",
      question_id = c("q1", "q2"),
      question_label = c("Question 1", "Question 2"),
      question_type = c("radio", "numeric"),
      max_score = c(1, 1)
    )
  )
}

tracking_template_yaml_lines <- function() {
  c(
    "courses:",
    "  - course_id: stat101",
    "    course_label: Statistics 101",
    "    semester: W2026",
    "tutorials:",
    "  - tutorial_id: module_01",
    "    course_id: stat101",
    "    tutorial_label: Module 1",
    "    version: 0.0.1",
    "students:",
    "  - student_id: student_001",
    "    student_label: Student 001",
    "    email: student_001@example.org",
    "    group_id: A",
    "  - student_id: student_002",
    "    student_label: Student 002",
    "    email: student_002@example.org",
    "    group_id: A",
    "questions:",
    "  - tutorial_id: module_01",
    "    question_id: q1",
    "    question_label: Question 1",
    "    question_type: radio",
    "    max_score: 1",
    "  - tutorial_id: module_01",
    "    question_id: q2",
    "    question_label: Question 2",
    "    question_type: numeric",
    "    max_score: 1"
  )
}

write_tracking_config_template_csv <- function(path, overwrite) {
  if (file.exists(path) && !dir.exists(path)) {
    cli::cli_abort(
      "The CSV tracking configuration path exists and is not a directory: {.path {path}}."
    )
  }

  if (!dir.exists(path)) {
    dir.create(path, recursive = TRUE)
  }

  tables <- tracking_config_template_tables()
  output <- tibble::tibble(
    component = names(tables),
    path = file.path(path, paste0(names(tables), ".csv"))
  )

  existing <- output$path[file.exists(output$path)]

  if (length(existing) > 0 && !overwrite) {
    cli::cli_abort(c(
      "Tracking configuration template files already exist.",
      "x" = "Existing paths: {.path {existing}}.",
      "i" = "Use {.code overwrite = TRUE} to replace existing template files."
    ))
  }

  for (row_index in seq_len(nrow(output))) {
    readr::write_csv(tables[[output$component[[row_index]]]], output$path[[row_index]])
  }

  output
}

write_tracking_config_template_yaml <- function(path, overwrite) {
  if (dir.exists(path)) {
    cli::cli_abort(
      "The YAML tracking configuration template path is a directory: {.path {path}}."
    )
  }

  if (file.exists(path) && !overwrite) {
    cli::cli_abort(c(
      "The tracking configuration template file already exists.",
      "x" = "{.path {path}}.",
      "i" = "Use {.code overwrite = TRUE} to replace it."
    ))
  }

  parent_dir <- dirname(path)

  if (!dir.exists(parent_dir)) {
    dir.create(parent_dir, recursive = TRUE)
  }

  writeLines(tracking_template_yaml_lines(), path)

  tibble::tibble(
    component = "yaml",
    path = path
  )
}

#' Create a tracking configuration template
#'
#' Creates a small, ready-to-edit tracking configuration template. The template
#' can be written either as a directory of CSV files or as one YAML file.
#'
#' @param path Output path. For `format = "csv"`, this is a directory. For
#'   `format = "yaml"`, this is a YAML file path.
#' @param format Template format. One of `"csv"` or `"yaml"`.
#' @param overwrite If `TRUE`, replace existing template files at `path`.
#'   Defaults to `FALSE`.
#'
#' @return A tibble with the created template component names and file paths,
#'   invisibly.
#' @export
#'
#' @examples
#' config_dir <- tempfile()
#' create_tracking_config_template(config_dir, format = "csv")
#' read_tracking_config(config_dir)
create_tracking_config_template <- function(path,
                                            format = c("csv", "yaml"),
                                            overwrite = FALSE) {
  path <- validate_path(path, arg = "path")
  format <- match.arg(format)
  overwrite <- validate_scalar_logical(overwrite, arg = "overwrite")

  created <- switch(
    format,
    csv = write_tracking_config_template_csv(path, overwrite = overwrite),
    yaml = write_tracking_config_template_yaml(path, overwrite = overwrite)
  )

  invisible(created)
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
