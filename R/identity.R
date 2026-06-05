#' Read the tracking student identifier
#'
#' Reads the student identifier from an environment variable. This helper is
#' intended for minimal `learnr` prototypes where the learner identity is passed
#' to the tutorial before launch.
#'
#' @param envvar Name of the environment variable that stores the student
#'   identifier. Defaults to `"LEARNRTRACKR_STUDENT_ID"`.
#' @param default Optional fallback identifier used when the environment
#'   variable is missing or empty.
#' @param required If `TRUE`, throw an informative error when no identifier is
#'   available. If `FALSE`, return `NA_character_` when no identifier is
#'   available.
#'
#' @return A character scalar student identifier, or `NA_character_` when
#'   `required = FALSE` and no identifier is available.
#' @export
#'
#' @examples
#' withr::local_envvar(LEARNRTRACKR_STUDENT_ID = "student_001")
#' get_tracking_student_id()
#'
#' get_tracking_student_id(default = "student_demo")
get_tracking_student_id <- function(envvar = "LEARNRTRACKR_STUDENT_ID",
                                    default = NULL,
                                    required = TRUE) {
  envvar <- validate_scalar_character(envvar, arg = "envvar")
  required <- validate_scalar_logical(required, arg = "required")

  default <- validate_scalar_character(
    default,
    arg = "default",
    allow_null = TRUE
  )

  value <- Sys.getenv(envvar, unset = NA_character_)

  if (!is.na(value)) {
    value <- trimws(value)
  }

  if (!is.na(value) && nzchar(value)) {
    return(value)
  }

  if (!is.null(default)) {
    return(default)
  }

  if (!required) {
    return(NA_character_)
  }

  cli::cli_abort(c(
    "Student identifier is missing.",
    "i" = "Set the {.envvar {envvar}} environment variable before launching the tutorial.",
    "i" = "Example: {.code Sys.setenv({envvar} = \"student_001\")}."
  ))
}

read_tracking_env_value <- function(envvar,
                                    default,
                                    required,
                                    label,
                                    allow_na = FALSE) {
  envvar <- validate_scalar_character(envvar, arg = "envvar")
  required <- validate_scalar_logical(required, arg = "required")
  label <- validate_scalar_character(label, arg = "label")

  default <- validate_scalar_character(
    default,
    arg = "default",
    allow_null = TRUE,
    allow_na = allow_na
  )

  value <- Sys.getenv(envvar, unset = NA_character_)

  if (!is.na(value)) {
    value <- trimws(value)
  }

  if (!is.na(value) && nzchar(value)) {
    return(value)
  }

  if (!is.null(default) && !(is.na(default) && required)) {
    return(default)
  }

  if (!required) {
    return(NA_character_)
  }

  cli::cli_abort(c(
    "{label} is missing.",
    "i" = "Set the {.envvar {envvar}} environment variable before launching the tutorial.",
    "i" = "Example: {.code Sys.setenv({envvar} = \"value\")}."
  ))
}

#' Read learnr tracking launch environment
#'
#' Reads and validates the environment variables normally needed before
#' launching a tracked `learnr` tutorial: a student identifier, a SQLite
#' database path, and an optional group identifier. This helper is intended for
#' tutorial setup chunks and launch scripts.
#'
#' @param student_envvar Name of the environment variable that stores the
#'   student identifier. Defaults to `"LEARNRTRACKR_STUDENT_ID"`.
#' @param db_envvar Name of the environment variable that stores the SQLite
#'   tracking database path. Defaults to `"LEARNRTRACKR_DB"`.
#' @param group_envvar Name of the environment variable that stores the optional
#'   group identifier. Defaults to `"LEARNRTRACKR_GROUP_ID"`.
#' @param default_db_path Optional fallback database path used when `db_envvar`
#'   is missing or empty.
#' @param default_group_id Optional fallback group identifier used when
#'   `group_envvar` is missing or empty. Defaults to `NA_character_`.
#' @param require_db_path If `TRUE`, throw an informative error when no database
#'   path is available.
#' @param require_group_id If `TRUE`, throw an informative error when no group
#'   identifier is available.
#'
#' @return A `learnrTrackR_env` list with `student_id`, `db_path`, `group_id`,
#'   `student_envvar`, `db_envvar`, and `group_envvar`.
#' @export
#'
#' @examples
#' withr::local_envvar(
#'   LEARNRTRACKR_STUDENT_ID = "student_001",
#'   LEARNRTRACKR_DB = tempfile(fileext = ".sqlite"),
#'   LEARNRTRACKR_GROUP_ID = "A"
#' )
#'
#' get_learnr_tracking_env()
get_learnr_tracking_env <- function(student_envvar = "LEARNRTRACKR_STUDENT_ID",
                                    db_envvar = "LEARNRTRACKR_DB",
                                    group_envvar = "LEARNRTRACKR_GROUP_ID",
                                    default_db_path = NULL,
                                    default_group_id = NA_character_,
                                    require_db_path = TRUE,
                                    require_group_id = FALSE) {
  student_envvar <- validate_scalar_character(
    student_envvar,
    arg = "student_envvar"
  )
  db_envvar <- validate_scalar_character(db_envvar, arg = "db_envvar")
  group_envvar <- validate_scalar_character(group_envvar, arg = "group_envvar")
  require_db_path <- validate_scalar_logical(
    require_db_path,
    arg = "require_db_path"
  )
  require_group_id <- validate_scalar_logical(
    require_group_id,
    arg = "require_group_id"
  )

  default_db_path <- validate_scalar_character(
    default_db_path,
    arg = "default_db_path",
    allow_null = TRUE
  )
  default_group_id <- validate_scalar_character(
    default_group_id,
    arg = "default_group_id",
    allow_na = TRUE,
    allow_null = TRUE,
    allow_empty = TRUE
  )

  student_id <- get_tracking_student_id(envvar = student_envvar)
  db_path <- read_tracking_env_value(
    envvar = db_envvar,
    default = default_db_path,
    required = require_db_path,
    label = "Tracking database path"
  )
  group_id <- read_tracking_env_value(
    envvar = group_envvar,
    default = default_group_id,
    required = require_group_id,
    label = "Tracking group identifier",
    allow_na = TRUE
  )

  if (!is.na(db_path)) {
    db_path <- validate_path(db_path, arg = "db_path")
  }

  group_id <- validate_scalar_character(
    group_id,
    arg = "group_id",
    allow_na = TRUE,
    allow_empty = TRUE
  )

  structure(
    list(
      student_id = student_id,
      db_path = db_path,
      group_id = group_id,
      student_envvar = student_envvar,
      db_envvar = db_envvar,
      group_envvar = group_envvar
    ),
    class = "learnrTrackR_env"
  )
}
