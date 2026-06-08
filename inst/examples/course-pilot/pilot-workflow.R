course_pilot_tutorial_id <- function() {
  "stat_descriptive_pilot"
}

course_pilot_config_dir <- function(example_dir) {
  file.path(example_dir, "config-csv")
}

course_pilot_load_config <- function(con, example_dir) {
  learnrTrackR::load_tracking_config(con, course_pilot_config_dir(example_dir))
}

course_pilot_record_simulated_attempts <- function(con,
                                                   tutorial_id = course_pilot_tutorial_id()) {
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
        "2026-01-15 09:00:00",
        tz = "America/Toronto"
      ) + 60 * minute_offset,
      require_registered_student = TRUE
    )
  }

  record_attempt("student_demo", "q1_variable_type", "study_hours", "correct", 1, 1, "Correct.", 1)
  record_attempt("student_demo", "q2_robust_summaries", "Median; Interquartile range", "correct", 1, 1, "Correct.", 2)
  record_attempt("student_demo", "q3_n_rows", "12", "correct", 1, 1, "Correct.", 3)
  record_attempt("student_demo", "q4_highest_median", "Sherbrooke", "correct", 1, 1, "Correct.", 4)
  record_attempt("student_demo", "q5_mean_study_hours", "mean(pilot_survey$study_hours)", "correct", 1, 1, "Correct.", 5)
  record_attempt(
    "student_demo",
    "q6_region_summary",
    "pilot_survey |> group_by(region) |> summarise(n = n(), median_study_hours = median(study_hours), mean_quiz_score = mean(quiz_score), .groups = \"drop\")",
    "correct",
    2,
    2,
    "Correct.",
    6
  )

  record_attempt("student_a01", "q1_variable_type", "study_hours", "correct", 1, 1, "Correct.", 7)
  record_attempt("student_a01", "q2_robust_summaries", "Mean; Standard deviation", "incorrect", 0, 1, "Try again.", 8)
  record_attempt("student_a01", "q3_n_rows", "12", "correct", 1, 1, "Correct.", 9)
  record_attempt("student_a01", "q4_highest_median", "Quebec City", "incorrect", 0, 1, "Try again.", 10)
  record_attempt("student_a01", "q4_highest_median", "Sherbrooke", "correct", 1, 1, "Correct.", 11)
  record_attempt("student_a01", "q5_mean_study_hours", "median(pilot_survey$study_hours)", "incorrect", 0, 1, "Try again.", 12)
  record_attempt("student_a01", "q5_mean_study_hours", "mean(pilot_survey$study_hours)", "correct", 1, 1, "Correct.", 13)
  record_attempt(
    "student_a01",
    "q6_region_summary",
    "pilot_survey |> group_by(region) |> summarise(n = n(), median_study_hours = median(study_hours), .groups = \"drop\")",
    "partial",
    1,
    2,
    "Partial credit.",
    14
  )

  record_attempt("student_b01", "q1_variable_type", "study_hours", "correct", 1, 1, "Correct.", 15)
  record_attempt("student_b01", "q3_n_rows", "10", "incorrect", 0, 1, "Try again.", 16)
  record_attempt("student_b01", "q5_mean_study_hours", "sum(pilot_survey$study_hours)", "incorrect", 0, 1, "Try again.", 17)
  record_attempt("student_a02", "q1_variable_type", "region", "incorrect", 0, 1, "Try again.", 18)

  invisible(learnrTrackR::get_attempts(con, tutorial_id = tutorial_id))
}

course_pilot_group_filter <- function(group_id = NULL) {
  if (is.null(group_id)) {
    return(NULL)
  }

  group_id <- trimws(as.character(group_id))
  if (!nzchar(group_id)) {
    return(NULL)
  }

  group_id
}

course_pilot_teacher_outputs <- function(con,
                                         output_dir,
                                         tutorial_id = course_pilot_tutorial_id(),
                                         group_id = NULL,
                                         rule = "last",
                                         render_report = requireNamespace(
                                           "rmarkdown",
                                           quietly = TRUE
                                         )) {
  group_filter <- course_pilot_group_filter(group_id)

  if (!dir.exists(output_dir)) {
    dir.create(output_dir, recursive = TRUE)
  }

  attempts <- learnrTrackR::get_attempts(con, tutorial_id = tutorial_id)
  scores <- learnrTrackR::compute_scores(con, tutorial_id = tutorial_id, rule = rule)
  grades <- learnrTrackR::gradebook(con, tutorial_id = tutorial_id, rule = rule)
  dashboard <- learnrTrackR::dashboard_data(
    con,
    tutorial_id = tutorial_id,
    group_id = group_filter,
    rule = rule
  )
  report <- learnrTrackR::teacher_report_data(
    con,
    tutorial_id = tutorial_id,
    group_id = group_filter,
    rule = rule
  )

  attempts_path <- file.path(output_dir, "course-pilot-attempts.csv")
  scores_path <- file.path(output_dir, "course-pilot-scores.csv")
  gradebook_path <- file.path(output_dir, "course-pilot-gradebook.csv")
  moodle_path <- file.path(output_dir, "course-pilot-moodle.csv")
  canvas_path <- file.path(output_dir, "course-pilot-canvas.csv")
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
  learnrTrackR::export_canvas_grades(
    con,
    canvas_path,
    tutorial_id = tutorial_id,
    assignment = "Descriptive statistics pilot",
    group_id = group_filter
  )
  bundle_paths <- learnrTrackR::export_tracking_bundle(
    con,
    bundle_dir,
    tutorial_id = tutorial_id,
    group_id = group_filter
  )

  if (isTRUE(render_report)) {
    learnrTrackR::generate_teacher_report(
      con,
      report_path,
      tutorial_id = tutorial_id,
      group_id = group_filter,
      rule = rule
    )
  } else {
    report_path <- NA_character_
  }

  invisible(
    list(
      attempts = attempts,
      scores = scores,
      gradebook = grades,
      dashboard = dashboard,
      report = report,
      bundle_paths = bundle_paths,
      paths = list(
        attempts = attempts_path,
        scores = scores_path,
        gradebook = gradebook_path,
        moodle = moodle_path,
        canvas = canvas_path,
        bundle = bundle_dir,
        report = report_path
      )
    )
  )
}
