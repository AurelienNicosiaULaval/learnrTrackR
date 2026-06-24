ulaval_pilot_template_dir <- function() {
  installed_dir <- system.file(
    "examples/ulaval-pilot-template",
    package = "learnrTrackR"
  )
  if (nzchar(installed_dir)) {
    return(installed_dir)
  }

  normalizePath(
    file.path("..", "..", "inst", "examples", "ulaval-pilot-template"),
    mustWork = TRUE
  )
}

test_that("ULaval pilot template configuration is coherent", {
  example_dir <- ulaval_pilot_template_dir()
  config <- read_tracking_config(file.path(example_dir, "config-csv"))

  expect_equal(config$courses$course_id, "stat_pilot")
  expect_equal(config$tutorials$tutorial_id, "pilot_tutorial_01")
  expect_equal(config$tutorials$version, "0.1.0")
  expect_equal(nrow(config$students), 4)
  expect_equal(nrow(config$questions), 4)
  expect_equal(sum(config$questions$max_score), 5)
  expect_true(all(config$questions$tutorial_id == "pilot_tutorial_01"))
  expect_setequal(config$students$group_id, c("A", "B"))
})

test_that("ULaval pilot template YAML configuration matches CSV", {
  skip_if_not_installed("yaml")

  example_dir <- ulaval_pilot_template_dir()
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

test_that("ULaval pilot template dry-run writes scoped exports", {
  example_dir <- ulaval_pilot_template_dir()
  db_path <- withr::local_tempfile(fileext = ".sqlite")
  output_dir <- withr::local_tempdir()

  withr::local_envvar(
    LEARNRTRACKR_TEMPLATE_DIR = example_dir,
    LEARNRTRACKR_DB = db_path,
    LEARNRTRACKR_OUTPUT_DIR = output_dir,
    LEARNRTRACKR_GROUP_ID = "A",
    LEARNRTRACKR_RENDER_REPORT = "false"
  )

  result <- invisible(capture.output(suppressMessages(
    source(file.path(example_dir, "run-dry-run.R"), local = new.env(parent = globalenv()))
  )))

  expected_files <- file.path(
    output_dir,
    c(
      "dry-run-readiness.csv",
      "dry-run-attempts.csv",
      "dry-run-scores.csv",
      "dry-run-gradebook.csv",
      "dry-run-moodle.csv",
      "dry-run-canvas.csv"
    )
  )

  expect_true(length(result) > 0)
  expect_true(all(file.exists(expected_files)))
  expect_true(dir.exists(file.path(output_dir, "dry-run-bundle")))

  readiness <- readr::read_csv(
    file.path(output_dir, "dry-run-readiness.csv"),
    show_col_types = FALSE
  )
  attempts <- readr::read_csv(
    file.path(output_dir, "dry-run-attempts.csv"),
    show_col_types = FALSE
  )
  gradebook <- readr::read_csv(
    file.path(output_dir, "dry-run-gradebook.csv"),
    show_col_types = FALSE
  )
  moodle <- readr::read_csv(
    file.path(output_dir, "dry-run-moodle.csv"),
    show_col_types = FALSE
  )
  canvas <- readr::read_csv(
    file.path(output_dir, "dry-run-canvas.csv"),
    show_col_types = FALSE
  )

  expect_false(any(readiness$status != "ok"))
  expect_setequal(attempts$student_id, c("student_demo", "student_alpha", "student_beta"))
  expect_setequal(gradebook$student_id, c("student_demo", "student_alpha", "student_beta"))
  expect_setequal(moodle$useridnumber, c("student_demo", "student_alpha", "student_beta"))
  expect_setequal(canvas[["SIS User ID"]], c("student_demo", "student_alpha", "student_beta"))
  expect_false("student_gamma" %in% attempts$student_id)
  expect_true(all(gradebook$completed))
})
