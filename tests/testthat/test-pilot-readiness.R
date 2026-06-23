readiness_status <- function(x, check) {
  x$status[x$check == check]
}

readiness_details <- function(x, check) {
  x$details[x$check == check]
}

test_that("check_pilot_readiness reports a clean scoped pilot export", {
  db_path <- withr::local_tempfile(fileext = ".sqlite")
  con <- init_tracking_db(db_path, overwrite = TRUE)
  withr::defer(DBI::dbDisconnect(con))

  register_students(
    con,
    data.frame(
      student_id = c("student_001", "student_002"),
      group_id = c("A", "A")
    )
  )
  register_questions(con, "module_01", c("q1", "q2"))

  track_attempt(con, "student_001", "module_01", "q1", "a", score = 1, max_score = 1)
  track_attempt(con, "student_001", "module_01", "q2", "b", score = 1, max_score = 1)
  track_attempt(con, "student_002", "module_01", "q1", "a", score = 1, max_score = 1)
  track_attempt(con, "student_002", "module_01", "q2", "b", score = 1, max_score = 1)

  readiness <- check_pilot_readiness(
    con,
    tutorial_id = "module_01",
    group_id = "A"
  )

  expect_s3_class(readiness, "tbl_df")
  expect_true(all(readiness$status == "ok"))
  expect_equal(readiness_status(readiness, "registered_students"), "ok")
  expect_equal(readiness_status(readiness, "moodle_identifier_values"), "ok")
  expect_equal(readiness_status(readiness, "canvas_identifier_values"), "ok")
})

test_that("check_pilot_readiness flags registry and export issues", {
  db_path <- withr::local_tempfile(fileext = ".sqlite")
  con <- init_tracking_db(db_path, overwrite = TRUE)
  withr::defer(DBI::dbDisconnect(con))

  register_students(
    con,
    data.frame(
      student_id = c("student_001", "student_002"),
      group_id = c("A", "A")
    )
  )
  register_questions(con, "module_01", c("q1", "q2"))

  track_attempt(con, "student_001", "module_01", "q1", "a", score = 1, max_score = 1)
  track_attempt(con, "intruder", "module_01", "q_extra", "x", score = 1, max_score = 1)

  readiness <- check_pilot_readiness(con, tutorial_id = "module_01")

  expect_equal(readiness_status(readiness, "unexpected_students"), "error")
  expect_equal(readiness_details(readiness, "unexpected_students"), "intruder")
  expect_equal(readiness_status(readiness, "unregistered_questions"), "error")
  expect_equal(readiness_details(readiness, "unregistered_questions"), "q_extra")
  expect_equal(readiness_status(readiness, "students_without_attempts"), "warning")
  expect_equal(readiness_status(readiness, "questions_without_attempts"), "warning")
  expect_equal(readiness_status(readiness, "incomplete_gradebook_rows"), "warning")

  expect_error(
    check_pilot_readiness(con, tutorial_id = "module_01", stop_on_error = TRUE),
    "Pilot readiness checks failed"
  )
})

test_that("check_pilot_readiness can require attempts and all students", {
  db_path <- withr::local_tempfile(fileext = ".sqlite")
  con <- init_tracking_db(db_path, overwrite = TRUE)
  withr::defer(DBI::dbDisconnect(con))

  register_students(con, data.frame(student_id = c("student_001", "student_002")))
  register_questions(con, "module_01", "q1")
  track_attempt(con, "student_001", "module_01", "q1", "a", score = 1, max_score = 1)

  readiness <- check_pilot_readiness(
    con,
    tutorial_id = "module_01",
    require_attempts = TRUE,
    require_all_students_attempted = TRUE
  )

  expect_equal(readiness_status(readiness, "recorded_attempts"), "ok")
  expect_equal(readiness_status(readiness, "students_without_attempts"), "error")
})
