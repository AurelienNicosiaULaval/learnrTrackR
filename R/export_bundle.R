resolve_export_student_ids <- function(con,
                                       tutorial_id,
                                       student_id = NULL,
                                       group_id = NULL) {
  student_id <- validate_scalar_character(
    student_id,
    arg = "student_id",
    allow_null = TRUE
  )
  group_id <- normalize_dashboard_group_id(group_id)

  registered <- get_students(con)
  selected_registered <- filter_registered_students(registered, group_id)
  attempts <- get_attempts(con, tutorial_id = tutorial_id)

  ids <- dashboard_student_ids(
    registered_students = selected_registered,
    attempts = attempts,
    group_id = group_id
  )

  if (!is.null(student_id)) {
    ids <- if (is.null(group_id)) student_id else intersect(ids, student_id)
  }

  sort(unique(ids))
}

tracking_export_summary <- function(tutorial_id,
                                    student_id,
                                    group_id,
                                    students,
                                    attempts,
                                    scores,
                                    grades,
                                    questions) {
  completed <- if (nrow(grades) > 0) {
    sum(grades$completed, na.rm = TRUE)
  } else {
    0L
  }

  tibble::tibble(
    metric = c(
      "tutorial_id",
      "student_id",
      "group_id",
      "n_students",
      "n_attempts",
      "n_scores",
      "n_gradebook_rows",
      "n_questions",
      "n_completed"
    ),
    value = c(
      tutorial_id,
      if (is.null(student_id)) "" else student_id,
      if (is.null(group_id)) "" else group_id,
      as.character(nrow(students)),
      as.character(nrow(attempts)),
      as.character(nrow(scores)),
      as.character(nrow(grades)),
      as.character(nrow(questions)),
      as.character(completed)
    )
  )
}

#' Prepare rich export data
#'
#' Builds a set of export tables for a tutorial, optionally filtered to one
#' registered group or one student.
#'
#' @param con A DBI connection.
#' @param tutorial_id Tutorial identifier. Required.
#' @param student_id Optional student identifier.
#' @param group_id Optional registered student group identifier.
#' @param rule Scoring rule passed to [gradebook()].
#' @param include_unregistered If `TRUE`, include attempted questions that were
#'   not registered with [register_questions()].
#'
#' @return A list containing `summary`, `students`, `attempts`, `scores`,
#'   `gradebook`, `questions`, and `moodle_grades` tibbles.
#' @export
#'
#' @examples
#' db_path <- tempfile(fileext = ".sqlite")
#' con <- init_tracking_db(db_path, overwrite = TRUE)
#' register_students(con, data.frame(student_id = "student_001", group_id = "A"))
#' register_questions(con, "module_01", c("q1", "q2"))
#' track_attempt(con, "student_001", "module_01", "q1", "mean(x)", score = 1, max_score = 1)
#' tracking_export_data(con, tutorial_id = "module_01", group_id = "A")
#' DBI::dbDisconnect(con)
tracking_export_data <- function(con,
                                 tutorial_id,
                                 student_id = NULL,
                                 group_id = NULL,
                                 rule = c("last", "best", "first"),
                                 include_unregistered = TRUE) {
  check_required_tables(con)

  tutorial_id <- validate_scalar_character(tutorial_id, arg = "tutorial_id")
  student_id <- validate_scalar_character(
    student_id,
    arg = "student_id",
    allow_null = TRUE
  )
  group_id <- normalize_dashboard_group_id(group_id)
  rule <- match.arg(rule)
  include_unregistered <- validate_scalar_logical(
    include_unregistered,
    arg = "include_unregistered"
  )

  student_ids <- resolve_export_student_ids(
    con,
    tutorial_id = tutorial_id,
    student_id = student_id,
    group_id = group_id
  )

  registered <- get_students(con)
  students <- dashboard_students_table(
    registered_students = filter_registered_students(registered, group_id),
    attempts = get_attempts(con, tutorial_id = tutorial_id),
    student_ids = student_ids
  )

  attempts <- filter_attempts_by_student_ids(
    get_attempts(con, tutorial_id = tutorial_id),
    student_ids
  )

  scores <- compute_scores(con, tutorial_id = tutorial_id, rule = rule)
  scores <- filter_attempts_by_student_ids(scores, student_ids)

  grades <- dashboard_gradebook(
    con = con,
    tutorial_id = tutorial_id,
    student_ids = student_ids,
    rule = rule,
    include_unregistered = include_unregistered
  )

  questions <- get_questions(con, tutorial_id = tutorial_id)

  attempts <- enrich_with_student_metadata(attempts, registered)
  scores <- enrich_with_student_metadata(scores, registered)
  grades <- enrich_with_student_metadata(grades, registered)

  moodle <- dashboard_moodle_grades(
    grades = grades,
    tutorial_id = tutorial_id
  )

  list(
    summary = tracking_export_summary(
      tutorial_id = tutorial_id,
      student_id = student_id,
      group_id = group_id,
      students = students,
      attempts = attempts,
      scores = scores,
      grades = grades,
      questions = questions
    ),
    students = students,
    attempts = attempts,
    scores = scores,
    gradebook = grades,
    questions = questions,
    moodle_grades = moodle
  )
}

#' Export a rich tracking CSV bundle
#'
#' Writes several CSV files for a tutorial: summary, students, attempts, scores,
#' gradebook, questions, and Moodle-ready grades. The export can be filtered by
#' registered group or by student.
#'
#' @inheritParams tracking_export_data
#' @param path Output directory. It is created if it does not exist.
#' @param prefix Optional file prefix. Defaults to `tutorial_id` plus the
#'   selected group or student filter.
#'
#' @return A tibble with export table names and file paths, invisibly.
#' @export
#'
#' @examples
#' db_path <- tempfile(fileext = ".sqlite")
#' out_dir <- tempfile()
#' con <- init_tracking_db(db_path, overwrite = TRUE)
#' register_students(con, data.frame(student_id = "student_001", group_id = "A"))
#' register_questions(con, "module_01", c("q1", "q2"))
#' track_attempt(con, "student_001", "module_01", "q1", "mean(x)", score = 1, max_score = 1)
#' export_tracking_bundle(con, out_dir, tutorial_id = "module_01", group_id = "A")
#' DBI::dbDisconnect(con)
export_tracking_bundle <- function(con,
                                   path,
                                   tutorial_id,
                                   student_id = NULL,
                                   group_id = NULL,
                                   rule = c("last", "best", "first"),
                                   include_unregistered = TRUE,
                                   prefix = NULL) {
  path <- validate_path(path, arg = "path")
  tutorial_id <- validate_scalar_character(tutorial_id, arg = "tutorial_id")
  student_id <- validate_scalar_character(
    student_id,
    arg = "student_id",
    allow_null = TRUE
  )
  group_id <- normalize_dashboard_group_id(group_id)
  prefix <- validate_scalar_character(
    prefix,
    arg = "prefix",
    allow_null = TRUE
  )
  rule <- match.arg(rule)

  if (!dir.exists(path)) {
    dir.create(path, recursive = TRUE)
  }

  if (is.null(prefix)) {
    prefix <- safe_dashboard_filename_part(tutorial_id, "tracking")

    if (!is.null(group_id)) {
      prefix <- paste0(
        prefix,
        "-group-",
        safe_dashboard_filename_part(group_id, "group")
      )
    }

    if (!is.null(student_id)) {
      prefix <- paste0(
        prefix,
        "-student-",
        safe_dashboard_filename_part(student_id, "student")
      )
    }
  }

  data <- tracking_export_data(
    con = con,
    tutorial_id = tutorial_id,
    student_id = student_id,
    group_id = group_id,
    rule = rule,
    include_unregistered = include_unregistered
  )

  table_names <- names(data)
  file_paths <- file.path(path, paste0(prefix, "-", table_names, ".csv"))

  for (index in seq_along(table_names)) {
    readr::write_csv(data[[table_names[[index]]]], file_paths[[index]])
  }

  out <- tibble::tibble(
    table = table_names,
    path = file_paths
  )

  invisible(out)
}
