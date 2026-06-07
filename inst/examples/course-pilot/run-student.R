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
read_local_env(file.path(example_dir, "student.env"))

if (!requireNamespace("learnr", quietly = TRUE)) {
  stop("Package learnr is required to launch the course pilot tutorial.", call. = FALSE)
}

db_path <- env_value(
  "LEARNRTRACKR_DB",
  file.path(tempdir(), "learnrtrackr-course-pilot.sqlite")
)
student_id <- env_value("LEARNRTRACKR_STUDENT_ID", "student_demo")
group_id <- env_value("LEARNRTRACKR_GROUP_ID", "A")

Sys.setenv(
  LEARNRTRACKR_EXAMPLE_DIR = example_dir,
  LEARNRTRACKR_DB = db_path,
  LEARNRTRACKR_STUDENT_ID = student_id,
  LEARNRTRACKR_GROUP_ID = group_id
)

message("Launching course pilot tutorial")
message("Student id: ", student_id)
message("Group id: ", group_id)
message("Tracking database: ", db_path)

learnr::run_tutorial(
  file.path(example_dir, "tutorial.Rmd"),
  clean = TRUE,
  as_rstudio_job = FALSE
)
