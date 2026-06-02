validate_digits <- function(digits) {
  if (is.null(digits)) {
    return(NULL)
  }

  validate_positive_integer(digits, arg = "digits")
}

format_grade_values <- function(values, digits) {
  if (is.null(digits)) {
    return(values)
  }

  round(values, digits = digits)
}

#' Create a Moodle-ready grade CSV table
#'
#' Builds a simple wide grade table suitable for Moodle CSV import mapping: one
#' student identifier column and one grade item column. In Moodle, the teacher
#' maps the identifier column to the matching user field and the grade item
#' column to an existing grade item.
#'
#' @param con A DBI connection.
#' @param tutorial_id Tutorial identifier. Required.
#' @param rule Scoring rule passed to [gradebook()].
#' @param grade_item Column name for the Moodle grade item. Defaults to
#'   `tutorial_id`.
#' @param id_column Column name for the exported student identifier. Defaults to
#'   `"useridnumber"`, a common Moodle mapping target for institutional student
#'   identifiers.
#' @param grade_value Which gradebook value to export. Use `"percent"` for a
#'   0-100 grade or `"score"` for the raw score.
#' @param digits Number of decimal places used to round exported grades. Use
#'   `NULL` to disable rounding.
#' @param include_unregistered If `TRUE`, include attempted questions that were
#'   not registered with [register_questions()].
#'
#' @return A tibble with one row per student.
#' @export
#'
#' @examples
#' db_path <- tempfile(fileext = ".sqlite")
#' con <- init_tracking_db(db_path, overwrite = TRUE)
#' register_questions(con, "module_01", c("q1", "q2"))
#' track_attempt(con, "student_001", "module_01", "q1", "mean(x)", score = 1, max_score = 1)
#' moodle_grades(con, tutorial_id = "module_01")
#' DBI::dbDisconnect(con)
moodle_grades <- function(con,
                          tutorial_id,
                          rule = c("last", "best", "first"),
                          grade_item = NULL,
                          id_column = "useridnumber",
                          grade_value = c("percent", "score"),
                          digits = 2,
                          include_unregistered = TRUE) {
  check_required_tables(con)

  tutorial_id <- validate_scalar_character(tutorial_id, arg = "tutorial_id")
  rule <- match.arg(rule)
  grade_value <- match.arg(grade_value)
  grade_item <- validate_scalar_character(
    grade_item,
    arg = "grade_item",
    allow_null = TRUE
  )
  id_column <- validate_scalar_character(id_column, arg = "id_column")
  digits <- validate_digits(digits)
  include_unregistered <- validate_scalar_logical(
    include_unregistered,
    arg = "include_unregistered"
  )

  if (is.null(grade_item)) {
    grade_item <- tutorial_id
  }

  if (identical(id_column, grade_item)) {
    cli::cli_abort(
      "{.arg id_column} and {.arg grade_item} must use different column names."
    )
  }

  grades <- gradebook(
    con,
    tutorial_id = tutorial_id,
    rule = rule,
    include_unregistered = include_unregistered
  )

  if (nrow(grades) == 0) {
    out <- tibble::tibble(
      student_id = character(),
      grade = numeric()
    )
  } else {
    out <- tibble::tibble(
      student_id = grades$student_id,
      grade = format_grade_values(grades[[grade_value]], digits = digits)
    )
  }

  names(out) <- c(id_column, grade_item)
  out
}

#' Export Moodle-ready grades to CSV
#'
#' Writes the output of [moodle_grades()] to a CSV file with
#' [readr::write_csv()].
#'
#' @inheritParams moodle_grades
#' @param path Output CSV path.
#'
#' @return The output path, invisibly.
#' @export
#'
#' @examples
#' db_path <- tempfile(fileext = ".sqlite")
#' csv_path <- tempfile(fileext = ".csv")
#' con <- init_tracking_db(db_path, overwrite = TRUE)
#' register_questions(con, "module_01", c("q1", "q2"))
#' track_attempt(con, "student_001", "module_01", "q1", "mean(x)", score = 1, max_score = 1)
#' export_moodle_grades(con, csv_path, tutorial_id = "module_01")
#' DBI::dbDisconnect(con)
export_moodle_grades <- function(con,
                                 path,
                                 tutorial_id,
                                 rule = c("last", "best", "first"),
                                 grade_item = NULL,
                                 id_column = "useridnumber",
                                 grade_value = c("percent", "score"),
                                 digits = 2,
                                 include_unregistered = TRUE) {
  path <- validate_path(path)

  parent_dir <- dirname(path)
  if (!dir.exists(parent_dir)) {
    cli::cli_abort("The parent directory of {.arg path} does not exist.")
  }

  data <- moodle_grades(
    con = con,
    tutorial_id = tutorial_id,
    rule = rule,
    grade_item = grade_item,
    id_column = id_column,
    grade_value = grade_value,
    digits = digits,
    include_unregistered = include_unregistered
  )

  readr::write_csv(data, path)

  invisible(path)
}
