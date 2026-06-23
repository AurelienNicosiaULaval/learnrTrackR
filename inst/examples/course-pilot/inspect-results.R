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

run_course_pilot_inspection <- function() {
  tutorial_id <- "stat_descriptive_pilot"
  db_path <- Sys.getenv(
    "LEARNRTRACKR_DB",
    unset = file.path(tempdir(), "learnrtrackr-course-pilot.sqlite")
  )
  group_id <- Sys.getenv("LEARNRTRACKR_GROUP_ID", unset = "")
  group_filter <- if (nzchar(group_id)) group_id else NULL
  output_dir <- Sys.getenv(
    "LEARNRTRACKR_OUTPUT_DIR",
    unset = file.path(dirname(db_path), "course-pilot-outputs")
  )

  if (!file.exists(db_path)) {
    stop(
      "No tracking database was found at: ",
      db_path,
      "\nRun simulate-results.R or launch the tutorial before inspecting results.",
      call. = FALSE
    )
  }

  if (!dir.exists(output_dir)) {
    dir.create(output_dir, recursive = TRUE)
  }

  example_dir <- resolve_course_pilot_dir()
  source(file.path(example_dir, "pilot-workflow.R"))

  con <- learnrTrackR::connect_tracking_db(db_path)
  on.exit(DBI::dbDisconnect(con), add = TRUE)

  outputs <- course_pilot_teacher_outputs(
    con = con,
    output_dir = output_dir,
    tutorial_id = tutorial_id,
    group_id = group_filter,
    rule = "last"
  )

  print(outputs$attempts)
  print(outputs$scores)
  print(outputs$gradebook)
  print(outputs$readiness)
  print(outputs$dashboard$summary)
  print(outputs$report$summary)

  message("Wrote attempts to: ", outputs$paths$attempts)
  message("Wrote scores to: ", outputs$paths$scores)
  message("Wrote gradebook to: ", outputs$paths$gradebook)
  message("Wrote readiness checks to: ", outputs$paths$readiness)
  message("Wrote Moodle-ready grades to: ", outputs$paths$moodle)
  message("Wrote Canvas Gradebook grades to: ", outputs$paths$canvas)
  message("Wrote rich export bundle to: ", outputs$paths$bundle)
  message("Wrote teacher report to: ", outputs$paths$report)
  print(outputs$bundle_paths)

  outputs
}

run_course_pilot_inspection()
