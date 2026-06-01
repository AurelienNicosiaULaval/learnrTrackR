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
