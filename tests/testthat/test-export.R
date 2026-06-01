test_that("export_results writes attempts and scores CSV files", {
  db_path <- withr::local_tempfile(fileext = ".sqlite")
  attempts_path <- withr::local_tempfile(fileext = ".csv")
  scores_path <- withr::local_tempfile(fileext = ".csv")

  con <- init_tracking_db(db_path, overwrite = TRUE)
  withr::defer(DBI::dbDisconnect(con))

  track_attempt(
    con,
    "student_001",
    "module_01",
    "q1",
    "mean(x)",
    score = 1,
    max_score = 1
  )

  expect_invisible(export_results(con, attempts_path, type = "attempts"))
  expect_invisible(export_results(con, scores_path, type = "scores"))

  expect_true(file.exists(attempts_path))
  expect_true(file.exists(scores_path))

  attempts <- readr::read_csv(attempts_path, show_col_types = FALSE)
  scores <- readr::read_csv(scores_path, show_col_types = FALSE)

  expect_equal(nrow(attempts), 1)
  expect_equal(nrow(scores), 1)
  expect_true("submitted_answer" %in% names(attempts))
  expect_true("percent" %in% names(scores))
})
