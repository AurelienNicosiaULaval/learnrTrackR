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

  con <- learnrTrackR::connect_tracking_db(db_path)
  on.exit(DBI::dbDisconnect(con), add = TRUE)

  attempts <- learnrTrackR::get_attempts(con, tutorial_id = tutorial_id)
  scores <- learnrTrackR::compute_scores(con, tutorial_id = tutorial_id, rule = "last")
  grades <- learnrTrackR::gradebook(con, tutorial_id = tutorial_id, rule = "last")
  dashboard <- learnrTrackR::dashboard_data(
    con,
    tutorial_id = tutorial_id,
    group_id = group_filter,
    rule = "last"
  )
  report <- learnrTrackR::teacher_report_data(
    con,
    tutorial_id = tutorial_id,
    group_id = group_filter,
    rule = "last"
  )

  attempts_path <- file.path(output_dir, "course-pilot-attempts.csv")
  scores_path <- file.path(output_dir, "course-pilot-scores.csv")
  gradebook_path <- file.path(output_dir, "course-pilot-gradebook.csv")
  moodle_path <- file.path(output_dir, "course-pilot-moodle.csv")
  bundle_dir <- file.path(output_dir, "course-pilot-bundle")
  report_path <- file.path(output_dir, "course-pilot-teacher-report.html")

  learnrTrackR::export_results(con, attempts_path, type = "attempts", tutorial_id = tutorial_id)
  learnrTrackR::export_results(con, scores_path, type = "scores", tutorial_id = tutorial_id)
  learnrTrackR::export_results(con, gradebook_path, type = "gradebook", tutorial_id = tutorial_id)
  learnrTrackR::export_moodle_grades(
    con,
    moodle_path,
    tutorial_id = tutorial_id,
    grade_item = "Descriptive statistics pilot",
    group_id = group_filter
  )
  bundle_paths <- learnrTrackR::export_tracking_bundle(
    con,
    bundle_dir,
    tutorial_id = tutorial_id,
    group_id = group_filter
  )

  if (requireNamespace("rmarkdown", quietly = TRUE)) {
    learnrTrackR::generate_teacher_report(
      con,
      report_path,
      tutorial_id = tutorial_id,
      group_id = group_filter,
      rule = "last"
    )
  } else {
    report_path <- NA_character_
  }

  print(attempts)
  print(scores)
  print(grades)
  print(dashboard$summary)
  print(report$summary)

  message("Wrote attempts to: ", attempts_path)
  message("Wrote scores to: ", scores_path)
  message("Wrote gradebook to: ", gradebook_path)
  message("Wrote Moodle-ready grades to: ", moodle_path)
  message("Wrote rich export bundle to: ", bundle_dir)
  message("Wrote teacher report to: ", report_path)
  print(bundle_paths)

  invisible(
    list(
      attempts = attempts,
      scores = scores,
      gradebook = grades,
      dashboard = dashboard,
      report = report,
      paths = list(
        attempts = attempts_path,
        scores = scores_path,
        gradebook = gradebook_path,
        moodle = moodle_path,
        bundle = bundle_dir,
        report = report_path
      )
    )
  )
}

run_course_pilot_inspection()
