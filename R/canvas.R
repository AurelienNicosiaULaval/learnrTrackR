canvas_identifier_columns <- function() {
  c("ID", "SIS User ID", "SIS Login ID")
}

canvas_reserved_columns <- function() {
  c(
    "Student",
    canvas_identifier_columns(),
    "Section",
    "Integration ID",
    "Root Account"
  )
}

canvas_forbidden_assignment_terms <- function() {
  c(
    "Current Score",
    "Current Points",
    "Current Grade",
    "Final Score",
    "Final Points",
    "Final Grade",
    "Override Score",
    "Override Grade",
    "Override Status"
  )
}

validate_canvas_assignment <- function(assignment) {
  assignment <- validate_scalar_character(assignment, arg = "assignment")

  if (assignment %in% canvas_reserved_columns()) {
    cli::cli_abort(
      "{.arg assignment} must not use a Canvas reserved column name."
    )
  }

  forbidden <- canvas_forbidden_assignment_terms()
  has_forbidden <- vapply(
    forbidden,
    function(term) grepl(term, assignment, fixed = TRUE),
    logical(1)
  )

  if (any(has_forbidden)) {
    cli::cli_abort(c(
      "{.arg assignment} contains text reserved by Canvas Gradebook import.",
      "x" = "Forbidden text: {forbidden[has_forbidden]}."
    ))
  }

  assignment
}

validate_canvas_student_id_column <- function(student_id_column) {
  student_id_column <- validate_scalar_character(
    student_id_column,
    arg = "student_id_column"
  )

  allowed <- canvas_identifier_columns()

  if (!student_id_column %in% allowed) {
    cli::cli_abort(c(
      "{.arg student_id_column} must be one of the Canvas identifier columns.",
      "i" = "Allowed values: {allowed}."
    ))
  }

  student_id_column
}

validate_canvas_student_id_source <- function(student_id_source) {
  student_id_source <- validate_scalar_character(
    student_id_source,
    arg = "student_id_source"
  )

  allowed <- c("student_id", "student_label", "email")

  if (!student_id_source %in% allowed) {
    cli::cli_abort(c(
      "{.arg student_id_source} must name a supported student metadata column.",
      "i" = "Allowed values: {allowed}."
    ))
  }

  student_id_source
}

validate_canvas_section <- function(section) {
  section <- validate_scalar_character(section, arg = "section")
  allowed <- c("group_id", "blank")

  if (!section %in% allowed) {
    cli::cli_abort(c(
      "{.arg section} must be {.val group_id} or {.val blank}.",
      "i" = "Use {.val group_id} to copy registered group identifiers to the Canvas Section column."
    ))
  }

  section
}

add_canvas_student_metadata <- function(grades, registered_students) {
  metadata <- registered_students[
    ,
    c("student_id", "student_label", "email", "group_id"),
    drop = FALSE
  ]

  out <- dplyr::left_join(grades, metadata, by = "student_id")

  missing_label <- is.na(out$student_label) | !nzchar(out$student_label)
  out$student_label[missing_label] <- out$student_id[missing_label]

  for (field in c("email", "group_id")) {
    out[[field]][is.na(out[[field]])] <- ""
  }

  out
}

canvas_student_identifier <- function(grades, student_id_source) {
  if (!student_id_source %in% names(grades)) {
    cli::cli_abort(
      "{.arg student_id_source} is not available in the grade data."
    )
  }

  values <- trimws(as.character(grades[[student_id_source]]))
  missing <- is.na(values) | !nzchar(values)

  if (any(missing)) {
    missing_ids <- grades$student_id[missing]
    cli::cli_abort(c(
      "Canvas student identifiers must not be missing.",
      "x" = "Missing {.field {student_id_source}} for student{?s}: {missing_ids}."
    ))
  }

  values
}

canvas_section_values <- function(grades, section) {
  if (identical(section, "blank")) {
    return(rep("", nrow(grades)))
  }

  values <- as.character(grades$group_id)
  values[is.na(values)] <- ""
  values
}

canvas_grades_from_gradebook <- function(grades,
                                         tutorial_id,
                                         assignment = NULL,
                                         student_id_column = "SIS User ID",
                                         student_id_source = "student_id",
                                         grade_value = c("score", "percent"),
                                         digits = 2,
                                         section = c("group_id", "blank")) {
  tutorial_id <- validate_scalar_character(tutorial_id, arg = "tutorial_id")
  assignment <- validate_scalar_character(
    assignment,
    arg = "assignment",
    allow_null = TRUE
  )
  student_id_column <- validate_canvas_student_id_column(student_id_column)
  student_id_source <- validate_canvas_student_id_source(student_id_source)
  grade_value <- match.arg(grade_value)
  digits <- validate_digits(digits)
  section <- match.arg(section)
  section <- validate_canvas_section(section)

  if (is.null(assignment)) {
    assignment <- tutorial_id
  }

  assignment <- validate_canvas_assignment(assignment)

  n <- nrow(grades)
  out <- tibble::tibble(
    Student = character(n),
    ID = character(n),
    `SIS User ID` = character(n),
    `SIS Login ID` = character(n),
    Section = character(n)
  )
  out[[assignment]] <- numeric(n)

  if (n == 0) {
    return(out)
  }

  out$Student <- grades$student_label
  out[[student_id_column]] <- canvas_student_identifier(
    grades,
    student_id_source = student_id_source
  )
  out$Section <- canvas_section_values(grades, section = section)
  out[[assignment]] <- format_grade_values(grades[[grade_value]], digits = digits)

  out
}

#' Create a Canvas Gradebook CSV table
#'
#' Builds a Canvas-style Gradebook CSV table with the standard leading columns
#' `Student`, `ID`, `SIS User ID`, `SIS Login ID`, `Section`, and one
#' assignment grade column. By default, `learnrTrackR` student identifiers are
#' exported to `SIS User ID` and raw gradebook scores are exported as points.
#'
#' The exported identifiers must match the identifiers used by the target
#' Canvas course. When in doubt, export the current Canvas Gradebook first and
#' compare the identifier columns before importing.
#'
#' @param con A DBI connection.
#' @param tutorial_id Tutorial identifier. Required.
#' @param rule Scoring rule passed to [gradebook()].
#' @param assignment Column name for the Canvas assignment. Defaults to
#'   `tutorial_id`.
#' @param student_id_column Canvas identifier column to populate. Use
#'   `"SIS User ID"`, `"SIS Login ID"`, or `"ID"`.
#' @param student_id_source Student metadata column used to populate
#'   `student_id_column`. Use `"student_id"`, `"student_label"`, or `"email"`.
#' @param grade_value Which gradebook value to export. Use `"score"` for raw
#'   points or `"percent"` for a 0-100 grade.
#' @param digits Number of decimal places used to round exported grades. Use
#'   `NULL` to disable rounding.
#' @param include_unregistered If `TRUE`, include attempted questions that were
#'   not registered with [register_questions()].
#' @param group_id Optional registered student group identifier. If supplied,
#'   only students in that registered group are exported.
#' @param section Use `"group_id"` to copy registered groups to the Canvas
#'   `Section` column, or `"blank"` to leave the section column empty.
#'
#' @return A tibble with one row per student.
#' @export
#'
#' @examples
#' db_path <- tempfile(fileext = ".sqlite")
#' con <- init_tracking_db(db_path, overwrite = TRUE)
#' register_students(con, data.frame(student_id = "student_001", group_id = "A"))
#' register_questions(con, "module_01", c("q1", "q2"))
#' track_attempt(con, "student_001", "module_01", "q1", "mean(x)", score = 1, max_score = 1)
#' canvas_grades(con, tutorial_id = "module_01")
#' DBI::dbDisconnect(con)
canvas_grades <- function(con,
                          tutorial_id,
                          rule = c("last", "best", "first"),
                          assignment = NULL,
                          student_id_column = "SIS User ID",
                          student_id_source = "student_id",
                          grade_value = c("score", "percent"),
                          digits = 2,
                          include_unregistered = TRUE,
                          group_id = NULL,
                          section = c("group_id", "blank")) {
  check_required_tables(con)

  tutorial_id <- validate_scalar_character(tutorial_id, arg = "tutorial_id")
  rule <- match.arg(rule)
  grade_value <- match.arg(grade_value)
  include_unregistered <- validate_scalar_logical(
    include_unregistered,
    arg = "include_unregistered"
  )
  group_id <- normalize_dashboard_group_id(group_id)

  if (is.null(group_id)) {
    grades <- gradebook(
      con,
      tutorial_id = tutorial_id,
      rule = rule,
      include_unregistered = include_unregistered
    )
  } else {
    student_ids <- resolve_export_student_ids(
      con,
      tutorial_id = tutorial_id,
      group_id = group_id
    )
    grades <- dashboard_gradebook(
      con = con,
      tutorial_id = tutorial_id,
      student_ids = student_ids,
      rule = rule,
      include_unregistered = include_unregistered
    )
  }

  grades <- add_canvas_student_metadata(
    grades = grades,
    registered_students = get_students(con)
  )

  canvas_grades_from_gradebook(
    grades = grades,
    tutorial_id = tutorial_id,
    assignment = assignment,
    student_id_column = student_id_column,
    student_id_source = student_id_source,
    grade_value = grade_value,
    digits = digits,
    section = section
  )
}

#' Export Canvas Gradebook grades to CSV
#'
#' Writes the output of [canvas_grades()] to a CSV file with
#' [readr::write_csv()].
#'
#' @inheritParams canvas_grades
#' @param path Output CSV path.
#'
#' @return The output path, invisibly.
#' @export
#'
#' @examples
#' db_path <- tempfile(fileext = ".sqlite")
#' csv_path <- tempfile(fileext = ".csv")
#' con <- init_tracking_db(db_path, overwrite = TRUE)
#' register_students(con, data.frame(student_id = "student_001", group_id = "A"))
#' register_questions(con, "module_01", c("q1", "q2"))
#' track_attempt(con, "student_001", "module_01", "q1", "mean(x)", score = 1, max_score = 1)
#' export_canvas_grades(con, csv_path, tutorial_id = "module_01")
#' DBI::dbDisconnect(con)
export_canvas_grades <- function(con,
                                 path,
                                 tutorial_id,
                                 rule = c("last", "best", "first"),
                                 assignment = NULL,
                                 student_id_column = "SIS User ID",
                                 student_id_source = "student_id",
                                 grade_value = c("score", "percent"),
                                 digits = 2,
                                 include_unregistered = TRUE,
                                 group_id = NULL,
                                 section = c("group_id", "blank")) {
  path <- validate_path(path)

  parent_dir <- dirname(path)
  if (!dir.exists(parent_dir)) {
    cli::cli_abort("The parent directory of {.arg path} does not exist.")
  }

  data <- canvas_grades(
    con = con,
    tutorial_id = tutorial_id,
    rule = rule,
    assignment = assignment,
    student_id_column = student_id_column,
    student_id_source = student_id_source,
    grade_value = grade_value,
    digits = digits,
    include_unregistered = include_unregistered,
    group_id = group_id,
    section = section
  )

  readr::write_csv(data, path)

  invisible(path)
}
