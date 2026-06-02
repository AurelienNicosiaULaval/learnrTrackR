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

test_that("dashboard_app builds a Shiny app object", {
  skip_if_not_installed("shiny")

  db_path <- withr::local_tempfile(fileext = ".sqlite")
  con <- init_tracking_db(db_path, overwrite = TRUE)
  withr::defer(DBI::dbDisconnect(con))

  register_questions(con, "module_01", c("q1"))

  app <- dashboard_app(db_path, tutorial_id = "module_01")

  expect_s3_class(app, "shiny.appobj")
})
