normalize_students_data <- function(students, timestamp) {
  if (is.character(students)) {
    students <- tibble::tibble(student_id = students)
  }

  if (!is.data.frame(students)) {
    cli::cli_abort(
      "{.arg students} must be a data frame or a character vector."
    )
  }

  students <- tibble::as_tibble(students)

  if (!"student_id" %in% names(students)) {
    cli::cli_abort("{.arg students} must contain a {.field student_id} column.")
  }

  students$student_id <- trimws(as.character(students$student_id))

  if (any(is.na(students$student_id)) || any(!nzchar(students$student_id))) {
    cli::cli_abort("{.field student_id} values must not be missing or empty.")
  }

  if (any(duplicated(students$student_id))) {
    duplicated_ids <- unique(students$student_id[duplicated(students$student_id)])
    cli::cli_abort(c(
      "{.arg students} contains duplicated student identifiers.",
      "x" = "Duplicated identifier{?s}: {duplicated_ids}."
    ))
  }

  if (!"student_label" %in% names(students)) {
    students$student_label <- students$student_id
  }

  if (!"email" %in% names(students)) {
    students$email <- NA_character_
  }

  if (!"group_id" %in% names(students)) {
    students$group_id <- NA_character_
  }

  tibble::tibble(
    student_id = students$student_id,
    student_label = as.character(students$student_label),
    email = as.character(students$email),
    group_id = as.character(students$group_id),
    created_at = timestamp
  )
}

student_is_registered <- function(con, student_id) {
  result <- DBI::dbGetQuery(
    con,
    "SELECT COUNT(*) AS n FROM students WHERE student_id = ?",
    params = list(student_id)
  )

  result$n[[1]] > 0
}

check_registered_student <- function(con, student_id) {
  if (!student_is_registered(con, student_id)) {
    cli::cli_abort(c(
      "Student identifier is not registered.",
      "x" = "{.field student_id}: {.val {student_id}}.",
      "i" = "Register the student with {.fn register_students} or set {.arg require_registered_student} to FALSE."
    ))
  }

  invisible(student_id)
}

#' Register expected students
#'
#' Stores expected student identifiers in the `students` table. Registered
#' students can be used by [track_attempt()] to reject attempts from unknown
#' identifiers when `require_registered_student = TRUE`.
#'
#' @param con A DBI connection.
#' @param students A data frame with a required `student_id` column and optional
#'   `student_label`, `email`, and `group_id` columns. A character vector is
#'   treated as a vector of student identifiers.
#' @param timestamp Creation timestamp for inserted rows. Defaults to
#'   `Sys.time()`.
#'
#' @return A tibble of registered students.
#' @export
#'
#' @examples
#' db_path <- tempfile(fileext = ".sqlite")
#' con <- init_tracking_db(db_path, overwrite = TRUE)
#' register_students(
#'   con,
#'   data.frame(
#'     student_id = c("student_001", "student_002"),
#'     group_id = c("A", "A")
#'   )
#' )
#' DBI::dbDisconnect(con)
register_students <- function(con,
                              students,
                              timestamp = Sys.time()) {
  check_required_tables(con)
  timestamp <- normalize_timestamp(timestamp)

  normalized <- normalize_students_data(
    students = students,
    timestamp = timestamp
  )

  DBI::dbWithTransaction(con, {
    for (row_index in seq_len(nrow(normalized))) {
      DBI::dbExecute(
        con,
        paste(
          "INSERT INTO students",
          "(student_id, student_label, email, group_id, created_at)",
          "VALUES (?, ?, ?, ?, ?)",
          "ON CONFLICT(student_id) DO UPDATE SET",
          "student_label = COALESCE(excluded.student_label, students.student_label),",
          "email = COALESCE(excluded.email, students.email),",
          "group_id = COALESCE(excluded.group_id, students.group_id)"
        ),
        params = list(
          normalized$student_id[[row_index]],
          normalized$student_label[[row_index]],
          normalized$email[[row_index]],
          normalized$group_id[[row_index]],
          normalized$created_at[[row_index]]
        )
      )
    }
  })

  get_students(con)
}

#' Read registered students
#'
#' Reads student definitions from the `students` table.
#'
#' @param con A DBI connection.
#' @param student_id Optional student identifier.
#' @param group_id Optional group identifier.
#'
#' @return A tibble of registered students.
#' @export
#'
#' @examples
#' db_path <- tempfile(fileext = ".sqlite")
#' con <- init_tracking_db(db_path, overwrite = TRUE)
#' register_students(con, c("student_001", "student_002"))
#' get_students(con, student_id = "student_001")
#' DBI::dbDisconnect(con)
get_students <- function(con,
                         student_id = NULL,
                         group_id = NULL) {
  check_required_tables(con)

  student_id <- validate_scalar_character(
    student_id,
    arg = "student_id",
    allow_null = TRUE
  )
  group_id <- validate_scalar_character(
    group_id,
    arg = "group_id",
    allow_null = TRUE
  )

  where <- character()
  params <- list()

  if (!is.null(student_id)) {
    where <- c(where, "student_id = ?")
    params <- c(params, list(student_id))
  }

  if (!is.null(group_id)) {
    where <- c(where, "group_id = ?")
    params <- c(params, list(group_id))
  }

  query <- paste(
    "SELECT student_id, student_label, email, group_id, created_at",
    "FROM students"
  )

  if (length(where) > 0) {
    query <- paste(query, "WHERE", paste(where, collapse = " AND "))
  }

  query <- paste(query, "ORDER BY student_id ASC")

  if (length(params) > 0) {
    students <- DBI::dbGetQuery(con, query, params = params)
  } else {
    students <- DBI::dbGetQuery(con, query)
  }

  tibble::as_tibble(students)
}
