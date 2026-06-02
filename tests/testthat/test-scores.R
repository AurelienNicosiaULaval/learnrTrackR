test_that("compute_scores supports last, best, and first rules", {
  db_path <- withr::local_tempfile(fileext = ".sqlite")
  con <- init_tracking_db(db_path, overwrite = TRUE)
  withr::defer(DBI::dbDisconnect(con))

  track_attempt(
    con,
    "student_001",
    "module_01",
    "q1",
    "mean(x)",
    score = 0,
    max_score = 1,
    timestamp = as.POSIXct("2026-01-01 10:00:00", tz = "UTC")
  )
  track_attempt(
    con,
    "student_001",
    "module_01",
    "q1",
    "mean(x, na.rm = TRUE)",
    score = 1,
    max_score = 1,
    timestamp = as.POSIXct("2026-01-01 10:05:00", tz = "UTC")
  )
  track_attempt(
    con,
    "student_001",
    "module_01",
    "q2",
    "summarise(df, x = mean(x))",
    score = 1,
    max_score = 1,
    timestamp = as.POSIXct("2026-01-01 10:10:00", tz = "UTC")
  )
  track_attempt(
    con,
    "student_002",
    "module_01",
    "q1",
    "mean(y)",
    score = 0.5,
    max_score = 1,
    timestamp = as.POSIXct("2026-01-01 10:00:00", tz = "UTC")
  )

  last_scores <- compute_scores(con, tutorial_id = "module_01", rule = "last")
  best_scores <- compute_scores(con, tutorial_id = "module_01", rule = "best")
  first_scores <- compute_scores(con, tutorial_id = "module_01", rule = "first")

  student_001_last <- last_scores[last_scores$student_id == "student_001", ]
  student_001_best <- best_scores[best_scores$student_id == "student_001", ]
  student_001_first <- first_scores[first_scores$student_id == "student_001", ]

  expect_equal(student_001_last$score, 2)
  expect_equal(student_001_last$max_score, 2)
  expect_equal(student_001_last$percent, 100)
  expect_equal(student_001_last$n_questions, 2L)
  expect_equal(student_001_last$n_answered, 2L)

  expect_equal(student_001_best$score, 2)
  expect_equal(student_001_first$score, 1)
})

test_that("compute_scores returns an empty tibble when there are no attempts", {
  db_path <- withr::local_tempfile(fileext = ".sqlite")
  con <- init_tracking_db(db_path, overwrite = TRUE)
  withr::defer(DBI::dbDisconnect(con))

  scores <- compute_scores(con)

  expect_s3_class(scores, "tbl_df")
  expect_equal(nrow(scores), 0)
  expect_equal(
    names(scores),
    c("student_id", "tutorial_id", "score", "max_score", "percent", "n_questions", "n_answered")
  )
})

test_that("gradebook counts registered unanswered questions", {
  db_path <- withr::local_tempfile(fileext = ".sqlite")
  con <- init_tracking_db(db_path, overwrite = TRUE)
  withr::defer(DBI::dbDisconnect(con))

  register_questions(
    con,
    "module_01",
    data.frame(
      question_id = c("q1", "q2", "q3"),
      max_score = c(1, 1, 2)
    )
  )

  track_attempt(
    con,
    "student_001",
    "module_01",
    "q1",
    "mean(x)",
    score = 1,
    max_score = 1
  )
  track_attempt(
    con,
    "student_001",
    "module_01",
    "q2",
    "sd(x)",
    score = 0.5,
    max_score = 1
  )

  grades <- gradebook(con, tutorial_id = "module_01")

  expect_equal(nrow(grades), 1)
  expect_equal(grades$score, 1.5)
  expect_equal(grades$max_score, 4)
  expect_equal(grades$percent, 37.5)
  expect_equal(grades$n_questions, 3L)
  expect_equal(grades$n_answered, 2L)
  expect_equal(grades$n_unanswered, 1L)
  expect_false(grades$completed)
})

test_that("gradebook supports first, last, and best rules", {
  db_path <- withr::local_tempfile(fileext = ".sqlite")
  con <- init_tracking_db(db_path, overwrite = TRUE)
  withr::defer(DBI::dbDisconnect(con))

  register_questions(con, "module_01", "q1")

  track_attempt(
    con,
    "student_001",
    "module_01",
    "q1",
    "wrong",
    score = 0,
    max_score = 1,
    timestamp = as.POSIXct("2026-01-01 10:00:00", tz = "UTC")
  )
  track_attempt(
    con,
    "student_001",
    "module_01",
    "q1",
    "right",
    score = 1,
    max_score = 1,
    timestamp = as.POSIXct("2026-01-01 10:05:00", tz = "UTC")
  )
  track_attempt(
    con,
    "student_001",
    "module_01",
    "q1",
    "partial",
    score = 0.5,
    max_score = 1,
    timestamp = as.POSIXct("2026-01-01 10:10:00", tz = "UTC")
  )

  expect_equal(gradebook(con, "module_01", rule = "first")$score, 0)
  expect_equal(gradebook(con, "module_01", rule = "last")$score, 0.5)
  expect_equal(gradebook(con, "module_01", rule = "best")$score, 1)
})

test_that("gradebook can include a student with no attempts", {
  db_path <- withr::local_tempfile(fileext = ".sqlite")
  con <- init_tracking_db(db_path, overwrite = TRUE)
  withr::defer(DBI::dbDisconnect(con))

  register_questions(con, "module_01", c("q1", "q2"))

  grades <- gradebook(con, tutorial_id = "module_01", student_id = "student_001")

  expect_equal(nrow(grades), 1)
  expect_equal(grades$student_id, "student_001")
  expect_equal(grades$score, 0)
  expect_equal(grades$max_score, 2)
  expect_equal(grades$n_answered, 0L)
  expect_equal(grades$n_unanswered, 2L)
  expect_false(grades$completed)
})
