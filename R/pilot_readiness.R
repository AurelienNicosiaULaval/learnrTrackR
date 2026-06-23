pilot_unique_values <- function(x) {
  x <- as.character(x)
  x <- x[!is.na(x) & nzchar(x)]
  sort(unique(x))
}

pilot_collapse_details <- function(x, max_items = 8L) {
  x <- pilot_unique_values(x)

  if (length(x) == 0) {
    return("")
  }

  shown <- utils::head(x, max_items)
  suffix <- if (length(x) > length(shown)) {
    paste0(" ... +", length(x) - length(shown), " more")
  } else {
    ""
  }

  paste0(paste(shown, collapse = ", "), suffix)
}

pilot_check_row <- function(check,
                            status,
                            n,
                            message,
                            details = character()) {
  tibble::tibble(
    check = check,
    status = status,
    n = as.integer(n),
    message = message,
    details = pilot_collapse_details(details)
  )
}

pilot_identifier_problems <- function(values) {
  values <- as.character(values)
  empty <- is.na(values) | !nzchar(values)
  non_empty <- values[!empty]
  duplicates <- sort(unique(non_empty[duplicated(non_empty)]))

  list(
    n_empty = sum(empty),
    duplicates = duplicates,
    n = sum(empty) + length(duplicates)
  )
}

pilot_identifier_details <- function(problems) {
  details <- problems$duplicates

  if (problems$n_empty > 0) {
    details <- c(paste0("empty values: ", problems$n_empty), details)
  }

  details
}

#' Check pilot readiness before teacher exports
#'
#' Runs a compact set of consistency checks before using tracked tutorial data
#' for a controlled pilot or LMS-oriented export. The checks focus on registered
#' students, registered questions, unexpected learners, unregistered attempted
#' questions, incomplete gradebook rows, and Moodle/Canvas export row
#' consistency.
#'
#' @param con A DBI connection.
#' @param tutorial_id Tutorial identifier. Required.
#' @param group_id Optional registered student group identifier. If supplied,
#'   checks and export counts are scoped to that group.
#' @param rule Scoring rule passed to [gradebook()] and export helpers.
#' @param include_unregistered If `TRUE`, gradebook calculations include
#'   attempted questions that were not registered with [register_questions()].
#' @param require_attempts If `TRUE`, no recorded attempt in the selected scope
#'   is reported as an error. If `FALSE`, it is reported as a warning.
#' @param require_all_students_attempted If `TRUE`, registered students without
#'   attempts in the selected scope are reported as an error. If `FALSE`, they
#'   are reported as a warning.
#' @param stop_on_error If `TRUE`, throw an error when any check has status
#'   `"error"`.
#'
#' @return A tibble with one row per check and columns `check`, `status`, `n`,
#'   `message`, and `details`.
#' @export
#'
#' @examples
#' db_path <- tempfile(fileext = ".sqlite")
#' con <- init_tracking_db(db_path, overwrite = TRUE)
#' register_students(con, data.frame(student_id = "student_001", group_id = "A"))
#' register_questions(con, "module_01", "q1")
#' track_attempt(con, "student_001", "module_01", "q1", "mean(x)", score = 1, max_score = 1)
#' check_pilot_readiness(con, tutorial_id = "module_01", group_id = "A")
#' DBI::dbDisconnect(con)
check_pilot_readiness <- function(con,
                                  tutorial_id,
                                  group_id = NULL,
                                  rule = c("last", "best", "first"),
                                  include_unregistered = TRUE,
                                  require_attempts = FALSE,
                                  require_all_students_attempted = FALSE,
                                  stop_on_error = FALSE) {
  check_required_tables(con)

  tutorial_id <- validate_scalar_character(tutorial_id, arg = "tutorial_id")
  group_id <- normalize_dashboard_group_id(group_id)
  rule <- match.arg(rule)
  include_unregistered <- validate_scalar_logical(
    include_unregistered,
    arg = "include_unregistered"
  )
  require_attempts <- validate_scalar_logical(
    require_attempts,
    arg = "require_attempts"
  )
  require_all_students_attempted <- validate_scalar_logical(
    require_all_students_attempted,
    arg = "require_all_students_attempted"
  )
  stop_on_error <- validate_scalar_logical(stop_on_error, arg = "stop_on_error")

  all_students <- get_students(con)
  registered_students <- filter_registered_students(all_students, group_id)
  questions <- get_questions(con, tutorial_id = tutorial_id)
  all_attempts <- get_attempts(con, tutorial_id = tutorial_id)
  scoped_attempts <- if (is.null(group_id)) {
    all_attempts
  } else {
    filter_attempts_by_student_ids(all_attempts, registered_students$student_id)
  }
  export_data <- tracking_export_data(
    con = con,
    tutorial_id = tutorial_id,
    group_id = group_id,
    rule = rule,
    include_unregistered = include_unregistered
  )

  rows <- list()

  if (is.null(group_id)) {
    rows[[length(rows) + 1L]] <- pilot_check_row(
      check = "group_filter",
      status = "ok",
      n = 0L,
      message = "No group filter is selected."
    )
  } else {
    group_known <- any(!is.na(all_students$group_id) & all_students$group_id == group_id)
    rows[[length(rows) + 1L]] <- pilot_check_row(
      check = "group_filter",
      status = if (group_known) "ok" else "error",
      n = if (group_known) nrow(registered_students) else 0L,
      message = if (group_known) {
        "The selected group exists in the student registry."
      } else {
        "The selected group does not exist in the student registry."
      },
      details = group_id
    )
  }

  rows[[length(rows) + 1L]] <- pilot_check_row(
    check = "registered_students",
    status = if (nrow(registered_students) > 0) "ok" else "error",
    n = nrow(registered_students),
    message = if (nrow(registered_students) > 0) {
      "Registered students are available for the selected scope."
    } else {
      "No registered students are available for the selected scope."
    }
  )

  rows[[length(rows) + 1L]] <- pilot_check_row(
    check = "registered_questions",
    status = if (nrow(questions) > 0) "ok" else "error",
    n = nrow(questions),
    message = if (nrow(questions) > 0) {
      "Registered questions are available for the tutorial."
    } else {
      "No registered questions are available for the tutorial."
    }
  )

  no_attempt_status <- if (require_attempts) "error" else "warning"
  rows[[length(rows) + 1L]] <- pilot_check_row(
    check = "recorded_attempts",
    status = if (nrow(scoped_attempts) > 0) "ok" else no_attempt_status,
    n = nrow(scoped_attempts),
    message = if (nrow(scoped_attempts) > 0) {
      "Recorded attempts are available for the selected scope."
    } else {
      "No recorded attempts are available for the selected scope."
    }
  )

  unexpected_students <- setdiff(
    pilot_unique_values(all_attempts$student_id),
    pilot_unique_values(all_students$student_id)
  )
  rows[[length(rows) + 1L]] <- pilot_check_row(
    check = "unexpected_students",
    status = if (length(unexpected_students) == 0) "ok" else "error",
    n = length(unexpected_students),
    message = if (length(unexpected_students) == 0) {
      "All attempted student identifiers are registered."
    } else {
      "Some attempts use student identifiers that are not registered."
    },
    details = unexpected_students
  )

  unregistered_questions <- setdiff(
    pilot_unique_values(scoped_attempts$question_id),
    pilot_unique_values(questions$question_id)
  )
  rows[[length(rows) + 1L]] <- pilot_check_row(
    check = "unregistered_questions",
    status = if (length(unregistered_questions) == 0) "ok" else "error",
    n = length(unregistered_questions),
    message = if (length(unregistered_questions) == 0) {
      "All attempted questions in scope are registered."
    } else {
      "Some attempted questions in scope are not registered."
    },
    details = unregistered_questions
  )

  students_without_attempts <- setdiff(
    pilot_unique_values(registered_students$student_id),
    pilot_unique_values(scoped_attempts$student_id)
  )
  missing_student_status <- if (require_all_students_attempted) "error" else "warning"
  rows[[length(rows) + 1L]] <- pilot_check_row(
    check = "students_without_attempts",
    status = if (length(students_without_attempts) == 0) "ok" else missing_student_status,
    n = length(students_without_attempts),
    message = if (length(students_without_attempts) == 0) {
      "Every registered student in scope has at least one attempt."
    } else {
      "Some registered students in scope have no recorded attempt."
    },
    details = students_without_attempts
  )

  questions_without_attempts <- setdiff(
    pilot_unique_values(questions$question_id),
    pilot_unique_values(scoped_attempts$question_id)
  )
  rows[[length(rows) + 1L]] <- pilot_check_row(
    check = "questions_without_attempts",
    status = if (length(questions_without_attempts) == 0) "ok" else "warning",
    n = length(questions_without_attempts),
    message = if (length(questions_without_attempts) == 0) {
      "Every registered question has at least one attempt in scope."
    } else {
      "Some registered questions have no attempt in scope."
    },
    details = questions_without_attempts
  )

  incomplete_students <- export_data$gradebook$student_id[
    !is.na(export_data$gradebook$completed) & !export_data$gradebook$completed
  ]
  rows[[length(rows) + 1L]] <- pilot_check_row(
    check = "incomplete_gradebook_rows",
    status = if (length(incomplete_students) == 0) "ok" else "warning",
    n = length(incomplete_students),
    message = if (length(incomplete_students) == 0) {
      "Every gradebook row is complete."
    } else {
      "Some gradebook rows are incomplete."
    },
    details = incomplete_students
  )

  expected_export_rows <- nrow(export_data$gradebook)
  rows[[length(rows) + 1L]] <- pilot_check_row(
    check = "moodle_export_rows",
    status = if (nrow(export_data$moodle_grades) == expected_export_rows) "ok" else "error",
    n = nrow(export_data$moodle_grades),
    message = paste0(
      "Moodle export row count is ",
      nrow(export_data$moodle_grades),
      "; expected ",
      expected_export_rows,
      "."
    )
  )

  rows[[length(rows) + 1L]] <- pilot_check_row(
    check = "canvas_export_rows",
    status = if (nrow(export_data$canvas_grades) == expected_export_rows) "ok" else "error",
    n = nrow(export_data$canvas_grades),
    message = paste0(
      "Canvas export row count is ",
      nrow(export_data$canvas_grades),
      "; expected ",
      expected_export_rows,
      "."
    )
  )

  moodle_id_column <- names(export_data$moodle_grades)[[1]]
  moodle_id_problems <- pilot_identifier_problems(export_data$moodle_grades[[moodle_id_column]])
  rows[[length(rows) + 1L]] <- pilot_check_row(
    check = "moodle_identifier_values",
    status = if (moodle_id_problems$n == 0) "ok" else "error",
    n = moodle_id_problems$n,
    message = if (moodle_id_problems$n == 0) {
      "Moodle identifier values are non-empty and unique."
    } else {
      "Moodle identifier values contain empty or duplicated values."
    },
    details = pilot_identifier_details(moodle_id_problems)
  )

  canvas_id_column <- "SIS User ID"
  if (!canvas_id_column %in% names(export_data$canvas_grades)) {
    rows[[length(rows) + 1L]] <- pilot_check_row(
      check = "canvas_identifier_values",
      status = "error",
      n = 1L,
      message = "Canvas export is missing the SIS User ID column.",
      details = canvas_id_column
    )
  } else {
    canvas_id_problems <- pilot_identifier_problems(export_data$canvas_grades[[canvas_id_column]])
    rows[[length(rows) + 1L]] <- pilot_check_row(
      check = "canvas_identifier_values",
      status = if (canvas_id_problems$n == 0) "ok" else "error",
      n = canvas_id_problems$n,
      message = if (canvas_id_problems$n == 0) {
        "Canvas SIS User ID values are non-empty and unique."
      } else {
        "Canvas SIS User ID values contain empty or duplicated values."
      },
      details = pilot_identifier_details(canvas_id_problems)
    )
  }

  out <- dplyr::bind_rows(rows)

  if (stop_on_error && any(out$status == "error")) {
    failed_checks <- out$check[out$status == "error"]
    cli::cli_abort(c(
      "Pilot readiness checks failed.",
      "x" = "Failed check{?s}: {failed_checks}."
    ))
  }

  out
}
