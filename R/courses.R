normalize_courses_data <- function(courses, timestamp) {
  if (is.character(courses)) {
    courses <- tibble::tibble(course_id = courses)
  }

  if (!is.data.frame(courses)) {
    cli::cli_abort(
      "{.arg courses} must be a data frame or a character vector."
    )
  }

  courses <- tibble::as_tibble(courses)

  if (!"course_id" %in% names(courses)) {
    cli::cli_abort("{.arg courses} must contain a {.field course_id} column.")
  }

  courses$course_id <- trimws(as.character(courses$course_id))

  if (any(is.na(courses$course_id)) || any(!nzchar(courses$course_id))) {
    cli::cli_abort("{.field course_id} values must not be missing or empty.")
  }

  if (any(duplicated(courses$course_id))) {
    duplicated_ids <- unique(courses$course_id[duplicated(courses$course_id)])
    cli::cli_abort(c(
      "{.arg courses} contains duplicated course identifiers.",
      "x" = "Duplicated identifier{?s}: {duplicated_ids}."
    ))
  }

  if (!"course_label" %in% names(courses)) {
    courses$course_label <- courses$course_id
  }

  if (!"semester" %in% names(courses)) {
    courses$semester <- NA_character_
  }

  tibble::tibble(
    course_id = courses$course_id,
    course_label = as.character(courses$course_label),
    semester = as.character(courses$semester),
    created_at = timestamp
  )
}

#' Register courses
#'
#' Stores course metadata in the `courses` table.
#'
#' @param con A DBI connection.
#' @param courses A data frame with a required `course_id` column and optional
#'   `course_label` and `semester` columns. A character vector is treated as a
#'   vector of course identifiers.
#' @param timestamp Creation timestamp for inserted rows. Defaults to
#'   `Sys.time()`.
#'
#' @return A tibble of registered courses.
#' @export
#'
#' @examples
#' db_path <- tempfile(fileext = ".sqlite")
#' con <- init_tracking_db(db_path, overwrite = TRUE)
#' register_courses(con, data.frame(course_id = "stat101", semester = "W2026"))
#' DBI::dbDisconnect(con)
register_courses <- function(con, courses, timestamp = Sys.time()) {
  check_required_tables(con)
  timestamp <- normalize_timestamp(timestamp)

  normalized <- normalize_courses_data(courses, timestamp = timestamp)

  DBI::dbWithTransaction(con, {
    for (row_index in seq_len(nrow(normalized))) {
      tracking_db_execute(
        con,
        paste(
          "INSERT INTO courses",
          "(course_id, course_label, semester, created_at)",
          "VALUES (?, ?, ?, ?)",
          "ON CONFLICT(course_id) DO UPDATE SET",
          "course_label = COALESCE(excluded.course_label, courses.course_label),",
          "semester = COALESCE(excluded.semester, courses.semester)"
        ),
        params = list(
          normalized$course_id[[row_index]],
          normalized$course_label[[row_index]],
          normalized$semester[[row_index]],
          normalized$created_at[[row_index]]
        )
      )
    }
  })

  get_courses(con)
}

#' Read registered courses
#'
#' Reads course definitions from the `courses` table.
#'
#' @param con A DBI connection.
#' @param course_id Optional course identifier.
#'
#' @return A tibble of registered courses.
#' @export
#'
#' @examples
#' db_path <- tempfile(fileext = ".sqlite")
#' con <- init_tracking_db(db_path, overwrite = TRUE)
#' register_courses(con, "stat101")
#' get_courses(con, course_id = "stat101")
#' DBI::dbDisconnect(con)
get_courses <- function(con, course_id = NULL) {
  check_required_tables(con)

  course_id <- validate_scalar_character(
    course_id,
    arg = "course_id",
    allow_null = TRUE
  )

  query <- paste(
    "SELECT course_id, course_label, semester, created_at",
    "FROM courses"
  )

  if (is.null(course_id)) {
    courses <- tracking_db_get_query(
      con,
      paste(query, "ORDER BY course_id ASC")
    )
  } else {
    courses <- tracking_db_get_query(
      con,
      paste(query, "WHERE course_id = ? ORDER BY course_id ASC"),
      params = list(course_id)
    )
  }

  tibble::as_tibble(courses)
}

normalize_tutorials_data <- function(tutorials, course_id, timestamp) {
  if (is.character(tutorials)) {
    tutorials <- tibble::tibble(tutorial_id = tutorials)
  }

  if (!is.data.frame(tutorials)) {
    cli::cli_abort(
      "{.arg tutorials} must be a data frame or a character vector."
    )
  }

  tutorials <- tibble::as_tibble(tutorials)

  if (!"tutorial_id" %in% names(tutorials)) {
    cli::cli_abort(
      "{.arg tutorials} must contain a {.field tutorial_id} column."
    )
  }

  tutorials$tutorial_id <- trimws(as.character(tutorials$tutorial_id))

  if (any(is.na(tutorials$tutorial_id)) || any(!nzchar(tutorials$tutorial_id))) {
    cli::cli_abort("{.field tutorial_id} values must not be missing or empty.")
  }

  if (any(duplicated(tutorials$tutorial_id))) {
    duplicated_ids <- unique(tutorials$tutorial_id[duplicated(tutorials$tutorial_id)])
    cli::cli_abort(c(
      "{.arg tutorials} contains duplicated tutorial identifiers.",
      "x" = "Duplicated identifier{?s}: {duplicated_ids}."
    ))
  }

  if (!"course_id" %in% names(tutorials)) {
    tutorials$course_id <- course_id
  }

  if (!"tutorial_label" %in% names(tutorials)) {
    tutorials$tutorial_label <- tutorials$tutorial_id
  }

  if (!"version" %in% names(tutorials)) {
    tutorials$version <- NA_character_
  }

  tibble::tibble(
    tutorial_id = tutorials$tutorial_id,
    course_id = as.character(tutorials$course_id),
    tutorial_label = as.character(tutorials$tutorial_label),
    version = as.character(tutorials$version),
    created_at = timestamp
  )
}

#' Register tutorials
#'
#' Stores tutorial metadata in the `tutorials` table.
#'
#' @param con A DBI connection.
#' @param tutorials A data frame with a required `tutorial_id` column and
#'   optional `course_id`, `tutorial_label`, and `version` columns. A character
#'   vector is treated as a vector of tutorial identifiers.
#' @param course_id Optional course identifier used when `tutorials` does not
#'   include a `course_id` column.
#' @param timestamp Creation timestamp for inserted rows. Defaults to
#'   `Sys.time()`.
#'
#' @return A tibble of registered tutorials.
#' @export
#'
#' @examples
#' db_path <- tempfile(fileext = ".sqlite")
#' con <- init_tracking_db(db_path, overwrite = TRUE)
#' register_tutorials(con, "module_01", course_id = "stat101")
#' DBI::dbDisconnect(con)
register_tutorials <- function(con,
                               tutorials,
                               course_id = NULL,
                               timestamp = Sys.time()) {
  check_required_tables(con)
  course_id <- validate_scalar_character(
    course_id,
    arg = "course_id",
    allow_null = TRUE
  )
  timestamp <- normalize_timestamp(timestamp)

  normalized <- normalize_tutorials_data(
    tutorials = tutorials,
    course_id = course_id,
    timestamp = timestamp
  )

  DBI::dbWithTransaction(con, {
    for (row_index in seq_len(nrow(normalized))) {
      tracking_db_execute(
        con,
        paste(
          "INSERT INTO tutorials",
          "(tutorial_id, course_id, tutorial_label, version, created_at)",
          "VALUES (?, ?, ?, ?, ?)",
          "ON CONFLICT(tutorial_id) DO UPDATE SET",
          "course_id = COALESCE(excluded.course_id, tutorials.course_id),",
          "tutorial_label = COALESCE(excluded.tutorial_label, tutorials.tutorial_label),",
          "version = COALESCE(excluded.version, tutorials.version)"
        ),
        params = list(
          normalized$tutorial_id[[row_index]],
          normalized$course_id[[row_index]],
          normalized$tutorial_label[[row_index]],
          normalized$version[[row_index]],
          normalized$created_at[[row_index]]
        )
      )
    }
  })

  get_tutorials(con)
}

#' Read registered tutorials
#'
#' Reads tutorial definitions from the `tutorials` table.
#'
#' @param con A DBI connection.
#' @param tutorial_id Optional tutorial identifier.
#' @param course_id Optional course identifier.
#'
#' @return A tibble of registered tutorials.
#' @export
#'
#' @examples
#' db_path <- tempfile(fileext = ".sqlite")
#' con <- init_tracking_db(db_path, overwrite = TRUE)
#' register_tutorials(con, "module_01", course_id = "stat101")
#' get_tutorials(con, course_id = "stat101")
#' DBI::dbDisconnect(con)
get_tutorials <- function(con,
                          tutorial_id = NULL,
                          course_id = NULL) {
  check_required_tables(con)

  tutorial_id <- validate_scalar_character(
    tutorial_id,
    arg = "tutorial_id",
    allow_null = TRUE
  )
  course_id <- validate_scalar_character(
    course_id,
    arg = "course_id",
    allow_null = TRUE
  )

  where <- character()
  params <- list()

  if (!is.null(tutorial_id)) {
    where <- c(where, "tutorial_id = ?")
    params <- c(params, list(tutorial_id))
  }

  if (!is.null(course_id)) {
    where <- c(where, "course_id = ?")
    params <- c(params, list(course_id))
  }

  query <- paste(
    "SELECT tutorial_id, course_id, tutorial_label, version, created_at",
    "FROM tutorials"
  )

  if (length(where) > 0) {
    query <- paste(query, "WHERE", paste(where, collapse = " AND "))
  }

  query <- paste(query, "ORDER BY tutorial_id ASC")

  if (length(params) > 0) {
    tutorials <- tracking_db_get_query(con, query, params = params)
  } else {
    tutorials <- tracking_db_get_query(con, query)
  }

  tibble::as_tibble(tutorials)
}
