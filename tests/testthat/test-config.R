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
