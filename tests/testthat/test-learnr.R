test_that("track_gradethis_attempt records and returns a gradethis grade", {
  skip_if_not_installed("gradethis")

  db_path <- withr::local_tempfile(fileext = ".sqlite")
  con <- init_tracking_db(db_path, overwrite = TRUE)
  withr::defer(DBI::dbDisconnect(con))

  grade <- track_gradethis_attempt(
    con = con,
    student_id = "student_001",
    tutorial_id = "minimal_learnr",
    question_id = "q2_mean",
    submitted_answer = "mean(c(2, 4, 6))",
    correct = TRUE,
    feedback = "Correct.",
    max_score = 1
  )

  attempts <- get_attempts(con)

  expect_s3_class(grade, "gradethis_graded")
  expect_true(grade$correct)
  expect_equal(nrow(attempts), 1)
  expect_equal(attempts$grade_status, "correct")
  expect_equal(attempts$score, 1)
})

test_that("track_gradethis_attempt works inside grade_this", {
  skip_if_not_installed("gradethis")

  db_path <- withr::local_tempfile(fileext = ".sqlite")
  con <- init_tracking_db(db_path, overwrite = TRUE)
  DBI::dbDisconnect(con)

  grader <- gradethis::grade_this({
    con <- init_tracking_db(db_path, overwrite = FALSE)
    on.exit(DBI::dbDisconnect(con), add = TRUE)

    correct <- identical(.result, 4)

    track_gradethis_attempt(
      con = con,
      student_id = "student_001",
      tutorial_id = "minimal_learnr",
      question_id = "q2_mean",
      submitted_answer = .user_code,
      correct = correct,
      feedback = if (correct) "Correct." else "Try again.",
      max_score = 1
    )
  })

  grade <- grader(gradethis::mock_this_exercise(.user_code = 2 + 2))

  con <- connect_tracking_db(db_path)
  withr::defer(DBI::dbDisconnect(con))
  attempts <- get_attempts(con)

  expect_s3_class(grade, "gradethis_graded")
  expect_true(grade$correct)
  expect_equal(nrow(attempts), 1)
  expect_equal(attempts$submitted_answer, "2 + 2")
})
