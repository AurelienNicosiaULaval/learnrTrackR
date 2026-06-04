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
#' @param context Optional context returned by [setup_learnr_tracking()]. If
#'   supplied, `student_id`, `tutorial_id`, and the database connection can be
#'   resolved from the context.
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
#'
#'   tracking <- setup_learnr_tracking(
#'     tutorial_id = "module_01",
#'     student_id = "student_001",
#'     db_path = db_path
#'   )
#'
#'   track_gradethis_attempt(
#'     context = tracking,
#'     question_id = "q2",
#'     submitted_answer = "mean(x)",
#'     correct = FALSE
#'   )
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
                                    timestamp = Sys.time(),
                                    context = NULL) {
  if (!requireNamespace("gradethis", quietly = TRUE)) {
    cli::cli_abort(
      "Package {.pkg gradethis} is required to use {.fn track_gradethis_attempt}."
    )
  }

  context <- validate_learnr_tracking_context(context, allow_null = TRUE)
  con_missing <- missing(con) || is.null(con)

  student_id <- learnr_context_value(
    context = context,
    name = "student_id",
    value = if (missing(student_id)) NULL else student_id,
    is_missing = missing(student_id),
    arg = "student_id"
  )
  tutorial_id <- learnr_context_value(
    context = context,
    name = "tutorial_id",
    value = if (missing(tutorial_id)) NULL else tutorial_id,
    is_missing = missing(tutorial_id),
    arg = "tutorial_id"
  )

  student_id <- validate_scalar_character(student_id, arg = "student_id")
  tutorial_id <- validate_scalar_character(tutorial_id, arg = "tutorial_id")
  question_id <- validate_scalar_character(question_id, arg = "question_id")

  if (con_missing) {
    if (is.null(context)) {
      cli::cli_abort(
        "{.arg con} is required unless {.arg context} provides a tracking database."
      )
    }

    con <- open_learnr_tracking_db(context)
    on.exit(DBI::dbDisconnect(con), add = TRUE)
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

validate_learnr_tracking_context <- function(context, allow_null = FALSE) {
  if (is.null(context)) {
    if (allow_null) {
      return(NULL)
    }

    cli::cli_abort("{.arg context} must not be NULL.")
  }

  if (!is.list(context)) {
    cli::cli_abort(
      "{.arg context} must be a list returned by {.fn setup_learnr_tracking}."
    )
  }

  required <- c("student_id", "tutorial_id", "db_path")
  missing_fields <- setdiff(required, names(context))

  if (length(missing_fields) > 0) {
    cli::cli_abort(c(
      "{.arg context} is missing required field{?s}.",
      "x" = "Missing field{?s}: {.field {missing_fields}}."
    ))
  }

  group_id <- context$group_id
  if (is.null(group_id)) {
    group_id <- NA_character_
  }

  config_path <- context$config_path
  if (is.null(config_path)) {
    config_path <- NA_character_
  }

  structure(
    list(
      student_id = validate_scalar_character(
        context$student_id,
        arg = "context$student_id"
      ),
      tutorial_id = validate_scalar_character(
        context$tutorial_id,
        arg = "context$tutorial_id"
      ),
      db_path = validate_path(context$db_path, arg = "context$db_path"),
      group_id = validate_scalar_character(
        group_id,
        arg = "context$group_id",
        allow_na = TRUE,
        allow_empty = TRUE
      ),
      config_path = validate_scalar_character(
        config_path,
        arg = "context$config_path",
        allow_na = TRUE
      )
    ),
    class = "learnrTrackR_context"
  )
}

learnr_context_value <- function(context,
                                 name,
                                 value,
                                 is_missing,
                                 arg) {
  if (!is_missing && !is.null(value)) {
    return(value)
  }

  if (!is.null(context)) {
    return(context[[name]])
  }

  cli::cli_abort(
    "{.arg {arg}} is required unless {.arg context} provides it."
  )
}

resolve_learnr_tracking_config <- function(context,
                                           student_id,
                                           student_id_missing,
                                           tutorial_id,
                                           tutorial_id_missing,
                                           question_id,
                                           db_path,
                                           db_path_missing,
                                           max_score) {
  context <- validate_learnr_tracking_context(context, allow_null = TRUE)

  student_id <- learnr_context_value(
    context = context,
    name = "student_id",
    value = student_id,
    is_missing = student_id_missing,
    arg = "student_id"
  )
  tutorial_id <- learnr_context_value(
    context = context,
    name = "tutorial_id",
    value = tutorial_id,
    is_missing = tutorial_id_missing,
    arg = "tutorial_id"
  )
  db_path <- learnr_context_value(
    context = context,
    name = "db_path",
    value = db_path,
    is_missing = db_path_missing,
    arg = "db_path"
  )

  list(
    student_id = validate_scalar_character(student_id, arg = "student_id"),
    tutorial_id = validate_scalar_character(tutorial_id, arg = "tutorial_id"),
    question_id = validate_scalar_character(question_id, arg = "question_id"),
    db_path = validate_path(db_path, arg = "db_path"),
    max_score = validate_scalar_numeric(max_score, arg = "max_score")
  )
}

#' Set up tracking for a learnr tutorial
#'
#' Initializes the tracking database, optionally loads a tracking configuration,
#' registers the current learner, and returns a small context object. The context
#' can then be passed to [tracked_question()], [tracked_question_radio()],
#' [tracked_question_checkbox()], [tracked_question_text()],
#' [tracked_question_numeric()], [track_gradethis_attempt()], and
#' [open_learnr_tracking_db()].
#'
#' This helper is intended for the setup chunk of a `learnr` tutorial. It keeps
#' the tutorial code explicit while avoiding repeated `student_id`,
#' `tutorial_id`, and `db_path` arguments in each tracked question.
#'
#' @param tutorial_id Tutorial identifier stored in the tracking database.
#' @param student_id Student identifier. Defaults to [get_tracking_student_id()].
#' @param db_path Path to the SQLite tracking database. Defaults to the
#'   `LEARNRTRACKR_DB` environment variable, or a temporary SQLite file based on
#'   `tutorial_id` when the variable is missing.
#' @param group_id Optional learner group. Defaults to the
#'   `LEARNRTRACKR_GROUP_ID` environment variable, or `NA_character_`.
#' @param config_path Optional YAML file or CSV directory loaded with
#'   [load_tracking_config()]. Use `NULL` to skip configuration loading.
#' @param student_label Optional label for the current learner. Defaults to
#'   `student_id`.
#' @param overwrite If `TRUE`, remove an existing SQLite database before
#'   initialization.
#' @param register_student If `TRUE`, register the current learner in the
#'   `students` table.
#'
#' @return A `learnrTrackR_context` list with `student_id`, `tutorial_id`,
#'   `db_path`, `group_id`, and `config_path`.
#' @export
#'
#' @examples
#' db_path <- tempfile(fileext = ".sqlite")
#' tracking <- setup_learnr_tracking(
#'   tutorial_id = "module_01",
#'   student_id = "student_001",
#'   db_path = db_path
#' )
#'
#' con <- open_learnr_tracking_db(tracking)
#' DBI::dbDisconnect(con)
setup_learnr_tracking <- function(tutorial_id,
                                  student_id = get_tracking_student_id(),
                                  db_path = Sys.getenv(
                                    "LEARNRTRACKR_DB",
                                    unset = file.path(
                                      tempdir(),
                                      paste0(tutorial_id, ".sqlite")
                                    )
                                  ),
                                  group_id = Sys.getenv(
                                    "LEARNRTRACKR_GROUP_ID",
                                    unset = NA_character_
                                  ),
                                  config_path = NULL,
                                  student_label = student_id,
                                  overwrite = FALSE,
                                  register_student = TRUE) {
  tutorial_id <- validate_scalar_character(tutorial_id, arg = "tutorial_id")
  student_id <- validate_scalar_character(student_id, arg = "student_id")
  db_path <- validate_path(db_path, arg = "db_path")
  group_id <- validate_scalar_character(
    group_id,
    arg = "group_id",
    allow_na = TRUE,
    allow_empty = TRUE
  )
  student_label <- validate_scalar_character(
    student_label,
    arg = "student_label",
    allow_empty = TRUE
  )
  overwrite <- validate_scalar_logical(overwrite, arg = "overwrite")
  register_student <- validate_scalar_logical(
    register_student,
    arg = "register_student"
  )

  if (!is.null(config_path) && !nzchar(config_path)) {
    config_path <- NULL
  }

  if (!is.null(config_path)) {
    config_path <- validate_path(config_path, arg = "config_path")
  }

  con <- init_tracking_db(db_path, overwrite = overwrite)
  on.exit(DBI::dbDisconnect(con), add = TRUE)

  if (!is.null(config_path)) {
    load_tracking_config(con, config_path)
  }

  if (register_student) {
    register_students(
      con,
      tibble::tibble(
        student_id = student_id,
        student_label = student_label,
        group_id = group_id
      )
    )
  }

  validate_learnr_tracking_context(
    list(
      student_id = student_id,
      tutorial_id = tutorial_id,
      db_path = db_path,
      group_id = group_id,
      config_path = if (is.null(config_path)) NA_character_ else config_path
    )
  )
}

#' Open the tracking database for a learnr context
#'
#' Opens the SQLite tracking database referenced by a context returned by
#' [setup_learnr_tracking()]. Missing schema objects are created idempotently
#' through [init_tracking_db()].
#'
#' @param context A context returned by [setup_learnr_tracking()].
#'
#' @return A DBI connection.
#' @export
#'
#' @examples
#' db_path <- tempfile(fileext = ".sqlite")
#' tracking <- setup_learnr_tracking(
#'   tutorial_id = "module_01",
#'   student_id = "student_001",
#'   db_path = db_path
#' )
#'
#' con <- open_learnr_tracking_db(tracking)
#' DBI::dbDisconnect(con)
open_learnr_tracking_db <- function(context) {
  context <- validate_learnr_tracking_context(context)
  init_tracking_db(context$db_path, overwrite = FALSE)
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
#' @param context Optional context returned by [setup_learnr_tracking()]. If
#'   supplied, `student_id`, `tutorial_id`, and `db_path` are read from the
#'   context unless explicitly provided.
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
#'
#'   tracking <- setup_learnr_tracking(
#'     tutorial_id = "module_01",
#'     student_id = "student_001",
#'     db_path = db_path
#'   )
#'
#'   tracked_question(
#'     "What is 3 + 3?",
#'     learnr::answer("5"),
#'     learnr::answer("6", correct = TRUE),
#'     type = "radio",
#'     question_id = "q2",
#'     context = tracking
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
                             max_score = 1,
                             context = NULL) {
  answers <- list(...)
  type <- normalize_tracked_question_type(type, answers = answers)
  tracking <- resolve_learnr_tracking_config(
    context = context,
    student_id = if (missing(student_id)) NULL else student_id,
    student_id_missing = missing(student_id),
    tutorial_id = if (missing(tutorial_id)) NULL else tutorial_id,
    tutorial_id_missing = missing(tutorial_id),
    question_id = question_id,
    db_path = if (missing(db_path)) NULL else db_path,
    db_path_missing = missing(db_path),
    max_score = max_score
  )
  args <- c(
    list(
      text = text
    ),
    answers,
    list(
      question_id = tracking$question_id,
      tutorial_id = tracking$tutorial_id,
      student_id = tracking$student_id,
      db_path = tracking$db_path,
      max_score = tracking$max_score
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
#' @param context Optional context returned by [setup_learnr_tracking()]. If
#'   supplied, `student_id`, `tutorial_id`, and `db_path` are read from the
#'   context unless explicitly provided.
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
                                   max_score = 1,
                                   context = NULL) {
  if (!requireNamespace("learnr", quietly = TRUE)) {
    cli::cli_abort(
      "Package {.pkg learnr} is required to use {.fn tracked_question_radio}."
    )
  }

  tracking <- resolve_learnr_tracking_config(
    context = context,
    student_id = if (missing(student_id)) NULL else student_id,
    student_id_missing = missing(student_id),
    tutorial_id = if (missing(tutorial_id)) NULL else tutorial_id,
    tutorial_id_missing = missing(tutorial_id),
    question_id = question_id,
    db_path = if (missing(db_path)) NULL else db_path,
    db_path_missing = missing(db_path),
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
#' @param context Optional context returned by [setup_learnr_tracking()]. If
#'   supplied, `student_id`, `tutorial_id`, and `db_path` are read from the
#'   context unless explicitly provided.
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
                                      max_score = 1,
                                      context = NULL) {
  if (!requireNamespace("learnr", quietly = TRUE)) {
    cli::cli_abort(
      "Package {.pkg learnr} is required to use {.fn tracked_question_checkbox}."
    )
  }

  tracking <- resolve_learnr_tracking_config(
    context = context,
    student_id = if (missing(student_id)) NULL else student_id,
    student_id_missing = missing(student_id),
    tutorial_id = if (missing(tutorial_id)) NULL else tutorial_id,
    tutorial_id_missing = missing(tutorial_id),
    question_id = question_id,
    db_path = if (missing(db_path)) NULL else db_path,
    db_path_missing = missing(db_path),
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
#' @param context Optional context returned by [setup_learnr_tracking()]. If
#'   supplied, `student_id`, `tutorial_id`, and `db_path` are read from the
#'   context unless explicitly provided.
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
                                  options = list(),
                                  context = NULL) {
  if (!requireNamespace("learnr", quietly = TRUE)) {
    cli::cli_abort(
      "Package {.pkg learnr} is required to use {.fn tracked_question_text}."
    )
  }

  tracking <- resolve_learnr_tracking_config(
    context = context,
    student_id = if (missing(student_id)) NULL else student_id,
    student_id_missing = missing(student_id),
    tutorial_id = if (missing(tutorial_id)) NULL else tutorial_id,
    tutorial_id_missing = missing(tutorial_id),
    question_id = question_id,
    db_path = if (missing(db_path)) NULL else db_path,
    db_path_missing = missing(db_path),
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
#' @param context Optional context returned by [setup_learnr_tracking()]. If
#'   supplied, `student_id`, `tutorial_id`, and `db_path` are read from the
#'   context unless explicitly provided.
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
                                     tolerance = 1.5e-08,
                                     context = NULL) {
  if (!requireNamespace("learnr", quietly = TRUE)) {
    cli::cli_abort(
      "Package {.pkg learnr} is required to use {.fn tracked_question_numeric}."
    )
  }

  tracking <- resolve_learnr_tracking_config(
    context = context,
    student_id = if (missing(student_id)) NULL else student_id,
    student_id_missing = missing(student_id),
    tutorial_id = if (missing(tutorial_id)) NULL else tutorial_id,
    tutorial_id_missing = missing(tutorial_id),
    question_id = question_id,
    db_path = if (missing(db_path)) NULL else db_path,
    db_path_missing = missing(db_path),
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
