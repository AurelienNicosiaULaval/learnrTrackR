required_tables <- function() {
  c(
    "students",
    "courses",
    "tutorials",
    "questions",
    "sessions",
    "attempts"
  )
}

check_connection <- function(con) {
  if (!inherits(con, "DBIConnection")) {
    cli::cli_abort("{.arg con} must be a DBI connection.")
  }

  if (!DBI::dbIsValid(con)) {
    cli::cli_abort("{.arg con} is not a valid DBI connection.")
  }

  invisible(con)
}

check_required_tables <- function(con, tables = required_tables()) {
  check_connection(con)

  existing_tables <- DBI::dbListTables(con)
  missing_tables <- setdiff(tables, existing_tables)

  if (length(missing_tables) > 0) {
    cli::cli_abort(c(
      "The tracking database schema is incomplete.",
      "x" = "Missing table{?s}: {missing_tables}."
    ))
  }

  invisible(TRUE)
}

validate_scalar_character <- function(x,
                                      arg,
                                      allow_na = FALSE,
                                      allow_null = FALSE,
                                      allow_empty = FALSE) {
  if (is.null(x)) {
    if (allow_null) {
      return(NULL)
    }

    cli::cli_abort("{.arg {arg}} must not be NULL.")
  }

  if (!is.character(x) || length(x) != 1) {
    cli::cli_abort("{.arg {arg}} must be a character scalar.")
  }

  if (is.na(x)) {
    if (allow_na) {
      return(x)
    }

    cli::cli_abort("{.arg {arg}} must not be NA.")
  }

  if (!allow_empty && !nzchar(x)) {
    cli::cli_abort("{.arg {arg}} must not be empty.")
  }

  x
}

validate_scalar_numeric <- function(x,
                                    arg,
                                    allow_na = FALSE,
                                    allow_null = FALSE) {
  if (is.null(x)) {
    if (allow_null) {
      return(NULL)
    }

    cli::cli_abort("{.arg {arg}} must not be NULL.")
  }

  if (!is.numeric(x) || length(x) != 1) {
    cli::cli_abort("{.arg {arg}} must be a numeric scalar.")
  }

  if (is.na(x)) {
    if (allow_na) {
      return(as.numeric(x))
    }

    cli::cli_abort("{.arg {arg}} must not be NA.")
  }

  as.numeric(x)
}

validate_positive_integer <- function(x, arg) {
  value <- validate_scalar_numeric(x, arg = arg, allow_na = FALSE)

  if (value < 1 || value != floor(value)) {
    cli::cli_abort("{.arg {arg}} must be a positive integer.")
  }

  as.integer(value)
}

validate_scalar_logical <- function(x, arg) {
  if (!is.logical(x) || length(x) != 1 || is.na(x)) {
    cli::cli_abort("{.arg {arg}} must be TRUE or FALSE.")
  }

  x
}

validate_path <- function(path, arg = "path") {
  validate_scalar_character(
    path,
    arg = arg,
    allow_na = FALSE,
    allow_null = FALSE,
    allow_empty = FALSE
  )
}

normalize_timestamp <- function(timestamp) {
  if (length(timestamp) != 1) {
    cli::cli_abort("{.arg timestamp} must be a scalar value.")
  }

  timestamp_posix <- NULL

  if (inherits(timestamp, "POSIXt")) {
    timestamp_posix <- as.POSIXct(timestamp, tz = "UTC")
  } else if (inherits(timestamp, "Date")) {
    timestamp_posix <- as.POSIXct(timestamp, tz = "UTC")
  } else if (is.character(timestamp)) {
    if (is.na(timestamp) || !nzchar(timestamp)) {
      cli::cli_abort("{.arg timestamp} must not be NA or empty.")
    }

    timestamp_value <- trimws(timestamp)
    timestamp_value <- gsub("T", " ", timestamp_value, fixed = TRUE)
    timestamp_value <- sub("Z$", "", timestamp_value)

    timestamp_posix <- as.POSIXct(
      timestamp_value,
      tz = "UTC",
      tryFormats = c(
        "%Y-%m-%d %H:%M:%OS",
        "%Y-%m-%d %H:%M:%S",
        "%Y-%m-%d",
        "%Y/%m/%d %H:%M:%OS",
        "%Y/%m/%d %H:%M:%S",
        "%Y/%m/%d"
      )
    )
  } else {
    cli::cli_abort(
      "{.arg timestamp} must be a POSIXt, Date, or character scalar."
    )
  }

  if (is.na(timestamp_posix)) {
    cli::cli_abort("{.arg timestamp} could not be parsed.")
  }

  format(timestamp_posix, "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
}

generate_session_id <- function(student_id,
                                tutorial_id,
                                timestamp = Sys.time()) {
  timestamp_text <- normalize_timestamp(timestamp)
  session_date <- gsub("-", "", substr(timestamp_text, 1, 10), fixed = TRUE)

  safe_id <- function(x) {
    out <- gsub("[^A-Za-z0-9]+", "_", x)
    out <- gsub("^_+|_+$", "", out)

    if (!nzchar(out)) {
      return("id")
    }

    out
  }

  paste(
    "session",
    safe_id(student_id),
    safe_id(tutorial_id),
    session_date,
    sep = "_"
  )
}

parse_timestamp_for_order <- function(x) {
  x <- gsub("T", " ", x, fixed = TRUE)
  x <- sub("Z$", "", x)
  parsed <- as.POSIXct(x, tz = "UTC")
  out <- as.numeric(parsed)
  out[is.na(out)] <- -Inf
  out
}

empty_scores_tibble <- function() {
  tibble::tibble(
    student_id = character(),
    tutorial_id = character(),
    score = numeric(),
    max_score = numeric(),
    percent = numeric(),
    n_questions = integer(),
    n_answered = integer()
  )
}

empty_gradebook_tibble <- function() {
  tibble::tibble(
    student_id = character(),
    tutorial_id = character(),
    score = numeric(),
    max_score = numeric(),
    percent = numeric(),
    n_questions = integer(),
    n_answered = integer(),
    n_unanswered = integer(),
    completed = logical()
  )
}
