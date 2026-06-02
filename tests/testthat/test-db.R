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

test_that("SQL helpers generate backend-specific statements", {
  sqlite_con <- structure(list(), class = "SQLiteConnection")
  postgres_con <- structure(list(), class = "PqConnection")

  expect_match(schema_statements(sqlite_con)[[6]], "AUTOINCREMENT")
  expect_match(schema_statements(postgres_con)[[6]], "BIGSERIAL")
  expect_equal(
    tracking_db_statement(
      postgres_con,
      "WHERE student_id = ? AND tutorial_id = ? AND question_id = ?"
    ),
    "WHERE student_id = $1 AND tutorial_id = $2 AND question_id = $3"
  )
  expect_equal(
    tracking_db_statement(sqlite_con, "WHERE student_id = ?"),
    "WHERE student_id = ?"
  )
})

test_that("PostgreSQL backend works when a test DSN is configured", {
  skip_if_not_installed("RPostgres")

  dsn <- Sys.getenv("LEARNRTRACKR_TEST_POSTGRES_DSN", unset = "")
  skip_if(
    !nzchar(dsn),
    "Set LEARNRTRACKR_TEST_POSTGRES_DSN to run PostgreSQL integration tests."
  )

  schema_name <- paste0(
    "learnrtrackr_test_",
    gsub("[^A-Za-z0-9]", "", basename(tempfile()))
  )
  con <- DBI::dbConnect(RPostgres::Postgres(), dbname = dsn)
  withr::defer(DBI::dbDisconnect(con))
  withr::defer(
    DBI::dbExecute(
      con,
      paste("DROP SCHEMA IF EXISTS", schema_name, "CASCADE")
    )
  )

  DBI::dbExecute(con, paste("CREATE SCHEMA", schema_name))
  DBI::dbExecute(con, paste("SET search_path TO", schema_name))

  create_schema(con)
  register_students(con, data.frame(student_id = "student_001", group_id = "A"))
  register_questions(con, "module_01", c("q1", "q2"))

  first_id <- track_attempt(
    con,
    "student_001",
    "module_01",
    "q1",
    "mean(x)",
    score = 1,
    max_score = 1,
    require_registered_student = TRUE
  )

  attempts <- get_attempts(con, tutorial_id = "module_01")
  grades <- gradebook(con, tutorial_id = "module_01")

  expect_true(first_id >= 1L)
  expect_equal(nrow(attempts), 1)
  expect_equal(grades$n_questions, 2)
  expect_equal(grades$n_answered, 1)
})
