validate_character_vector <- function(x, arg, allow_empty = TRUE) {
  if (!is.character(x) || any(is.na(x))) {
    cli::cli_abort("{.arg {arg}} must be a character vector without missing values.")
  }

  if (!allow_empty && length(x) == 0) {
    cli::cli_abort("{.arg {arg}} must not be empty.")
  }

  if (any(!nzchar(x))) {
    cli::cli_abort("{.arg {arg}} must not contain empty values.")
  }

  x
}

validate_results_object <- function(x, arg = "x") {
  if (is.data.frame(x)) {
    return(invisible(TRUE))
  }

  if (is.list(x) && all(vapply(x, is.data.frame, logical(1)))) {
    return(invisible(TRUE))
  }

  cli::cli_abort(
    "{.arg {arg}} must be a data frame or a list of data frames."
  )
}

result_tables <- function(x) {
  if (is.data.frame(x)) {
    return(list(.data = x))
  }

  x
}

restore_result_tables <- function(tables, original) {
  if (is.data.frame(original)) {
    return(tables$.data)
  }

  tables
}

remove_result_columns <- function(table, columns) {
  table[, setdiff(names(table), columns), drop = FALSE]
}

collect_result_ids <- function(tables, id_column) {
  ids <- unlist(
    lapply(tables, function(table) {
      if (!id_column %in% names(table)) {
        return(character())
      }

      as.character(table[[id_column]])
    }),
    use.names = FALSE
  )

  ids <- ids[!is.na(ids) & nzchar(ids)]
  sort(unique(ids))
}

build_pseudonym_key <- function(ids, prefix, id_column) {
  if (length(ids) == 0) {
    out <- tibble::tibble(
      original_id = character(),
      pseudonym = character()
    )
    names(out)[names(out) == "original_id"] <- id_column
    return(out)
  }

  digits <- max(4L, nchar(length(ids)))

  out <- tibble::tibble(
    original_id = ids,
    pseudonym = paste0(prefix, "_", sprintf(paste0("%0", digits, "d"), seq_along(ids)))
  )
  names(out)[names(out) == "original_id"] <- id_column
  out
}

validate_pseudonym_key <- function(key, id_column) {
  if (is.null(key)) {
    return(NULL)
  }

  if (!is.data.frame(key)) {
    cli::cli_abort("{.arg key} must be a data frame.")
  }

  key <- tibble::as_tibble(key)

  required <- c(id_column, "pseudonym")
  missing <- setdiff(required, names(key))

  if (length(missing) > 0) {
    cli::cli_abort(c(
      "{.arg key} is missing required columns.",
      "x" = "Missing columns: {missing}."
    ))
  }

  key[[id_column]] <- as.character(key[[id_column]])
  key$pseudonym <- as.character(key$pseudonym)

  if (
    any(is.na(key[[id_column]])) ||
      any(!nzchar(key[[id_column]])) ||
      any(is.na(key$pseudonym)) ||
      any(!nzchar(key$pseudonym))
  ) {
    cli::cli_abort(
      "{.arg key} identifier and pseudonym columns must not contain missing or empty values."
    )
  }

  if (any(duplicated(key[[id_column]]))) {
    cli::cli_abort("{.arg key} must not contain duplicated identifiers.")
  }

  if (any(duplicated(key$pseudonym))) {
    cli::cli_abort("{.arg key} must not contain duplicated pseudonyms.")
  }

  key[, required, drop = FALSE]
}

pseudonymise_table <- function(table, key, id_column, drop_columns) {
  if (id_column %in% names(table)) {
    ids <- as.character(table[[id_column]])
    positions <- match(ids, key[[id_column]])
    missing <- is.na(positions) & !is.na(ids) & nzchar(ids)

    if (any(missing)) {
      missing_ids <- sort(unique(ids[missing]))
      cli::cli_abort(c(
        "{.arg key} does not cover all identifiers in the supplied data.",
        "x" = "Missing identifier{?s}: {missing_ids}."
      ))
    }

    table[[id_column]] <- key$pseudonym[positions]
  }

  remove_result_columns(table, setdiff(drop_columns, id_column))
}

#' Delete one student's tracking data
#'
#' Deletes attempts and sessions associated with one student identifier. By
#' default, the corresponding row in the student registry is also deleted.
#' Course, tutorial, and question metadata are preserved.
#'
#' @param con A DBI connection.
#' @param student_id Student identifier to delete.
#' @param delete_student If `TRUE`, also delete the matching row from the
#'   `students` table. If `FALSE`, preserve the student registry row.
#'
#' @return A tibble with deleted row counts by table.
#' @export
#'
#' @examples
#' db_path <- tempfile(fileext = ".sqlite")
#' con <- init_tracking_db(db_path, overwrite = TRUE)
#' track_attempt(con, "student_001", "module_01", "q1", "mean(x)")
#' delete_student_data(con, "student_001")
#' DBI::dbDisconnect(con)
delete_student_data <- function(con,
                                student_id,
                                delete_student = TRUE) {
  check_required_tables(con)

  student_id <- validate_scalar_character(student_id, arg = "student_id")
  delete_student <- validate_scalar_logical(
    delete_student,
    arg = "delete_student"
  )

  DBI::dbWithTransaction(con, {
    attempts <- tracking_db_execute(
      con,
      "DELETE FROM attempts WHERE student_id = ?",
      params = list(student_id)
    )
    sessions <- tracking_db_execute(
      con,
      "DELETE FROM sessions WHERE student_id = ?",
      params = list(student_id)
    )
    students <- if (delete_student) {
      tracking_db_execute(
        con,
        "DELETE FROM students WHERE student_id = ?",
        params = list(student_id)
      )
    } else {
      0
    }

    tibble::tibble(
      table = c("attempts", "sessions", "students"),
      deleted_rows = as.integer(c(attempts, sessions, students))
    )
  })
}

#' Pseudonymise student identifiers in result tables
#'
#' Replaces student identifiers with stable sequential pseudonyms and returns a
#' separate key. The key remains identifying and should be stored separately
#' from exported results.
#'
#' @param x A data frame or a list of data frames, such as the output of
#'   [tracking_export_data()].
#' @param id_column Name of the student identifier column. Defaults to
#'   `"student_id"`.
#' @param prefix Prefix used to create pseudonyms. Defaults to `"student"`.
#' @param drop_columns Columns removed from the returned data after
#'   pseudonymisation. Defaults to `student_label` and `email`.
#' @param key Optional existing key with columns `id_column` and `pseudonym`.
#'   Use this to keep the same mapping across separate exports.
#'
#' @return A list with `data`, the pseudonymised data in the same shape as `x`,
#'   and `key`, a tibble mapping original identifiers to pseudonyms.
#' @export
#'
#' @examples
#' results <- data.frame(
#'   student_id = c("student_001", "student_002"),
#'   email = c("a@example.org", "b@example.org"),
#'   score = c(8, 9)
#' )
#' pseudonymise_results(results)
pseudonymise_results <- function(x,
                                 id_column = "student_id",
                                 prefix = "student",
                                 drop_columns = c("student_label", "email"),
                                 key = NULL) {
  validate_results_object(x)
  id_column <- validate_scalar_character(id_column, arg = "id_column")
  prefix <- validate_scalar_character(prefix, arg = "prefix")
  drop_columns <- validate_character_vector(drop_columns, arg = "drop_columns")
  tables <- result_tables(x)

  key <- validate_pseudonym_key(key, id_column = id_column)

  if (is.null(key)) {
    key <- build_pseudonym_key(
      ids = collect_result_ids(tables, id_column = id_column),
      prefix = prefix,
      id_column = id_column
    )
  }

  out <- lapply(
    tables,
    pseudonymise_table,
    key = key,
    id_column = id_column,
    drop_columns = drop_columns
  )

  list(
    data = restore_result_tables(out, x),
    key = tibble::as_tibble(key)
  )
}

#' Remove direct identifiers from result tables
#'
#' Removes selected identifier columns from a data frame or list of data frames.
#' This is a practical data-minimisation helper. It does not guarantee legal or
#' statistical anonymity.
#'
#' @param x A data frame or a list of data frames.
#' @param drop_columns Columns to remove. Defaults to `student_id`,
#'   `student_label`, and `email`.
#'
#' @return The input data with selected columns removed, preserving the shape of
#'   `x`.
#' @export
#'
#' @examples
#' results <- data.frame(
#'   student_id = "student_001",
#'   email = "student@example.org",
#'   score = 10
#' )
#' anonymise_results(results)
anonymise_results <- function(x,
                              drop_columns = c("student_id", "student_label", "email")) {
  validate_results_object(x)
  drop_columns <- validate_character_vector(drop_columns, arg = "drop_columns")

  tables <- result_tables(x)
  out <- lapply(tables, remove_result_columns, columns = drop_columns)

  restore_result_tables(out, x)
}
