ulaval_pilot_script_file <- tryCatch(
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

resolve_ulaval_pilot_template_dir <- function(script_file = ulaval_pilot_script_file) {
  env_dir <- Sys.getenv("LEARNRTRACKR_TEMPLATE_DIR", unset = "")
  if (nzchar(env_dir)) {
    return(env_dir)
  }

  installed_dir <- system.file(
    "examples/ulaval-pilot-template",
    package = "learnrTrackR"
  )
  if (nzchar(installed_dir)) {
    return(installed_dir)
  }

  if (nzchar(script_file)) {
    return(dirname(script_file))
  }

  "."
}

ulaval_pilot_tutorial_id <- function() {
  "pilot_tutorial_01"
}

ulaval_pilot_config_dir <- function(template_dir) {
  file.path(template_dir, "config-csv")
}

ulaval_pilot_group_filter <- function(group_id = NULL) {
  if (is.null(group_id)) {
    return(NULL)
  }

  group_id <- trimws(as.character(group_id))
  if (!nzchar(group_id)) {
    return(NULL)
  }

  group_id
}

ulaval_pilot_render_report <- function() {
  value <- tolower(trimws(Sys.getenv("LEARNRTRACKR_RENDER_REPORT", unset = "auto")))

  if (value %in% c("false", "0", "no", "non")) {
    return(FALSE)
  }

  if (value %in% c("true", "1", "yes", "oui")) {
    return(requireNamespace("rmarkdown", quietly = TRUE))
  }

  requireNamespace("rmarkdown", quietly = TRUE)
}

record_ulaval_pilot_attempts <- function(con,
                                         tutorial_id = ulaval_pilot_tutorial_id()) {
  record_attempt <- function(student_id,
                             question_id,
                             submitted_answer,
                             grade_status,
                             score,
                             max_score,
                             feedback,
                             minute_offset) {
    learnrTrackR::track_attempt(
      con = con,
      student_id = student_id,
      tutorial_id = tutorial_id,
      question_id = question_id,
      submitted_answer = submitted_answer,
      grade_status = grade_status,
      score = score,
      max_score = max_score,
      feedback = feedback,
      timestamp = as.POSIXct(
        "2026-01-20 09:00:00",
        tz = "America/Toronto"
      ) + 60 * minute_offset,
      require_registered_student = TRUE
    )
  }

  record_attempt("student_demo", "q1_variable_type", "quantitative", "correct", 1, 1, "Correct.", 1)
  record_attempt("student_demo", "q2_summary_choice", "mean; standard deviation", "correct", 1, 1, "Correct.", 2)
  record_attempt("student_demo", "q3_mean_value", "6.25", "correct", 1, 1, "Correct.", 3)
  record_attempt("student_demo", "q4_code_summary", "survey |> summarise(mean_hours = mean(hours))", "correct", 2, 2, "Correct.", 4)

  record_attempt("student_alpha", "q1_variable_type", "categorical", "incorrect", 0, 1, "Try again.", 5)
  record_attempt("student_alpha", "q1_variable_type", "quantitative", "correct", 1, 1, "Correct.", 6)
  record_attempt("student_alpha", "q2_summary_choice", "mean; standard deviation", "correct", 1, 1, "Correct.", 7)
  record_attempt("student_alpha", "q3_mean_value", "6.25", "correct", 1, 1, "Correct.", 8)
  record_attempt("student_alpha", "q4_code_summary", "survey |> summarise(mean_hours = mean(hours), n = n())", "correct", 2, 2, "Correct.", 9)

  record_attempt("student_beta", "q1_variable_type", "quantitative", "correct", 1, 1, "Correct.", 10)
  record_attempt("student_beta", "q2_summary_choice", "median; interquartile range", "incorrect", 0, 1, "Try again.", 11)
  record_attempt("student_beta", "q2_summary_choice", "mean; standard deviation", "correct", 1, 1, "Correct.", 12)
  record_attempt("student_beta", "q3_mean_value", "6.2", "partial", 0.5, 1, "Rounded answer.", 13)
  record_attempt("student_beta", "q4_code_summary", "survey |> summarise(mean_hours = mean(hours))", "partial", 1, 2, "Partial credit.", 14)

  record_attempt("student_gamma", "q1_variable_type", "quantitative", "correct", 1, 1, "Correct.", 15)

  invisible(learnrTrackR::get_attempts(con, tutorial_id = tutorial_id))
}

write_ulaval_pilot_outputs <- function(con,
                                       output_dir,
                                       tutorial_id = ulaval_pilot_tutorial_id(),
                                       group_id = "A",
                                       rule = "last",
                                       render_report = ulaval_pilot_render_report()) {
  group_filter <- ulaval_pilot_group_filter(group_id)

  if (!dir.exists(output_dir)) {
    dir.create(output_dir, recursive = TRUE)
  }

  export_data <- learnrTrackR::tracking_export_data(
    con = con,
    tutorial_id = tutorial_id,
    group_id = group_filter,
    rule = rule
  )
  readiness <- learnrTrackR::check_pilot_readiness(
    con = con,
    tutorial_id = tutorial_id,
    group_id = group_filter,
    rule = rule,
    require_attempts = TRUE,
    require_all_students_attempted = TRUE
  )
  dashboard <- learnrTrackR::dashboard_data(
    con = con,
    tutorial_id = tutorial_id,
    group_id = group_filter,
    rule = rule
  )
  report <- learnrTrackR::teacher_report_data(
    con = con,
    tutorial_id = tutorial_id,
    group_id = group_filter,
    rule = rule
  )

  paths <- list(
    readiness = file.path(output_dir, "dry-run-readiness.csv"),
    attempts = file.path(output_dir, "dry-run-attempts.csv"),
    scores = file.path(output_dir, "dry-run-scores.csv"),
    gradebook = file.path(output_dir, "dry-run-gradebook.csv"),
    moodle = file.path(output_dir, "dry-run-moodle.csv"),
    canvas = file.path(output_dir, "dry-run-canvas.csv"),
    bundle = file.path(output_dir, "dry-run-bundle"),
    report = file.path(output_dir, "dry-run-teacher-report.html")
  )

  readr::write_csv(readiness, paths$readiness)
  readr::write_csv(export_data$attempts, paths$attempts)
  readr::write_csv(export_data$scores, paths$scores)
  readr::write_csv(export_data$gradebook, paths$gradebook)
  learnrTrackR::export_moodle_grades(
    con = con,
    path = paths$moodle,
    tutorial_id = tutorial_id,
    grade_item = "Pilot tutorial dry-run",
    group_id = group_filter,
    rule = rule
  )
  learnrTrackR::export_canvas_grades(
    con = con,
    path = paths$canvas,
    tutorial_id = tutorial_id,
    assignment = "Pilot tutorial dry-run",
    group_id = group_filter,
    rule = rule
  )
  bundle_paths <- learnrTrackR::export_tracking_bundle(
    con = con,
    path = paths$bundle,
    tutorial_id = tutorial_id,
    group_id = group_filter,
    rule = rule
  )

  if (isTRUE(render_report)) {
    learnrTrackR::generate_teacher_report(
      con = con,
      path = paths$report,
      tutorial_id = tutorial_id,
      group_id = group_filter,
      rule = rule
    )
  } else {
    paths$report <- NA_character_
  }

  invisible(
    list(
      readiness = readiness,
      export_data = export_data,
      dashboard = dashboard,
      report = report,
      bundle_paths = bundle_paths,
      paths = paths
    )
  )
}

run_ulaval_pilot_dry_run <- function() {
  template_dir <- resolve_ulaval_pilot_template_dir()
  tutorial_id <- ulaval_pilot_tutorial_id()
  db_path <- Sys.getenv(
    "LEARNRTRACKR_DB",
    unset = file.path(tempdir(), "learnrtrackr-ulaval-pilot-template.sqlite")
  )
  output_dir <- Sys.getenv(
    "LEARNRTRACKR_OUTPUT_DIR",
    unset = file.path(dirname(db_path), "ulaval-pilot-template-outputs")
  )
  group_id <- Sys.getenv("LEARNRTRACKR_GROUP_ID", unset = "A")

  con <- learnrTrackR::init_tracking_db(db_path, overwrite = TRUE)
  on.exit(DBI::dbDisconnect(con), add = TRUE)

  learnrTrackR::load_tracking_config(
    con,
    ulaval_pilot_config_dir(template_dir),
    overwrite_questions = TRUE
  )
  record_ulaval_pilot_attempts(con, tutorial_id = tutorial_id)

  outputs <- write_ulaval_pilot_outputs(
    con = con,
    output_dir = output_dir,
    tutorial_id = tutorial_id,
    group_id = group_id,
    rule = "last"
  )

  message("Created pilot template database: ", db_path)
  message("Wrote dry-run outputs to: ", output_dir)
  message("Readiness checks:")
  print(outputs$readiness)
  message("Dashboard summary:")
  print(outputs$dashboard$summary)
  message("Output paths:")
  print(unlist(outputs$paths))

  invisible(
    list(
      db_path = db_path,
      output_dir = output_dir,
      outputs = outputs
    )
  )
}

run_ulaval_pilot_dry_run()
