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

read_local_env <- function(path) {
  if (file.exists(path)) {
    readRenviron(path)
  }

  invisible(TRUE)
}

env_value <- function(name, default = "") {
  Sys.getenv(name, unset = default)
}

env_flag <- function(name, default = FALSE) {
  value <- tolower(trimws(env_value(name, as.character(default))))
  value %in% c("1", "true", "yes", "y", "on")
}

dashboard_token <- function() {
  token <- env_value("LEARNRTRACKR_DASHBOARD_TOKEN")

  if (
    !nzchar(token) ||
      identical(token, "replace-with-a-long-random-dashboard-token")
  ) {
    return(NULL)
  }

  token
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

  script_dir()
}

load_learnrtrackr()

example_dir <- resolve_course_pilot_dir()
read_local_env(file.path(example_dir, "teacher.env"))

db_path <- env_value(
  "LEARNRTRACKR_DB",
  file.path(tempdir(), "learnrtrackr-course-pilot.sqlite")
)
group_id <- env_value("LEARNRTRACKR_GROUP_ID", "A")
output_dir <- env_value(
  "LEARNRTRACKR_OUTPUT_DIR",
  file.path(dirname(db_path), "course-pilot-outputs")
)

if (!file.exists(db_path)) {
  stop(
    "No tracking database was found at: ",
    db_path,
    "\nRun run-student.R, simulate-results.R, or set LEARNRTRACKR_DB to an existing database.",
    call. = FALSE
  )
}

Sys.setenv(
  LEARNRTRACKR_EXAMPLE_DIR = example_dir,
  LEARNRTRACKR_DB = db_path,
  LEARNRTRACKR_GROUP_ID = group_id,
  LEARNRTRACKR_OUTPUT_DIR = output_dir
)

source(file.path(example_dir, "inspect-results.R"))

if (env_flag("LEARNRTRACKR_TEACHER_OPEN_DASHBOARD", FALSE)) {
  learnrTrackR::run_dashboard(
    db_path,
    tutorial_id = "stat_descriptive_pilot",
    group_id = group_id,
    access_token = dashboard_token()
  )
}
