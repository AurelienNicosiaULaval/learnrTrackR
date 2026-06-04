test_that("teacher_report_data prepares report tables", {
  db_path <- withr::local_tempfile(fileext = ".sqlite")
  con <- init_tracking_db(db_path, overwrite = TRUE)
  withr::defer(DBI::dbDisconnect(con))

  register_students(con, c("student_001", "student_002"))
  register_questions(con, "module_01", c("q1", "q2"))
  track_attempt(con, "student_001", "module_01", "q1", "right", score = 1, max_score = 1)
  track_attempt(con, "student_002", "module_01", "q1", "wrong", score = 0, max_score = 1)

  report <- teacher_report_data(
    con,
    tutorial_id = "module_01",
    max_mean_percent = 60,
    max_student_percent = 40
  )

  expect_equal(report$tutorial_id, "module_01")
  expect_equal(report$rule, "last")
  expect_s3_class(report$summary, "tbl_df")
  expect_s3_class(report$questions, "tbl_df")
  expect_s3_class(report$students, "tbl_df")
  expect_s3_class(report$difficult_questions, "tbl_df")
  expect_s3_class(report$stalled_students, "tbl_df")
  expect_equal(
    report$summary$value[report$summary$metric == "n_students"],
    "2"
  )
  expect_true("q1" %in% report$difficult_questions$question_id)
  expect_equal(report$stalled_students$student_id, "student_002")
})

test_that("generate_teacher_report renders an HTML file", {
  skip_if_not_installed("rmarkdown")
  skip_if_not(rmarkdown::pandoc_available(), "Pandoc is required to render HTML reports.")

  db_path <- withr::local_tempfile(fileext = ".sqlite")
  report_path <- withr::local_tempfile(fileext = ".html")
  con <- init_tracking_db(db_path, overwrite = TRUE)
  withr::defer(DBI::dbDisconnect(con))

  register_questions(con, "module_01", c("q1", "q2"))
  track_attempt(con, "student_001", "module_01", "q1", "right", score = 1, max_score = 1)

  expect_invisible(
    generate_teacher_report(
      con,
      path = report_path,
      tutorial_id = "module_01"
    )
  )

  expect_true(file.exists(report_path))
  html <- paste(readLines(report_path, warn = FALSE), collapse = "\n")
  expect_match(html, "learnrTrackR teacher report", fixed = TRUE)
  expect_match(html, "Difficult Questions", fixed = TRUE)
  expect_match(html, "Student Summary", fixed = TRUE)
})

test_that("generate_teacher_report validates the output parent directory", {
  skip_if_not_installed("rmarkdown")

  db_path <- withr::local_tempfile(fileext = ".sqlite")
  con <- init_tracking_db(db_path, overwrite = TRUE)
  withr::defer(DBI::dbDisconnect(con))

  expect_error(
    generate_teacher_report(
      con,
      path = file.path(tempdir(), "missing-dir", "report.html"),
      tutorial_id = "module_01"
    ),
    "parent directory"
  )
})
