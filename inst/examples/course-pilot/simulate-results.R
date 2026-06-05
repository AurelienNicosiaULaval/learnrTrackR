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
  source(file.path(example_dir, "pilot-data.R"))

  tutorial_id <- "stat_descriptive_pilot"
  db_path <- Sys.getenv(
    "LEARNRTRACKR_DB",
    unset = file.path(tempdir(), "learnrtrackr-course-pilot.sqlite")
  )
  config_dir <- file.path(example_dir, "config-csv")

  con <- learnrTrackR::init_tracking_db(db_path, overwrite = TRUE)
  on.exit(DBI::dbDisconnect(con), add = TRUE)

  learnrTrackR::load_tracking_config(con, config_dir)

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
