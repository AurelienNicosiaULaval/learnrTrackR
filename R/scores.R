attempt_key <- function(x) {
  paste(x$student_id, x$tutorial_id, x$question_id, sep = "\r")
}

select_attempts_for_score <- function(attempts, rule) {
  timestamp_order <- parse_timestamp_for_order(attempts$timestamp)

  if (rule == "first") {
    ordered <- attempts[order(
      attempts$student_id,
      attempts$tutorial_id,
      attempts$question_id,
      timestamp_order,
      attempts$attempt_number,
      attempts$attempt_id
    ), , drop = FALSE]

    return(ordered[!duplicated(attempt_key(ordered)), , drop = FALSE])
  }

  if (rule == "last") {
    ordered <- attempts[order(
      attempts$student_id,
      attempts$tutorial_id,
      attempts$question_id,
      timestamp_order,
      attempts$attempt_number,
      attempts$attempt_id
    ), , drop = FALSE]

    return(
      ordered[!duplicated(attempt_key(ordered), fromLast = TRUE), , drop = FALSE]
    )
  }

  score_order <- attempts$score
  score_order[is.na(score_order)] <- -Inf

  ordered <- attempts[order(
    attempts$student_id,
    attempts$tutorial_id,
    attempts$question_id,
    -score_order,
    -timestamp_order,
    -attempts$attempt_id
  ), , drop = FALSE]

  ordered[!duplicated(attempt_key(ordered)), , drop = FALSE]
}

summarise_selected_scores <- function(selected) {
  group_key <- paste(selected$student_id, selected$tutorial_id, sep = "\r")
  groups <- split(seq_len(nrow(selected)), group_key)

  rows <- lapply(groups, function(index) {
    current <- selected[index, , drop = FALSE]
    score <- sum(current$score, na.rm = TRUE)
    max_score <- sum(current$max_score, na.rm = TRUE)
    answers <- current$submitted_answer
    answered <- !is.na(answers) & nzchar(answers)

    data.frame(
      student_id = current$student_id[[1]],
      tutorial_id = current$tutorial_id[[1]],
      score = score,
      max_score = max_score,
      percent = if (max_score > 0) 100 * score / max_score else NA_real_,
      n_questions = length(unique(current$question_id)),
      n_answered = sum(answered),
      stringsAsFactors = FALSE
    )
  })

  dplyr::bind_rows(rows)
}

question_metadata_from_attempts <- function(selected, tutorial_id) {
  if (nrow(selected) == 0) {
    return(tibble::tibble(
      question_id = character(),
      tutorial_id = character(),
      question_label = character(),
      question_type = character(),
      max_score = numeric()
    ))
  }

  groups <- split(seq_len(nrow(selected)), selected$question_id)

  rows <- lapply(groups, function(index) {
    current <- selected[index, , drop = FALSE]
    max_score <- current$max_score
    max_score <- max_score[!is.na(max_score)]

    data.frame(
      question_id = current$question_id[[1]],
      tutorial_id = tutorial_id,
      question_label = current$question_id[[1]],
      question_type = NA_character_,
      max_score = if (length(max_score) > 0) max(max_score) else 0,
      stringsAsFactors = FALSE
    )
  })

  dplyr::bind_rows(rows)
}

merge_question_metadata <- function(registered, selected, tutorial_id, include_unregistered) {
  if (nrow(registered) == 0) {
    return(question_metadata_from_attempts(selected, tutorial_id))
  }

  out <- registered[, c(
    "question_id",
    "tutorial_id",
    "question_label",
    "question_type",
    "max_score"
  ), drop = FALSE]

  if (!include_unregistered || nrow(selected) == 0) {
    return(tibble::as_tibble(out))
  }

  unregistered <- selected[!selected$question_id %in% out$question_id, , drop = FALSE]

  if (nrow(unregistered) == 0) {
    return(tibble::as_tibble(out))
  }

  dplyr::bind_rows(
    tibble::as_tibble(out),
    question_metadata_from_attempts(unregistered, tutorial_id)
  )
}

summarise_gradebook_for_student <- function(student_id,
                                            tutorial_id,
                                            questions,
                                            selected) {
  selected <- selected[selected$student_id == student_id, , drop = FALSE]

  rows <- lapply(seq_len(nrow(questions)), function(index) {
    question <- questions[index, , drop = FALSE]
    attempt <- selected[selected$question_id == question$question_id[[1]], , drop = FALSE]

    if (nrow(attempt) == 0) {
      return(data.frame(
        question_id = question$question_id[[1]],
        score = 0,
        max_score = question$max_score[[1]],
        answered = FALSE,
        stringsAsFactors = FALSE
      ))
    }

    submitted_answer <- attempt$submitted_answer[[1]]
    answered <- !is.na(submitted_answer) && nzchar(submitted_answer)
    score <- attempt$score[[1]]

    data.frame(
      question_id = question$question_id[[1]],
      score = if (is.na(score)) 0 else score,
      max_score = question$max_score[[1]],
      answered = answered,
      stringsAsFactors = FALSE
    )
  })

  question_scores <- dplyr::bind_rows(rows)

  score <- sum(question_scores$score, na.rm = TRUE)
  max_score <- sum(question_scores$max_score, na.rm = TRUE)
  n_questions <- nrow(question_scores)
  n_answered <- sum(question_scores$answered)
  n_unanswered <- n_questions - n_answered

  tibble::tibble(
    student_id = student_id,
    tutorial_id = tutorial_id,
    score = score,
    max_score = max_score,
    percent = if (max_score > 0) 100 * score / max_score else NA_real_,
    n_questions = n_questions,
    n_answered = n_answered,
    n_unanswered = n_unanswered,
    completed = n_questions > 0 && n_unanswered == 0
  )
}

#' Compute summarized tutorial scores
#'
#' Computes one score per student and tutorial from recorded attempts. For each
#' question, the selected attempt is determined by `rule`.
#'
#' @param con A DBI connection.
#' @param tutorial_id Optional tutorial identifier used to filter attempts.
#' @param rule Scoring rule. `"last"` keeps the last attempt per question,
#'   `"best"` keeps the attempt with the highest score, and `"first"` keeps the
#'   first attempt.
#'
#' @return A tibble with `student_id`, `tutorial_id`, `score`, `max_score`,
#'   `percent`, `n_questions`, and `n_answered`.
#' @export
#'
#' @examples
#' db_path <- tempfile(fileext = ".sqlite")
#' con <- init_tracking_db(db_path, overwrite = TRUE)
#' track_attempt(con, "student_001", "module_01", "q1", "mean(x)", score = 1, max_score = 1)
#' compute_scores(con, tutorial_id = "module_01")
#' DBI::dbDisconnect(con)
compute_scores <- function(con,
                           tutorial_id = NULL,
                           rule = c("last", "best", "first")) {
  rule <- match.arg(rule)

  tutorial_id <- validate_scalar_character(
    tutorial_id,
    arg = "tutorial_id",
    allow_null = TRUE
  )

  attempts <- get_attempts(con, tutorial_id = tutorial_id)

  if (nrow(attempts) == 0) {
    return(empty_scores_tibble())
  }

  selected <- select_attempts_for_score(attempts, rule = rule)

  if (nrow(selected) == 0) {
    return(empty_scores_tibble())
  }

  summarise_selected_scores(selected)
}

#' Build a gradebook with expected questions
#'
#' Computes one gradebook row per student and tutorial. Unlike
#' [compute_scores()], this function uses registered questions from
#' [register_questions()] when available, so unanswered questions are counted in
#' the denominator.
#'
#' @param con A DBI connection.
#' @param tutorial_id Tutorial identifier. Required.
#' @param student_id Optional student identifier. If supplied, the gradebook
#'   includes that student even when they have no recorded attempts.
#' @param rule Scoring rule. `"last"` keeps the last attempt per question,
#'   `"best"` keeps the attempt with the highest score, and `"first"` keeps the
#'   first attempt.
#' @param include_unregistered If `TRUE`, attempted questions that are not in
#'   the registered question list are included in the gradebook. If `FALSE`,
#'   they are ignored when registered questions exist.
#'
#' @return A tibble with `student_id`, `tutorial_id`, `score`, `max_score`,
#'   `percent`, `n_questions`, `n_answered`, `n_unanswered`, and `completed`.
#' @export
#'
#' @examples
#' db_path <- tempfile(fileext = ".sqlite")
#' con <- init_tracking_db(db_path, overwrite = TRUE)
#' register_questions(con, "module_01", c("q1", "q2"))
#' track_attempt(con, "student_001", "module_01", "q1", "mean(x)", score = 1, max_score = 1)
#' gradebook(con, tutorial_id = "module_01")
#' DBI::dbDisconnect(con)
gradebook <- function(con,
                      tutorial_id,
                      student_id = NULL,
                      rule = c("last", "best", "first"),
                      include_unregistered = TRUE) {
  check_required_tables(con)

  tutorial_id <- validate_scalar_character(tutorial_id, arg = "tutorial_id")
  student_id <- validate_scalar_character(
    student_id,
    arg = "student_id",
    allow_null = TRUE
  )
  rule <- match.arg(rule)
  include_unregistered <- validate_scalar_logical(
    include_unregistered,
    arg = "include_unregistered"
  )

  attempts <- get_attempts(con, student_id = student_id, tutorial_id = tutorial_id)
  selected <- if (nrow(attempts) == 0) attempts else select_attempts_for_score(attempts, rule = rule)
  registered <- get_questions(con, tutorial_id = tutorial_id)
  questions <- merge_question_metadata(
    registered = registered,
    selected = selected,
    tutorial_id = tutorial_id,
    include_unregistered = include_unregistered
  )

  students <- if (is.null(student_id)) {
    unique(attempts$student_id)
  } else {
    student_id
  }

  if (length(students) == 0) {
    return(empty_gradebook_tibble())
  }

  rows <- lapply(students, function(current_student_id) {
    summarise_gradebook_for_student(
      student_id = current_student_id,
      tutorial_id = tutorial_id,
      questions = questions,
      selected = selected
    )
  })

  dplyr::bind_rows(rows)
}
