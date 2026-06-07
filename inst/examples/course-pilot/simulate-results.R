course_pilot_script_file <- tryCatch(
  {
    script_file <- sys.frame(1)$ofile
    if (is.null(script_file)) {
      ""
    } else {
      normalizePath(script_file, mustWork = FALSE)
    }
  },
  error = function(cnd) ""
)

resolve_course_pilot_dir <- function(script_file = course_pilot_script_file) {
  env_dir <- Sys.getenv("LEARNRTRACKR_EXAMPLE_DIR", unset = "")
  if (nzchar(env_dir)) {
    return(env_dir)
  }

  installed_dir <- system.file("examples/course-pilot", package = "learnrTrackR")
  if (nzchar(installed_dir)) {
    return(installed_dir)
  }

  if (nzchar(script_file)) {
    return(dirname(script_file))
  }

  "."
}

run_course_pilot_simulation <- function() {
  example_dir <- resolve_course_pilot_dir()
  source(file.path(example_dir, "pilot-workflow.R"))

  tutorial_id <- course_pilot_tutorial_id()
  db_path <- Sys.getenv(
    "LEARNRTRACKR_DB",
    unset = file.path(tempdir(), "learnrtrackr-course-pilot.sqlite")
  )

  con <- learnrTrackR::init_tracking_db(db_path, overwrite = TRUE)
  on.exit(DBI::dbDisconnect(con), add = TRUE)

  course_pilot_load_config(con, example_dir)
  course_pilot_record_simulated_attempts(con, tutorial_id = tutorial_id)

  attempts <- learnrTrackR::get_attempts(con, tutorial_id = tutorial_id)
  grades <- learnrTrackR::gradebook(con, tutorial_id = tutorial_id, rule = "last")

  message("Created pilot database: ", db_path)
  message("Attempts recorded: ", nrow(attempts))
  message("Gradebook:")
  print(grades)

  invisible(
    list(
      db_path = db_path,
      attempts = attempts,
      gradebook = grades
    )
  )
}

run_course_pilot_simulation()
