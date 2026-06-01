#' Track an attempt from a gradethis check
#'
#' Records one attempt and returns a `gradethis` graded result. This helper is
#' intended for explicit use inside a `gradethis::grade_this()` check chunk in a
#' `learnr` tutorial. It does not intercept `learnr` submissions automatically.
#'
#' @param con A DBI connection.
#' @param student_id Student identifier.
#' @param tutorial_id Tutorial identifier.
#' @param question_id Question identifier.
#' @param submitted_answer Submitted answer or code. In a `grade_this()` check,
#'   this is usually `.user_code`.
#' @param correct Logical scalar indicating whether the submission is correct.
#' @param feedback Feedback returned to the learner and stored in the database.
#'   If `NULL`, a simple default message is chosen from `correct`.
#' @param score Numeric score to store. If `NULL`, stores `max_score` when
#'   `correct = TRUE` and `0` otherwise.
#' @param max_score Numeric maximum score. Defaults to `1`.
#' @param grade_status Character status to store. If `NULL`, stores
#'   `"correct"` when `correct = TRUE` and `"incorrect"` otherwise.
#' @param session_id Optional session identifier passed to [track_attempt()].
#' @param attempt_number Optional attempt number passed to [track_attempt()].
#' @param timestamp Attempt timestamp. Defaults to `Sys.time()`.
#'
#' @return A `gradethis_graded` object returned by `gradethis::graded()`.
#' @export
#'
#' @examples
#' if (requireNamespace("gradethis", quietly = TRUE)) {
#'   db_path <- tempfile(fileext = ".sqlite")
#'   con <- init_tracking_db(db_path, overwrite = TRUE)
#'
#'   track_gradethis_attempt(
#'     con = con,
#'     student_id = "student_001",
#'     tutorial_id = "module_01",
#'     question_id = "q1",
#'     submitted_answer = "2 + 2",
#'     correct = TRUE,
#'     feedback = "Correct."
#'   )
#'
#'   DBI::dbDisconnect(con)
#' }
track_gradethis_attempt <- function(con,
                                    student_id,
                                    tutorial_id,
                                    question_id,
                                    submitted_answer,
                                    correct,
                                    feedback = NULL,
                                    score = NULL,
                                    max_score = 1,
                                    grade_status = NULL,
                                    session_id = NULL,
                                    attempt_number = NULL,
                                    timestamp = Sys.time()) {
  if (!requireNamespace("gradethis", quietly = TRUE)) {
    cli::cli_abort(
      "Package {.pkg gradethis} is required to use {.fn track_gradethis_attempt}."
    )
  }

  correct <- validate_scalar_logical(correct, arg = "correct")
  max_score <- validate_scalar_numeric(max_score, arg = "max_score")

  if (is.null(feedback)) {
    feedback <- if (correct) "Correct." else "Incorrect."
  }

  feedback <- validate_scalar_character(
    feedback,
    arg = "feedback",
    allow_empty = TRUE
  )

  if (is.null(score)) {
    score <- if (correct) max_score else 0
  }

  score <- validate_scalar_numeric(score, arg = "score", allow_na = TRUE)

  if (is.null(grade_status)) {
    grade_status <- if (correct) "correct" else "incorrect"
  }

  grade_status <- validate_scalar_character(
    grade_status,
    arg = "grade_status",
    allow_empty = TRUE
  )

  track_attempt(
    con = con,
    student_id = student_id,
    tutorial_id = tutorial_id,
    question_id = question_id,
    submitted_answer = submitted_answer,
    grade_status = grade_status,
    score = score,
    max_score = max_score,
    feedback = feedback,
    session_id = session_id,
    attempt_number = attempt_number,
    timestamp = timestamp
  )

  gradethis::graded(
    correct = correct,
    message = feedback
  )
}
