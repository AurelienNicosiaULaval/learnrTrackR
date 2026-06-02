normalize_questions_data <- function(questions,
                                     tutorial_id,
                                     default_max_score,
                                     timestamp) {
  if (is.character(questions)) {
    questions <- tibble::tibble(question_id = questions)
  }

  if (!is.data.frame(questions)) {
    cli::cli_abort(
      "{.arg questions} must be a data frame or a character vector."
    )
  }

  questions <- tibble::as_tibble(questions)

  if (!"question_id" %in% names(questions)) {
    cli::cli_abort("{.arg questions} must contain a {.field question_id} column.")
  }

  questions$question_id <- as.character(questions$question_id)

  if (any(is.na(questions$question_id)) || any(!nzchar(questions$question_id))) {
    cli::cli_abort("{.field question_id} values must not be missing or empty.")
  }

  if (any(duplicated(questions$question_id))) {
    duplicated_ids <- unique(questions$question_id[duplicated(questions$question_id)])
    cli::cli_abort(c(
      "{.arg questions} contains duplicated question identifiers.",
      "x" = "Duplicated identifier{?s}: {duplicated_ids}."
    ))
  }

  if (!"question_label" %in% names(questions)) {
    questions$question_label <- questions$question_id
  }

  if (!"question_type" %in% names(questions)) {
    questions$question_type <- NA_character_
  }

  if (!"max_score" %in% names(questions)) {
    questions$max_score <- default_max_score
  }

  questions$question_label <- as.character(questions$question_label)
  questions$question_type <- as.character(questions$question_type)
  questions$max_score <- as.numeric(questions$max_score)

  missing_max_score <- is.na(questions$max_score)
  questions$max_score[missing_max_score] <- default_max_score

  if (any(questions$max_score < 0)) {
    cli::cli_abort("{.field max_score} values must be greater than or equal to 0.")
  }

  tibble::tibble(
    question_id = questions$question_id,
    tutorial_id = tutorial_id,
    question_label = questions$question_label,
    question_type = questions$question_type,
    max_score = questions$max_score,
    created_at = timestamp
  )
}

#' Register expected tutorial questions
#'
#' Stores the expected questions for a tutorial in the `questions` table. These
#' registered questions are used by [gradebook()] to count unanswered questions
#' in the score denominator.
#'
#' @param con A DBI connection.
#' @param tutorial_id Tutorial identifier.
#' @param questions A data frame with a required `question_id` column and
#'   optional `question_label`, `question_type`, and `max_score` columns. A
#'   character vector is treated as a vector of question identifiers.
#' @param default_max_score Score used when `max_score` is missing. Defaults to
#'   `1`.
#' @param overwrite If `TRUE`, delete existing registered questions for
#'   `tutorial_id` before inserting `questions`. If `FALSE`, upsert the supplied
#'   questions and leave other registered questions unchanged.
#' @param timestamp Creation timestamp for inserted rows. Defaults to
#'   `Sys.time()`.
#'
#' @return A tibble of registered questions.
#' @export
#'
#' @examples
#' db_path <- tempfile(fileext = ".sqlite")
#' con <- init_tracking_db(db_path, overwrite = TRUE)
#' register_questions(
#'   con,
#'   tutorial_id = "module_01",
#'   questions = data.frame(
#'     question_id = c("q1", "q2"),
#'     max_score = c(1, 2)
#'   )
#' )
#' DBI::dbDisconnect(con)
register_questions <- function(con,
                               tutorial_id,
                               questions,
                               default_max_score = 1,
                               overwrite = FALSE,
                               timestamp = Sys.time()) {
  check_required_tables(con)

  tutorial_id <- validate_scalar_character(tutorial_id, arg = "tutorial_id")
  default_max_score <- validate_scalar_numeric(
    default_max_score,
    arg = "default_max_score"
  )
  overwrite <- validate_scalar_logical(overwrite, arg = "overwrite")
  timestamp <- normalize_timestamp(timestamp)

  if (default_max_score < 0) {
    cli::cli_abort("{.arg default_max_score} must be greater than or equal to 0.")
  }

  normalized <- normalize_questions_data(
    questions = questions,
    tutorial_id = tutorial_id,
    default_max_score = default_max_score,
    timestamp = timestamp
  )

  DBI::dbWithTransaction(con, {
    if (overwrite) {
      tracking_db_execute(
        con,
        "DELETE FROM questions WHERE tutorial_id = ?",
        params = list(tutorial_id)
      )
    }

    for (row_index in seq_len(nrow(normalized))) {
      tracking_db_execute(
        con,
        paste(
          "INSERT INTO questions",
          "(question_id, tutorial_id, question_label, question_type, max_score, created_at)",
          "VALUES (?, ?, ?, ?, ?, ?)",
          "ON CONFLICT(question_id, tutorial_id) DO UPDATE SET",
          "question_label = COALESCE(excluded.question_label, questions.question_label),",
          "question_type = COALESCE(excluded.question_type, questions.question_type),",
          "max_score = COALESCE(excluded.max_score, questions.max_score)"
        ),
        params = list(
          normalized$question_id[[row_index]],
          normalized$tutorial_id[[row_index]],
          normalized$question_label[[row_index]],
          normalized$question_type[[row_index]],
          normalized$max_score[[row_index]],
          normalized$created_at[[row_index]]
        )
      )
    }
  })

  get_questions(con, tutorial_id = tutorial_id)
}

#' Read registered tutorial questions
#'
#' Reads question definitions from the `questions` table.
#'
#' @param con A DBI connection.
#' @param tutorial_id Optional tutorial identifier.
#'
#' @return A tibble of registered questions.
#' @export
#'
#' @examples
#' db_path <- tempfile(fileext = ".sqlite")
#' con <- init_tracking_db(db_path, overwrite = TRUE)
#' register_questions(con, "module_01", c("q1", "q2"))
#' get_questions(con, tutorial_id = "module_01")
#' DBI::dbDisconnect(con)
get_questions <- function(con, tutorial_id = NULL) {
  check_required_tables(con)

  tutorial_id <- validate_scalar_character(
    tutorial_id,
    arg = "tutorial_id",
    allow_null = TRUE
  )

  query <- paste(
    "SELECT question_id, tutorial_id, question_label, question_type, max_score, created_at",
    "FROM questions"
  )

  if (is.null(tutorial_id)) {
    questions <- tracking_db_get_query(
      con,
      paste(query, "ORDER BY tutorial_id ASC, question_id ASC")
    )
  } else {
    questions <- tracking_db_get_query(
      con,
      paste(query, "WHERE tutorial_id = ? ORDER BY question_id ASC"),
      params = list(tutorial_id)
    )
  }

  tibble::as_tibble(questions)
}
