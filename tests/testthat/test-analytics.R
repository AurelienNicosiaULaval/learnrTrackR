test_that("summarise_questions reports question-level activity and difficulty", {
  db_path <- withr::local_tempfile(fileext = ".sqlite")
  con <- init_tracking_db(db_path, overwrite = TRUE)
  withr::defer(DBI::dbDisconnect(con))

  register_students(
    con,
    data.frame(
      student_id = c("student_001", "student_002", "student_003"),
      student_label = c("Student 1", "Student 2", "Student 3"),
      group_id = c("A", "B", "A")
    )
  )
  register_questions(
    con,
    "module_01",
    data.frame(
      question_id = c("q1", "q2", "q3"),
      question_label = c("Mean", "Median", "Spread"),
      max_score = c(1, 1, 1)
    )
  )

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
  track_attempt(con, "student_001", "module_01", "q2", "partial", score = 0.5, max_score = 1)
  track_attempt(con, "student_002", "module_01", "q1", "wrong", score = 0, max_score = 1)
  track_attempt(con, "student_002", "module_01", "q2", "wrong", score = 0, max_score = 1)

  questions <- summarise_questions(con, "module_01")
  q1 <- questions[questions$question_id == "q1", ]
  q2 <- questions[questions$question_id == "q2", ]
  q3 <- questions[questions$question_id == "q3", ]

  expect_equal(questions$question_id, c("q2", "q1", "q3"))
  expect_equal(q1$n_possible_students, 3L)
  expect_equal(q1$n_students, 2L)
  expect_equal(q1$n_attempts, 3L)
  expect_equal(q1$mean_percent, 50)
  expect_equal(q1$full_credit_rate, 50)
  expect_equal(q2$mean_percent, 25)
  expect_equal(q3$n_attempts, 0L)
  expect_true(is.na(q3$mean_percent))
})

test_that("summarise_students reports progress and registered metadata", {
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
  register_questions(con, "module_01", c("q1", "q2", "q3"))
  track_attempt(con, "student_001", "module_01", "q1", "right", score = 1, max_score = 1)
  track_attempt(con, "student_001", "module_01", "q2", "partial", score = 0.5, max_score = 1)
  track_attempt(con, "student_002", "module_01", "q1", "wrong", score = 0, max_score = 1)

  students <- summarise_students(con, "module_01")
  student_001 <- students[students$student_id == "student_001", ]
  student_003 <- students[students$student_id == "student_003", ]
  group_a <- summarise_students(con, "module_01", group_id = "A")

  expect_equal(students$student_id, c("student_001", "student_003", "student_002"))
  expect_equal(student_001$student_label, "Student 1")
  expect_equal(student_001$score, 1.5)
  expect_equal(student_001$max_score, 3)
  expect_equal(student_001$percent, 50)
  expect_equal(student_001$n_attempts, 2L)
  expect_equal(student_001$status, "in_progress")
  expect_equal(student_003$n_attempts, 0L)
  expect_equal(student_003$status, "not_started")
  expect_equal(group_a$student_id, c("student_001", "student_003"))
})

test_that("detect_difficult_questions flags low-performing questions", {
  db_path <- withr::local_tempfile(fileext = ".sqlite")
  con <- init_tracking_db(db_path, overwrite = TRUE)
  withr::defer(DBI::dbDisconnect(con))

  register_questions(con, "module_01", c("q1", "q2"))
  track_attempt(con, "student_001", "module_01", "q1", "right", score = 1, max_score = 1)
  track_attempt(con, "student_002", "module_01", "q1", "wrong", score = 0, max_score = 1)
  track_attempt(con, "student_001", "module_01", "q2", "wrong", score = 0, max_score = 1)
  track_attempt(con, "student_002", "module_01", "q2", "wrong", score = 0, max_score = 1)

  difficult <- detect_difficult_questions(
    con,
    "module_01",
    max_mean_percent = 30,
    min_students = 2
  )

  expect_equal(difficult$question_id, "q2")
  expect_equal(difficult$mean_percent, 0)
})

test_that("detect_stalled_students flags active incomplete low-score students", {
  db_path <- withr::local_tempfile(fileext = ".sqlite")
  con <- init_tracking_db(db_path, overwrite = TRUE)
  withr::defer(DBI::dbDisconnect(con))

  register_students(con, c("student_001", "student_002", "student_003"))
  register_questions(con, "module_01", c("q1", "q2", "q3"))
  track_attempt(con, "student_001", "module_01", "q1", "right", score = 1, max_score = 1)
  track_attempt(con, "student_001", "module_01", "q2", "right", score = 1, max_score = 1)
  track_attempt(con, "student_002", "module_01", "q1", "wrong", score = 0, max_score = 1)

  stalled <- detect_stalled_students(
    con,
    "module_01",
    max_percent = 40,
    min_attempts = 1
  )

  expect_equal(stalled$student_id, "student_002")
  expect_equal(stalled$status, "in_progress")
  expect_equal(stalled$percent, 0)
})
