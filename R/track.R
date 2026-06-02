next_attempt_number <- function(con, student_id, tutorial_id, question_id) {
  result <- tracking_db_get_query(
    con,
    paste(
      "SELECT COALESCE(MAX(attempt_number), 0) + 1 AS attempt_number",
      "FROM attempts",
      "WHERE student_id = ? AND tutorial_id = ? AND question_id = ?"
    ),
    params = list(student_id, tutorial_id, question_id)
  )

  as.integer(result$attempt_number[[1]])
}

upsert_session <- function(con,
                           session_id,
                           student_id,
                           tutorial_id,
                           timestamp) {
  exists <- tracking_db_get_query(
    con,
    "SELECT COUNT(*) AS n FROM sessions WHERE session_id = ?",
    params = list(session_id)
  )$n[[1]]

  if (exists == 0) {
    tracking_db_execute(
      con,
      paste(
        "INSERT INTO sessions",
        "(session_id, student_id, tutorial_id, started_at, last_seen_at, completed_at)",
        "VALUES (?, ?, ?, ?, ?, NULL)"
      ),
      params = list(
        session_id,
        student_id,
        tutorial_id,
        timestamp,
        timestamp
      )
    )
  } else {
    tracking_db_execute(
      con,
      "UPDATE sessions SET last_seen_at = ? WHERE session_id = ?",
      params = list(timestamp, session_id)
    )
  }

  invisible(session_id)
}

insert_attempt <- function(con,
                           session_id,
                           student_id,
                           tutorial_id,
                           question_id,
                           attempt_number,
                           submitted_answer,
                           grade_status,
                           score,
                           max_score,
                           feedback,
                           timestamp) {
  statement <- paste(
    "INSERT INTO attempts",
    "(session_id, student_id, tutorial_id, question_id, attempt_number,",
    "submitted_answer, grade_status, score, max_score, feedback, timestamp)",
    "VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)"
  )
  params <- list(
    session_id,
    student_id,
    tutorial_id,
    question_id,
    attempt_number,
    submitted_answer,
    grade_status,
    score,
    max_score,
    feedback,
    timestamp
  )

  if (tracking_db_backend(con) == "postgres") {
    result <- tracking_db_get_query(
      con,
      paste(statement, "RETURNING attempt_id"),
      params = params
    )

    return(result$attempt_id[[1]])
  }

  tracking_db_execute(con, statement, params = params)
  tracking_db_get_query(con, "SELECT last_insert_rowid() AS attempt_id")$attempt_id[[1]]
}

#' Record a simulated tutorial attempt
#'
#' Inserts one attempt in the `attempts` table. If `session_id` is `NULL`, a
#' simple session identifier is generated from the student, tutorial, and date.
#' If `attempt_number` is `NULL`, the next number is computed for the
#' student-tutorial-question combination.
#'
#' @param con A DBI connection.
#' @param student_id Student identifier.
#' @param tutorial_id Tutorial identifier.
#' @param question_id Question identifier.
#' @param submitted_answer Submitted answer as text.
#' @param grade_status Optional grading status, such as `"correct"` or
#'   `"partial"`.
#' @param score Optional numeric score.
#' @param max_score Optional numeric maximum score.
#' @param feedback Optional feedback text.
#' @param session_id Optional session identifier.
#' @param attempt_number Optional positive integer attempt number.
#' @param timestamp Attempt timestamp. Defaults to `Sys.time()`.
#' @param require_registered_student If `TRUE`, `student_id` must already be
#'   present in the `students` table through [register_students()].
#'
#' @return The inserted `attempt_id`, invisibly.
#' @export
#'
#' @examples
#' db_path <- tempfile(fileext = ".sqlite")
#' con <- init_tracking_db(db_path, overwrite = TRUE)
#'
#' track_attempt(
#'   con = con,
#'   student_id = "student_001",
#'   tutorial_id = "module_01",
#'   question_id = "q1",
#'   submitted_answer = "mean(x)",
#'   grade_status = "correct",
#'   score = 1,
#'   max_score = 1,
#'   feedback = "Correct."
#' )
#'
#' DBI::dbDisconnect(con)
track_attempt <- function(con,
                          student_id,
                          tutorial_id,
                          question_id,
                          submitted_answer,
                          grade_status = NA_character_,
                          score = NA_real_,
                          max_score = NA_real_,
                          feedback = NA_character_,
                          session_id = NULL,
                          attempt_number = NULL,
                          timestamp = Sys.time(),
                          require_registered_student = FALSE) {
  check_required_tables(con)

  student_id <- validate_scalar_character(student_id, arg = "student_id")
  tutorial_id <- validate_scalar_character(tutorial_id, arg = "tutorial_id")
  question_id <- validate_scalar_character(question_id, arg = "question_id")
  submitted_answer <- validate_scalar_character(
    submitted_answer,
    arg = "submitted_answer",
    allow_na = TRUE,
    allow_empty = TRUE
  )
  grade_status <- validate_scalar_character(
    grade_status,
    arg = "grade_status",
    allow_na = TRUE,
    allow_empty = TRUE
  )
  score <- validate_scalar_numeric(score, arg = "score", allow_na = TRUE)
  max_score <- validate_scalar_numeric(
    max_score,
    arg = "max_score",
    allow_na = TRUE
  )
  feedback <- validate_scalar_character(
    feedback,
    arg = "feedback",
    allow_na = TRUE,
    allow_empty = TRUE
  )
  timestamp <- normalize_timestamp(timestamp)
  require_registered_student <- validate_scalar_logical(
    require_registered_student,
    arg = "require_registered_student"
  )

  if (require_registered_student) {
    check_registered_student(con, student_id)
  }

  if (is.null(session_id)) {
    session_id <- generate_session_id(
      student_id = student_id,
      tutorial_id = tutorial_id,
      timestamp = timestamp
    )
  } else {
    session_id <- validate_scalar_character(session_id, arg = "session_id")
  }

  if (!is.null(attempt_number)) {
    attempt_number <- validate_positive_integer(
      attempt_number,
      arg = "attempt_number"
    )
  }

  attempt_id <- DBI::dbWithTransaction(con, {
    upsert_session(
      con = con,
      session_id = session_id,
      student_id = student_id,
      tutorial_id = tutorial_id,
      timestamp = timestamp
    )

    if (is.null(attempt_number)) {
      attempt_number <- next_attempt_number(
        con = con,
        student_id = student_id,
        tutorial_id = tutorial_id,
        question_id = question_id
      )
    }

    insert_attempt(
      con,
      session_id = session_id,
      student_id = student_id,
      tutorial_id = tutorial_id,
      question_id = question_id,
      attempt_number = attempt_number,
      submitted_answer = submitted_answer,
      grade_status = grade_status,
      score = score,
      max_score = max_score,
      feedback = feedback,
      timestamp = timestamp
    )
  })

  invisible(as.integer(attempt_id))
}

#' Read recorded attempts
#'
#' Reads attempts from the tracking database, with optional filters by student,
#' tutorial, and question. Results are ordered by timestamp and then attempt id.
#'
#' @param con A DBI connection.
#' @param student_id Optional student identifier.
#' @param tutorial_id Optional tutorial identifier.
#' @param question_id Optional question identifier.
#'
#' @return A tibble of recorded attempts.
#' @export
#'
#' @examples
#' db_path <- tempfile(fileext = ".sqlite")
#' con <- init_tracking_db(db_path, overwrite = TRUE)
#' track_attempt(con, "student_001", "module_01", "q1", "mean(x)")
#' get_attempts(con)
#' DBI::dbDisconnect(con)
get_attempts <- function(con,
                         student_id = NULL,
                         tutorial_id = NULL,
                         question_id = NULL) {
  check_required_tables(con)

  student_id <- validate_scalar_character(
    student_id,
    arg = "student_id",
    allow_null = TRUE
  )
  tutorial_id <- validate_scalar_character(
    tutorial_id,
    arg = "tutorial_id",
    allow_null = TRUE
  )
  question_id <- validate_scalar_character(
    question_id,
    arg = "question_id",
    allow_null = TRUE
  )

  where <- character()
  params <- list()

  if (!is.null(student_id)) {
    where <- c(where, "student_id = ?")
    params <- c(params, list(student_id))
  }

  if (!is.null(tutorial_id)) {
    where <- c(where, "tutorial_id = ?")
    params <- c(params, list(tutorial_id))
  }

  if (!is.null(question_id)) {
    where <- c(where, "question_id = ?")
    params <- c(params, list(question_id))
  }

  query <- paste(
    "SELECT",
    "attempt_id, session_id, student_id, tutorial_id, question_id,",
    "attempt_number, submitted_answer, grade_status, score, max_score,",
    "feedback, timestamp",
    "FROM attempts"
  )

  if (length(where) > 0) {
    query <- paste(query, "WHERE", paste(where, collapse = " AND "))
  }

  query <- paste(query, "ORDER BY timestamp ASC, attempt_id ASC")

  if (length(params) > 0) {
    attempts <- tracking_db_get_query(con, query, params = params)
  } else {
    attempts <- tracking_db_get_query(con, query)
  }

  tibble::as_tibble(attempts)
}
