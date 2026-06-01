test_that("track_attempt adds attempts and computes attempt_number", {
  db_path <- withr::local_tempfile(fileext = ".sqlite")
  con <- init_tracking_db(db_path, overwrite = TRUE)
  withr::defer(DBI::dbDisconnect(con))

  first_id <- track_attempt(
    con = con,
    student_id = "student_001",
    tutorial_id = "module_01",
    question_id = "q1",
    submitted_answer = "mean(x)",
    score = 0,
    max_score = 1,
    timestamp = as.POSIXct("2026-01-01 10:00:00", tz = "UTC")
  )

  second_id <- track_attempt(
    con = con,
    student_id = "student_001",
    tutorial_id = "module_01",
    question_id = "q1",
    submitted_answer = "mean(x, na.rm = TRUE)",
    score = 1,
    max_score = 1,
    timestamp = as.POSIXct("2026-01-01 10:05:00", tz = "UTC")
  )

  attempts <- get_attempts(con, student_id = "student_001", question_id = "q1")

  expect_identical(first_id, 1L)
  expect_identical(second_id, 2L)
  expect_s3_class(attempts, "tbl_df")
  expect_equal(attempts$attempt_number, c(1L, 2L))
  expect_equal(attempts$submitted_answer, c("mean(x)", "mean(x, na.rm = TRUE)"))
})

test_that("get_attempts filters by student, tutorial, and question", {
  db_path <- withr::local_tempfile(fileext = ".sqlite")
  con <- init_tracking_db(db_path, overwrite = TRUE)
  withr::defer(DBI::dbDisconnect(con))

  track_attempt(con, "student_001", "module_01", "q1", "mean(x)")
  track_attempt(con, "student_002", "module_01", "q1", "sd(x)")
  track_attempt(con, "student_001", "module_02", "q2", "median(x)")

  expect_equal(nrow(get_attempts(con, student_id = "student_001")), 2)
  expect_equal(nrow(get_attempts(con, tutorial_id = "module_01")), 2)
  expect_equal(nrow(get_attempts(con, question_id = "q2")), 1)
})
