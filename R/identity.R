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
