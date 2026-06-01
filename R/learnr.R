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

validate_learnr_tracking_config <- function(student_id,
                                            tutorial_id,
                                            question_id,
                                            db_path,
                                            max_score) {
  list(
    student_id = validate_scalar_character(student_id, arg = "student_id"),
    tutorial_id = validate_scalar_character(tutorial_id, arg = "tutorial_id"),
    question_id = validate_scalar_character(question_id, arg = "question_id"),
    db_path = validate_path(db_path, arg = "db_path"),
    max_score = validate_scalar_numeric(max_score, arg = "max_score")
  )
}

add_tracked_question_class <- function(question, class_name, tracking) {
  question$options$learnrTrackR <- tracking
  class(question) <- c(class_name, class(question))
  question
}

normalize_tracked_question_type <- function(type, answers) {
  type <- match.arg(
    type,
    choices = c(
      "auto",
      "single",
      "multiple",
      "radio",
      "checkbox",
      "text",
      "numeric",
      "learnr_radio",
      "learnr_checkbox",
      "learnr_text",
      "learnr_numeric"
    )
  )

  if (type == "auto") {
    n_correct <- sum(vapply(
      answers,
      function(answer) {
        inherits(answer, "tutorial_question_answer") && isTRUE(answer$correct)
      },
      logical(1)
    ))

    if (n_correct > 1) {
      return("checkbox")
    }

    return("radio")
  }

  switch(
    type,
    single = "radio",
    multiple = "checkbox",
    learnr_radio = "radio",
    learnr_checkbox = "checkbox",
    learnr_text = "text",
    learnr_numeric = "numeric",
    type
  )
}

#' Create a tracked learnr question
#'
#' Creates a tracked `learnr` question and dispatches to the appropriate
#' question-specific helper: [tracked_question_radio()],
#' [tracked_question_checkbox()], [tracked_question_text()], or
#' [tracked_question_numeric()].
#'
#' For `type = "auto"`, the helper follows the same simple convention as
#' `learnr::question()` for literal answer choices: one correct answer creates a
#' radio question, and more than one correct answer creates a checkbox question.
#' Text and numeric questions should be requested explicitly with `type = "text"`
#' or `type = "numeric"`.
#'
#' @param text Question text.
#' @param ... Answers and type-specific arguments passed to the selected
#'   question helper.
#' @param type Question type. Supported values are `"auto"`, `"radio"`,
#'   `"checkbox"`, `"text"`, and `"numeric"`, with aliases `"single"`,
#'   `"multiple"`, `"learnr_radio"`, `"learnr_checkbox"`, `"learnr_text"`, and
#'   `"learnr_numeric"`.
#' @param question_id Question identifier stored in the tracking database.
#' @param tutorial_id Tutorial identifier stored in the tracking database.
#' @param student_id Student identifier stored in the tracking database.
#' @param db_path Path to the SQLite tracking database.
#' @param max_score Maximum score stored for the question. Defaults to `1`.
#'
#' @return A tracked `learnr` question object.
#' @export
#'
#' @examples
#' if (requireNamespace("learnr", quietly = TRUE)) {
#'   db_path <- tempfile(fileext = ".sqlite")
#'   question <- tracked_question(
#'     "What is 2 + 2?",
#'     learnr::answer("3"),
#'     learnr::answer("4", correct = TRUE),
#'     type = "radio",
#'     question_id = "q1",
#'     tutorial_id = "module_01",
#'     student_id = "student_001",
#'     db_path = db_path
#'   )
#' }
tracked_question <- function(text,
                             ...,
                             type = c(
                               "auto",
                               "single",
                               "multiple",
                               "radio",
                               "checkbox",
                               "text",
                               "numeric",
                               "learnr_radio",
                               "learnr_checkbox",
                               "learnr_text",
                               "learnr_numeric"
                             ),
                             question_id,
                             tutorial_id,
                             student_id,
                             db_path,
                             max_score = 1) {
  answers <- list(...)
  type <- normalize_tracked_question_type(type, answers = answers)
  args <- c(
    list(
      text = text
    ),
    answers,
    list(
      question_id = question_id,
      tutorial_id = tutorial_id,
      student_id = student_id,
      db_path = db_path,
      max_score = max_score
    )
  )

  switch(
    type,
    radio = do.call(tracked_question_radio, args),
    checkbox = do.call(tracked_question_checkbox, args),
    text = do.call(tracked_question_text, args),
    numeric = do.call(tracked_question_numeric, args)
  )
}

#' Create a tracked learnr radio question
#'
#' Wraps [learnr::question_radio()] and records each submitted answer in a
#' `learnrTrackR` SQLite database when `learnr` evaluates the question. This
#' function is intended for small prototypes and local teaching workflows.
#'
#' The tracking implementation uses the public `learnr::question_is_correct()`
#' S3 extension point. It does not use browser JavaScript interception.
#'
#' @param text Question text passed to [learnr::question_radio()].
#' @param ... Answers created with [learnr::answer()], followed by optional
#'   arguments passed to [learnr::question_radio()].
#' @param question_id Question identifier stored in the tracking database.
#' @param tutorial_id Tutorial identifier stored in the tracking database.
#' @param student_id Student identifier stored in the tracking database.
#' @param db_path Path to the SQLite tracking database.
#' @param max_score Maximum score stored for the question. Defaults to `1`.
#'
#' @return A `learnr` radio question object with tracking metadata.
#' @export
#'
#' @examples
#' if (requireNamespace("learnr", quietly = TRUE)) {
#'   db_path <- tempfile(fileext = ".sqlite")
#'   question <- tracked_question_radio(
#'     "What is 2 + 2?",
#'     learnr::answer("3"),
#'     learnr::answer("4", correct = TRUE),
#'     question_id = "q1",
#'     tutorial_id = "module_01",
#'     student_id = "student_001",
#'     db_path = db_path
#'   )
#' }
tracked_question_radio <- function(text,
                                   ...,
                                   question_id,
                                   tutorial_id,
                                   student_id,
                                   db_path,
                                   max_score = 1) {
  if (!requireNamespace("learnr", quietly = TRUE)) {
    cli::cli_abort(
      "Package {.pkg learnr} is required to use {.fn tracked_question_radio}."
    )
  }

  tracking <- validate_learnr_tracking_config(
    student_id = student_id,
    tutorial_id = tutorial_id,
    question_id = question_id,
    db_path = db_path,
    max_score = max_score
  )

  question <- learnr::question_radio(text, ...)

  add_tracked_question_class(
    question = question,
    class_name = "learnrTrackR_tracked_radio",
    tracking = tracking
  )
}

#' Create a tracked learnr checkbox question
#'
#' Wraps [learnr::question_checkbox()] and records each submitted answer in a
#' `learnrTrackR` SQLite database when `learnr` evaluates the question.
#'
#' The tracking implementation uses the public `learnr::question_is_correct()`
#' S3 extension point. It does not use browser JavaScript interception.
#'
#' @param text Question text passed to [learnr::question_checkbox()].
#' @param ... Answers created with [learnr::answer()] or [learnr::answer_fn()],
#'   followed by optional arguments passed to [learnr::question_checkbox()].
#' @param question_id Question identifier stored in the tracking database.
#' @param tutorial_id Tutorial identifier stored in the tracking database.
#' @param student_id Student identifier stored in the tracking database.
#' @param db_path Path to the SQLite tracking database.
#' @param max_score Maximum score stored for the question. Defaults to `1`.
#'
#' @return A `learnr` checkbox question object with tracking metadata.
#' @export
#'
#' @examples
#' if (requireNamespace("learnr", quietly = TRUE)) {
#'   db_path <- tempfile(fileext = ".sqlite")
#'   question <- tracked_question_checkbox(
#'     "Select all even numbers.",
#'     learnr::answer("2", correct = TRUE),
#'     learnr::answer("3"),
#'     learnr::answer("4", correct = TRUE),
#'     question_id = "q1",
#'     tutorial_id = "module_01",
#'     student_id = "student_001",
#'     db_path = db_path
#'   )
#' }
tracked_question_checkbox <- function(text,
                                      ...,
                                      question_id,
                                      tutorial_id,
                                      student_id,
                                      db_path,
                                      max_score = 1) {
  if (!requireNamespace("learnr", quietly = TRUE)) {
    cli::cli_abort(
      "Package {.pkg learnr} is required to use {.fn tracked_question_checkbox}."
    )
  }

  tracking <- validate_learnr_tracking_config(
    student_id = student_id,
    tutorial_id = tutorial_id,
    question_id = question_id,
    db_path = db_path,
    max_score = max_score
  )

  question <- learnr::question_checkbox(text, ...)

  add_tracked_question_class(
    question = question,
    class_name = "learnrTrackR_tracked_checkbox",
    tracking = tracking
  )
}

#' Create a tracked learnr text question
#'
#' Wraps [learnr::question_text()] and records each submitted answer in a
#' `learnrTrackR` SQLite database when `learnr` evaluates the question.
#'
#' The tracking implementation uses the public `learnr::question_is_correct()`
#' S3 extension point. It does not use browser JavaScript interception.
#'
#' @param text Question text passed to [learnr::question_text()].
#' @param ... Answers created with [learnr::answer()] or [learnr::answer_fn()],
#'   followed by optional arguments passed to [learnr::question_text()].
#' @param question_id Question identifier stored in the tracking database.
#' @param tutorial_id Tutorial identifier stored in the tracking database.
#' @param student_id Student identifier stored in the tracking database.
#' @param db_path Path to the SQLite tracking database.
#' @param max_score Maximum score stored for the question. Defaults to `1`.
#' @param correct Text shown by `learnr` for a correct answer.
#' @param incorrect Text shown by `learnr` for an incorrect answer.
#' @param try_again Text shown by `learnr` for an incorrect retry.
#' @param allow_retry Whether `learnr` should allow retries.
#' @param random_answer_order Passed to [learnr::question_text()].
#' @param placeholder Placeholder text for the input.
#' @param trim Whether `learnr` should trim whitespace before checking.
#' @param rows,cols Optional text area dimensions.
#' @param options Additional `learnr` question options.
#'
#' @return A `learnr` text question object with tracking metadata.
#' @export
#'
#' @examples
#' if (requireNamespace("learnr", quietly = TRUE)) {
#'   db_path <- tempfile(fileext = ".sqlite")
#'   question <- tracked_question_text(
#'     "Type the word mean.",
#'     learnr::answer("mean", correct = TRUE),
#'     question_id = "q1",
#'     tutorial_id = "module_01",
#'     student_id = "student_001",
#'     db_path = db_path
#'   )
#' }
tracked_question_text <- function(text,
                                  ...,
                                  question_id,
                                  tutorial_id,
                                  student_id,
                                  db_path,
                                  max_score = 1,
                                  correct = "Correct!",
                                  incorrect = "Incorrect",
                                  try_again = incorrect,
                                  allow_retry = FALSE,
                                  random_answer_order = FALSE,
                                  placeholder = "Enter answer here...",
                                  trim = TRUE,
                                  rows = NULL,
                                  cols = NULL,
                                  options = list()) {
  if (!requireNamespace("learnr", quietly = TRUE)) {
    cli::cli_abort(
      "Package {.pkg learnr} is required to use {.fn tracked_question_text}."
    )
  }

  tracking <- validate_learnr_tracking_config(
    student_id = student_id,
    tutorial_id = tutorial_id,
    question_id = question_id,
    db_path = db_path,
    max_score = max_score
  )

  question <- learnr::question_text(
    text,
    ...,
    correct = correct,
    incorrect = incorrect,
    try_again = try_again,
    allow_retry = allow_retry,
    random_answer_order = random_answer_order,
    placeholder = placeholder,
    trim = trim,
    rows = rows,
    cols = cols,
    options = options
  )

  add_tracked_question_class(
    question = question,
    class_name = "learnrTrackR_tracked_text",
    tracking = tracking
  )
}

#' Create a tracked learnr numeric question
#'
#' Wraps [learnr::question_numeric()] and records each submitted answer in a
#' `learnrTrackR` SQLite database when `learnr` evaluates the question.
#'
#' The tracking implementation uses the public `learnr::question_is_correct()`
#' S3 extension point. It does not use browser JavaScript interception.
#'
#' @param text Question text passed to [learnr::question_numeric()].
#' @param ... Answers created with [learnr::answer()] or [learnr::answer_fn()],
#'   followed by optional arguments passed to [learnr::question_numeric()].
#' @param question_id Question identifier stored in the tracking database.
#' @param tutorial_id Tutorial identifier stored in the tracking database.
#' @param student_id Student identifier stored in the tracking database.
#' @param db_path Path to the SQLite tracking database.
#' @param max_score Maximum score stored for the question. Defaults to `1`.
#' @param correct Text shown by `learnr` for a correct answer.
#' @param incorrect Text shown by `learnr` for an incorrect answer.
#' @param try_again Text shown by `learnr` for an incorrect retry.
#' @param allow_retry Whether `learnr` should allow retries.
#' @param value Initial numeric value.
#' @param min,max Optional numeric bounds.
#' @param step Optional numeric step.
#' @param options Additional `learnr` question options.
#' @param tolerance Numeric tolerance used by `learnr`.
#'
#' @return A `learnr` numeric question object with tracking metadata.
#' @export
#'
#' @examples
#' if (requireNamespace("learnr", quietly = TRUE)) {
#'   db_path <- tempfile(fileext = ".sqlite")
#'   question <- tracked_question_numeric(
#'     "What is 2 + 2?",
#'     learnr::answer(4, correct = TRUE),
#'     question_id = "q1",
#'     tutorial_id = "module_01",
#'     student_id = "student_001",
#'     db_path = db_path
#'   )
#' }
tracked_question_numeric <- function(text,
                                     ...,
                                     question_id,
                                     tutorial_id,
                                     student_id,
                                     db_path,
                                     max_score = 1,
                                     correct = "Correct!",
                                     incorrect = "Incorrect",
                                     try_again = incorrect,
                                     allow_retry = FALSE,
                                     value = NULL,
                                     min = NA,
                                     max = NA,
                                     step = NA,
                                     options = list(),
                                     tolerance = 1.5e-08) {
  if (!requireNamespace("learnr", quietly = TRUE)) {
    cli::cli_abort(
      "Package {.pkg learnr} is required to use {.fn tracked_question_numeric}."
    )
  }

  tracking <- validate_learnr_tracking_config(
    student_id = student_id,
    tutorial_id = tutorial_id,
    question_id = question_id,
    db_path = db_path,
    max_score = max_score
  )

  question <- learnr::question_numeric(
    text,
    ...,
    correct = correct,
    incorrect = incorrect,
    try_again = try_again,
    allow_retry = allow_retry,
    value = value,
    min = min,
    max = max,
    step = step,
    options = options,
    tolerance = tolerance
  )

  add_tracked_question_class(
    question = question,
    class_name = "learnrTrackR_tracked_numeric",
    tracking = tracking
  )
}

serialize_learnr_submission <- function(value) {
  if (is.null(value) || length(value) == 0) {
    return("")
  }

  paste(as.character(value), collapse = "\n")
}

feedback_from_learnr_result <- function(result) {
  messages <- result$messages

  if (is.null(messages) || length(messages) == 0) {
    return(if (isTRUE(result$correct)) "Correct." else "Incorrect.")
  }

  paste(as.character(messages), collapse = "\n")
}

track_learnr_question_result <- function(question, value, result) {
  tracking <- question$options$learnrTrackR

  if (is.null(tracking)) {
    cli::cli_abort("The question does not contain learnrTrackR metadata.")
  }

  con <- init_tracking_db(tracking$db_path, overwrite = FALSE)
  on.exit(DBI::dbDisconnect(con), add = TRUE)

  correct <- isTRUE(result$correct)

  track_attempt(
    con = con,
    student_id = tracking$student_id,
    tutorial_id = tracking$tutorial_id,
    question_id = tracking$question_id,
    submitted_answer = serialize_learnr_submission(value),
    grade_status = if (correct) "correct" else "incorrect",
    score = if (correct) tracking$max_score else 0,
    max_score = tracking$max_score,
    feedback = feedback_from_learnr_result(result)
  )

  invisible(result)
}

#' @exportS3Method learnr::question_is_correct
question_is_correct.learnrTrackR_tracked_radio <- function(question,
                                                          value,
                                                          ...) {
  result <- NextMethod()
  track_learnr_question_result(question, value, result)
  result
}

#' @exportS3Method learnr::question_is_correct
question_is_correct.learnrTrackR_tracked_checkbox <- function(question,
                                                             value,
                                                             ...) {
  result <- NextMethod()
  track_learnr_question_result(question, value, result)
  result
}

#' @exportS3Method learnr::question_is_correct
question_is_correct.learnrTrackR_tracked_text <- function(question,
                                                         value,
                                                         ...) {
  result <- NextMethod()
  track_learnr_question_result(question, value, result)
  result
}

#' @exportS3Method learnr::question_is_correct
question_is_correct.learnrTrackR_tracked_numeric <- function(question,
                                                            value,
                                                            ...) {
  result <- NextMethod()
  track_learnr_question_result(question, value, result)
  result
}
