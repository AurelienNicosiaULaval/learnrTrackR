test_that("register_students stores character vectors", {
  db_path <- withr::local_tempfile(fileext = ".sqlite")
  con <- init_tracking_db(db_path, overwrite = TRUE)
  withr::defer(DBI::dbDisconnect(con))

  students <- register_students(
    con,
    c("student_002", "student_001"),
    timestamp = as.POSIXct("2026-01-01 10:00:00", tz = "UTC")
  )

  expect_s3_class(students, "tbl_df")
  expect_equal(students$student_id, c("student_001", "student_002"))
  expect_equal(students$student_label, c("student_001", "student_002"))
  expect_equal(students$created_at, rep("2026-01-01T10:00:00Z", 2))
})

test_that("register_students stores metadata and upserts existing rows", {
  db_path <- withr::local_tempfile(fileext = ".sqlite")
  con <- init_tracking_db(db_path, overwrite = TRUE)
  withr::defer(DBI::dbDisconnect(con))

  register_students(
    con,
    data.frame(
      student_id = "student_001",
      student_label = "Student 1",
      email = "student1@example.org",
      group_id = "A"
    )
  )
  register_students(
    con,
    data.frame(
      student_id = "student_001",
      student_label = "Student One",
      email = NA_character_,
      group_id = "B"
    )
  )

  students <- get_students(con, student_id = "student_001")

  expect_equal(nrow(students), 1)
  expect_equal(students$student_label, "Student One")
  expect_equal(students$email, "student1@example.org")
  expect_equal(students$group_id, "B")
})

test_that("get_students filters by student and group", {
  db_path <- withr::local_tempfile(fileext = ".sqlite")
  con <- init_tracking_db(db_path, overwrite = TRUE)
  withr::defer(DBI::dbDisconnect(con))

  register_students(
    con,
    data.frame(
      student_id = c("student_001", "student_002", "student_003"),
      group_id = c("A", "A", "B")
    )
  )

  expect_equal(nrow(get_students(con, student_id = "student_001")), 1)
  expect_equal(nrow(get_students(con, group_id = "A")), 2)
  expect_equal(nrow(get_students(con, student_id = "student_003", group_id = "A")), 0)
})

test_that("register_students validates input", {
  db_path <- withr::local_tempfile(fileext = ".sqlite")
  con <- init_tracking_db(db_path, overwrite = TRUE)
  withr::defer(DBI::dbDisconnect(con))

  expect_error(
    register_students(con, data.frame(label = "Student 1")),
    "student_id"
  )
  expect_error(
    register_students(con, c("student_001", "student_001")),
    "duplicated student identifiers"
  )
})
