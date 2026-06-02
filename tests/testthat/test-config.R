test_that("load_tracking_config loads a CSV configuration directory", {
  config_dir <- withr::local_tempdir()
  db_path <- withr::local_tempfile(fileext = ".sqlite")
  con <- init_tracking_db(db_path, overwrite = TRUE)
  withr::defer(DBI::dbDisconnect(con))

  readr::write_csv(
    data.frame(course_id = "stat101", course_label = "Statistics 101"),
    file.path(config_dir, "courses.csv")
  )
  readr::write_csv(
    data.frame(
      tutorial_id = "module_01",
      course_id = "stat101",
      tutorial_label = "Module 1"
    ),
    file.path(config_dir, "tutorials.csv")
  )
  readr::write_csv(
    data.frame(student_id = "student_001", group_id = "A"),
    file.path(config_dir, "students.csv")
  )
  readr::write_csv(
    data.frame(
      tutorial_id = "module_01",
      question_id = c("q1", "q2"),
      max_score = c(1, 2)
    ),
    file.path(config_dir, "questions.csv")
  )

  loaded <- load_tracking_config(con, config_dir)

  expect_equal(loaded$courses$course_id, "stat101")
  expect_equal(loaded$tutorials$tutorial_id, "module_01")
  expect_equal(loaded$students$student_id, "student_001")
  expect_equal(loaded$questions$question_id, c("q1", "q2"))
})

test_that("load_tracking_config loads a YAML configuration file", {
  skip_if_not_installed("yaml")

  config_path <- withr::local_tempfile(fileext = ".yml")
  db_path <- withr::local_tempfile(fileext = ".sqlite")
  con <- init_tracking_db(db_path, overwrite = TRUE)
  withr::defer(DBI::dbDisconnect(con))

  writeLines(
    c(
      "courses:",
      "  - course_id: stat101",
      "    course_label: Statistics 101",
      "tutorials:",
      "  - tutorial_id: module_01",
      "    course_id: stat101",
      "    tutorial_label: Module 1",
      "students:",
      "  - student_id: student_001",
      "    group_id: A",
      "questions:",
      "  - tutorial_id: module_01",
      "    question_id: q1",
      "    max_score: 1"
    ),
    config_path
  )

  loaded <- load_tracking_config(con, config_path)

  expect_equal(loaded$courses$course_id, "stat101")
  expect_equal(loaded$tutorials$course_id, "stat101")
  expect_equal(loaded$students$group_id, "A")
  expect_equal(loaded$questions$question_id, "q1")
})

test_that("read_tracking_config rejects missing paths", {
  expect_error(
    read_tracking_config(file.path(tempdir(), "missing-config.yml")),
    "does not exist"
  )
})

test_that("create_tracking_config_template writes CSV files that load", {
  config_dir <- withr::local_tempdir()
  db_path <- withr::local_tempfile(fileext = ".sqlite")
  con <- init_tracking_db(db_path, overwrite = TRUE)
  withr::defer(DBI::dbDisconnect(con))

  created <- create_tracking_config_template(config_dir, format = "csv")
  config <- read_tracking_config(config_dir)
  loaded <- load_tracking_config(con, config_dir)

  expect_equal(created$component, c("courses", "tutorials", "students", "questions"))
  expect_true(all(file.exists(created$path)))
  expect_equal(nrow(config$courses), 1)
  expect_equal(nrow(config$tutorials), 1)
  expect_equal(nrow(config$students), 2)
  expect_equal(nrow(config$questions), 2)
  expect_equal(loaded$courses$course_id, "stat101")
  expect_equal(loaded$students$student_id, c("student_001", "student_002"))
})

test_that("create_tracking_config_template writes YAML files that load", {
  skip_if_not_installed("yaml")

  config_path <- withr::local_tempfile(fileext = ".yml")
  db_path <- withr::local_tempfile(fileext = ".sqlite")
  con <- init_tracking_db(db_path, overwrite = TRUE)
  withr::defer(DBI::dbDisconnect(con))

  created <- create_tracking_config_template(config_path, format = "yaml")
  config <- read_tracking_config(config_path)
  loaded <- load_tracking_config(con, config_path)

  expect_equal(created$component, "yaml")
  expect_true(file.exists(created$path))
  expect_equal(nrow(config$courses), 1)
  expect_equal(nrow(config$tutorials), 1)
  expect_equal(nrow(config$students), 2)
  expect_equal(nrow(config$questions), 2)
  expect_equal(loaded$tutorials$tutorial_id, "module_01")
  expect_equal(loaded$questions$question_id, c("q1", "q2"))
})

test_that("create_tracking_config_template protects existing files", {
  config_dir <- withr::local_tempdir()
  config_path <- withr::local_tempfile(fileext = ".yml")

  create_tracking_config_template(config_dir, format = "csv")
  create_tracking_config_template(config_path, format = "yaml")

  expect_error(
    create_tracking_config_template(config_dir, format = "csv"),
    "already exist"
  )
  expect_error(
    create_tracking_config_template(config_path, format = "yaml"),
    "already exists"
  )
  expect_error(
    create_tracking_config_template(config_dir, format = "yaml"),
    "is a directory"
  )

  expect_no_error(
    create_tracking_config_template(config_dir, format = "csv", overwrite = TRUE)
  )
  expect_no_error(
    create_tracking_config_template(config_path, format = "yaml", overwrite = TRUE)
  )
})
