test_that("init_tracking_db creates a SQLite file and required tables", {
  db_path <- withr::local_tempfile(fileext = ".sqlite")
  con <- init_tracking_db(db_path, overwrite = TRUE)
  withr::defer(DBI::dbDisconnect(con))

  expect_true(file.exists(db_path))
  expect_true(all(
    c("students", "courses", "tutorials", "questions", "sessions", "attempts") %in%
      DBI::dbListTables(con)
  ))
})

test_that("create_schema is idempotent", {
  db_path <- withr::local_tempfile(fileext = ".sqlite")
  con <- init_tracking_db(db_path, overwrite = TRUE)
  withr::defer(DBI::dbDisconnect(con))

  expect_no_error(create_schema(con))
  expect_no_error(create_schema(con))
})

test_that("connect_tracking_db connects to an existing schema", {
  db_path <- withr::local_tempfile(fileext = ".sqlite")
  con <- init_tracking_db(db_path, overwrite = TRUE)
  DBI::dbDisconnect(con)

  con <- connect_tracking_db(db_path)
  withr::defer(DBI::dbDisconnect(con))

  expect_true(DBI::dbIsValid(con))
})
