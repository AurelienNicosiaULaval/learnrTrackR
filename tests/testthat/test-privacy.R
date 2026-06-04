test_that("delete_student_data removes attempts, sessions, and registry rows", {
  db_path <- withr::local_tempfile(fileext = ".sqlite")
  con <- init_tracking_db(db_path, overwrite = TRUE)
  withr::defer(DBI::dbDisconnect(con))

  register_students(con, c("student_001", "student_002"))
  track_attempt(con, "student_001", "module_01", "q1", "mean(x)")
  track_attempt(con, "student_002", "module_01", "q1", "sd(x)")

  deleted <- delete_student_data(con, "student_001")

  expect_s3_class(deleted, "tbl_df")
  expect_equal(deleted$table, c("attempts", "sessions", "students"))
  expect_equal(deleted$deleted_rows, c(1L, 1L, 1L))
  expect_equal(get_attempts(con)$student_id, "student_002")
  expect_equal(get_students(con)$student_id, "student_002")
})

test_that("delete_student_data can preserve the student registry", {
  db_path <- withr::local_tempfile(fileext = ".sqlite")
  con <- init_tracking_db(db_path, overwrite = TRUE)
  withr::defer(DBI::dbDisconnect(con))

  register_students(con, "student_001")
  track_attempt(con, "student_001", "module_01", "q1", "mean(x)")

  deleted <- delete_student_data(
    con,
    "student_001",
    delete_student = FALSE
  )

  expect_equal(deleted$deleted_rows, c(1L, 1L, 0L))
  expect_equal(get_students(con)$student_id, "student_001")
  expect_equal(nrow(get_attempts(con)), 0)
})

test_that("pseudonymise_results replaces identifiers and returns a key", {
  data <- tibble::tibble(
    student_id = c("student_002", "student_001", "student_002"),
    student_label = c("Student 2", "Student 1", "Student 2"),
    email = c("two@example.org", "one@example.org", "two@example.org"),
    score = c(8, 9, 10)
  )

  out <- pseudonymise_results(data)

  expect_equal(out$key$student_id, c("student_001", "student_002"))
  expect_equal(out$key$pseudonym, c("student_0001", "student_0002"))
  expect_equal(out$data$student_id, c("student_0002", "student_0001", "student_0002"))
  expect_false("student_label" %in% names(out$data))
  expect_false("email" %in% names(out$data))
})

test_that("pseudonymise_results handles lists and existing keys", {
  data <- list(
    attempts = tibble::tibble(
      student_id = "student_001",
      submitted_answer = "mean(x)"
    ),
    students = tibble::tibble(
      student_id = "student_001",
      email = "one@example.org"
    )
  )
  key <- tibble::tibble(
    student_id = "student_001",
    pseudonym = "learner_A"
  )

  out <- pseudonymise_results(data, key = key)

  expect_equal(out$data$attempts$student_id, "learner_A")
  expect_equal(out$data$students$student_id, "learner_A")
  expect_false("email" %in% names(out$data$students))
  expect_equal(out$key$pseudonym, "learner_A")
})

test_that("pseudonymise_results supports custom identifier columns", {
  data <- tibble::tibble(
    learner_id = c("u2", "u1"),
    score = c(8, 9)
  )

  out <- pseudonymise_results(
    data,
    id_column = "learner_id",
    prefix = "learner"
  )

  expect_equal(names(out$key), c("learner_id", "pseudonym"))
  expect_equal(out$key$learner_id, c("u1", "u2"))
  expect_equal(out$data$learner_id, c("learner_0002", "learner_0001"))
})

test_that("pseudonymise_results rejects incomplete keys", {
  data <- tibble::tibble(student_id = c("student_001", "student_002"))
  key <- tibble::tibble(
    student_id = "student_001",
    pseudonym = "learner_A"
  )

  expect_error(
    pseudonymise_results(data, key = key),
    "does not cover all identifiers"
  )
})

test_that("anonymise_results removes direct identifier columns", {
  data <- list(
    gradebook = tibble::tibble(
      student_id = "student_001",
      email = "one@example.org",
      score = 9
    ),
    summary = tibble::tibble(metric = "n_students", value = "1")
  )

  out <- anonymise_results(data)

  expect_equal(names(out$gradebook), "score")
  expect_equal(names(out$summary), c("metric", "value"))
})
