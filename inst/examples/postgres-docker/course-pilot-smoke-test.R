load_learnrtrackr <- function() {
  if (requireNamespace("learnrTrackR", quietly = TRUE)) {
    return(invisible(TRUE))
  }

  repo_root <- normalizePath(
    file.path(getwd(), "..", "..", ".."),
    mustWork = FALSE
  )

  if (
    file.exists(file.path(repo_root, "DESCRIPTION")) &&
      requireNamespace("devtools", quietly = TRUE)
  ) {
    devtools::load_all(repo_root, quiet = TRUE)
    return(invisible(TRUE))
  }

  stop(
    "Install learnrTrackR or run this script from the package source example directory.",
    call. = FALSE
  )
}

read_local_env <- function(path = ".env") {
  if (file.exists(path)) {
    readRenviron(path)
  }

  invisible(TRUE)
}

env_value <- function(name, default = "") {
  Sys.getenv(name, unset = default)
}

env_flag <- function(name, default = TRUE) {
  value <- tolower(trimws(env_value(name, as.character(default))))
  value %in% c("1", "true", "yes", "y", "on")
}

script_dir <- function() {
  script_file <- tryCatch(
    {
      file <- sys.frame(1)$ofile
      if (is.null(file)) "" else normalizePath(file, mustWork = FALSE)
    },
    error = function(cnd) ""
  )

  if (nzchar(script_file)) {
    return(dirname(script_file))
  }

  getwd()
}

resolve_course_pilot_dir <- function() {
  env_dir <- env_value("LEARNRTRACKR_EXAMPLE_DIR")
  if (nzchar(env_dir)) {
    return(env_dir)
  }

  installed_dir <- system.file("examples/course-pilot", package = "learnrTrackR")
  if (nzchar(installed_dir)) {
    return(installed_dir)
  }

  normalizePath(
    file.path(script_dir(), "..", "course-pilot"),
    mustWork = FALSE
  )
}

validate_postgres_identifier <- function(value, name) {
  if (!grepl("^[A-Za-z_][A-Za-z0-9_]*$", value)) {
    stop(
      name,
      " must start with a letter or underscore and contain only letters, digits, or underscores.",
      call. = FALSE
    )
  }

  value
}

prepare_pilot_schema <- function(con, schema_name, reset) {
  schema_name <- validate_postgres_identifier(schema_name, "LEARNRTRACKR_POSTGRES_SCHEMA")
  quoted_schema <- DBI::dbQuoteIdentifier(con, schema_name)

  if (isTRUE(reset)) {
    DBI::dbExecute(
      con,
      paste("DROP SCHEMA IF EXISTS", quoted_schema, "CASCADE")
    )
  }

  DBI::dbExecute(con, paste("CREATE SCHEMA IF NOT EXISTS", quoted_schema))
  DBI::dbExecute(con, paste("SET search_path TO", quoted_schema))
  learnrTrackR::create_schema(con)

  invisible(schema_name)
}

load_learnrtrackr()
read_local_env()

if (!requireNamespace("RPostgres", quietly = TRUE)) {
  stop("Package RPostgres is required for this smoke test.", call. = FALSE)
}

password <- env_value("LEARNRTRACKR_POSTGRES_PASSWORD")

if (
  !nzchar(password) ||
    identical(password, "replace-with-a-long-random-password")
) {
  stop(
    "Set LEARNRTRACKR_POSTGRES_PASSWORD in .env before running this smoke test.",
    call. = FALSE
  )
}

example_dir <- resolve_course_pilot_dir()
source(file.path(example_dir, "pilot-workflow.R"))

schema_name <- env_value("LEARNRTRACKR_POSTGRES_SCHEMA", "learnrtrackr_pilot")
group_id <- env_value("LEARNRTRACKR_PILOT_GROUP_ID", "A")
output_dir <- env_value(
  "LEARNRTRACKR_PILOT_OUTPUT_DIR",
  file.path(script_dir(), "pilot-outputs")
)
reset_schema <- env_flag("LEARNRTRACKR_PILOT_RESET", TRUE)

con <- DBI::dbConnect(
  RPostgres::Postgres(),
  dbname = env_value("LEARNRTRACKR_POSTGRES_DB", "learnrtrackr"),
  host = env_value("LEARNRTRACKR_POSTGRES_HOST", "127.0.0.1"),
  port = as.integer(env_value("LEARNRTRACKR_POSTGRES_PORT", "5432")),
  user = env_value("LEARNRTRACKR_POSTGRES_USER", "learnrtrackr"),
  password = password
)
on.exit(DBI::dbDisconnect(con), add = TRUE)

prepare_pilot_schema(
  con = con,
  schema_name = schema_name,
  reset = reset_schema
)

course_pilot_load_config(con, example_dir)
course_pilot_record_simulated_attempts(con)
outputs <- course_pilot_teacher_outputs(
  con = con,
  output_dir = output_dir,
  group_id = group_id
)

moodle <- readr::read_csv(outputs$paths$moodle, show_col_types = FALSE)

message("PostgreSQL pilot schema: ", schema_name)
message("PostgreSQL pilot group: ", group_id)
message("Teacher output directory: ", output_dir)
message("Dashboard summary:")
print(outputs$dashboard$summary)
message("Moodle-ready CSV:")
print(moodle)
