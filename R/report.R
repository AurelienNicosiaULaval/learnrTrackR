teacher_report_summary <- function(report) {
  students <- report$students
  questions <- report$questions
  difficult <- report$difficult_questions
  stalled <- report$stalled_students

  n_students <- nrow(students)
  n_completed <- if (n_students > 0) {
    sum(students$completed, na.rm = TRUE)
  } else {
    0L
  }
  mean_percent <- if (n_students > 0) {
    safe_mean(students$percent)
  } else {
    NA_real_
  }

  tibble::tibble(
    metric = c(
      "tutorial_id",
      "group_id",
      "scoring_rule",
      "n_students",
      "n_completed",
      "completion_rate",
      "mean_percent",
      "n_questions",
      "n_difficult_questions",
      "n_stalled_students"
    ),
    value = c(
      report$tutorial_id,
      if (is.null(report$group_id)) "" else report$group_id,
      report$rule,
      as.character(n_students),
      as.character(n_completed),
      as.character(if (n_students > 0) 100 * n_completed / n_students else NA_real_),
      as.character(mean_percent),
      as.character(nrow(questions)),
      as.character(nrow(difficult)),
      as.character(nrow(stalled))
    )
  )
}

teacher_report_rmd_lines <- function() {
  c(
    "---",
    "title: \"learnrTrackR teacher report\"",
    "output:",
    "  html_document:",
    "    toc: true",
    "    toc_depth: 2",
    "params:",
    "  report: null",
    "---",
    "",
    "```{r, include = FALSE}",
    "knitr::opts_chunk$set(echo = FALSE, message = FALSE, warning = FALSE)",
    "report <- params$report",
    "table_or_note <- function(x, note = \"No rows to display.\") {",
    "  if (nrow(x) == 0) {",
    "    return(note)",
    "  }",
    "  knitr::kable(x)",
    "}",
    "```",
    "",
    "# Summary",
    "",
    "Tutorial: `r report$tutorial_id`",
    "",
    "Group: `r if (is.null(report$group_id)) \"All groups\" else report$group_id`",
    "",
    "Scoring rule: `r report$rule`",
    "",
    "```{r}",
    "table_or_note(report$summary)",
    "```",
    "",
    "# Difficult Questions",
    "",
    "```{r}",
    "table_or_note(report$difficult_questions)",
    "```",
    "",
    "# Stalled Students",
    "",
    "```{r}",
    "table_or_note(report$stalled_students)",
    "```",
    "",
    "# Question Summary",
    "",
    "```{r}",
    "table_or_note(report$questions)",
    "```",
    "",
    "# Student Summary",
    "",
    "```{r}",
    "table_or_note(report$students)",
    "```"
  )
}

#' Prepare teacher report data
#'
#' Builds the data tables used by [generate_teacher_report()] without rendering
#' an HTML file. This is useful for inspection, testing, and custom reports.
#'
#' @param con A DBI connection.
#' @param tutorial_id Tutorial identifier. Required.
#' @param rule Scoring rule passed to [summarise_questions()] and
#'   [summarise_students()].
#' @param include_unregistered If `TRUE`, include attempted questions not
#'   registered with [register_questions()].
#' @param group_id Optional registered student group identifier.
#' @param max_mean_percent Maximum mean question percent used by
#'   [detect_difficult_questions()].
#' @param max_student_percent Maximum student percent used by
#'   [detect_stalled_students()].
#' @param min_students Minimum student count for difficult-question detection.
#' @param min_attempts Minimum attempt count for difficult-question and
#'   stalled-student detection.
#'
#' @return A list containing report metadata and tibbles named `summary`,
#'   `questions`, `students`, `difficult_questions`, and `stalled_students`.
#' @export
#'
#' @examples
#' db_path <- tempfile(fileext = ".sqlite")
#' con <- init_tracking_db(db_path, overwrite = TRUE)
#' register_questions(con, "module_01", c("q1", "q2"))
#' track_attempt(con, "student_001", "module_01", "q1", "mean(x)", score = 1, max_score = 1)
#' teacher_report_data(con, "module_01")
#' DBI::dbDisconnect(con)
teacher_report_data <- function(con,
                                tutorial_id,
                                rule = c("last", "best", "first"),
                                include_unregistered = TRUE,
                                group_id = NULL,
                                max_mean_percent = 60,
                                max_student_percent = 60,
                                min_students = 1,
                                min_attempts = 1) {
  check_required_tables(con)

  tutorial_id <- validate_scalar_character(tutorial_id, arg = "tutorial_id")
  rule <- match.arg(rule)
  include_unregistered <- validate_scalar_logical(
    include_unregistered,
    arg = "include_unregistered"
  )
  group_id <- normalize_dashboard_group_id(group_id)
  max_mean_percent <- validate_percent_threshold(
    max_mean_percent,
    arg = "max_mean_percent"
  )
  max_student_percent <- validate_percent_threshold(
    max_student_percent,
    arg = "max_student_percent"
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
  students <- summarise_students(
    con = con,
    tutorial_id = tutorial_id,
    rule = rule,
    include_unregistered = include_unregistered,
    group_id = group_id
  )
  difficult <- detect_difficult_questions(
    con = con,
    tutorial_id = tutorial_id,
    rule = rule,
    include_unregistered = include_unregistered,
    group_id = group_id,
    max_mean_percent = max_mean_percent,
    min_students = min_students,
    min_attempts = min_attempts
  )
  stalled <- detect_stalled_students(
    con = con,
    tutorial_id = tutorial_id,
    rule = rule,
    include_unregistered = include_unregistered,
    group_id = group_id,
    max_percent = max_student_percent,
    min_attempts = min_attempts
  )

  report <- list(
    tutorial_id = tutorial_id,
    group_id = group_id,
    rule = rule,
    generated_at = normalize_timestamp(Sys.time()),
    questions = questions,
    students = students,
    difficult_questions = difficult,
    stalled_students = stalled
  )
  report$summary <- teacher_report_summary(report)

  report
}

#' Generate an HTML teacher report
#'
#' Renders a small HTML report for one tutorial using question summaries,
#' student summaries, difficult-question flags, and stalled-student flags.
#'
#' @inheritParams teacher_report_data
#' @param path Output HTML file path.
#' @param quiet If `TRUE`, suppress rendering output from [rmarkdown::render()].
#'
#' @return The output path, invisibly.
#' @export
#'
#' @examples
#' \dontrun{
#' db_path <- tempfile(fileext = ".sqlite")
#' con <- init_tracking_db(db_path, overwrite = TRUE)
#' register_questions(con, "module_01", c("q1", "q2"))
#' track_attempt(con, "student_001", "module_01", "q1", "mean(x)", score = 1, max_score = 1)
#' generate_teacher_report(con, tempfile(fileext = ".html"), "module_01")
#' DBI::dbDisconnect(con)
#' }
generate_teacher_report <- function(con,
                                    path,
                                    tutorial_id,
                                    rule = c("last", "best", "first"),
                                    include_unregistered = TRUE,
                                    group_id = NULL,
                                    max_mean_percent = 60,
                                    max_student_percent = 60,
                                    min_students = 1,
                                    min_attempts = 1,
                                    quiet = TRUE) {
  if (!requireNamespace("rmarkdown", quietly = TRUE)) {
    cli::cli_abort(
      "Package {.pkg rmarkdown} is required to generate teacher reports."
    )
  }

  path <- validate_path(path, arg = "path")
  quiet <- validate_scalar_logical(quiet, arg = "quiet")

  parent_dir <- dirname(path)
  if (!dir.exists(parent_dir)) {
    cli::cli_abort("The parent directory of {.arg path} does not exist.")
  }

  report <- teacher_report_data(
    con = con,
    tutorial_id = tutorial_id,
    rule = rule,
    include_unregistered = include_unregistered,
    group_id = group_id,
    max_mean_percent = max_mean_percent,
    max_student_percent = max_student_percent,
    min_students = min_students,
    min_attempts = min_attempts
  )

  input <- tempfile(fileext = ".Rmd")
  writeLines(teacher_report_rmd_lines(), input)

  rmarkdown::render(
    input = input,
    output_file = basename(path),
    output_dir = dirname(path),
    params = list(report = report),
    envir = new.env(parent = globalenv()),
    quiet = quiet
  )

  invisible(path)
}
