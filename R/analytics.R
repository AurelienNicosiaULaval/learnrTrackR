empty_question_analytics_tibble <- function() {
  tibble::tibble(
    tutorial_id = character(),
    question_id = character(),
    question_label = character(),
    question_type = character(),
    max_score = numeric(),
    n_possible_students = integer(),
    n_students = integer(),
    n_attempts = integer(),
    n_answered = integer(),
    n_full_credit = integer(),
    mean_score = numeric(),
    mean_percent = numeric(),
    full_credit_rate = numeric(),
    mean_attempts_per_student = numeric()
  )
}

empty_student_analytics_tibble <- function() {
  tibble::tibble(
    student_id = character(),
    student_label = character(),
    email = character(),
    group_id = character(),
    tutorial_id = character(),
    score = numeric(),
    max_score = numeric(),
    percent = numeric(),
    n_questions = integer(),
    n_answered = integer(),
    n_unanswered = integer(),
    completed = logical(),
    n_attempts = integer(),
    last_activity = character(),
    status = character()
  )
}

validate_percent_threshold <- function(x, arg) {
  x <- validate_scalar_numeric(x, arg = arg, allow_na = FALSE)

  if (x < 0 || x > 100) {
    cli::cli_abort("{.arg {arg}} must be between 0 and 100.")
  }

  x
}

safe_mean <- function(x) {
  out <- mean(x, na.rm = TRUE)

  if (is.nan(out)) {
    return(NA_real_)
  }

  out
}

analytics_student_ids <- function(con, tutorial_id, group_id = NULL) {
  registered_students <- get_students(con)
  selected_registered <- filter_registered_students(
    registered_students,
    group_id = group_id
  )
  attempts <- get_attempts(con, tutorial_id = tutorial_id)

  dashboard_student_ids(
    registered_students = selected_registered,
    attempts = attempts,
    group_id = group_id
  )
}

last_activity_by_student <- function(attempts) {
  if (nrow(attempts) == 0) {
    return(tibble::tibble(
      student_id = character(),
      last_activity = character()
    ))
  }

  out <- stats::aggregate(
    timestamp ~ student_id,
    data = attempts,
    FUN = max
  )
  names(out) <- c("student_id", "last_activity")

  tibble::as_tibble(out)
}

status_from_student_summary <- function(n_attempts, completed) {
  ifelse(
    n_attempts == 0,
    "not_started",
    ifelse(completed, "completed", "in_progress")
  )
}

#' Summarise tutorial questions
#'
#' Builds one row per question with attempt counts, answer counts, mean score,
#' mean percent, and full-credit rate. Registered questions with no attempts are
#' included.
#'
#' @param con A DBI connection.
#' @param tutorial_id Tutorial identifier. Required.
#' @param rule Scoring rule used to select one attempt per student and question.
#' @param include_unregistered If `TRUE`, include attempted questions not
#'   registered with [register_questions()].
#' @param group_id Optional registered student group identifier. If supplied,
#'   only attempts from students in that group are included.
#'
#' @return A tibble with question-level pedagogical summary metrics.
#' @export
#'
#' @examples
#' db_path <- tempfile(fileext = ".sqlite")
#' con <- init_tracking_db(db_path, overwrite = TRUE)
#' register_questions(con, "module_01", c("q1", "q2"))
#' track_attempt(con, "student_001", "module_01", "q1", "mean(x)", score = 1, max_score = 1)
#' summarise_questions(con, "module_01")
#' DBI::dbDisconnect(con)
summarise_questions <- function(con,
                                tutorial_id,
                                rule = c("last", "best", "first"),
                                include_unregistered = TRUE,
                                group_id = NULL) {
  check_required_tables(con)

  tutorial_id <- validate_scalar_character(tutorial_id, arg = "tutorial_id")
  rule <- match.arg(rule)
  include_unregistered <- validate_scalar_logical(
    include_unregistered,
    arg = "include_unregistered"
  )
  group_id <- normalize_dashboard_group_id(group_id)

  student_ids <- analytics_student_ids(
    con = con,
    tutorial_id = tutorial_id,
    group_id = group_id
  )
  attempts <- get_attempts(con, tutorial_id = tutorial_id)
  attempts <- filter_attempts_by_student_ids(attempts, student_ids)
  selected <- if (nrow(attempts) == 0) {
    attempts
  } else {
    select_attempts_for_score(attempts, rule = rule)
  }
  registered <- get_questions(con, tutorial_id = tutorial_id)
  questions <- merge_question_metadata(
    registered = registered,
    selected = selected,
    tutorial_id = tutorial_id,
    include_unregistered = include_unregistered
  )

  if (nrow(questions) == 0) {
    return(empty_question_analytics_tibble())
  }

  n_possible_students <- length(student_ids)

  rows <- lapply(seq_len(nrow(questions)), function(index) {
    question <- questions[index, , drop = FALSE]
    question_id <- question$question_id[[1]]
    question_attempts <- attempts[attempts$question_id == question_id, , drop = FALSE]
    question_selected <- selected[selected$question_id == question_id, , drop = FALSE]
    answers <- question_selected$submitted_answer
    answered <- !is.na(answers) & nzchar(answers)
    scores <- question_selected$score
    selected_max_scores <- question_selected$max_score
    selected_max_scores[is.na(selected_max_scores)] <- question$max_score[[1]]
    score_percent <- ifelse(
      !is.na(scores) & !is.na(selected_max_scores) & selected_max_scores > 0,
      100 * scores / selected_max_scores,
      NA_real_
    )
    full_credit <- !is.na(scores) &
      !is.na(selected_max_scores) &
      selected_max_scores > 0 &
      scores >= selected_max_scores
    n_students <- length(unique(question_selected$student_id))
    n_answered <- sum(answered)

    tibble::tibble(
      tutorial_id = tutorial_id,
      question_id = question_id,
      question_label = question$question_label[[1]],
      question_type = question$question_type[[1]],
      max_score = question$max_score[[1]],
      n_possible_students = as.integer(n_possible_students),
      n_students = as.integer(n_students),
      n_attempts = as.integer(nrow(question_attempts)),
      n_answered = as.integer(n_answered),
      n_full_credit = as.integer(sum(full_credit)),
      mean_score = safe_mean(scores),
      mean_percent = safe_mean(score_percent),
      full_credit_rate = if (n_answered > 0) {
        100 * sum(full_credit) / n_answered
      } else {
        NA_real_
      },
      mean_attempts_per_student = if (n_students > 0) {
        nrow(question_attempts) / n_students
      } else {
        0
      }
    )
  })

  out <- dplyr::bind_rows(rows)
  out[order(out$mean_percent, -out$n_attempts, out$question_id, na.last = TRUE), , drop = FALSE]
}

#' Summarise tutorial students
#'
#' Builds one row per student with gradebook metrics, attempt counts, last
#' activity, registered metadata, and a simple status.
#'
#' @inheritParams summarise_questions
#'
#' @return A tibble with student-level pedagogical summary metrics.
#' @export
#'
#' @examples
#' db_path <- tempfile(fileext = ".sqlite")
#' con <- init_tracking_db(db_path, overwrite = TRUE)
#' register_students(con, "student_001")
#' register_questions(con, "module_01", c("q1", "q2"))
#' track_attempt(con, "student_001", "module_01", "q1", "mean(x)", score = 1, max_score = 1)
#' summarise_students(con, "module_01")
#' DBI::dbDisconnect(con)
summarise_students <- function(con,
                               tutorial_id,
                               rule = c("last", "best", "first"),
                               include_unregistered = TRUE,
                               group_id = NULL) {
  check_required_tables(con)

  tutorial_id <- validate_scalar_character(tutorial_id, arg = "tutorial_id")
  rule <- match.arg(rule)
  include_unregistered <- validate_scalar_logical(
    include_unregistered,
    arg = "include_unregistered"
  )
  group_id <- normalize_dashboard_group_id(group_id)
  registered <- get_students(con)
  student_ids <- analytics_student_ids(
    con = con,
    tutorial_id = tutorial_id,
    group_id = group_id
  )

  if (length(student_ids) == 0) {
    return(empty_student_analytics_tibble())
  }

  attempts <- get_attempts(con, tutorial_id = tutorial_id)
  attempts <- filter_attempts_by_student_ids(attempts, student_ids)
  grades <- dashboard_gradebook(
    con = con,
    tutorial_id = tutorial_id,
    student_ids = student_ids,
    rule = rule,
    include_unregistered = include_unregistered
  )
  counts <- attempt_counts_by_student(attempts)
  activity <- last_activity_by_student(attempts)
  out <- enrich_with_student_metadata(grades, registered)
  out <- dplyr::left_join(out, counts, by = "student_id")
  out <- dplyr::left_join(out, activity, by = "student_id")

  out$n_attempts[is.na(out$n_attempts)] <- 0L
  out$n_attempts <- as.integer(out$n_attempts)
  out$status <- status_from_student_summary(
    n_attempts = out$n_attempts,
    completed = out$completed
  )

  out <- out[, names(empty_student_analytics_tibble()), drop = FALSE]
  out[order(is.na(out$group_id), out$group_id, out$student_id), , drop = FALSE]
}

#' Detect potentially difficult questions
#'
#' Filters [summarise_questions()] to questions whose mean percent is below a
#' threshold and that have enough observed activity.
#'
#' @inheritParams summarise_questions
#' @param max_mean_percent Maximum mean percent used to flag a question.
#'   Defaults to `60`.
#' @param min_students Minimum number of students with a selected attempt.
#'   Defaults to `1`.
#' @param min_attempts Minimum number of raw attempts. Defaults to `1`.
#'
#' @return A tibble of flagged question summaries, sorted from lowest mean
#'   percent to highest.
#' @export
#'
#' @examples
#' db_path <- tempfile(fileext = ".sqlite")
#' con <- init_tracking_db(db_path, overwrite = TRUE)
#' track_attempt(con, "student_001", "module_01", "q1", "wrong", score = 0, max_score = 1)
#' detect_difficult_questions(con, "module_01")
#' DBI::dbDisconnect(con)
detect_difficult_questions <- function(con,
                                       tutorial_id,
                                       rule = c("last", "best", "first"),
                                       include_unregistered = TRUE,
                                       group_id = NULL,
                                       max_mean_percent = 60,
                                       min_students = 1,
                                       min_attempts = 1) {
  max_mean_percent <- validate_percent_threshold(
    max_mean_percent,
    arg = "max_mean_percent"
  )
  min_students <- validate_positive_integer(min_students, arg = "min_students")
  min_attempts <- validate_positive_integer(min_attempts, arg = "min_attempts")

  questions <- summarise_questions(
    con = con,
    tutorial_id = tutorial_id,
    rule = rule,
    include_unregistered = include_unregistered,
    group_id = group_id
  )

  difficult <- questions[
    !is.na(questions$mean_percent) &
      questions$mean_percent <= max_mean_percent &
      questions$n_students >= min_students &
      questions$n_attempts >= min_attempts,
    ,
    drop = FALSE
  ]

  difficult[
    order(difficult$mean_percent, -difficult$n_attempts, difficult$question_id),
    ,
    drop = FALSE
  ]
}

#' Detect potentially stalled students
#'
#' Filters [summarise_students()] to students with activity, incomplete work, and
#' a percent below a configurable threshold.
#'
#' @inheritParams summarise_students
#' @param max_percent Maximum percent used to flag a student. Defaults to `60`.
#' @param min_attempts Minimum number of attempts before a student can be
#'   flagged. Defaults to `1`.
#' @param require_incomplete If `TRUE`, only incomplete students are flagged.
#'   Defaults to `TRUE`.
#'
#' @return A tibble of flagged student summaries.
#' @export
#'
#' @examples
#' db_path <- tempfile(fileext = ".sqlite")
#' con <- init_tracking_db(db_path, overwrite = TRUE)
#' register_questions(con, "module_01", c("q1", "q2"))
#' track_attempt(con, "student_001", "module_01", "q1", "wrong", score = 0, max_score = 1)
#' detect_stalled_students(con, "module_01")
#' DBI::dbDisconnect(con)
detect_stalled_students <- function(con,
                                    tutorial_id,
                                    rule = c("last", "best", "first"),
                                    include_unregistered = TRUE,
                                    group_id = NULL,
                                    max_percent = 60,
                                    min_attempts = 1,
                                    require_incomplete = TRUE) {
  max_percent <- validate_percent_threshold(max_percent, arg = "max_percent")
  min_attempts <- validate_positive_integer(min_attempts, arg = "min_attempts")
  require_incomplete <- validate_scalar_logical(
    require_incomplete,
    arg = "require_incomplete"
  )

  students <- summarise_students(
    con = con,
    tutorial_id = tutorial_id,
    rule = rule,
    include_unregistered = include_unregistered,
    group_id = group_id
  )

  flagged <- students[
    students$n_attempts >= min_attempts &
      (is.na(students$percent) | students$percent <= max_percent),
    ,
    drop = FALSE
  ]

  if (require_incomplete) {
    flagged <- flagged[!flagged$completed, , drop = FALSE]
  }

  flagged[
    order(flagged$percent, -flagged$n_attempts, flagged$student_id, na.last = TRUE),
    ,
    drop = FALSE
  ]
}
