course_pilot_example_dir <- function() {
  installed_dir <- system.file("examples/course-pilot", package = "learnrTrackR")
  if (nzchar(installed_dir)) {
    return(installed_dir)
  }

  normalizePath(
    file.path("..", "..", "inst", "examples", "course-pilot"),
    mustWork = TRUE
  )
}

test_that("course pilot configuration is coherent", {
  example_dir <- course_pilot_example_dir()
  config <- read_tracking_config(file.path(example_dir, "config-csv"))

  expect_equal(config$courses$course_id, "stat_intro")
  expect_equal(config$tutorials$tutorial_id, "stat_descriptive_pilot")
  expect_equal(config$tutorials$version, "0.2.0")
  expect_equal(nrow(config$students), 4)
  expect_equal(nrow(config$questions), 6)
  expect_equal(sum(config$questions$max_score), 7)
  expect_true(all(config$questions$tutorial_id == "stat_descriptive_pilot"))
})

test_that("course pilot includes launch scripts and checklist", {
  example_dir <- course_pilot_example_dir()
  expected_files <- file.path(
    example_dir,
    c(
      "run-student.R",
      "run-teacher.R",
      "student.env.example",
      "teacher.env.example",
      "pilot-checklist.md",
      "config/tracking.yml"
    )
  )

  expect_true(all(file.exists(expected_files)))
  expect_silent(parse(file = file.path(example_dir, "run-student.R")))
  expect_silent(parse(file = file.path(example_dir, "run-teacher.R")))

  student_launcher <- readLines(file.path(example_dir, "run-student.R"), warn = FALSE)
  teacher_launcher <- readLines(file.path(example_dir, "run-teacher.R"), warn = FALSE)
  checklist <- readLines(file.path(example_dir, "pilot-checklist.md"), warn = FALSE)

  expect_true(any(grepl("learnr::run_tutorial", student_launcher, fixed = TRUE)))
  expect_true(any(grepl("inspect-results.R", teacher_launcher, fixed = TRUE)))
  expect_true(any(grepl("LEARNRTRACKR_TEACHER_OPEN_DASHBOARD", teacher_launcher, fixed = TRUE)))
  expect_true(any(grepl("Moodle import", checklist, fixed = TRUE)))
  expect_true(any(grepl("Privacy", checklist, fixed = TRUE)))
})

test_that("course pilot YAML configuration matches the CSV configuration", {
  skip_if_not_installed("yaml")

  example_dir <- course_pilot_example_dir()
  csv_config <- read_tracking_config(file.path(example_dir, "config-csv"))
  yaml_config <- read_tracking_config(file.path(example_dir, "config", "tracking.yml"))
  normalize_empty_email <- function(data) {
    if ("email" %in% names(data)) {
      data$email[is.na(data$email)] <- ""
    }

    data
  }

  expect_equal(yaml_config$courses, csv_config$courses)
  expect_equal(yaml_config$tutorials, csv_config$tutorials)
  expect_equal(normalize_empty_email(yaml_config$students), normalize_empty_email(csv_config$students))
  expect_equal(yaml_config$questions, csv_config$questions)
})

test_that("course pilot data support the tutorial answers", {
  example_dir <- course_pilot_example_dir()
  source(file.path(example_dir, "pilot-data.R"), local = TRUE)

  region_summary <- pilot_survey |>
    dplyr::group_by(region) |>
    dplyr::summarise(
      median_study_hours = median(study_hours),
      .groups = "drop"
    ) |>
    dplyr::arrange(dplyr::desc(median_study_hours))

  expect_equal(nrow(pilot_survey), 12)
  expect_equal(region_summary$region[[1]], "Sherbrooke")
  expect_equal(mean(pilot_survey$study_hours), 77 / 12)
})

test_that("course pilot simulation writes teacher outputs", {
  example_dir <- course_pilot_example_dir()
  db_path <- withr::local_tempfile(fileext = ".sqlite")
  output_dir <- withr::local_tempdir()

  withr::local_envvar(
    LEARNRTRACKR_EXAMPLE_DIR = example_dir,
    LEARNRTRACKR_DB = db_path,
    LEARNRTRACKR_OUTPUT_DIR = output_dir,
    LEARNRTRACKR_GROUP_ID = "A"
  )

  invisible(capture.output(suppressMessages(
    source(file.path(example_dir, "simulate-results.R"), local = new.env(parent = globalenv()))
  )))

  con <- connect_tracking_db(db_path)
  withr::defer(DBI::dbDisconnect(con))

  grades <- gradebook(con, tutorial_id = "stat_descriptive_pilot", rule = "last")
  expect_equal(nrow(get_attempts(con, tutorial_id = "stat_descriptive_pilot")), 18)
  expect_equal(nrow(grades), 4)
  expect_equal(max(grades$max_score), 7)

  invisible(capture.output(suppressMessages(
    source(file.path(example_dir, "inspect-results.R"), local = new.env(parent = globalenv()))
  )))

  expected_files <- file.path(
    output_dir,
    c(
      "course-pilot-attempts.csv",
      "course-pilot-scores.csv",
      "course-pilot-gradebook.csv",
      "course-pilot-moodle.csv"
    )
  )

  expect_true(all(file.exists(expected_files)))
  expect_true(dir.exists(file.path(output_dir, "course-pilot-bundle")))

  moodle <- readr::read_csv(
    file.path(output_dir, "course-pilot-moodle.csv"),
    show_col_types = FALSE
  )
  expect_setequal(moodle$useridnumber, c("student_demo", "student_a01", "student_a02"))
  expect_false("student_b01" %in% moodle$useridnumber)
})
