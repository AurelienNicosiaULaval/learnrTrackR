#' Export attempts or scores to CSV
#'
#' Writes raw attempts, observed-attempt scores, or gradebook rows to a CSV file using
#' [readr::write_csv()].
#'
#' @param con A DBI connection.
#' @param path Output CSV path.
#' @param type Export type. Use `"attempts"` for raw attempts, `"scores"` for
#'   observed-attempt scores, or `"gradebook"` for scores based on registered
#'   expected questions.
#' @param tutorial_id Optional tutorial identifier.
#' @param rule Scoring rule used when `type = "scores"`.
#' @param include_unregistered If `TRUE`, gradebook exports include attempted
#'   questions that were not registered with [register_questions()].
#'
#' @return The output path, invisibly.
#' @export
#'
#' @examples
#' db_path <- tempfile(fileext = ".sqlite")
#' csv_path <- tempfile(fileext = ".csv")
#' con <- init_tracking_db(db_path, overwrite = TRUE)
#' track_attempt(con, "student_001", "module_01", "q1", "mean(x)", score = 1, max_score = 1)
#' export_results(con, csv_path, type = "attempts")
#' DBI::dbDisconnect(con)
export_results <- function(con,
                           path,
                           type = c("attempts", "scores", "gradebook"),
                           tutorial_id = NULL,
                           rule = "last",
                           include_unregistered = TRUE) {
  check_required_tables(con)

  path <- validate_path(path)
  type <- match.arg(type)

  parent_dir <- dirname(path)
  if (!dir.exists(parent_dir)) {
    cli::cli_abort("The parent directory of {.arg path} does not exist.")
  }

  tutorial_id <- validate_scalar_character(
    tutorial_id,
    arg = "tutorial_id",
    allow_null = TRUE
  )

  data <- switch(
    type,
    attempts = get_attempts(con, tutorial_id = tutorial_id),
    scores = compute_scores(con, tutorial_id = tutorial_id, rule = rule),
    gradebook = {
      if (is.null(tutorial_id)) {
        cli::cli_abort(
          "{.arg tutorial_id} is required when {.arg type} is {.val gradebook}."
        )
      }

      gradebook(
        con,
        tutorial_id = tutorial_id,
        rule = rule,
        include_unregistered = include_unregistered
      )
    }
  )

  readr::write_csv(data, path)

  invisible(path)
}
