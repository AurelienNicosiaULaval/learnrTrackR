test_that("dashboard_data summarizes gradebook, attempts, and questions", {
  db_path <- withr::local_tempfile(fileext = ".sqlite")
  con <- init_tracking_db(db_path, overwrite = TRUE)
  withr::defer(DBI::dbDisconnect(con))

  register_questions(con, "module_01", c("q1", "q2"))
  track_attempt(con, "student_001", "module_01", "q1", "mean(x)", score = 1, max_score = 1)
  track_attempt(con, "student_002", "module_01", "q1", "sd(x)", score = 0, max_score = 1)

  data <- dashboard_data(con, tutorial_id = "module_01")

  expect_equal(data$tutorial_id, "module_01")
  expect_equal(nrow(data$gradebook), 2)
  expect_equal(nrow(data$questions), 2)
  expect_equal(nrow(data$attempts), 2)
  expect_equal(data$summary$value[data$summary$metric == "Students"], "2")
  expect_equal(data$summary$value[data$summary$metric == "Questions"], "2")
  expect_equal(data$questions$n_answered[data$questions$question_id == "q2"], 0)
})

test_that("dashboard_data infers the first available tutorial", {
  db_path <- withr::local_tempfile(fileext = ".sqlite")
  con <- init_tracking_db(db_path, overwrite = TRUE)
  withr::defer(DBI::dbDisconnect(con))

  register_questions(con, "module_b", c("q1"))
  register_questions(con, "module_a", c("q1"))

  data <- dashboard_data(con)

  expect_equal(data$tutorial_id, "module_a")
  expect_equal(data$tutorials$tutorial_id, c("module_a", "module_b"))
})

test_that("dashboard_data handles empty databases", {
  db_path <- withr::local_tempfile(fileext = ".sqlite")
  con <- init_tracking_db(db_path, overwrite = TRUE)
  withr::defer(DBI::dbDisconnect(con))

  data <- dashboard_data(con)

  expect_null(data$tutorial_id)
  expect_equal(nrow(data$gradebook), 0)
  expect_equal(nrow(data$questions), 0)
  expect_equal(nrow(data$attempts), 0)
})

test_that("dashboard_data enriches rows with students and filters by group", {
  db_path <- withr::local_tempfile(fileext = ".sqlite")
  con <- init_tracking_db(db_path, overwrite = TRUE)
  withr::defer(DBI::dbDisconnect(con))

  register_students(
    con,
    data.frame(
      student_id = c("student_001", "student_002", "student_003"),
      student_label = c("Student 1", "Student 2", "Student 3"),
      email = c("s1@example.org", "s2@example.org", "s3@example.org"),
      group_id = c("A", "B", "A")
    )
  )
  register_questions(con, "module_01", c("q1", "q2"))
  track_attempt(con, "student_001", "module_01", "q1", "mean(x)", score = 1, max_score = 1)
  track_attempt(con, "student_002", "module_01", "q1", "sd(x)", score = 0, max_score = 1)

  data_all <- dashboard_data(con, tutorial_id = "module_01")
  data_group_a <- dashboard_data(con, tutorial_id = "module_01", group_id = "A")

  expect_equal(data_all$groups$group_id, c("A", "B"))
  expect_equal(data_all$students$student_id, c("student_001", "student_003", "student_002"))
  expect_equal(nrow(data_all$gradebook), 3)
  expect_true(all(c("student_label", "email", "group_id") %in% names(data_all$gradebook)))

  expect_equal(data_group_a$group_id, "A")
  expect_equal(data_group_a$students$student_id, c("student_001", "student_003"))
  expect_equal(data_group_a$attempts$student_id, "student_001")
  expect_equal(nrow(data_group_a$gradebook), 2)
  expect_equal(nrow(data_group_a$moodle_grades), 2)
  expect_equal(
    data_group_a$gradebook$n_answered[data_group_a$gradebook$student_id == "student_003"],
    0
  )
  expect_equal(data_group_a$summary$value[data_group_a$summary$metric == "Group"], "A")
})

test_that("dashboard download filenames include group filters", {
  expect_equal(
    dashboard_download_filename("module 01", NULL, "gradebook"),
    "module-01-gradebook.csv"
  )
  expect_equal(
    dashboard_download_filename("module 01", "Group A", "moodle"),
    "module-01-group-Group-A-moodle.csv"
  )
})

test_that("dashboard_app builds a Shiny app object", {
  skip_if_not_installed("shiny")

  db_path <- withr::local_tempfile(fileext = ".sqlite")
  con <- init_tracking_db(db_path, overwrite = TRUE)
  withr::defer(DBI::dbDisconnect(con))

  register_questions(con, "module_01", c("q1"))
  register_students(con, data.frame(student_id = "student_001", group_id = "A"))

  app <- dashboard_app(db_path, tutorial_id = "module_01", group_id = "A")

  expect_s3_class(app, "shiny.appobj")
})

test_that("dashboard_app builds a token-gated Shiny app object", {
  skip_if_not_installed("shiny")

  db_path <- withr::local_tempfile(fileext = ".sqlite")
  con <- init_tracking_db(db_path, overwrite = TRUE)
  withr::defer(DBI::dbDisconnect(con))

  register_questions(con, "module_01", c("q1"))

  app <- dashboard_app(
    db_path,
    tutorial_id = "module_01",
    access_token = "secret-token"
  )

  expect_s3_class(app, "shiny.appobj")
})

test_that("dashboard access token can be explicit or environment based", {
  withr::local_envvar(LEARNRTRACKR_DASHBOARD_TOKEN = "env-token")

  expect_equal(
    resolve_dashboard_access_token("explicit-token"),
    "explicit-token"
  )
  expect_equal(
    resolve_dashboard_access_token(),
    "env-token"
  )
  expect_null(
    resolve_dashboard_access_token(token_envvar = NULL)
  )
})

test_that("dashboard launch security refuses unprotected remote hosts", {
  expect_true(
    check_dashboard_launch_security(
      host = "127.0.0.1",
      access_token = NULL,
      allow_remote = FALSE
    )
  )
  expect_true(
    check_dashboard_launch_security(
      host = "0.0.0.0",
      access_token = "secret-token",
      allow_remote = FALSE
    )
  )
  expect_error(
    check_dashboard_launch_security(
      host = "0.0.0.0",
      access_token = NULL,
      allow_remote = FALSE
    ),
    "Refusing to run the dashboard"
  )
})
